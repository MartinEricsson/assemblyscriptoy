// Cornell Box with Global Illumination (Path Tracing)
// Uses f32 only — progressive accumulation via frame count
// Adjust SAMPLES_PER_PIXEL and MAX_BOUNCES to trade noise vs speed
const WIDTH: i32 = 256;
const HEIGHT: i32 = 256;
const TIME_OFFSET: i32 = 0;

// ========== TUNABLE PARAMETERS ==========
const SAMPLES_PER_PIXEL: i32 = 100;   // rays per pixel per frame (more = less noise, slower)
const MAX_BOUNCES: i32 = 5;         // max light bounces (more = better GI, slower)
// =========================================

const PI: f32 = 3.14159265;
const TWO_PI: f32 = 6.28318530;
const INF: f32 = 1.0e20;
const EPSILON: f32 = 0.001;

// ---- f32-only math helpers (no i64/f64) ----
function sinF(x: f32): f32 {
  x = x - Mathf.floor(x / TWO_PI + 0.5) * TWO_PI;
  if (x > PI * 0.5) x = PI - x;
  if (x < -PI * 0.5) x = -PI - x;
  const x2: f32 = x * x;
  return x * (1.0 - x2 / 6.0 * (1.0 - x2 / 20.0 * (1.0 - x2 / 42.0)));
}
function cosF(x: f32): f32 { return sinF(x + PI * 0.5); }

function logF(x: f32): f32 {
  if (x <= 0.0) return -100.0;
  let n: i32 = 0;
  let m: f32 = x;
  while (m >= 2.0) { m *= 0.5; n++; }
  while (m < 1.0) { m *= 2.0; n--; }
  const t: f32 = (m - 1.0) / (m + 1.0);
  const t2: f32 = t * t;
  return <f32>n * 0.6931472 + 2.0 * t * (1.0 + t2 * (0.3333333 + t2 * 0.2));
}
function expF(x: f32): f32 {
  if (x < -20.0) return 0.0;
  if (x > 20.0) return 485165195.0;
  const n: f32 = Mathf.floor(x * 1.4426950);
  const f: f32 = x - n * 0.6931472;
  const ef: f32 = 1.0 + f * (1.0 + f * (0.5 + f * (0.1666667 + f * 0.04166667)));
  const ni: i32 = <i32>n;
  let p: f32 = 1.0;
  if (ni > 0) { for (let i: i32 = 0; i < ni; i++) p *= 2.0; }
  else { const nn: i32 = -ni; for (let i: i32 = 0; i < nn; i++) p *= 0.5; }
  return p * ef;
}
function powF(b: f32, e: f32): f32 {
  if (b <= 0.0) return 0.0;
  return expF(e * logF(b));
}

function clampF(v: f32, lo: f32, hi: f32): f32 { return Mathf.min(Mathf.max(v, lo), hi); }

// ---- Pseudo-random hash (PCG-style, u32 only) ----
let rngState: u32 = 0;

function initRng(px: i32, py: i32, frame: i32): void {
  rngState = <u32>(px * 1973 + py * 9277 + frame * 26699) | 1;
  // warm up
  randU32();
  randU32();
}

function randU32(): u32 {
  rngState = rngState * 747796405 + 2891336453;
  const word: u32 = ((rngState >> ((rngState >> 28) + 4)) ^ rngState) * 277803737;
  rngState = (word >> 22) ^ word;
  return rngState;
}

function randF(): f32 {
  return <f32>randU32() / 4294967296.0;
}

