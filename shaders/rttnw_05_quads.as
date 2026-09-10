// ============================================================
//  Ray Tracing: The Next Week — Quads
// ============================================================
//  Five lambertian parallelograms from the book, square frame.
//  One path per frame accumulates in persistent memory.
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
const MAGIC: i32 = 0x52544E57;
const MAX_DEPTH: i32 = 10;

const TMIN: f32 = 0.001;
const TMAX: f32 = 100000.0;
const HALF_VFOV_TAN: f32 = 0.83909963;

const MAT_LAMBERT: i32 = 0;
const MAT_METAL: i32 = 1;
const MAT_GLASS: i32 = 2;
const MAT_LIGHT: i32 = 3;
const MAT_ISO: i32 = 4;

const BG_R: f32 = 0.70;
const BG_G: f32 = 0.80;
const BG_B: f32 = 1.00;

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

function quadQX(id: i32): f32 {
  if (id == 0) return -3.0;
  if (id == 1) return -2.0;
  if (id == 2) return 3.0;
  return -2.0;
}

function quadQY(id: i32): f32 {
  if (id == 3) return 3.0;
  if (id == 4) return -3.0;
  return -2.0;
}

function quadQZ(id: i32): f32 {
  if (id == 0) return 5.0;
  if (id == 1) return 0.0;
  if (id == 4) return 5.0;
  return 1.0;
}

function quadUX(id: i32): f32 {
  if (id == 0) return 0.0;
  if (id == 2) return 0.0;
  return 4.0;
}

function quadUY(id: i32): f32 { return 0.0; }

function quadUZ(id: i32): f32 {
  if (id == 0) return -4.0;
  if (id == 2) return 4.0;
  if (id == 3) return 4.0;
  if (id == 4) return -4.0;
  return 0.0;
}

function quadVX(id: i32): f32 { return 0.0; }

function quadVY(id: i32): f32 {
  if (id <= 2) return 4.0;
  return 0.0;
}

function quadVZ(id: i32): f32 {
  if (id == 3) return 4.0;
  if (id == 4) return -4.0;
  return 0.0;
}

function quadAlbedoR(id: i32): f32 {
  if (id == 0) return 1.0;
  if (id == 3) return 1.0;
  return 0.2;
}

function quadAlbedoG(id: i32): f32 {
  if (id == 0) return 0.2;
  if (id == 1) return 1.0;
  if (id == 3) return 0.5;
  if (id == 4) return 0.8;
  return 0.2;
}

function quadAlbedoB(id: i32): f32 {
  if (id == 2) return 1.0;
  if (id == 4) return 0.8;
  return 0.2;
}

function quadHitT(
  ox: f32, oy: f32, oz: f32,
  dx: f32, dy: f32, dz: f32,
  id: i32,
  tMin: f32,
  tMax: f32,
): f32 {
  const qx: f32 = quadQX(id);
  const qy: f32 = quadQY(id);
  const qz: f32 = quadQZ(id);
  const ux: f32 = quadUX(id);
  const uy: f32 = quadUY(id);
  const uz: f32 = quadUZ(id);
  const vx: f32 = quadVX(id);
  const vy: f32 = quadVY(id);
  const vz: f32 = quadVZ(id);
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

export function main(): void {
  const frame: i32 = <i32>load<f32>(0);
  const initialized: bool = load<i32>(MAGIC_OFFSET) == MAGIC;

  const lookfromX: f32 = 0.0;
  const lookfromY: f32 = 0.0;
  const lookfromZ: f32 = 9.0;
  const wLen: f32 = length3(lookfromX, lookfromY, lookfromZ);
  const wX: f32 = lookfromX / wLen;
  const wY: f32 = lookfromY / wLen;
  const wZ: f32 = lookfromZ / wLen;
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

  const focusDist: f32 = 9.0;
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

      for (let q: i32 = 0; q < 5; q++) {
        const t: f32 = quadHitT(ox, oy, oz, dx, dy, dz, q, TMIN, closest);
        if (t > 0.0) {
          closest = t;
          hitId = q;
        }
      }

      if (hitId < 0) {
        colR += attR * BG_R;
        colG += attG * BG_G;
        colB += attB * BG_B;
        attR = 0.0;
        attG = 0.0;
        attB = 0.0;
      } else {
        const qx: f32 = quadQX(hitId);
        const qy: f32 = quadQY(hitId);
        const qz: f32 = quadQZ(hitId);
        const ux: f32 = quadUX(hitId);
        const uy: f32 = quadUY(hitId);
        const uz: f32 = quadUZ(hitId);
        const vx: f32 = quadVX(hitId);
        const vy: f32 = quadVY(hitId);
        const vz: f32 = quadVZ(hitId);
        const rawX: f32 = crossX(uy, uz, vy, vz);
        const rawY: f32 = crossY(uz, ux, vz, vx);
        const rawZ: f32 = crossZ(ux, uy, vx, vy);
        const nlen: f32 = length3(rawX, rawY, rawZ);
        const outwardX: f32 = rawX / nlen;
        const outwardY: f32 = rawY / nlen;
        const outwardZ: f32 = rawZ / nlen;
        const frontFace: bool = dot3(dx, dy, dz, outwardX, outwardY, outwardZ) < 0.0;
        const nx: f32 = frontFace ? outwardX : -outwardX;
        const ny: f32 = frontFace ? outwardY : -outwardY;
        const nz: f32 = frontFace ? outwardZ : -outwardZ;
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
        randX /= rlen;
        randY /= rlen;
        randZ /= rlen;

        attR *= quadAlbedoR(hitId);
        attG *= quadAlbedoG(hitId);
        attB *= quadAlbedoB(hitId);
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
