// ============================================================
// SIMD Packet Sphere Tracer - 4-wide primary-ray packets
// ============================================================
//  Four jittered primary rays per pixel travel as f32x4 origin
//  and direction lanes. Sphere hits use v128 disc math so the
//  WAT listing should show f32x4.add / sub / mul / sqrt rather
//  than four scalar solvers. Gasm 0.9 still lowers those ops to
//  vec4<u32> bitcasts in WGSL; the SIMD exhibit is the WAT.
//  Neon Kaleidoscope remains the M0 palette demo.
// ============================================================

const WIDTH: i32 = 256;
const TIME_OFFSET: i32 = 0;

const PI: f32 = 3.14159265;
const TWO_PI: f32 = 6.28318530;
const NO_HIT: f32 = -1.0;
const ID_MISS: f32 = 0.0;
const ID_FRONT: f32 = 1.0;
const ID_PLANE: f32 = 10.0;
const FRONT_RADIUS: f32 = 0.85;
const BG_RADIUS: f32 = 1.1;
const SKY_FILL: f32 = 0.15;
const SHADOW_EPS: f32 = 0.002;

function sinF(x: f32): f32 {
  x = x - Mathf.floor(x / TWO_PI + 0.5) * TWO_PI;
  if (x > PI * 0.5) x = PI - x;
  if (x < -PI * 0.5) x = -PI - x;
  const x2: f32 = x * x;
  return x * (1.0 - x2 / 6.0 * (1.0 - x2 / 20.0 * (1.0 - x2 / 42.0)));
}

function clamp0(v: f32): f32 {
  return v < 0.0 ? 0.0 : v;
}

function clamp255(v: f32): i32 {
  if (v < 0.0) return 0;
  if (v > 255.0) return 255;
  return <i32>v;
}

function sphereT4(
  cx: f32, cy: f32, cz: f32, radius: f32,
  ox: v128, oy: v128, oz: v128,
  dx: v128, dy: v128, dz: v128,
): v128 {
  const otcX: v128 = v128.sub<f32>(v128.splat<f32>(cx), ox);
  const otcY: v128 = v128.sub<f32>(v128.splat<f32>(cy), oy);
  const otcZ: v128 = v128.sub<f32>(v128.splat<f32>(cz), oz);
  const v: v128 = v128.add<f32>(
    v128.add<f32>(v128.mul<f32>(otcX, dx), v128.mul<f32>(otcY, dy)),
    v128.mul<f32>(otcZ, dz),
  );
  const otc2: v128 = v128.add<f32>(
    v128.add<f32>(v128.mul<f32>(otcX, otcX), v128.mul<f32>(otcY, otcY)),
    v128.mul<f32>(otcZ, otcZ),
  );
  const disc: v128 = v128.sub<f32>(
    v128.splat<f32>(radius * radius),
    v128.sub<f32>(otc2, v128.mul<f32>(v, v)),
  );
  const miss: v128 = v128.lt<f32>(disc, v128.splat<f32>(0.0));
  const tHit: v128 = v128.sub<f32>(v, v128.sqrt<f32>(v128.max<f32>(disc, v128.splat<f32>(0.0))));
  return v128.bitselect(v128.splat<f32>(NO_HIT), tHit, miss);
}

function chooseT4(a: v128, b: v128): v128 {
  const zero: v128 = v128.splat<f32>(0.0);
  const aMiss: v128 = v128.lt<f32>(a, zero);
  const bMiss: v128 = v128.lt<f32>(b, zero);
  const bLtA: v128 = v128.lt<f32>(b, a);
  const bothValid: v128 = v128.bitselect(b, a, bLtA);
  const bChecked: v128 = v128.bitselect(a, bothValid, bMiss);
  return v128.bitselect(b, bChecked, aMiss);
}

function chooseId4(tA: v128, idA: v128, tB: v128, idB: v128): v128 {
  const zero: v128 = v128.splat<f32>(0.0);
  const aMiss: v128 = v128.lt<f32>(tA, zero);
  const bMiss: v128 = v128.lt<f32>(tB, zero);
  const bLtA: v128 = v128.lt<f32>(tB, tA);
  const bothValid: v128 = v128.bitselect(idB, idA, bLtA);
  const bChecked: v128 = v128.bitselect(idA, bothValid, bMiss);
  return v128.bitselect(idB, bChecked, aMiss);
}