// ---- Cosine-weighted hemisphere sampling ----
function sampleHemisphere(nx: f32, ny: f32, nz: f32): f32 {
  // Returns direction in global coords; we store it via globals
  const r1: f32 = randF();
  const r2: f32 = randF();
  const sqR2: f32 = Mathf.sqrt(r2);
  const phi: f32 = TWO_PI * r1;

  // Build tangent frame
  let tx: f32; let ty: f32; let tz: f32;
  if (Mathf.abs(ny) > 0.9) {
    // normal ~aligned with Y (floor/ceiling), use X-axis as helper
    // t = normalize(n × (1,0,0)) = normalize(0, nz, -ny)
    const invLen: f32 = 1.0 / Mathf.sqrt(nz * nz + ny * ny);
    tx = 0.0; ty = nz * invLen; tz = -ny * invLen;
  } else {
    // use Y-axis as helper
    // t = normalize(n × (0,1,0)) = normalize(-nz, 0, nx)
    const invLen: f32 = 1.0 / Mathf.sqrt(nz * nz + nx * nx);
    tx = -nz * invLen; ty = 0.0; tz = nx * invLen;
  }
  // bi-tangent = n x t
  const bx: f32 = ny * tz - nz * ty;
  const by: f32 = nz * tx - nx * tz;
  const bz: f32 = nx * ty - ny * tx;

  const cosTheta: f32 = Mathf.sqrt(1.0 - r2);
  const sinTheta: f32 = sqR2;
  const cosPhi: f32 = cosF(phi);
  const sinPhi: f32 = sinF(phi);

  hemDirX = tx * sinTheta * cosPhi + bx * sinTheta * sinPhi + nx * cosTheta;
  hemDirY = ty * sinTheta * cosPhi + by * sinTheta * sinPhi + ny * cosTheta;
  hemDirZ = tz * sinTheta * cosPhi + bz * sinTheta * sinPhi + nz * cosTheta;
  return 0.0; // dummy return; result in globals
}

// Globals for hemisphere sample direction
let hemDirX: f32 = 0.0;
let hemDirY: f32 = 0.0;
let hemDirZ: f32 = 0.0;

// ---- Ray-AABB intersection (slab method) ----
// Returns t >= 0 on hit, sets hitNormal globals; < 0 on miss
let hitNx: f32 = 0.0;
let hitNy: f32 = 0.0;
let hitNz: f32 = 0.0;

function intersectAABB(
  ox: f32, oy: f32, oz: f32,
  dx: f32, dy: f32, dz: f32,
  minX: f32, minY: f32, minZ: f32,
  maxX: f32, maxY: f32, maxZ: f32
): f32 {
  let tmin: f32 = -INF;
  let tmax: f32 = INF;
  let nxT: f32 = 0.0; let nyT: f32 = 0.0; let nzT: f32 = 0.0;
  let nxE: f32 = 0.0; let nyE: f32 = 0.0; let nzE: f32 = 0.0;

  // X slab
  if (Mathf.abs(dx) > 1.0e-8) {
    let t1: f32 = (minX - ox) / dx;
    let t2: f32 = (maxX - ox) / dx;
    let n1x: f32 = -1.0; let n2x: f32 = 1.0;
    if (t1 > t2) {
      const tmp: f32 = t1; t1 = t2; t2 = tmp;
      n1x = 1.0; n2x = -1.0;
    }
    if (t1 > tmin) { tmin = t1; nxT = n1x; nyT = 0.0; nzT = 0.0; }
    if (t2 < tmax) { tmax = t2; nxE = n2x; nyE = 0.0; nzE = 0.0; }
  } else {
    if (ox < minX || ox > maxX) return -1.0;
  }
  // Y slab
  if (Mathf.abs(dy) > 1.0e-8) {
    let t1: f32 = (minY - oy) / dy;
    let t2: f32 = (maxY - oy) / dy;
    let n1y: f32 = -1.0; let n2y: f32 = 1.0;
    if (t1 > t2) {
      const tmp: f32 = t1; t1 = t2; t2 = tmp;
      n1y = 1.0; n2y = -1.0;
    }
    if (t1 > tmin) { tmin = t1; nxT = 0.0; nyT = n1y; nzT = 0.0; }
    if (t2 < tmax) { tmax = t2; nxE = 0.0; nyE = n2y; nzE = 0.0; }
  } else {
    if (oy < minY || oy > maxY) return -1.0;
  }
  // Z slab
  if (Mathf.abs(dz) > 1.0e-8) {
    let t1: f32 = (minZ - oz) / dz;
    let t2: f32 = (maxZ - oz) / dz;
    let n1z: f32 = -1.0; let n2z: f32 = 1.0;
    if (t1 > t2) {
      const tmp: f32 = t1; t1 = t2; t2 = tmp;
      n1z = 1.0; n2z = -1.0;
    }
    if (t1 > tmin) { tmin = t1; nxT = 0.0; nyT = 0.0; nzT = n1z; }
    if (t2 < tmax) { tmax = t2; nxE = 0.0; nyE = 0.0; nzE = n2z; }
  } else {
    if (oz < minZ || oz > maxZ) return -1.0;
  }

  if (tmin > tmax || tmax < 0.0) return -1.0;
  if (tmin < EPSILON) {
    // inside the box — use exit normal (tmax)
    hitNx = nxE; hitNy = nyE; hitNz = nzE;
    return tmax;
  }
  hitNx = nxT; hitNy = nyT; hitNz = nzT;
  return tmin;
}

