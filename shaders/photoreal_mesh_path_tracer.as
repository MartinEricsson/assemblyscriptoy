// ============================================================
// Photoreal Mesh Path Tracer - packed triangles + threaded BVH
// ============================================================
// The host packs a deterministic product-studio mesh, materials,
// and stackless BVH into persistent memory before the first dispatch.
// This shader path traces one jittered sample per 256x256 pixel and
// accumulates f32 radiance over time in persistent memory. To avoid
// long-running WebGPU dispatches on integrated GPUs, each frame updates
// one 4x4 pixel phase and leaves the other output pixels resident.
// ============================================================

const WIDTH: i32 = 256;
const FIELD: i32 = 256;
const CELLS: i32 = FIELD * FIELD;
const STATE_OFFSET: i32 = 16 + WIDTH * WIDTH * 12;
const MAGIC: i32 = 0x504d4256; // PMBV
const MATERIAL_STRIDE: i32 = 32;
const TRIANGLE_STRIDE: i32 = 64;
const NODE_STRIDE: i32 = 48;
const TILE_PHASES: i32 = 16;
const MAX_BVH_VISITS: i32 = 512;
const MAX_BOUNCES: i32 = 2;
const EPSILON: f32 = 0.003;
const INF: f32 = 100000.0;
const PI: f32 = 3.14159265;
const TWO_PI: f32 = 6.28318530;
const LIGHT_Y: f32 = 2.85;
const LIGHT_AREA: f32 = 3.90;

let rngState: u32 = 1;
let sampleX: f32 = 0.0;
let sampleY: f32 = 0.0;
let sampleZ: f32 = 1.0;
let hitT: f32 = 0.0;
let hitNX: f32 = 0.0;
let hitNY: f32 = 1.0;
let hitNZ: f32 = 0.0;
let hitMaterial: i32 = -1;
let pathR: f32 = 0.0;
let pathG: f32 = 0.0;
let pathB: f32 = 0.0;

function clampF(value: f32, low: f32, high: f32): f32 {
  return Mathf.min(Mathf.max(value, low), high);
}

function saturate(value: f32): f32 {
  return clampF(value, 0.0, 1.0);
}

function mixF(a: f32, b: f32, amount: f32): f32 {
  return a + (b - a) * amount;
}

function sinF(x: f32): f32 {
  x = x - Mathf.floor(x / TWO_PI + 0.5) * TWO_PI;
  if (x > PI * 0.5) x = PI - x;
  if (x < -PI * 0.5) x = -PI - x;
  const x2: f32 = x * x;
  return x * (1.0 - x2 / 6.0 * (1.0 - x2 / 20.0 * (1.0 - x2 / 42.0)));
}

function cosF(x: f32): f32 {
  return sinF(x + PI * 0.5);
}