function sphereT(
  cx: f32, cy: f32, cz: f32, radius: f32,
  ox: f32, oy: f32, oz: f32,
  dx: f32, dy: f32, dz: f32,
): f32 {
  const otcX: f32 = cx - ox;
  const otcY: f32 = cy - oy;
  const otcZ: f32 = cz - oz;
  const v: f32 = otcX * dx + otcY * dy + otcZ * dz;
  const otc2: f32 = otcX * otcX + otcY * otcY + otcZ * otcZ;
  const disc: f32 = radius * radius - (otc2 - v * v);
  if (disc < 0.0) return NO_HIT;
  return v - Mathf.sqrt(disc);
}

function bgCenterX(s: i32): f32 {
  return -3.0 + <f32>(s % 4) * 2.0;
}

function bgCenterY(s: i32, angle: f32): f32 {
  // Sit on the y=-1 plane at the bottom of the bounce, then rise.
  return -1.0 + BG_RADIUS + (sinF(angle + <f32>(s % 4) + <f32>(s / 4)) + 1.0);
}

function bgCenterZ(s: i32): f32 {
  return 6.0 + <f32>(s / 4) * 3.0;
}

function bgAlbedoR(s: i32): f32 {
  const k: i32 = s & 3;
  if (k == 0) return 0.86;
  if (k == 1) return 0.92;
  if (k == 2) return 0.18;
  return 0.55;
}

function bgAlbedoG(s: i32): f32 {
  const k: i32 = s & 3;
  if (k == 0) return 0.28;
  if (k == 1) return 0.74;
  if (k == 2) return 0.66;
  return 0.32;
}

function bgAlbedoB(s: i32): f32 {
  const k: i32 = s & 3;
  if (k == 0) return 0.22;
  if (k == 1) return 0.18;
  if (k == 2) return 0.72;
  return 0.82;
}

function skyR(dy: f32): f32 {
  const t: f32 = 0.5 * (dy + 1.0);
  return 0.62 + 0.28 * t;
}

function skyG(dy: f32): f32 {
  const t: f32 = 0.5 * (dy + 1.0);
  return 0.74 + 0.16 * t;
}

function skyB(dy: f32): f32 {
  const t: f32 = 0.5 * (dy + 1.0);
  return 0.92 + 0.06 * t;
}

function shadeLane(
  tHit: f32, idHit: f32,
  dx: f32, dy: f32, dz: f32,
  frontX: f32, frontY: f32, frontZ: f32,
  lx: f32, ly: f32, lz: f32,
  angle: f32,
  channel: i32,
): f32 {
  if (dy < 0.0) {
    const tPlane: f32 = -1.0 / dy;
    if (tPlane > 0.0) {
      if (tHit < 0.0) {
        tHit = tPlane;
        idHit = ID_PLANE;
      } else if (tPlane < tHit) {
        tHit = tPlane;
        idHit = ID_PLANE;
      }
    }
  }

  if (tHit < 0.0) {
    if (channel == 0) return skyR(dy);
    if (channel == 1) return skyG(dy);
    return skyB(dy);
  }

  const hx: f32 = dx * tHit;
  const hy: f32 = dy * tHit;
  const hz: f32 = dz * tHit;

  let nx: f32 = 0.0;
  let ny: f32 = 1.0;
  let nz: f32 = 0.0;
  let albedoR: f32 = 0.12;
  let albedoG: f32 = 0.12;
  let albedoB: f32 = 0.12;

  if (idHit == ID_FRONT) {
    nx = hx - frontX;
    ny = hy - frontY;
    nz = hz - frontZ;
    albedoR = 0.85;
    albedoG = 0.92;
    albedoB = 1.0;
  } else if (idHit == ID_PLANE) {
    const checker: i32 = (<i32>Mathf.floor(hx) + <i32>Mathf.floor(hz)) & 1;
    if (checker == 0) {
      albedoR = 0.12;
      albedoG = 0.12;
      albedoB = 0.12;
    } else {
      albedoR = 0.75;
      albedoG = 0.75;
      albedoB = 0.75;
    }
  } else {
    const s: i32 = <i32>(idHit - 2.0);
    nx = hx - bgCenterX(s);
    ny = hy - bgCenterY(s, angle);
    nz = hz - bgCenterZ(s);
    albedoR = bgAlbedoR(s);
    albedoG = bgAlbedoG(s);
    albedoB = bgAlbedoB(s);
  }

  if (idHit != ID_PLANE) {
    const nlen: f32 = Mathf.sqrt(nx * nx + ny * ny + nz * nz);
    nx = nx / nlen;
    ny = ny / nlen;
    nz = nz / nlen;
  }

  const sox: f32 = hx + nx * SHADOW_EPS;
  const soy: f32 = hy + ny * SHADOW_EPS;
  const soz: f32 = hz + nz * SHADOW_EPS;
  const shadowT: f32 = sphereT(
    frontX, frontY, frontZ, FRONT_RADIUS,
    sox, soy, soz, lx, ly, lz,
  );
  const lit: f32 = shadowT > SHADOW_EPS ? 0.0 : clamp0(nx * lx + ny * ly + nz * lz);
  const lighting: f32 = SKY_FILL + lit;

  let cr: f32 = albedoR * lighting;
  let cg: f32 = albedoG * lighting;
  let cb: f32 = albedoB * lighting;

  if (idHit == ID_FRONT) {
    const nd: f32 = nx * dx + ny * dy + nz * dz;
    const rdy: f32 = dy - 2.0 * ny * nd;
    const fres: f32 = 0.18 + 0.28 * (1.0 - clamp0(-nd));
    cr = cr + skyR(rdy) * fres;
    cg = cg + skyG(rdy) * fres;
    cb = cb + skyB(rdy) * fres;
  }

  if (channel == 0) return cr;
  if (channel == 1) return cg;
  return cb;
}