// ---- Ray-Sphere intersection ----
function intersectSphere(
  ox: f32, oy: f32, oz: f32,
  dx: f32, dy: f32, dz: f32,
  cx: f32, cy: f32, cz: f32, r: f32
): f32 {
  const ex: f32 = ox - cx; const ey: f32 = oy - cy; const ez: f32 = oz - cz;
  const b: f32 = ex * dx + ey * dy + ez * dz;
  const c: f32 = ex * ex + ey * ey + ez * ez - r * r;
  let disc: f32 = b * b - c;
  if (disc < 0.0) return -1.0;
  disc = Mathf.sqrt(disc);
  let t: f32 = -b - disc;
  if (t < EPSILON) t = -b + disc;
  if (t < EPSILON) return -1.0;
  // Compute normal
  hitNx = (ox + dx * t - cx) / r;
  hitNy = (oy + dy * t - cy) / r;
  hitNz = (oz + dz * t - cz) / r;
  return t;
}

// ---- Scene definition (Cornell Box) ----
// Box extents: x in [-1,1], y in [-1,1], z in [-1,3]
// Camera at (0, 0, -0.9) looking +Z

// Hit info globals
let sceneT: f32 = 0.0;
let sceneNx: f32 = 0.0;
let sceneNy: f32 = 0.0;
let sceneNz: f32 = 0.0;
let sceneMatR: f32 = 0.0;
let sceneMatG: f32 = 0.0;
let sceneMatB: f32 = 0.0;
let sceneEmitR: f32 = 0.0;
let sceneEmitG: f32 = 0.0;
let sceneEmitB: f32 = 0.0;

