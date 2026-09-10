// ============================================================
//  Ray Tracing: The Next Week — Lights
// ============================================================
//  Marble spheres lit by an emissive quad and sphere against a
//  black background. One path per frame accumulates in persistent
//  memory.
// ============================================================

const WIDTH: i32 = 256;
const HEIGHT: i32 = 256;
const IMAGE_WIDTH: i32 = 256;
const IMAGE_HEIGHT: i32 = 144;
const LETTERBOX: i32 = 56;
const PIXEL_COUNT: i32 = 65536;
const STATE_OFFSET: i32 = 16 + PIXEL_COUNT * 12;
const MAGIC_OFFSET: i32 = STATE_OFFSET;
const SUM_OFFSET: i32 = STATE_OFFSET + 16;
const COUNT_OFFSET: i32 = SUM_OFFSET + PIXEL_COUNT * 12;
const MAGIC: i32 = 0x52544E57;
const MAX_DEPTH: i32 = 10;
const TURB_DEPTH: i32 = 7;

const TMIN: f32 = 0.001;
const TMAX: f32 = 100000.0;
const HALF_VFOV_TAN: f32 = 0.17632698;
const PI: f32 = 3.14159265;
const TWO_PI: f32 = 6.28318530;

const MAT_LAMBERT: i32 = 0;
const MAT_METAL: i32 = 1;
const MAT_GLASS: i32 = 2;
const MAT_LIGHT: i32 = 3;
const MAT_ISO: i32 = 4;

const EMIT: f32 = 4.0;

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
  return 0.5 * (1.0 + sinF(4.0 * pz + 10.0 * turb(px, py, pz)));
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

export function main(): void {
  const frame: i32 = <i32>load<f32>(0);
  const initialized: bool = load<i32>(MAGIC_OFFSET) == MAGIC;

  const lookfromX: f32 = 26.0;
  const lookfromY: f32 = 3.0;
  const lookfromZ: f32 = 6.0;
  const lookatX: f32 = 0.0;
  const lookatY: f32 = 2.0;
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

    let attR: f32 = 1.0;
    let attG: f32 = 1.0;
    let attB: f32 = 1.0;
    let colR: f32 = 0.0;
    let colG: f32 = 0.0;
    let colB: f32 = 0.0;

    for (let depth: i32 = 0; depth < MAX_DEPTH; depth++) {
      let closest: f32 = TMAX;
      let hitId: i32 = -1;

      const tGround: f32 = sphereHitT(ox, oy, oz, dx, dy, dz, 0.0, -1000.0, 0.0, 1000.0, TMIN, closest);
      if (tGround > 0.0) {
        closest = tGround;
        hitId = 0;
      }
      const tBall: f32 = sphereHitT(ox, oy, oz, dx, dy, dz, 0.0, 2.0, 0.0, 2.0, TMIN, closest);
      if (tBall > 0.0) {
        closest = tBall;
        hitId = 1;
      }
      const tLightSphere: f32 = sphereHitT(ox, oy, oz, dx, dy, dz, 0.0, 7.0, 0.0, 2.0, TMIN, closest);
      if (tLightSphere > 0.0) {
        closest = tLightSphere;
        hitId = 2;
      }
      const tLightQuad: f32 = quadHitT(
        ox, oy, oz, dx, dy, dz,
        3.0, 1.0, -2.0,
        2.0, 0.0, 0.0,
        0.0, 2.0, 0.0,
        TMIN, closest,
      );
      if (tLightQuad > 0.0) {
        closest = tLightQuad;
        hitId = 3;
      }

      if (hitId < 0) {
        attR = 0.0;
        attG = 0.0;
        attB = 0.0;
      } else if (hitId >= 2) {
        colR += attR * EMIT;
        colG += attG * EMIT;
        colB += attB * EMIT;
        attR = 0.0;
        attG = 0.0;
        attB = 0.0;
      } else {
        const cy: f32 = hitId == 0 ? -1000.0 : 2.0;
        const radius: f32 = hitId == 0 ? 1000.0 : 2.0;
        const hx: f32 = ox + dx * closest;
        const hy: f32 = oy + dy * closest;
        const hz: f32 = oz + dz * closest;
        const outwardX: f32 = hx / radius;
        const outwardY: f32 = (hy - cy) / radius;
        const outwardZ: f32 = hz / radius;
        const frontFace: bool = dot3(dx, dy, dz, outwardX, outwardY, outwardZ) < 0.0;
        const nx: f32 = frontFace ? outwardX : -outwardX;
        const ny: f32 = frontFace ? outwardY : -outwardY;
        const nz: f32 = frontFace ? outwardZ : -outwardZ;
        const n: f32 = marble(hx, hy, hz);

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

        attR *= n;
        attG *= n;
        attB *= n;
        ox = hx;
        oy = hy;
        oz = hz;
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