export function main(): void {
  const angle: f32 = load<f32>(TIME_OFFSET) * 0.016;
  const frontX: f32 = sinF(angle + 1.5);
  const frontY: f32 = -1.0 + FRONT_RADIUS + 0.2 * (sinF(angle) + 1.0);
  const frontZ: f32 = 4.0;
  const lightX: f32 = 0.35;
  const lightY: f32 = 0.8;
  const lightZ: f32 = 0.45;
  const llen: f32 = Mathf.sqrt(lightX * lightX + lightY * lightY + lightZ * lightZ);
  const lx: f32 = lightX / llen;
  const ly: f32 = lightY / llen;
  const lz: f32 = lightZ / llen;

  let jitterX: v128 = v128.splat<f32>(0.0);
  jitterX = v128.replace_lane<f32>(jitterX, 0, -0.375);
  jitterX = v128.replace_lane<f32>(jitterX, 1, -0.125);
  jitterX = v128.replace_lane<f32>(jitterX, 2, 0.125);
  jitterX = v128.replace_lane<f32>(jitterX, 3, 0.375);

  const ox: v128 = v128.splat<f32>(0.0);
  const oy: v128 = v128.splat<f32>(0.0);
  const oz: v128 = v128.splat<f32>(0.0);

  for (let i: i32 = 0; i < WIDTH * WIDTH; i++) {
    const x: i32 = i % WIDTH;
    const y: i32 = i / WIDTH;
    const rx: v128 = v128.sub<f32>(
      v128.div<f32>(
        v128.add<f32>(v128.splat<f32>(<f32>x), jitterX),
        v128.splat<f32>(128.0),
      ),
      v128.splat<f32>(1.0),
    );
    // Canvas y=0 is the top row; negate NDC Y so +Y (sky) is up.
    const ry: v128 = v128.splat<f32>(1.0 - <f32>y / 128.0);
    const len2: v128 = v128.add<f32>(
      v128.add<f32>(v128.mul<f32>(rx, rx), v128.mul<f32>(ry, ry)),
      v128.splat<f32>(1.0),
    );
    const invLen: v128 = v128.div<f32>(v128.splat<f32>(1.0), v128.sqrt<f32>(len2));
    const dx: v128 = v128.mul<f32>(rx, invLen);
    const dy: v128 = v128.mul<f32>(ry, invLen);
    const dz: v128 = invLen;

    let tBest: v128 = v128.splat<f32>(NO_HIT);
    let idBest: v128 = v128.splat<f32>(ID_MISS);

    const tFront: v128 = sphereT4(
      frontX, frontY, frontZ, FRONT_RADIUS,
      ox, oy, oz, dx, dy, dz,
    );
    idBest = chooseId4(tBest, idBest, tFront, v128.splat<f32>(ID_FRONT));
    tBest = chooseT4(tBest, tFront);

    for (let group: i32 = 0; group < 2; group++) {
      for (let k: i32 = 0; k < 4; k++) {
        const s: i32 = group * 4 + k;
        const tBg: v128 = sphereT4(
          bgCenterX(s), bgCenterY(s, angle), bgCenterZ(s), BG_RADIUS,
          ox, oy, oz, dx, dy, dz,
        );
        idBest = chooseId4(tBest, idBest, tBg, v128.splat<f32>(2.0 + <f32>s));
        tBest = chooseT4(tBest, tBg);
      }
    }

    let sumR: f32 = 0.0;
    let sumG: f32 = 0.0;
    let sumB: f32 = 0.0;
    sumR = sumR + shadeLane(
      v128.extract_lane<f32>(tBest, 0), v128.extract_lane<f32>(idBest, 0),
      v128.extract_lane<f32>(dx, 0), v128.extract_lane<f32>(dy, 0), v128.extract_lane<f32>(dz, 0),
      frontX, frontY, frontZ, lx, ly, lz, angle, 0,
    );
    sumG = sumG + shadeLane(
      v128.extract_lane<f32>(tBest, 0), v128.extract_lane<f32>(idBest, 0),
      v128.extract_lane<f32>(dx, 0), v128.extract_lane<f32>(dy, 0), v128.extract_lane<f32>(dz, 0),
      frontX, frontY, frontZ, lx, ly, lz, angle, 1,
    );
    sumB = sumB + shadeLane(
      v128.extract_lane<f32>(tBest, 0), v128.extract_lane<f32>(idBest, 0),
      v128.extract_lane<f32>(dx, 0), v128.extract_lane<f32>(dy, 0), v128.extract_lane<f32>(dz, 0),
      frontX, frontY, frontZ, lx, ly, lz, angle, 2,
    );
    sumR = sumR + shadeLane(
      v128.extract_lane<f32>(tBest, 1), v128.extract_lane<f32>(idBest, 1),
      v128.extract_lane<f32>(dx, 1), v128.extract_lane<f32>(dy, 1), v128.extract_lane<f32>(dz, 1),
      frontX, frontY, frontZ, lx, ly, lz, angle, 0,
    );
    sumG = sumG + shadeLane(
      v128.extract_lane<f32>(tBest, 1), v128.extract_lane<f32>(idBest, 1),
      v128.extract_lane<f32>(dx, 1), v128.extract_lane<f32>(dy, 1), v128.extract_lane<f32>(dz, 1),
      frontX, frontY, frontZ, lx, ly, lz, angle, 1,
    );
    sumB = sumB + shadeLane(
      v128.extract_lane<f32>(tBest, 1), v128.extract_lane<f32>(idBest, 1),
      v128.extract_lane<f32>(dx, 1), v128.extract_lane<f32>(dy, 1), v128.extract_lane<f32>(dz, 1),
      frontX, frontY, frontZ, lx, ly, lz, angle, 2,
    );
    sumR = sumR + shadeLane(
      v128.extract_lane<f32>(tBest, 2), v128.extract_lane<f32>(idBest, 2),
      v128.extract_lane<f32>(dx, 2), v128.extract_lane<f32>(dy, 2), v128.extract_lane<f32>(dz, 2),
      frontX, frontY, frontZ, lx, ly, lz, angle, 0,
    );
    sumG = sumG + shadeLane(
      v128.extract_lane<f32>(tBest, 2), v128.extract_lane<f32>(idBest, 2),
      v128.extract_lane<f32>(dx, 2), v128.extract_lane<f32>(dy, 2), v128.extract_lane<f32>(dz, 2),
      frontX, frontY, frontZ, lx, ly, lz, angle, 1,
    );
    sumB = sumB + shadeLane(
      v128.extract_lane<f32>(tBest, 2), v128.extract_lane<f32>(idBest, 2),
      v128.extract_lane<f32>(dx, 2), v128.extract_lane<f32>(dy, 2), v128.extract_lane<f32>(dz, 2),
      frontX, frontY, frontZ, lx, ly, lz, angle, 2,
    );
    sumR = sumR + shadeLane(
      v128.extract_lane<f32>(tBest, 3), v128.extract_lane<f32>(idBest, 3),
      v128.extract_lane<f32>(dx, 3), v128.extract_lane<f32>(dy, 3), v128.extract_lane<f32>(dz, 3),
      frontX, frontY, frontZ, lx, ly, lz, angle, 0,
    );
    sumG = sumG + shadeLane(
      v128.extract_lane<f32>(tBest, 3), v128.extract_lane<f32>(idBest, 3),
      v128.extract_lane<f32>(dx, 3), v128.extract_lane<f32>(dy, 3), v128.extract_lane<f32>(dz, 3),
      frontX, frontY, frontZ, lx, ly, lz, angle, 1,
    );
    sumB = sumB + shadeLane(
      v128.extract_lane<f32>(tBest, 3), v128.extract_lane<f32>(idBest, 3),
      v128.extract_lane<f32>(dx, 3), v128.extract_lane<f32>(dy, 3), v128.extract_lane<f32>(dz, 3),
      frontX, frontY, frontZ, lx, ly, lz, angle, 2,
    );

    const r: f32 = Mathf.sqrt(sumR * 0.25);
    const g: f32 = Mathf.sqrt(sumG * 0.25);
    const b: f32 = Mathf.sqrt(sumB * 0.25);
    const pixelOffset: i32 = 16 + i * 12;
    store<i32>(pixelOffset, clamp255(r * 255.0));
    store<i32>(pixelOffset + 4, clamp255(g * 255.0));
    store<i32>(pixelOffset + 8, clamp255(b * 255.0));
  }
}