function traceScene(ox: f32, oy: f32, oz: f32, dx: f32, dy: f32, dz: f32): bool {
  let bestT: f32 = INF;
  let bestNx: f32 = 0.0; let bestNy: f32 = 0.0; let bestNz: f32 = 0.0;
  let matR: f32 = 0.0; let matG: f32 = 0.0; let matB: f32 = 0.0;
  let emR: f32 = 0.0; let emG: f32 = 0.0; let emB: f32 = 0.0;

  // --- Back wall (z = 3) ---
  if (Mathf.abs(dz) > 1.0e-8) {
    const tw: f32 = (3.0 - oz) / dz;
    if (tw > EPSILON && tw < bestT) {
      const hx: f32 = ox + dx * tw; const hy: f32 = oy + dy * tw;
      if (hx >= -1.0 && hx <= 1.0 && hy >= -1.0 && hy <= 1.0) {
        bestT = tw; bestNx = 0.0; bestNy = 0.0; bestNz = -1.0;
        matR = 0.73; matG = 0.73; matB = 0.73;
        emR = 0.0; emG = 0.0; emB = 0.0;
      }
    }
  }

  // --- Front wall (z = -1) ---
  if (Mathf.abs(dz) > 1.0e-8) {
    const twf: f32 = (-1.0 - oz) / dz;
    if (twf > EPSILON && twf < bestT) {
      const hx: f32 = ox + dx * twf; const hy: f32 = oy + dy * twf;
      if (hx >= -1.0 && hx <= 1.0 && hy >= -1.0 && hy <= 1.0) {
        bestT = twf; bestNx = 0.0; bestNy = 0.0; bestNz = 1.0;
        matR = 0.73; matG = 0.73; matB = 0.73;
        emR = 0.0; emG = 0.0; emB = 0.0;
      }
    }
  }

  // --- Floor (y = -1) ---
  if (Mathf.abs(dy) > 1.0e-8) {
    const tf: f32 = (-1.0 - oy) / dy;
    if (tf > EPSILON && tf < bestT) {
      const hx: f32 = ox + dx * tf; const hz: f32 = oz + dz * tf;
      if (hx >= -1.0 && hx <= 1.0 && hz >= -1.0 && hz <= 3.0) {
        bestT = tf; bestNx = 0.0; bestNy = 1.0; bestNz = 0.0;
        matR = 0.73; matG = 0.73; matB = 0.73;
        emR = 0.0; emG = 0.0; emB = 0.0;
      }
    }
  }

  // --- Ceiling (y = 1) ---
  if (Mathf.abs(dy) > 1.0e-8) {
    const tc: f32 = (1.0 - oy) / dy;
    if (tc > EPSILON && tc < bestT) {
      const hx: f32 = ox + dx * tc; const hz: f32 = oz + dz * tc;
      if (hx >= -1.0 && hx <= 1.0 && hz >= -1.0 && hz <= 3.0) {
        bestT = tc; bestNx = 0.0; bestNy = -1.0; bestNz = 0.0;
        matR = 0.73; matG = 0.73; matB = 0.73;
        emR = 0.0; emG = 0.0; emB = 0.0;
      }
    }
  }

  // --- Left wall (x = -1) — RED ---
  if (Mathf.abs(dx) > 1.0e-8) {
    const tl: f32 = (-1.0 - ox) / dx;
    if (tl > EPSILON && tl < bestT) {
      const hy: f32 = oy + dy * tl; const hz: f32 = oz + dz * tl;
      if (hy >= -1.0 && hy <= 1.0 && hz >= -1.0 && hz <= 3.0) {
        bestT = tl; bestNx = 1.0; bestNy = 0.0; bestNz = 0.0;
        matR = 0.65; matG = 0.05; matB = 0.05;
        emR = 0.0; emG = 0.0; emB = 0.0;
      }
    }
  }

  // --- Right wall (x = 1) — GREEN ---
  if (Mathf.abs(dx) > 1.0e-8) {
    const tr: f32 = (1.0 - ox) / dx;
    if (tr > EPSILON && tr < bestT) {
      const hy: f32 = oy + dy * tr; const hz: f32 = oz + dz * tr;
      if (hy >= -1.0 && hy <= 1.0 && hz >= -1.0 && hz <= 3.0) {
        bestT = tr; bestNx = -1.0; bestNy = 0.0; bestNz = 0.0;
        matR = 0.12; matG = 0.45; matB = 0.15;
        emR = 0.0; emG = 0.0; emB = 0.0;
      }
    }
  }

  // --- Ceiling light (emissive quad, y = 0.99, small patch) ---
  if (Mathf.abs(dy) > 1.0e-8) {
    const tlgt: f32 = (0.99 - oy) / dy;
    if (tlgt > EPSILON && tlgt < bestT) {
      const hx: f32 = ox + dx * tlgt; const hz: f32 = oz + dz * tlgt;
      if (hx >= -0.35 && hx <= 0.35 && hz >= 0.7 && hz <= 1.4) {
        bestT = tlgt; bestNx = 0.0; bestNy = -1.0; bestNz = 0.0;
        matR = 0.78; matG = 0.78; matB = 0.78;
        emR = 18.0; emG = 16.0; emB = 10.0;
      }
    }
  }

  // --- Tall box (right side) ---
  const t5: f32 = intersectAABB(ox, oy, oz, dx, dy, dz,
    0.13, -1.0, 0.65, 0.73, 0.2, 1.25);
  if (t5 > EPSILON && t5 < bestT) {
    bestT = t5; bestNx = hitNx; bestNy = hitNy; bestNz = hitNz;
    matR = 0.73; matG = 0.73; matB = 0.73;
    emR = 0.0; emG = 0.0; emB = 0.0;
  }

  // --- Short box (left side) ---
  const t6: f32 = intersectAABB(ox, oy, oz, dx, dy, dz,
    -0.73, -1.0, 1.1, -0.13, -0.4, 1.7);
  if (t6 > EPSILON && t6 < bestT) {
    bestT = t6; bestNx = hitNx; bestNy = hitNy; bestNz = hitNz;
    matR = 0.73; matG = 0.73; matB = 0.73;
    emR = 0.0; emG = 0.0; emB = 0.0;
  }

  // --- Glass sphere (left) ---
  const ts1: f32 = intersectSphere(ox, oy, oz, dx, dy, dz,
    -0.43, -0.65, 1.4, 0.35);
  if (ts1 > EPSILON && ts1 < bestT) {
    bestT = ts1; bestNx = hitNx; bestNy = hitNy; bestNz = hitNz;
    matR = 0.9; matG = 0.9; matB = 0.95;
    emR = 0.0; emG = 0.0; emB = 0.0;
  }

  // --- Metal sphere (right, on tall box) ---
  const ts2: f32 = intersectSphere(ox, oy, oz, dx, dy, dz,
    0.43, 0.45, 0.95, 0.25);
  if (ts2 > EPSILON && ts2 < bestT) {
    bestT = ts2; bestNx = hitNx; bestNy = hitNy; bestNz = hitNz;
    matR = 0.95; matG = 0.75; matB = 0.4;
    emR = 0.0; emG = 0.0; emB = 0.0;
  }

  if (bestT >= INF) return false;

  sceneT = bestT;
  sceneNx = bestNx; sceneNy = bestNy; sceneNz = bestNz;
  sceneMatR = matR; sceneMatG = matG; sceneMatB = matB;
  sceneEmitR = emR; sceneEmitG = emG; sceneEmitB = emB;
  return true;
}

