// ============================================================
//  Ray Tracing: The Next Week — Final Scene
// ============================================================
//  Reduced book final: ground boxes, clustered spheres, earth,
//  marble, motion, metal, glass, blue volume, and mist. One path
//  per frame accumulates in persistent memory.
// ============================================================

const WIDTH: i32 = 256;
const HEIGHT: i32 = 256;
const IMAGE_WIDTH: i32 = 256;
const IMAGE_HEIGHT: i32 = 256;
const LETTERBOX: i32 = 0;
const PIXEL_COUNT: i32 = 65536;
const STATE_OFFSET: i32 = 16 + PIXEL_COUNT * 12;
const MAGIC_OFFSET: i32 = STATE_OFFSET;
const SUM_OFFSET: i32 = STATE_OFFSET + 16;
const COUNT_OFFSET: i32 = SUM_OFFSET + PIXEL_COUNT * 12;
const TEX_HEADER_OFFSET: i32 = 1835072;
const MAGIC: i32 = 0x52544E57;
const MAX_DEPTH: i32 = 8;
const TURB_DEPTH: i32 = 7;
const BOX_SIDE: i32 = 6;
const CLUSTER_COUNT: i32 = 48;

const TMIN: f32 = 0.001;
const TMAX: f32 = 100000.0;
const HALF_VFOV_TAN: f32 = 0.36397023;
const PI: f32 = 3.14159265;
const TWO_PI: f32 = 6.28318530;
const SIN_15: f32 = 0.25881905;
const COS_15: f32 = 0.96592583;
const MIST_NEG_INV: f32 = -10000.0;
const BLUE_NEG_INV: f32 = -5.0;

const MAT_LAMBERT: i32 = 0;
const MAT_METAL: i32 = 1;
const MAT_GLASS: i32 = 2;
const MAT_LIGHT: i32 = 3;
const MAT_ISO: i32 = 4;

const HIT_LIGHT: i32 = 0;
const HIT_MIST: i32 = 1;
const HIT_BOX: i32 = 2;
const HIT_CLUSTER: i32 = 3;
const HIT_EARTH: i32 = 4;
const HIT_MARBLE: i32 = 5;
const HIT_MOVE: i32 = 6;
const HIT_GLASS1: i32 = 7;
const HIT_METAL: i32 = 8;
const HIT_GLASS2: i32 = 9;
const HIT_BLUE: i32 = 10;

function hashU(value: u32): u32 {
  let state: u32 = value * 747796405 + 2891336453;
  const word: u32 = ((state >> ((state >> 28) + 4)) ^ state) * 277803737;
  return (word >> 22) ^ word;
}

function randomF(value: u32): f32 {
  return <f32>value / 4294967296.0;
}

function length3(x: f32, y: f32, z: f32): f32 {
  return Mathf.sqrt(x * x + y * y + z * z);
}

function dot3(ax: f32, ay: f32, az: f32, bx: f32, by: f32, bz: f32): f32 {
  return ax * bx + ay * by + az * bz;
}

function crossX(ay: f32, az: f32, by: f32, bz: f32): f32 { return ay * bz - az * by; }
function crossY(az: f32, ax: f32, bz: f32, bx: f32): f32 { return az * bx - ax * bz; }
function crossZ(ax: f32, ay: f32, bx: f32, by: f32): f32 { return ax * by - ay * bx; }

function sinF(x: f32): f32 {
  x = x - Mathf.floor(x / TWO_PI + 0.5) * TWO_PI;
  if (x > PI * 0.5) x = PI - x;
  if (x < -PI * 0.5) x = -PI - x;
  const x2: f32 = x * x;
  return x * (1.0 - x2 / 6.0 * (1.0 - x2 / 20.0 * (1.0 - x2 / 42.0)));
}

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

function atan2F(y: f32, x: f32): f32 {
  const absY: f32 = Mathf.abs(y) + 0.000001;
  let angle: f32;
  if (x >= 0.0) {
    const ratio: f32 = (x - absY) / (x + absY);
    angle = PI * 0.25 - PI * 0.25 * ratio;
  } else {
    const ratio: f32 = (x + absY) / (absY - x);
    angle = PI * 0.75 - PI * 0.25 * ratio;
  }
  return y < 0.0 ? -angle : angle;
}

function acosF(y: f32): f32 {
  const c: f32 = Mathf.min(Mathf.max(y, -1.0), 1.0);
  return atan2F(Mathf.sqrt(Mathf.max(0.0, 1.0 - c * c)), c);
}

function reflectance(cosine: f32, ri: f32): f32 {
  let r0: f32 = (1.0 - ri) / (1.0 + ri);
  r0 = r0 * r0;
  const m: f32 = 1.0 - cosine;
  const m2: f32 = m * m;
  return r0 + (1.0 - r0) * m2 * m2 * m;
}

function hash31(ix: i32, iy: i32, iz: i32): u32 {
  return hashU(<u32>(ix * 374761393 + iy * 668265263 + iz * 2147483647 + 1013));
}