function hashU(value: u32): u32 {
  let state: u32 = value * 747796405 + 2891336453;
  const word: u32 = ((state >> ((state >> 28) + 4)) ^ state) * 277803737;
  return (word >> 22) ^ word;
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

function initRng(cellX: i32, cellY: i32, sampleIndex: i32, frame: i32): void {
  rngState = <u32>(cellX * 1973 + cellY * 9277 + sampleIndex * 26699 + frame * 31847) | 1;
  rngState = hashU(rngState);
  randU32();
  randU32();
}

function materialOffset(): i32 { return load<i32>(STATE_OFFSET + 20); }
function triangleOffset(): i32 { return load<i32>(STATE_OFFSET + 24); }
function nodeOffset(): i32 { return load<i32>(STATE_OFFSET + 28); }
function accumOffset(): i32 { return load<i32>(STATE_OFFSET + 32); }

function materialBase(material: i32): i32 {
  return materialOffset() + material * MATERIAL_STRIDE;
}

function triangleBase(triangle: i32): i32 {
  return triangleOffset() + triangle * TRIANGLE_STRIDE;
}

function nodeBase(node: i32): i32 {
  return nodeOffset() + node * NODE_STRIDE;
}

function nextMissNode(current: i32, miss: i32, nodeCount: i32): i32 {
  if (miss < 0) return -1;
  return miss > current ? miss : nodeCount;
}

function writePixel(x: i32, y: i32, r: i32, g: i32, b: i32): void {
  const pixel: i32 = y * WIDTH + x;
  const offset: i32 = 16 + pixel * 12;
  store<i32>(offset, r);
  store<i32>(offset + 4, g);
  store<i32>(offset + 8, b);
}

function hitAabb(
  base: i32,
  ox: f32, oy: f32, oz: f32,
  dx: f32, dy: f32, dz: f32,
  maxT: f32,
): bool {
  let tMin: f32 = EPSILON;
  let tMax: f32 = maxT;
  let minV: f32;
  let maxV: f32;
  let t1: f32;
  let t2: f32;
  let tmp: f32;

  minV = load<f32>(base);
  maxV = load<f32>(base + 12);
  if (Mathf.abs(dx) < 0.000001) {
    if (ox < minV || ox > maxV) return false;
  } else {
    t1 = (minV - ox) / dx;
    t2 = (maxV - ox) / dx;
    if (t1 > t2) { tmp = t1; t1 = t2; t2 = tmp; }
    tMin = Mathf.max(tMin, t1);
    tMax = Mathf.min(tMax, t2);
    if (tMax < tMin) return false;
  }

  minV = load<f32>(base + 4);
  maxV = load<f32>(base + 16);
  if (Mathf.abs(dy) < 0.000001) {
    if (oy < minV || oy > maxV) return false;
  } else {
    t1 = (minV - oy) / dy;
    t2 = (maxV - oy) / dy;
    if (t1 > t2) { tmp = t1; t1 = t2; t2 = tmp; }
    tMin = Mathf.max(tMin, t1);
    tMax = Mathf.min(tMax, t2);
    if (tMax < tMin) return false;
  }

  minV = load<f32>(base + 8);
  maxV = load<f32>(base + 20);
  if (Mathf.abs(dz) < 0.000001) {
    if (oz < minV || oz > maxV) return false;
  } else {
    t1 = (minV - oz) / dz;
    t2 = (maxV - oz) / dz;
    if (t1 > t2) { tmp = t1; t1 = t2; t2 = tmp; }
    tMin = Mathf.max(tMin, t1);
    tMax = Mathf.min(tMax, t2);
    if (tMax < tMin) return false;
  }

  return true;
}

function intersectTriangle(
  tri: i32,
  ox: f32, oy: f32, oz: f32,
  dx: f32, dy: f32, dz: f32,
  maxT: f32,
): f32 {
  const base: i32 = triangleBase(tri);
  const v0x: f32 = load<f32>(base);
  const v0y: f32 = load<f32>(base + 4);
  const v0z: f32 = load<f32>(base + 8);
  const e1x: f32 = load<f32>(base + 12);
  const e1y: f32 = load<f32>(base + 16);
  const e1z: f32 = load<f32>(base + 20);
  const e2x: f32 = load<f32>(base + 24);
  const e2y: f32 = load<f32>(base + 28);
  const e2z: f32 = load<f32>(base + 32);

  const px: f32 = dy * e2z - dz * e2y;
  const py: f32 = dz * e2x - dx * e2z;
  const pz: f32 = dx * e2y - dy * e2x;
  const det: f32 = e1x * px + e1y * py + e1z * pz;
  if (Mathf.abs(det) < 0.0000008) return -1.0;
  const invDet: f32 = 1.0 / det;

  const tx: f32 = ox - v0x;
  const ty: f32 = oy - v0y;
  const tz: f32 = oz - v0z;
  const u: f32 = (tx * px + ty * py + tz * pz) * invDet;
  if (u < 0.0 || u > 1.0) return -1.0;

  const qx: f32 = ty * e1z - tz * e1y;
  const qy: f32 = tz * e1x - tx * e1z;
  const qz: f32 = tx * e1y - ty * e1x;
  const v: f32 = (dx * qx + dy * qy + dz * qz) * invDet;
  if (v < 0.0 || u + v > 1.0) return -1.0;

  const t: f32 = (e2x * qx + e2y * qy + e2z * qz) * invDet;
  if (t <= EPSILON || t >= maxT) return -1.0;
  return t;
}

function setHitFromTriangle(tri: i32, dx: f32, dy: f32, dz: f32): void {
  const base: i32 = triangleBase(tri);
  let nx: f32 = load<f32>(base + 36);
  let ny: f32 = load<f32>(base + 40);
  let nz: f32 = load<f32>(base + 44);
  if (nx * dx + ny * dy + nz * dz > 0.0) {
    nx = -nx;
    ny = -ny;
    nz = -nz;
  }
  hitNX = nx;
  hitNY = ny;
  hitNZ = nz;
  hitMaterial = load<i32>(base + 48);
}

function traceScene(
  ox: f32, oy: f32, oz: f32,
  dx: f32, dy: f32, dz: f32,
  maxT: f32,
): bool {
  const nodeCount: i32 = load<i32>(STATE_OFFSET + 16);
  let node: i32 = 0;
  let best: f32 = maxT;
  let bestTri: i32 = -1;
  let visits: i32 = 0;

  while (node >= 0 && node < nodeCount && visits < MAX_BVH_VISITS) {
    visits++;
    const base: i32 = nodeBase(node);
    const miss: i32 = load<i32>(base + 32);
    const missNode: i32 = nextMissNode(node, miss, nodeCount);
    if (hitAabb(base, ox, oy, oz, dx, dy, dz, best)) {
      const count: i32 = load<i32>(base + 28);
      if (count > 0) {
        const first: i32 = load<i32>(base + 24);
        for (let i: i32 = 0; i < count; i++) {
          const t: f32 = intersectTriangle(first + i, ox, oy, oz, dx, dy, dz, best);
          if (t > 0.0) {
            best = t;
            bestTri = first + i;
          }
        }
        node = missNode;
      } else {
        node++;
      }
    } else {
      node = missNode;
    }
  }

  if (bestTri < 0) return false;
  hitT = best;
  setHitFromTriangle(bestTri, dx, dy, dz);
  return true;
}

function traceAny(
  ox: f32, oy: f32, oz: f32,
  dx: f32, dy: f32, dz: f32,
  maxT: f32,
): bool {
  const nodeCount: i32 = load<i32>(STATE_OFFSET + 16);
  let node: i32 = 0;
  let visits: i32 = 0;

  while (node >= 0 && node < nodeCount && visits < MAX_BVH_VISITS) {
    visits++;
    const base: i32 = nodeBase(node);
    const miss: i32 = load<i32>(base + 32);
    const missNode: i32 = nextMissNode(node, miss, nodeCount);
    if (hitAabb(base, ox, oy, oz, dx, dy, dz, maxT)) {
      const count: i32 = load<i32>(base + 28);
      if (count > 0) {
        const first: i32 = load<i32>(base + 24);
        for (let i: i32 = 0; i < count; i++) {
          if (intersectTriangle(first + i, ox, oy, oz, dx, dy, dz, maxT) > 0.0) {
            return true;
          }
        }
        node = missNode;
      } else {
        node++;
      }
    } else {
      node = missNode;
    }
  }

  return false;
}

function sampleCosineHemisphere(nx: f32, ny: f32, nz: f32): void {
  const r1: f32 = randF();
  const r2: f32 = randF();
  const phi: f32 = TWO_PI * r1;
  const radius: f32 = Mathf.sqrt(r2);
  const localX: f32 = cosF(phi) * radius;
  const localY: f32 = sinF(phi) * radius;
  const localZ: f32 = Mathf.sqrt(Mathf.max(0.0, 1.0 - r2));

  let tx: f32;
  let ty: f32;
  let tz: f32;
  if (Mathf.abs(ny) > 0.88) {
    const invLen: f32 = 1.0 / Mathf.sqrt(nx * nx + ny * ny);
    tx = ny * invLen;
    ty = -nx * invLen;
    tz = 0.0;
  } else {
    const invLen2: f32 = 1.0 / Mathf.sqrt(nz * nz + nx * nx);
    tx = -nz * invLen2;
    ty = 0.0;
    tz = nx * invLen2;
  }
  const bx: f32 = ny * tz - nz * ty;
  const by: f32 = nz * tx - nx * tz;
  const bz: f32 = nx * ty - ny * tx;

  sampleX = tx * localX + bx * localY + nx * localZ;
  sampleY = ty * localX + by * localY + ny * localZ;
  sampleZ = tz * localX + bz * localY + nz * localZ;
}

function tracePath(
  ox0: f32, oy0: f32, oz0: f32,
  dx0: f32, dy0: f32, dz0: f32,
): void {
  let ox: f32 = ox0;
  let oy: f32 = oy0;
  let oz: f32 = oz0;
  let dx: f32 = dx0;
  let dy: f32 = dy0;
  let dz: f32 = dz0;
  let throughR: f32 = 1.0;
  let throughG: f32 = 1.0;
  let throughB: f32 = 1.0;
  let accumR: f32 = 0.0;
  let accumG: f32 = 0.0;
  let accumB: f32 = 0.0;

  for (let bounce: i32 = 0; bounce < MAX_BOUNCES; bounce++) {
    if (!traceScene(ox, oy, oz, dx, dy, dz, INF)) {
      const sky: f32 = saturate(0.55 + dy * 0.45);
      accumR += throughR * (0.44 + sky * 0.20);
      accumG += throughG * (0.42 + sky * 0.18);
      accumB += throughB * (0.37 + sky * 0.15);
      break;
    }

    const hx: f32 = ox + dx * hitT;
    const hy: f32 = oy + dy * hitT;
    const hz: f32 = oz + dz * hitT;
    const nx: f32 = hitNX;
    const ny: f32 = hitNY;
    const nz: f32 = hitNZ;
    const mat: i32 = hitMaterial;
    const mb: i32 = materialBase(mat);
    const baseR: f32 = load<f32>(mb);
    const baseG: f32 = load<f32>(mb + 4);
    const baseB: f32 = load<f32>(mb + 8);
    const roughness: f32 = load<f32>(mb + 12);
    const metallic: f32 = load<f32>(mb + 16);
    const emitR: f32 = load<f32>(mb + 20);
    const emitG: f32 = load<f32>(mb + 24);
    const emitB: f32 = load<f32>(mb + 28);

    if (emitR + emitG + emitB > 0.0) {
      accumR += throughR * emitR;
      accumG += throughG * emitG;
      accumB += throughB * emitB;
      break;
    }

    const fill: f32 = (0.010 + 0.024 * saturate(ny * 0.5 + 0.5)) * (1.0 - metallic * 0.30);
    accumR += throughR * baseR * fill;
    accumG += throughG * baseG * fill;
    accumB += throughB * baseB * fill;

    const lightX: f32 = -1.9 + randF() * 2.6;
    const lightZ: f32 = 0.35 + randF() * 1.5;
    const toLX: f32 = lightX - hx;
    const toLY: f32 = LIGHT_Y - hy;
    const toLZ: f32 = lightZ - hz;
    const lightDist2: f32 = toLX * toLX + toLY * toLY + toLZ * toLZ;
    const lightDist: f32 = Mathf.sqrt(lightDist2);
    const ldx: f32 = toLX / lightDist;
    const ldy: f32 = toLY / lightDist;
    const ldz: f32 = toLZ / lightDist;
    const cosSurface: f32 = saturate(nx * ldx + ny * ldy + nz * ldz);
    const cosLight: f32 = saturate(-ldy);

    if (cosSurface > 0.0 && cosLight > 0.0) {
      const sx: f32 = hx + nx * EPSILON;
      const sy: f32 = hy + ny * EPSILON;
      const sz: f32 = hz + nz * EPSILON;
      if (!traceAny(sx, sy, sz, ldx, ldy, ldz, lightDist - 0.012)) {
        const direct: f32 = (cosSurface * cosLight * LIGHT_AREA) / (PI * lightDist2);
        const diffuseWeight: f32 = 1.0 - metallic * 0.65;
        accumR += throughR * baseR * 10.5 * direct * diffuseWeight;
        accumG += throughG * baseG * 9.0 * direct * diffuseWeight;
        accumB += throughB * baseB * 6.2 * direct * diffuseWeight;

        const anisotropy: f32 = mat == 1 ? 0.82 : (mat == 2 ? 0.55 : 0.0);
        if (anisotropy > 0.0) {
          let tx: f32 = -nz;
          let ty: f32 = 0.0;
          let tz: f32 = nx;
          let tLen: f32 = Mathf.sqrt(tx * tx + tz * tz);
          if (tLen < 0.001) {
            tx = 1.0;
            ty = 0.0;
            tz = 0.0;
            tLen = 1.0;
          }
          tx /= tLen;
          tz /= tLen;
          const bx: f32 = ny * tz - nz * ty;
          const by: f32 = nz * tx - nx * tz;
          const bz: f32 = nx * ty - ny * tx;

          const vx: f32 = -dx;
          const vy: f32 = -dy;
          const vz: f32 = -dz;
          let hxv: f32 = ldx + vx;
          let hyv: f32 = ldy + vy;
          let hzv: f32 = ldz + vz;
          let hLen: f32 = Mathf.sqrt(hxv * hxv + hyv * hyv + hzv * hzv);
          if (hLen < 0.001) hLen = 1.0;
          hxv /= hLen;
          hyv /= hLen;
          hzv /= hLen;

          const nDotH: f32 = saturate(nx * hxv + ny * hyv + nz * hzv);
          const tDotH: f32 = tx * hxv + ty * hyv + tz * hzv;
          const bDotH: f32 = bx * hxv + by * hyv + bz * hzv;
          const rough2: f32 = roughness * roughness;
          const ax: f32 = 0.032 + rough2 * (1.0 + anisotropy * 3.2);
          const ay: f32 = 0.032 + rough2 / (1.0 + anisotropy * 2.6);
          const ellipse: f32 = (tDotH * tDotH) / (ax * ax) + (bDotH * bDotH) / (ay * ay);
          const h2: f32 = nDotH * nDotH;
          const specular: f32 = (h2 * h2 * (0.22 + metallic * 1.10)) / (0.22 + ellipse);
          const specDirect: f32 = specular * cosSurface * cosLight * LIGHT_AREA / lightDist2;
          const specTintR: f32 = mixF(1.0, baseR, metallic * 0.65);
          const specTintG: f32 = mixF(1.0, baseG, metallic * 0.65);
          const specTintB: f32 = mixF(1.0, baseB, metallic * 0.65);
          accumR += throughR * specTintR * 10.5 * specDirect;
          accumG += throughG * specTintG * 9.0 * specDirect;
          accumB += throughB * specTintB * 6.2 * specDirect;
        }
      }
    }

    const ndotI: f32 = dx * nx + dy * ny + dz * nz;
    let rx: f32 = dx - 2.0 * ndotI * nx;
    let ry: f32 = dy - 2.0 * ndotI * ny;
    let rz: f32 = dz - 2.0 * ndotI * nz;
    sampleCosineHemisphere(nx, ny, nz);

    if (randF() < metallic) {
      const fuzz: f32 = roughness * roughness;
      rx = mixF(rx, sampleX, fuzz);
      ry = mixF(ry, sampleY, fuzz);
      rz = mixF(rz, sampleZ, fuzz);
      const lenR: f32 = Mathf.sqrt(rx * rx + ry * ry + rz * rz);
      dx = rx / lenR;
      dy = ry / lenR;
      dz = rz / lenR;
      throughR *= mixF(baseR, 1.0, 0.18);
      throughG *= mixF(baseG, 1.0, 0.18);
      throughB *= mixF(baseB, 1.0, 0.18);
    } else {
      dx = sampleX;
      dy = sampleY;
      dz = sampleZ;
      throughR *= baseR;
      throughG *= baseG;
      throughB *= baseB;
    }

    ox = hx + nx * EPSILON;
    oy = hy + ny * EPSILON;
    oz = hz + nz * EPSILON;

    if (bounce == MAX_BOUNCES - 1) {
      const keep: f32 = Mathf.max(throughR, Mathf.max(throughG, throughB));
      if (keep < 0.08 || randF() > keep) break;
      throughR /= keep;
      throughG /= keep;
      throughB /= keep;
    }
  }

  pathR = accumR;
  pathG = accumG;
  pathB = accumB;
}

function acesTone(value: f32): f32 {
  const mapped: f32 = (value * (2.51 * value + 0.03)) / (value * (2.43 * value + 0.59) + 0.14);
  return saturate(mapped);
}

export function main(): void {
  const frame: i32 = <i32>load<f32>(0);
  const magic: i32 = load<i32>(STATE_OFFSET);
  const phase: i32 = frame & (TILE_PHASES - 1);

  for (let i: i32 = 0; i < WIDTH * WIDTH; i++) {
    if (i >= CELLS) continue;

    const cellX: i32 = i & 255;
    const cellY: i32 = i >> 8;
    const pixelPhase: i32 = (cellX & 3) | ((cellY & 3) << 2);

    if (magic != MAGIC) {
      const warn: i32 = ((cellX >> 3) ^ (cellY >> 3)) & 1;
      writePixel(cellX, cellY, warn == 0 ? 230 : 40, 30, warn == 0 ? 180 : 70);
      continue;
    }

    if (pixelPhase != phase) continue;

    const accumBase: i32 = accumOffset() + i * 16;
    const oldCountF: f32 = load<f32>(accumBase + 12);
    const oldCount: i32 = <i32>oldCountF;
    initRng(cellX, cellY, oldCount + 1, frame);

    const jitterX: f32 = randF() - 0.5;
    const jitterY: f32 = randF() - 0.5;
    const screenX: f32 = (((<f32>cellX + 0.5 + jitterX) / <f32>FIELD) * 2.0 - 1.0) * 0.66;
    const screenY: f32 = (1.0 - ((<f32>cellY + 0.5 + jitterY) / <f32>FIELD) * 2.0) * 0.66;

    const camX: f32 = 0.0;
    const camY: f32 = 1.10;
    const camZ: f32 = 4.35;
    const targetX: f32 = 0.0;
    const targetY: f32 = 0.92;
    const targetZ: f32 = 0.20;
    let fwdX: f32 = targetX - camX;
    let fwdY: f32 = targetY - camY;
    let fwdZ: f32 = targetZ - camZ;
    const fwdLen: f32 = Mathf.sqrt(fwdX * fwdX + fwdY * fwdY + fwdZ * fwdZ);
    fwdX /= fwdLen;
    fwdY /= fwdLen;
    fwdZ /= fwdLen;

    let rightX: f32 = fwdZ;
    let rightY: f32 = 0.0;
    let rightZ: f32 = -fwdX;
    const rightLen: f32 = Mathf.sqrt(rightX * rightX + rightZ * rightZ);
    rightX /= rightLen;
    rightZ /= rightLen;

    const upX: f32 = rightY * fwdZ - rightZ * fwdY;
    const upY: f32 = rightZ * fwdX - rightX * fwdZ;
    const upZ: f32 = rightX * fwdY - rightY * fwdX;

    let dirX: f32 = fwdX * 1.75 + rightX * screenX + upX * screenY;
    let dirY: f32 = fwdY * 1.75 + rightY * screenX + upY * screenY;
    let dirZ: f32 = fwdZ * 1.75 + rightZ * screenX + upZ * screenY;
    let dirLen: f32 = Mathf.sqrt(dirX * dirX + dirY * dirY + dirZ * dirZ);
    dirX /= dirLen;
    dirY /= dirLen;
    dirZ /= dirLen;

    const focusDist: f32 = 4.15;
    const focusX: f32 = camX + dirX * focusDist;
    const focusY: f32 = camY + dirY * focusDist;
    const focusZ: f32 = camZ + dirZ * focusDist;
    const lensRadius: f32 = 0.022;
    const lensAngle: f32 = randF() * TWO_PI;
    const lensRad: f32 = Mathf.sqrt(randF()) * lensRadius;
    const lensX: f32 = cosF(lensAngle) * lensRad;
    const lensY: f32 = sinF(lensAngle) * lensRad;
    const originX: f32 = camX + rightX * lensX + upX * lensY;
    const originY: f32 = camY + rightY * lensX + upY * lensY;
    const originZ: f32 = camZ + rightZ * lensX + upZ * lensY;

    dirX = focusX - originX;
    dirY = focusY - originY;
    dirZ = focusZ - originZ;
    dirLen = Mathf.sqrt(dirX * dirX + dirY * dirY + dirZ * dirZ);
    dirX /= dirLen;
    dirY /= dirLen;
    dirZ /= dirLen;

    tracePath(originX, originY, originZ, dirX, dirY, dirZ);

    const sumR: f32 = load<f32>(accumBase) + pathR;
    const sumG: f32 = load<f32>(accumBase + 4) + pathG;
    const sumB: f32 = load<f32>(accumBase + 8) + pathB;
    const newCount: f32 = oldCountF + 1.0;
    store<f32>(accumBase, sumR);
    store<f32>(accumBase + 4, sumG);
    store<f32>(accumBase + 8, sumB);
    store<f32>(accumBase + 12, newCount);

    let outR: f32 = acesTone(sumR / newCount);
    let outG: f32 = acesTone(sumG / newCount);
    let outB: f32 = acesTone(sumB / newCount);
    outR = Mathf.sqrt(outR);
    outG = Mathf.sqrt(outG);
    outB = Mathf.sqrt(outB);

    writePixel(
      cellX,
      cellY,
      <i32>(clampF(outR, 0.0, 1.0) * 255.0),
      <i32>(clampF(outG, 0.0, 1.0) * 255.0),
      <i32>(clampF(outB, 0.0, 1.0) * 255.0),
    );
  }
}