// ---- Path trace one ray ----
function pathTrace(ox: f32, oy: f32, oz: f32, dx: f32, dy: f32, dz: f32): f32 {
  // Output colour stored in globals
  let accumR: f32 = 0.0; let accumG: f32 = 0.0; let accumB: f32 = 0.0;
  let throughR: f32 = 1.0; let throughG: f32 = 1.0; let throughB: f32 = 1.0;

  let rox: f32 = ox; let roy: f32 = oy; let roz: f32 = oz;
  let rdx: f32 = dx; let rdy: f32 = dy; let rdz: f32 = dz;

  for (let bounce: i32 = 0; bounce < MAX_BOUNCES; bounce++) {
    if (!traceScene(rox, roy, roz, rdx, rdy, rdz)) {
      // Miss — no contribution (enclosed box, shouldn't happen often)
      break;
    }

    // Add emission
    accumR += throughR * sceneEmitR;
    accumG += throughG * sceneEmitG;
    accumB += throughB * sceneEmitB;

    // If we hit a light, stop bouncing
    if (sceneEmitR + sceneEmitG + sceneEmitB > 0.0) break;

    // Hit point
    const hx: f32 = rox + rdx * sceneT;
    const hy: f32 = roy + rdy * sceneT;
    const hz: f32 = roz + rdz * sceneT;
    const nx: f32 = sceneNx; const ny: f32 = sceneNy; const nz: f32 = sceneNz;

    // Attenuate throughput by material albedo
    throughR *= sceneMatR;
    throughG *= sceneMatG;
    throughB *= sceneMatB;

    // Russian roulette (after 2 bounces)
    if (bounce > 1) {
      const pContinue: f32 = Mathf.max(throughR, Mathf.max(throughG, throughB));
      if (randF() > pContinue) break;
      const invP: f32 = 1.0 / pContinue;
      throughR *= invP; throughG *= invP; throughB *= invP;
    }

    // Generate new direction (cosine-weighted) — implicit BRDF factor cancels with PDF
    sampleHemisphere(nx, ny, nz);
    rdx = hemDirX; rdy = hemDirY; rdz = hemDirZ;
    rox = hx + nx * EPSILON;
    roy = hy + ny * EPSILON;
    roz = hz + nz * EPSILON;
  }

  ptResultR = accumR;
  ptResultG = accumG;
  ptResultB = accumB;
  return 0.0;
}