function fade(t: f32): f32 {
  return t * t * (3.0 - 2.0 * t);
}

function cornerDot(ix: i32, iy: i32, iz: i32, wx: f32, wy: f32, wz: f32): f32 {
  let s: u32 = hash31(ix, iy, iz);
  let gx: f32 = randomF(s) * 2.0 - 1.0;
  s = hashU(s);
  let gy: f32 = randomF(s) * 2.0 - 1.0;
  s = hashU(s);
  let gz: f32 = randomF(s) * 2.0 - 1.0;
  let len: f32 = length3(gx, gy, gz);
  if (len < 0.000001) len = 1.0;
  return (gx / len) * wx + (gy / len) * wy + (gz / len) * wz;
}

function noise(px: f32, py: f32, pz: f32): f32 {
  const ix: i32 = <i32>Mathf.floor(px);
  const iy: i32 = <i32>Mathf.floor(py);
  const iz: i32 = <i32>Mathf.floor(pz);
  const u: f32 = px - <f32>ix;
  const v: f32 = py - <f32>iy;
  const w: f32 = pz - <f32>iz;
  const uu: f32 = fade(u);
  const vv: f32 = fade(v);
  const ww: f32 = fade(w);
  let accum: f32 = 0.0;
  for (let di: i32 = 0; di < 2; di++) {
    for (let dj: i32 = 0; dj < 2; dj++) {
      for (let dk: i32 = 0; dk < 2; dk++) {
        const fi: f32 = <f32>di;
        const fj: f32 = <f32>dj;
        const fk: f32 = <f32>dk;
        const weight: f32 = (fi * uu + (1.0 - fi) * (1.0 - uu))
          * (fj * vv + (1.0 - fj) * (1.0 - vv))
          * (fk * ww + (1.0 - fk) * (1.0 - ww));
        accum += weight * cornerDot(ix + di, iy + dj, iz + dk, u - fi, v - fj, w - fk);
      }
    }
  }
  return accum;
}

function turb(px: f32, py: f32, pz: f32): f32 {
  let accum: f32 = 0.0;
  let wx: f32 = px;
  let wy: f32 = py;
  let wz: f32 = pz;
  let amp: f32 = 1.0;
  for (let d: i32 = 0; d < TURB_DEPTH; d++) {
    accum += amp * Mathf.abs(noise(wx, wy, wz));
    amp *= 0.5;
    wx *= 2.0;
    wy *= 2.0;
    wz *= 2.0;
  }
  return accum;
}

function marble(px: f32, py: f32, pz: f32): f32 {
  return 0.5 * (1.0 + sinF(0.2 * pz + 10.0 * turb(px, py, pz)));
}

function sphereHitT(
  ox: f32, oy: f32, oz: f32,
  dx: f32, dy: f32, dz: f32,
  cx: f32, cy: f32, cz: f32,
  radius: f32,
  tMin: f32,
  tMax: f32,
): f32 {
  const ocx: f32 = cx - ox;
  const ocy: f32 = cy - oy;
  const ocz: f32 = cz - oz;
  const a: f32 = dot3(dx, dy, dz, dx, dy, dz);
  const h: f32 = dot3(dx, dy, dz, ocx, ocy, ocz);
  const c: f32 = dot3(ocx, ocy, ocz, ocx, ocy, ocz) - radius * radius;
  const discriminant: f32 = h * h - a * c;
  if (discriminant < 0.0) return -1.0;
  const sqrtd: f32 = Mathf.sqrt(discriminant);
  let root: f32 = (h - sqrtd) / a;
  if (root <= tMin || tMax <= root) {
    root = (h + sqrtd) / a;
    if (root <= tMin || tMax <= root) return -1.0;
  }
  return root;
}

function sphereVolumeHitT(
  ox: f32, oy: f32, oz: f32,
  dx: f32, dy: f32, dz: f32,
  cx: f32, cy: f32, cz: f32,
  radius: f32,
  negInv: f32,
  rand: f32,
  tMin: f32,
  tMax: f32,
): f32 {
  const ocx: f32 = cx - ox;
  const ocy: f32 = cy - oy;
  const ocz: f32 = cz - oz;
  const a: f32 = dot3(dx, dy, dz, dx, dy, dz);
  const h: f32 = dot3(dx, dy, dz, ocx, ocy, ocz);
  const c: f32 = dot3(ocx, ocy, ocz, ocx, ocy, ocz) - radius * radius;
  const discriminant: f32 = h * h - a * c;
  if (discriminant < 0.0) return -1.0;
  const sqrtd: f32 = Mathf.sqrt(discriminant);
  let t1: f32 = (h - sqrtd) / a;
  let t2: f32 = (h + sqrtd) / a;
  if (t1 > t2) {
    const tmp: f32 = t1;
    t1 = t2;
    t2 = tmp;
  }
  if (t1 < tMin) t1 = tMin;
  if (t2 > tMax) t2 = tMax;
  if (t1 >= t2) return -1.0;
  if (t1 < 0.0) t1 = 0.0;
  const dirLen: f32 = length3(dx, dy, dz);
  const distInside: f32 = (t2 - t1) * dirLen;
  let u: f32 = rand;
  if (u < 0.000001) u = 0.000001;
  const hitDist: f32 = negInv * logF(u);
  if (hitDist > distInside) return -1.0;
  return t1 + hitDist / dirLen;
}

