// ============================================================
//  Ray Tracing: The Next Week — Cornell Box
// ============================================================
//  Book Cornell walls, ceiling light, and two white AABBs with
//  rotate_y + translate. One path per frame accumulates in
//  persistent memory.
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
const MAX_DEPTH: i32 = 8;

const TMIN: f32 = 0.001;
const TMAX: f32 = 100000.0;
const HALF_VFOV_TAN: f32 = 0.36397023;

const MAT_LAMBERT: i32 = 0;
const MAT_METAL: i32 = 1;
const MAT_GLASS: i32 = 2;
const MAT_LIGHT: i32 = 3;
const MAT_ISO: i32 = 4;

const SIN_15: f32 = 0.25881905;
const COS_15: f32 = 0.96592583;
const SIN_N18: f32 = -0.30901699;
const COS_N18: f32 = 0.95105652;

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

function rotatedBoxHitT(
  ox: f32, oy: f32, oz: f32,
  dx: f32, dy: f32, dz: f32,
  minX: f32, minY: f32, minZ: f32,
  maxX: f32, maxY: f32, maxZ: f32,
  offX: f32, offY: f32, offZ: f32,
  sinT: f32, cosT: f32,
  tMin: f32,
  tMax: f32,
): f32 {
  const px: f32 = ox - offX;
  const py: f32 = oy - offY;
  const pz: f32 = oz - offZ;
  const rox: f32 = cosT * px - sinT * pz;
  const roy: f32 = py;
  const roz: f32 = sinT * px + cosT * pz;
  const rdx: f32 = cosT * dx - sinT * dz;
  const rdy: f32 = dy;
  const rdz: f32 = sinT * dx + cosT * dz;
  return aabbHitT(rox, roy, roz, rdx, rdy, rdz, minX, minY, minZ, maxX, maxY, maxZ, tMin, tMax);
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

function wallQX(id: i32): f32 {
  if (id == 0) return 555.0;
  if (id == 2) return 343.0;
  if (id == 4) return 555.0;
  return 0.0;
}

function wallQY(id: i32): f32 {
  if (id == 2) return 554.0;
  if (id == 4) return 555.0;
  return 0.0;
}

function wallQZ(id: i32): f32 {
  if (id == 2) return 332.0;
  if (id == 4) return 555.0;
  if (id == 5) return 555.0;
  return 0.0;
}

function wallUX(id: i32): f32 {
  if (id == 0 || id == 1) return 0.0;
  if (id == 2) return -130.0;
  if (id == 4) return -555.0;
  return 555.0;
}

function wallUY(id: i32): f32 {
  if (id == 0 || id == 1) return 555.0;
  return 0.0;
}

function wallUZ(id: i32): f32 { return 0.0; }

function wallVX(id: i32): f32 { return 0.0; }

function wallVY(id: i32): f32 {
  if (id == 5) return 555.0;
  return 0.0;
}

function wallVZ(id: i32): f32 {
  if (id == 2) return -105.0;
  if (id == 4) return -555.0;
  if (id == 5) return 0.0;
  return 555.0;
}

function wallAlbedoR(id: i32): f32 {
  if (id == 0) return 0.12;
  if (id == 1) return 0.65;
  return 0.73;
}

function wallAlbedoG(id: i32): f32 {
  if (id == 0) return 0.45;
  if (id == 1) return 0.05;
  return 0.73;
}

function wallAlbedoB(id: i32): f32 {
  if (id == 0) return 0.15;
  if (id == 1) return 0.05;
  return 0.73;
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

export function main(): void {
  const frame: i32 = <i32>load<f32>(0);
  const initialized: bool = load<i32>(MAGIC_OFFSET) == MAGIC;

  const lookfromX: f32 = 278.0;
  const lookfromY: f32 = 278.0;
  const lookfromZ: f32 = -800.0;
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

    let attR: f32 = 1.0;
    let attG: f32 = 1.0;
    let attB: f32 = 1.0;
    let colR: f32 = 0.0;
    let colG: f32 = 0.0;
    let colB: f32 = 0.0;

    for (let depth: i32 = 0; depth < MAX_DEPTH; depth++) {
      let closest: f32 = TMAX;
      let hitId: i32 = -1;

      for (let w: i32 = 0; w < 6; w++) {
        const t: f32 = quadHitT(
          ox, oy, oz, dx, dy, dz,
          wallQX(w), wallQY(w), wallQZ(w),
          wallUX(w), wallUY(w), wallUZ(w),
          wallVX(w), wallVY(w), wallVZ(w),
          TMIN, closest,
        );
        if (t > 0.0) {
          closest = t;
          hitId = w;
        }
      }

      const tTall: f32 = rotatedBoxHitT(
        ox, oy, oz, dx, dy, dz,
        0.0, 0.0, 0.0, 165.0, 330.0, 165.0,
        265.0, 0.0, 295.0, SIN_15, COS_15,
        TMIN, closest,
      );
      if (tTall > 0.0) {
        closest = tTall;
        hitId = 6;
      }
      const tShort: f32 = rotatedBoxHitT(
        ox, oy, oz, dx, dy, dz,
        0.0, 0.0, 0.0, 165.0, 165.0, 165.0,
        130.0, 0.0, 65.0, SIN_N18, COS_N18,
        TMIN, closest,
      );
      if (tShort > 0.0) {
        closest = tShort;
        hitId = 7;
      }

      if (hitId < 0) {
        attR = 0.0;
        attG = 0.0;
        attB = 0.0;
      } else if (hitId == 2) {
        colR += attR * 15.0;
        colG += attG * 15.0;
        colB += attB * 15.0;
        attR = 0.0;
        attG = 0.0;
        attB = 0.0;
      } else {
        const hx: f32 = ox + dx * closest;
        const hy: f32 = oy + dy * closest;
        const hz: f32 = oz + dz * closest;
        let outwardX: f32 = 0.0;
        let outwardY: f32 = 0.0;
        let outwardZ: f32 = 0.0;
        let albedoR: f32 = 0.73;
        let albedoG: f32 = 0.73;
        let albedoB: f32 = 0.73;

        if (hitId < 6) {
          albedoR = wallAlbedoR(hitId);
          albedoG = wallAlbedoG(hitId);
          albedoB = wallAlbedoB(hitId);
          const ux: f32 = wallUX(hitId);
          const uy: f32 = wallUY(hitId);
          const uz: f32 = wallUZ(hitId);
          const vx: f32 = wallVX(hitId);
          const vy: f32 = wallVY(hitId);
          const vz: f32 = wallVZ(hitId);
          const rawX: f32 = crossX(uy, uz, vy, vz);
          const rawY: f32 = crossY(uz, ux, vz, vx);
          const rawZ: f32 = crossZ(ux, uy, vx, vy);
          const nlen: f32 = length3(rawX, rawY, rawZ);
          outwardX = rawX / nlen;
          outwardY = rawY / nlen;
          outwardZ = rawZ / nlen;
        } else {
          const tall: bool = hitId == 6;
          const offX: f32 = tall ? 265.0 : 130.0;
          const offZ: f32 = tall ? 295.0 : 65.0;
          const sinT: f32 = tall ? SIN_15 : SIN_N18;
          const cosT: f32 = tall ? COS_15 : COS_N18;
          const maxY: f32 = tall ? 330.0 : 165.0;
          const px: f32 = hx - offX;
          const pz: f32 = hz - offZ;
          const lx: f32 = cosT * px - sinT * pz;
          const ly: f32 = hy;
          const lz: f32 = sinT * px + cosT * pz;
          const lnx: f32 = aabbFaceNX(lx, ly, lz, 0.0, 0.0, 0.0, 165.0, maxY, 165.0);
          const lny: f32 = aabbFaceNY(lx, ly, lz, 0.0, 0.0, 0.0, 165.0, maxY, 165.0);
          const lnz: f32 = aabbFaceNZ(lx, ly, lz, 0.0, 0.0, 0.0, 165.0, maxY, 165.0);
          outwardX = cosT * lnx + sinT * lnz;
          outwardY = lny;
          outwardZ = -sinT * lnx + cosT * lnz;
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

        attR *= albedoR;
        attG *= albedoG;
        attB *= albedoB;
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