let ptResultR: f32 = 0.0;
let ptResultG: f32 = 0.0;
let ptResultB: f32 = 0.0;

// ---- Entry point ----
export function main(): void {
  const frame: f32 = load<f32>(TIME_OFFSET);
  const frameI: i32 = <i32>frame;
  const invW: f32 = 1.0 / <f32>WIDTH;
  const invH: f32 = 1.0 / <f32>HEIGHT;

  // Camera
  const camOX: f32 = 0.0;
  const camOY: f32 = 0.0;
  const camOZ: f32 = -0.9;
  const fov: f32 = 1.2; // roughly 67 degrees half-angle

  for (let i: i32 = 0; i < WIDTH * HEIGHT; i++) {
    const px: i32 = i % WIDTH;
    const py: i32 = i / WIDTH;

    initRng(px, py, frameI);

    let colR: f32 = 0.0; let colG: f32 = 0.0; let colB: f32 = 0.0;

    for (let s: i32 = 0; s < SAMPLES_PER_PIXEL; s++) {
      // Jittered UV
      const uvx: f32 = (2.0 * (<f32>px + randF()) * invW - 1.0) * fov;
      const uvy: f32 = -(2.0 * (<f32>py + randF()) * invH - 1.0) * fov;

      // Ray direction (pinhole camera looking +Z)
      let rdx: f32 = uvx;
      let rdy: f32 = uvy;
      let rdz: f32 = 1.0;
      const rlen: f32 = Mathf.sqrt(rdx * rdx + rdy * rdy + rdz * rdz);
      rdx /= rlen; rdy /= rlen; rdz /= rlen;

      pathTrace(camOX, camOY, camOZ, rdx, rdy, rdz);

      colR += ptResultR;
      colG += ptResultG;
      colB += ptResultB;
    }

    const invSamples: f32 = 1.0 / <f32>SAMPLES_PER_PIXEL;
    colR *= invSamples;
    colG *= invSamples;
    colB *= invSamples;

    // Tone-map (Reinhard) + gamma
    colR = colR / (colR + 1.0);
    colG = colG / (colG + 1.0);
    colB = colB / (colB + 1.0);
    colR = powF(colR, 0.4545);
    colG = powF(colG, 0.4545);
    colB = powF(colB, 0.4545);

    const off: i32 = 16 + i * 12;
    store<i32>(off, <i32>(clampF(colR, 0.0, 1.0) * 255.0));
    store<i32>(off + 4, <i32>(clampF(colG, 0.0, 1.0) * 255.0));
    store<i32>(off + 8, <i32>(clampF(colB, 0.0, 1.0) * 255.0));
  }
}