function aabbHitT(
  ox: f32, oy: f32, oz: f32,
  dx: f32, dy: f32, dz: f32,
  minX: f32, minY: f32, minZ: f32,
  maxX: f32, maxY: f32, maxZ: f32,
  tMin: f32,
  tMax: f32,
): f32 {
  let mnX: f32 = minX;
  let mxX: f32 = maxX;
  let mnY: f32 = minY;
  let mxY: f32 = maxY;
  let mnZ: f32 = minZ;
  let mxZ: f32 = maxZ;
  if (mxX - mnX < 0.0001) {
    mnX -= 0.0001;
    mxX += 0.0001;
  }
  if (mxY - mnY < 0.0001) {
    mnY -= 0.0001;
    mxY += 0.0001;
  }
  if (mxZ - mnZ < 0.0001) {
    mnZ -= 0.0001;
    mxZ += 0.0001;
  }
  const invDx: f32 = 1.0 / dx;
  const invDy: f32 = 1.0 / dy;
  const invDz: f32 = 1.0 / dz;
  let t0x: f32 = (mnX - ox) * invDx;
  let t1x: f32 = (mxX - ox) * invDx;
  if (t0x > t1x) {
    const tmp: f32 = t0x;
    t0x = t1x;
    t1x = tmp;
  }
  let t0y: f32 = (mnY - oy) * invDy;
  let t1y: f32 = (mxY - oy) * invDy;
  if (t0y > t1y) {
    const tmp: f32 = t0y;
    t0y = t1y;
    t1y = tmp;
  }
  let t0z: f32 = (mnZ - oz) * invDz;
  let t1z: f32 = (mxZ - oz) * invDz;
  if (t0z > t1z) {
    const tmp: f32 = t0z;
    t0z = t1z;
    t1z = tmp;
  }
  const tNear: f32 = Mathf.max(t0x, Mathf.max(t0y, t0z));
  const tFar: f32 = Mathf.min(t1x, Mathf.min(t1y, t1z));
  if (tNear >= tFar) return -1.0;
  if (tNear >= tMin && tNear < tMax) return tNear;
  if (tNear < tMin && tFar > tMin && tFar < tMax) return tFar;
  return -1.0;
}

function quadHitT(
  ox: f32, oy: f32, oz: f32,
  dx: f32, dy: f32, dz: f32,
  qx: f32, qy: f32, qz: f32,
  ux: f32, uy: f32, uz: f32,
  vx: f32, vy: f32, vz: f32,
  tMin: f32,
  tMax: f32,
): f32 {
  const nx: f32 = crossX(uy, uz, vy, vz);
  const ny: f32 = crossY(uz, ux, vz, vx);
  const nz: f32 = crossZ(ux, uy, vx, vy);
  const n2: f32 = nx * nx + ny * ny + nz * nz;
  if (n2 < 1.0e-16) return -1.0;
  const nlen: f32 = Mathf.sqrt(n2);
  const nnx: f32 = nx / nlen;
  const nny: f32 = ny / nlen;
  const nnz: f32 = nz / nlen;
  const D: f32 = dot3(nnx, nny, nnz, qx, qy, qz);
  const denom: f32 = dot3(nnx, nny, nnz, dx, dy, dz);
  if (Mathf.abs(denom) < 1.0e-8) return -1.0;
  const t: f32 = (D - dot3(nnx, nny, nnz, ox, oy, oz)) / denom;
  if (t <= tMin || tMax <= t) return -1.0;
  const vpx: f32 = ox + t * dx - qx;
  const vpy: f32 = oy + t * dy - qy;
  const vpz: f32 = oz + t * dz - qz;
  const wx: f32 = nx / n2;
  const wy: f32 = ny / n2;
  const wz: f32 = nz / n2;
  const alpha: f32 = dot3(wx, wy, wz, crossX(vpy, vpz, vy, vz), crossY(vpz, vpx, vz, vx), crossZ(vpx, vpy, vx, vy));
  const beta: f32 = dot3(wx, wy, wz, crossX(uy, uz, vpy, vpz), crossY(uz, ux, vpz, vpx), crossZ(ux, uy, vpx, vpy));
  if (alpha < 0.0 || alpha > 1.0 || beta < 0.0 || beta > 1.0) return -1.0;
  return t;
}

function gammaByte(v: f32): i32 {
  let g: f32 = v > 0.0 ? Mathf.sqrt(v) : 0.0;
  if (g < 0.0) g = 0.0;
  if (g > 1.0) g = 1.0;
  return <i32>(g * 255.0);
}

function writeRgb(i: i32, r: i32, g: i32, b: i32): void {
  const offset: i32 = 16 + i * 12;
  store<i32>(offset, r);
  store<i32>(offset + 4, g);
  store<i32>(offset + 8, b);
}

function boxY1(bi: i32, bj: i32): f32 {
  return 1.0 + 100.0 * randomF(hashU(<u32>(bi * 1973 + bj * 9277 + 1013)));
}

function clusterCX(n: i32): f32 {
  return randomF(hashU(<u32>(n * 1973 + 11))) * 165.0;
}

function clusterCY(n: i32): f32 {
  return randomF(hashU(<u32>(n * 9277 + 13))) * 165.0;
}

function clusterCZ(n: i32): f32 {
  return randomF(hashU(<u32>(n * 26699 + 17))) * 165.0;
}

function aabbFaceNX(px: f32, py: f32, pz: f32, minX: f32, minY: f32, minZ: f32, maxX: f32, maxY: f32, maxZ: f32): f32 {
  const cx: f32 = 0.5 * (minX + maxX);
  const cy: f32 = 0.5 * (minY + maxY);
  const cz: f32 = 0.5 * (minZ + maxZ);
  const hx: f32 = 0.5 * (maxX - minX) + 0.0001;
  const hy: f32 = 0.5 * (maxY - minY) + 0.0001;
  const hz: f32 = 0.5 * (maxZ - minZ) + 0.0001;
  const ax: f32 = Mathf.abs((px - cx) / hx);
  const ay: f32 = Mathf.abs((py - cy) / hy);
  const az: f32 = Mathf.abs((pz - cz) / hz);
  if (ax >= ay && ax >= az) return px >= cx ? 1.0 : -1.0;
  return 0.0;
}

function aabbFaceNY(px: f32, py: f32, pz: f32, minX: f32, minY: f32, minZ: f32, maxX: f32, maxY: f32, maxZ: f32): f32 {
  const cx: f32 = 0.5 * (minX + maxX);
  const cy: f32 = 0.5 * (minY + maxY);
  const cz: f32 = 0.5 * (minZ + maxZ);
  const hx: f32 = 0.5 * (maxX - minX) + 0.0001;
  const hy: f32 = 0.5 * (maxY - minY) + 0.0001;
  const hz: f32 = 0.5 * (maxZ - minZ) + 0.0001;
  const ax: f32 = Mathf.abs((px - cx) / hx);
  const ay: f32 = Mathf.abs((py - cy) / hy);
  const az: f32 = Mathf.abs((pz - cz) / hz);
  if (ay > ax && ay >= az) return py >= cy ? 1.0 : -1.0;
  return 0.0;
}

function aabbFaceNZ(px: f32, py: f32, pz: f32, minX: f32, minY: f32, minZ: f32, maxX: f32, maxY: f32, maxZ: f32): f32 {
  const cx: f32 = 0.5 * (minX + maxX);
  const cy: f32 = 0.5 * (minY + maxY);
  const cz: f32 = 0.5 * (minZ + maxZ);
  const hx: f32 = 0.5 * (maxX - minX) + 0.0001;
  const hy: f32 = 0.5 * (maxY - minY) + 0.0001;
  const hz: f32 = 0.5 * (maxZ - minZ) + 0.0001;
  const ax: f32 = Mathf.abs((px - cx) / hx);
  const ay: f32 = Mathf.abs((py - cy) / hy);
  const az: f32 = Mathf.abs((pz - cz) / hz);
  if (az > ax && az > ay) return pz >= cz ? 1.0 : -1.0;
  return 0.0;
}

function sampleEarth(nx: f32, ny: f32, nz: f32): i32 {
  let uu: f32 = (atan2F(-nz, nx) + PI) / TWO_PI;
  let vv: f32 = 1.0 - acosF(-ny) / PI;
  if (uu < 0.0) uu = 0.0;
  if (uu > 1.0) uu = 1.0;
  if (vv < 0.0) vv = 0.0;
  if (vv > 1.0) vv = 1.0;
  const texW: i32 = load<i32>(TEX_HEADER_OFFSET);
  const texH: i32 = load<i32>(TEX_HEADER_OFFSET + 4);
  const texelOffset: i32 = load<i32>(TEX_HEADER_OFFSET + 8);
  let ti: i32 = <i32>(uu * <f32>texW);
  let tj: i32 = <i32>(vv * <f32>texH);
  if (ti < 0) ti = 0;
  if (tj < 0) tj = 0;
  if (ti >= texW) ti = texW - 1;
  if (tj >= texH) tj = texH - 1;
  return load<i32>(texelOffset + (tj * texW + ti) * 4);
}

export function main(): void {
  const frame: i32 = <i32>load<f32>(0);
  const initialized: bool = load<i32>(MAGIC_OFFSET) == MAGIC;

  const lookfromX: f32 = 478.0;
  const lookfromY: f32 = 278.0;
  const lookfromZ: f32 = -600.0;
  const lookatX: f32 = 278.0;
  const lookatY: f32 = 278.0;
  const lookatZ: f32 = 0.0;
  const wRawX: f32 = lookfromX - lookatX;
  const wRawY: f32 = lookfromY - lookatY;
  const wRawZ: f32 = lookfromZ - lookatZ;
  const wLen: f32 = length3(wRawX, wRawY, wRawZ);
  const wX: f32 = wRawX / wLen;
  const wY: f32 = wRawY / wLen;
  const wZ: f32 = wRawZ / wLen;
  const uRawX: f32 = wZ;
  const uRawY: f32 = 0.0;
  const uRawZ: f32 = -wX;
  const uLen: f32 = length3(uRawX, uRawY, uRawZ);
  const uX: f32 = uRawX / uLen;
  const uY: f32 = uRawY / uLen;
  const uZ: f32 = uRawZ / uLen;
  const vX: f32 = wY * uZ - wZ * uY;
  const vY: f32 = wZ * uX - wX * uZ;
  const vZ: f32 = wX * uY - wY * uX;

  const focusDist: f32 = wLen;
  const viewportHeight: f32 = 2.0 * HALF_VFOV_TAN * focusDist;
  const viewportWidth: f32 = viewportHeight * <f32>IMAGE_WIDTH / <f32>IMAGE_HEIGHT;
  const vuX: f32 = viewportWidth * uX;
  const vuY: f32 = viewportWidth * uY;
  const vuZ: f32 = viewportWidth * uZ;
  const vvX: f32 = viewportHeight * -vX;
  const vvY: f32 = viewportHeight * -vY;
  const vvZ: f32 = viewportHeight * -vZ;
  const duX: f32 = vuX / <f32>IMAGE_WIDTH;
  const duY: f32 = vuY / <f32>IMAGE_WIDTH;
  const duZ: f32 = vuZ / <f32>IMAGE_WIDTH;
  const dvX: f32 = vvX / <f32>IMAGE_HEIGHT;
  const dvY: f32 = vvY / <f32>IMAGE_HEIGHT;
  const dvZ: f32 = vvZ / <f32>IMAGE_HEIGHT;
  const upperX: f32 = lookfromX - focusDist * wX - 0.5 * vuX - 0.5 * vvX;
  const upperY: f32 = lookfromY - focusDist * wY - 0.5 * vuY - 0.5 * vvY;
  const upperZ: f32 = lookfromZ - focusDist * wZ - 0.5 * vuZ - 0.5 * vvZ;
  const p00X: f32 = upperX + 0.5 * (duX + dvX);
  const p00Y: f32 = upperY + 0.5 * (duY + dvY);
  const p00Z: f32 = upperZ + 0.5 * (duZ + dvZ);

  for (let i: i32 = 0; i < WIDTH * HEIGHT; i++) {
    const x: i32 = i % WIDTH;
    const y: i32 = i / WIDTH;
    const imageY: i32 = y - LETTERBOX;

    if (imageY < 0 || imageY >= IMAGE_HEIGHT) {
      writeRgb(i, 0, 0, 0);
      continue;
    }

    const sumAddress: i32 = SUM_OFFSET + i * 12;
    const countAddress: i32 = COUNT_OFFSET + i * 4;
    const oldCount: f32 = initialized ? load<f32>(countAddress) : 0.0;
    let seed: u32 = hashU(<u32>(x * 1973 + imageY * 9277 + (<i32>oldCount + 1) * 26699 + frame * 17) | 1);

    seed = hashU(seed);
    const jitterX: f32 = randomF(seed) - 0.5;
    seed = hashU(seed);
    const jitterY: f32 = randomF(seed) - 0.5;
    const sampleX: f32 = p00X + (<f32>x + jitterX) * duX + (<f32>imageY + jitterY) * dvX;
    const sampleY: f32 = p00Y + (<f32>x + jitterX) * duY + (<f32>imageY + jitterY) * dvY;
    const sampleZ: f32 = p00Z + (<f32>x + jitterX) * duZ + (<f32>imageY + jitterY) * dvZ;

    let ox: f32 = lookfromX;
    let oy: f32 = lookfromY;
    let oz: f32 = lookfromZ;
    let dx: f32 = sampleX - ox;
    let dy: f32 = sampleY - oy;
    let dz: f32 = sampleZ - oz;

    seed = hashU(seed);
    const rayTime: f32 = randomF(seed);

    let attR: f32 = 1.0;
    let attG: f32 = 1.0;
    let attB: f32 = 1.0;
    let colR: f32 = 0.0;
    let colG: f32 = 0.0;
    let colB: f32 = 0.0;

    for (let depth: i32 = 0; depth < MAX_DEPTH; depth++) {
      let closest: f32 = TMAX;
      let hitKind: i32 = -1;
      let hitIndex: i32 = 0;

      const tLight: f32 = quadHitT(
        ox, oy, oz, dx, dy, dz,
        123.0, 554.0, 147.0,
        300.0, 0.0, 0.0,
        0.0, 0.0, 265.0,
        TMIN, closest,
      );
      if (tLight > 0.0) {
        closest = tLight;
        hitKind = HIT_LIGHT;
      }

      seed = hashU(seed);
      const tMist: f32 = sphereVolumeHitT(
        ox, oy, oz, dx, dy, dz,
        0.0, 0.0, 0.0, 5000.0,
        MIST_NEG_INV, randomF(seed), TMIN, closest,
      );
      if (tMist > 0.0) {
        closest = tMist;
        hitKind = HIT_MIST;
      }

      for (let box: i32 = 0; box < BOX_SIDE * BOX_SIDE; box++) {
        const bi: i32 = box / BOX_SIDE;
        const bj: i32 = box % BOX_SIDE;
        const x0: f32 = -1000.0 + <f32>bi * 100.0;
        const z0: f32 = -1000.0 + <f32>bj * 100.0;
        const y1: f32 = boxY1(bi, bj);
        const t: f32 = aabbHitT(ox, oy, oz, dx, dy, dz, x0, 0.0, z0, x0 + 100.0, y1, z0 + 100.0, TMIN, closest);
        if (t > 0.0) {
          closest = t;
          hitKind = HIT_BOX;
          hitIndex = box;
        }
      }

      const cpx: f32 = ox + 100.0;
      const cpy: f32 = oy - 270.0;
      const cpz: f32 = oz - 395.0;
      const crox: f32 = COS_15 * cpx - SIN_15 * cpz;
      const croy: f32 = cpy;
      const croz: f32 = SIN_15 * cpx + COS_15 * cpz;
      const crdx: f32 = COS_15 * dx - SIN_15 * dz;
      const crdy: f32 = dy;
      const crdz: f32 = SIN_15 * dx + COS_15 * dz;
      for (let n: i32 = 0; n < CLUSTER_COUNT; n++) {
        const t: f32 = sphereHitT(
          crox, croy, croz, crdx, crdy, crdz,
          clusterCX(n), clusterCY(n), clusterCZ(n), 10.0,
          TMIN, closest,
        );
        if (t > 0.0) {
          closest = t;
          hitKind = HIT_CLUSTER;
          hitIndex = n;
        }
      }

      const tEarth: f32 = sphereHitT(ox, oy, oz, dx, dy, dz, 400.0, 200.0, 400.0, 100.0, TMIN, closest);
      if (tEarth > 0.0) {
        closest = tEarth;
        hitKind = HIT_EARTH;
      }
      const tMarble: f32 = sphereHitT(ox, oy, oz, dx, dy, dz, 220.0, 280.0, 300.0, 80.0, TMIN, closest);
      if (tMarble > 0.0) {
        closest = tMarble;
        hitKind = HIT_MARBLE;
      }
      const moveX: f32 = 400.0 + 30.0 * rayTime;
      const tMove: f32 = sphereHitT(ox, oy, oz, dx, dy, dz, moveX, 400.0, 200.0, 50.0, TMIN, closest);
      if (tMove > 0.0) {
        closest = tMove;
        hitKind = HIT_MOVE;
      }
      const tGlass1: f32 = sphereHitT(ox, oy, oz, dx, dy, dz, 260.0, 150.0, 45.0, 50.0, TMIN, closest);
      if (tGlass1 > 0.0) {
        closest = tGlass1;
        hitKind = HIT_GLASS1;
      }
      const tMetal: f32 = sphereHitT(ox, oy, oz, dx, dy, dz, 0.0, 150.0, 145.0, 50.0, TMIN, closest);
      if (tMetal > 0.0) {
        closest = tMetal;
        hitKind = HIT_METAL;
      }
      const tGlass2: f32 = sphereHitT(ox, oy, oz, dx, dy, dz, 360.0, 150.0, 145.0, 70.0, TMIN, closest);
      if (tGlass2 > 0.0) {
        closest = tGlass2;
        hitKind = HIT_GLASS2;
      }
      seed = hashU(seed);
      const tBlue: f32 = sphereVolumeHitT(
        ox, oy, oz, dx, dy, dz,
        360.0, 150.0, 145.0, 70.0,
        BLUE_NEG_INV, randomF(seed), TMIN, closest,
      );
      if (tBlue > 0.0) {
        closest = tBlue;
        hitKind = HIT_BLUE;
      }

      if (hitKind < 0) {
        attR = 0.0;
        attG = 0.0;
        attB = 0.0;
      } else if (hitKind == HIT_LIGHT) {
        colR += attR * 7.0;
        colG += attG * 7.0;
        colB += attB * 7.0;
        attR = 0.0;
        attG = 0.0;
        attB = 0.0;
      } else if (hitKind == HIT_MIST || hitKind == HIT_BLUE) {
        const hx: f32 = ox + dx * closest;
        const hy: f32 = oy + dy * closest;
        const hz: f32 = oz + dz * closest;
        let randX: f32 = 0.0;
        let randY: f32 = 0.0;
        let randZ: f32 = 0.0;
        for (let k: i32 = 0; k < 8; k++) {
          seed = hashU(seed);
          randX = randomF(seed) * 2.0 - 1.0;
          seed = hashU(seed);
          randY = randomF(seed) * 2.0 - 1.0;
          seed = hashU(seed);
          randZ = randomF(seed) * 2.0 - 1.0;
          if (randX * randX + randY * randY + randZ * randZ < 1.0) break;
        }
        let rlen: f32 = length3(randX, randY, randZ);
        if (rlen < 0.000001) rlen = 1.0;
        if (hitKind == HIT_BLUE) {
          attR *= 0.2;
          attG *= 0.4;
          attB *= 0.9;
        }
        ox = hx;
        oy = hy;
        oz = hz;
        dx = randX / rlen;
        dy = randY / rlen;
        dz = randZ / rlen;
      } else {
        const hx: f32 = ox + dx * closest;
        const hy: f32 = oy + dy * closest;
        const hz: f32 = oz + dz * closest;
        let cx: f32 = 0.0;
        let cy: f32 = 0.0;
        let cz: f32 = 0.0;
        let radius: f32 = 1.0;
        let mat: i32 = MAT_LAMBERT;
        let albedoR: f32 = 1.0;
        let albedoG: f32 = 1.0;
        let albedoB: f32 = 1.0;
        let fuzz: f32 = 0.0;
        let outwardX: f32 = 0.0;
        let outwardY: f32 = 1.0;
        let outwardZ: f32 = 0.0;

        if (hitKind == HIT_BOX) {
          const bi: i32 = hitIndex / BOX_SIDE;
          const bj: i32 = hitIndex % BOX_SIDE;
          const x0: f32 = -1000.0 + <f32>bi * 100.0;
          const z0: f32 = -1000.0 + <f32>bj * 100.0;
          const y1: f32 = boxY1(bi, bj);
          outwardX = aabbFaceNX(hx, hy, hz, x0, 0.0, z0, x0 + 100.0, y1, z0 + 100.0);
          outwardY = aabbFaceNY(hx, hy, hz, x0, 0.0, z0, x0 + 100.0, y1, z0 + 100.0);
          outwardZ = aabbFaceNZ(hx, hy, hz, x0, 0.0, z0, x0 + 100.0, y1, z0 + 100.0);
          albedoR = 0.48;
          albedoG = 0.83;
          albedoB = 0.53;
        } else if (hitKind == HIT_CLUSTER) {
          cx = clusterCX(hitIndex);
          cy = clusterCY(hitIndex);
          cz = clusterCZ(hitIndex);
          const lhx: f32 = crox + crdx * closest;
          const lhy: f32 = croy + crdy * closest;
          const lhz: f32 = croz + crdz * closest;
          const lnx: f32 = (lhx - cx) / 10.0;
          const lny: f32 = (lhy - cy) / 10.0;
          const lnz: f32 = (lhz - cz) / 10.0;
          outwardX = COS_15 * lnx + SIN_15 * lnz;
          outwardY = lny;
          outwardZ = -SIN_15 * lnx + COS_15 * lnz;
          albedoR = 0.73;
          albedoG = 0.73;
          albedoB = 0.73;
        } else if (hitKind == HIT_EARTH) {
          cx = 400.0; cy = 200.0; cz = 400.0; radius = 100.0;
          outwardX = (hx - cx) / radius;
          outwardY = (hy - cy) / radius;
          outwardZ = (hz - cz) / radius;
          const packed: i32 = sampleEarth(outwardX, outwardY, outwardZ);
          albedoR = <f32>(packed & 255) / 255.0;
          albedoG = <f32>((packed >> 8) & 255) / 255.0;
          albedoB = <f32>((packed >> 16) & 255) / 255.0;
        } else if (hitKind == HIT_MARBLE) {
          cx = 220.0; cy = 280.0; cz = 300.0; radius = 80.0;
          outwardX = (hx - cx) / radius;
          outwardY = (hy - cy) / radius;
          outwardZ = (hz - cz) / radius;
          const n: f32 = marble(hx, hy, hz);
          albedoR = n; albedoG = n; albedoB = n;
        } else if (hitKind == HIT_MOVE) {
          cx = moveX; cy = 400.0; cz = 200.0; radius = 50.0;
          outwardX = (hx - cx) / radius;
          outwardY = (hy - cy) / radius;
          outwardZ = (hz - cz) / radius;
          albedoR = 0.7; albedoG = 0.3; albedoB = 0.1;
        } else if (hitKind == HIT_GLASS1) {
          cx = 260.0; cy = 150.0; cz = 45.0; radius = 50.0;
          outwardX = (hx - cx) / radius;
          outwardY = (hy - cy) / radius;
          outwardZ = (hz - cz) / radius;
          mat = MAT_GLASS;
          albedoR = 1.0; albedoG = 1.0; albedoB = 1.0;
        } else if (hitKind == HIT_METAL) {
          cx = 0.0; cy = 150.0; cz = 145.0; radius = 50.0;
          outwardX = (hx - cx) / radius;
          outwardY = (hy - cy) / radius;
          outwardZ = (hz - cz) / radius;
          mat = MAT_METAL;
          albedoR = 0.8; albedoG = 0.8; albedoB = 0.9;
          fuzz = 1.0;
        } else {
          cx = 360.0; cy = 150.0; cz = 145.0; radius = 70.0;
          outwardX = (hx - cx) / radius;
          outwardY = (hy - cy) / radius;
          outwardZ = (hz - cz) / radius;
          mat = MAT_GLASS;
          albedoR = 1.0; albedoG = 1.0; albedoB = 1.0;
        }

        const frontFace: bool = dot3(dx, dy, dz, outwardX, outwardY, outwardZ) < 0.0;
        const nx: f32 = frontFace ? outwardX : -outwardX;
        const ny: f32 = frontFace ? outwardY : -outwardY;
        const nz: f32 = frontFace ? outwardZ : -outwardZ;

        let randX: f32 = 0.0;
        let randY: f32 = 0.0;
        let randZ: f32 = 0.0;
        for (let k: i32 = 0; k < 8; k++) {
          seed = hashU(seed);
          randX = randomF(seed) * 2.0 - 1.0;
          seed = hashU(seed);
          randY = randomF(seed) * 2.0 - 1.0;
          seed = hashU(seed);
          randZ = randomF(seed) * 2.0 - 1.0;
          if (randX * randX + randY * randY + randZ * randZ < 1.0) break;
        }
        let rlen: f32 = length3(randX, randY, randZ);
        if (rlen < 0.000001) rlen = 1.0;
        randX /= rlen;
        randY /= rlen;
        randZ /= rlen;

        ox = hx;
        oy = hy;
        oz = hz;

        if (mat == MAT_GLASS) {
          const inv: f32 = 1.0 / length3(dx, dy, dz);
          const ux: f32 = dx * inv;
          const uy: f32 = dy * inv;
          const uz: f32 = dz * inv;
          const ri: f32 = frontFace ? 1.0 / 1.5 : 1.5;
          const cosTheta: f32 = Mathf.min(-dot3(ux, uy, uz, nx, ny, nz), 1.0);
          const sinTheta: f32 = Mathf.sqrt(1.0 - cosTheta * cosTheta);
          seed = hashU(seed);
          const cannotRefract: bool = ri * sinTheta > 1.0 || reflectance(cosTheta, ri) > randomF(seed);
          if (cannotRefract) {
            const d: f32 = dot3(ux, uy, uz, nx, ny, nz);
            dx = ux - 2.0 * d * nx;
            dy = uy - 2.0 * d * ny;
            dz = uz - 2.0 * d * nz;
          } else {
            const px: f32 = ri * (ux + cosTheta * nx);
            const py: f32 = ri * (uy + cosTheta * ny);
            const pz: f32 = ri * (uz + cosTheta * nz);
            const plen2: f32 = px * px + py * py + pz * pz;
            const parallel: f32 = -Mathf.sqrt(Mathf.abs(1.0 - plen2));
            dx = px + parallel * nx;
            dy = py + parallel * ny;
            dz = pz + parallel * nz;
          }
        } else if (mat == MAT_METAL) {
          attR *= albedoR;
          attG *= albedoG;
          attB *= albedoB;
          const inv: f32 = 1.0 / length3(dx, dy, dz);
          const ux: f32 = dx * inv;
          const uy: f32 = dy * inv;
          const uz: f32 = dz * inv;
          const d: f32 = dot3(ux, uy, uz, nx, ny, nz);
          const sx: f32 = ux - 2.0 * d * nx + fuzz * randX;
          const sy: f32 = uy - 2.0 * d * ny + fuzz * randY;
          const sz: f32 = uz - 2.0 * d * nz + fuzz * randZ;
          if (dot3(sx, sy, sz, nx, ny, nz) > 0.0) {
            dx = sx;
            dy = sy;
            dz = sz;
          } else {
            attR = 0.0;
            attG = 0.0;
            attB = 0.0;
          }
        } else {
          attR *= albedoR;
          attG *= albedoG;
          attB *= albedoB;
          let sx: f32 = nx + randX;
          let sy: f32 = ny + randY;
          let sz: f32 = nz + randZ;
          if (sx * sx + sy * sy + sz * sz < 1.0e-16) {
            sx = nx;
            sy = ny;
            sz = nz;
          }
          dx = sx;
          dy = sy;
          dz = sz;
        }
      }
    }

    const oldR: f32 = initialized ? load<f32>(sumAddress) : 0.0;
    const oldG: f32 = initialized ? load<f32>(sumAddress + 4) : 0.0;
    const oldB: f32 = initialized ? load<f32>(sumAddress + 8) : 0.0;
    const newCount: f32 = oldCount + 1.0;
    store<f32>(sumAddress, oldR + colR);
    store<f32>(sumAddress + 4, oldG + colG);
    store<f32>(sumAddress + 8, oldB + colB);
    store<f32>(countAddress, newCount);
    if (!initialized) store<i32>(MAGIC_OFFSET, MAGIC);

    writeRgb(
      i,
      gammaByte((oldR + colR) / newCount),
      gammaByte((oldG + colG) / newCount),
      gammaByte((oldB + colB) / newCount),
    );
  }
}
