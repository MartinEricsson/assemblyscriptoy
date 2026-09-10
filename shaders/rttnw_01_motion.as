// ============================================================
//  Ray Tracing: The Next Week — Motion Blur
// ============================================================
//  Weekend sphere world with lambertian cell centers moving
//  during the shutter. One path per frame accumulates in
//  persistent memory.
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
const GRID: i32 = 10;
const GRID_A0: i32 = -5;

const TMIN: f32 = 0.001;
const TMAX: f32 = 100000.0;
const HALF_VFOV_TAN: f32 = 0.17632698;
const HALF_DEFOCUS_TAN: f32 = 0.00523599;

const MAT_LAMBERT: i32 = 0;
const MAT_METAL: i32 = 1;
const MAT_GLASS: i32 = 2;
const MAT_LIGHT: i32 = 3;
const MAT_ISO: i32 = 4;

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

function reflectance(cosine: f32, ri: f32): f32 {
  let r0: f32 = (1.0 - ri) / (1.0 + ri);
  r0 = r0 * r0;
  const m: f32 = 1.0 - cosine;
  const m2: f32 = m * m;
  return r0 + (1.0 - r0) * m2 * m2 * m;
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

function cellSeed(a: i32, b: i32, salt: i32): u32 {
  return hashU(<u32>(a * 1973 + b * 9277 + salt * 26699 + 12345));
}

function cellCX(a: i32, b: i32): f32 {
  return <f32>a + 0.9 * randomF(cellSeed(a, b, 2));
}

function cellCZ(a: i32, b: i32): f32 {
  return <f32>b + 0.9 * randomF(cellSeed(a, b, 3));
}

function cellAlive(a: i32, b: i32): bool {
  const dx: f32 = cellCX(a, b) - 4.0;
  const dz: f32 = cellCZ(a, b);
  return dx * dx + dz * dz > 0.81;
}

function cellChoose(a: i32, b: i32): f32 {
  return randomF(cellSeed(a, b, 1));
}

function cellMat(a: i32, b: i32): i32 {
  const choose: f32 = cellChoose(a, b);
  if (choose < 0.8) return MAT_LAMBERT;
  if (choose < 0.95) return MAT_METAL;
  return MAT_GLASS;
}

function cellAlbedoR(a: i32, b: i32): f32 {
  const mat: i32 = cellMat(a, b);
  if (mat == MAT_GLASS) return 1.0;
  if (mat == MAT_METAL) return 0.5 * (1.0 + randomF(cellSeed(a, b, 20)));
  return randomF(cellSeed(a, b, 10)) * randomF(cellSeed(a, b, 11));
}

function cellAlbedoG(a: i32, b: i32): f32 {
  const mat: i32 = cellMat(a, b);
  if (mat == MAT_GLASS) return 1.0;
  if (mat == MAT_METAL) return 0.5 * (1.0 + randomF(cellSeed(a, b, 21)));
  return randomF(cellSeed(a, b, 12)) * randomF(cellSeed(a, b, 13));
}

function cellAlbedoB(a: i32, b: i32): f32 {
  const mat: i32 = cellMat(a, b);
  if (mat == MAT_GLASS) return 1.0;
  if (mat == MAT_METAL) return 0.5 * (1.0 + randomF(cellSeed(a, b, 22)));
  return randomF(cellSeed(a, b, 14)) * randomF(cellSeed(a, b, 15));
}

function cellFuzz(a: i32, b: i32): f32 {
  if (cellMat(a, b) != MAT_METAL) return 0.0;
  return 0.5 * randomF(cellSeed(a, b, 23));
}

function cellCY(a: i32, b: i32, time: f32): f32 {
  if (cellMat(a, b) != MAT_LAMBERT) return 0.2;
  return 0.2 + time * 0.5 * randomF(cellSeed(a, b, 30));
}

function heroCX(id: i32): f32 {
  if (id == 2) return -4.0;
  if (id == 3) return 4.0;
  return 0.0;
}

function heroCY(id: i32): f32 {
  return id == 0 ? -1000.0 : 1.0;
}

function heroCZ(id: i32): f32 {
  return 0.0;
}

function heroRadius(id: i32): f32 {
  return id == 0 ? 1000.0 : 1.0;
}

function heroMat(id: i32): i32 {
  if (id == 1) return MAT_GLASS;
  if (id == 3) return MAT_METAL;
  return MAT_LAMBERT;
}

function heroAlbedoR(id: i32): f32 {
  if (id == 0) return 0.5;
  if (id == 2) return 0.4;
  if (id == 3) return 0.7;
  return 1.0;
}

function heroAlbedoG(id: i32): f32 {
  if (id == 0) return 0.5;
  if (id == 2) return 0.2;
  if (id == 3) return 0.6;
  return 1.0;
}

function heroAlbedoB(id: i32): f32 {
  if (id == 0) return 0.5;
  if (id == 2) return 0.1;
  if (id == 3) return 0.5;
  return 1.0;
}

export function main(): void {
  const frame: i32 = <i32>load<f32>(0);
  const initialized: bool = load<i32>(MAGIC_OFFSET) == MAGIC;

  const lookfromX: f32 = 13.0;
  const lookfromY: f32 = 2.0;
  const lookfromZ: f32 = 3.0;
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

  const focusDist: f32 = 10.0;
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
  const defocusRadius: f32 = focusDist * HALF_DEFOCUS_TAN;
  const diskUX: f32 = uX * defocusRadius;
  const diskUY: f32 = uY * defocusRadius;
  const diskUZ: f32 = uZ * defocusRadius;
  const diskVX: f32 = vX * defocusRadius;
  const diskVY: f32 = vY * defocusRadius;
  const diskVZ: f32 = vZ * defocusRadius;

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

    let diskX: f32 = 0.0;
    let diskY: f32 = 0.0;
    for (let k: i32 = 0; k < 8; k++) {
      seed = hashU(seed);
      diskX = randomF(seed) * 2.0 - 1.0;
      seed = hashU(seed);
      diskY = randomF(seed) * 2.0 - 1.0;
      if (diskX * diskX + diskY * diskY < 1.0) break;
    }

    let ox: f32 = lookfromX + diskX * diskUX + diskY * diskVX;
    let oy: f32 = lookfromY + diskX * diskUY + diskY * diskVY;
    let oz: f32 = lookfromZ + diskX * diskUZ + diskY * diskVZ;
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
      let hitId: i32 = -1;

      for (let s: i32 = 0; s < 4; s++) {
        const t: f32 = sphereHitT(
          ox, oy, oz, dx, dy, dz,
          heroCX(s), heroCY(s), heroCZ(s), heroRadius(s),
          TMIN, closest,
        );
        if (t > 0.0) {
          closest = t;
          hitId = s;
        }
      }

      for (let cell: i32 = 0; cell < GRID * GRID; cell++) {
        const a: i32 = cell / GRID + GRID_A0;
        const b: i32 = cell % GRID + GRID_A0;
        if (!cellAlive(a, b)) continue;
        const t: f32 = sphereHitT(
          ox, oy, oz, dx, dy, dz,
          cellCX(a, b), cellCY(a, b, rayTime), cellCZ(a, b), 0.2,
          TMIN, closest,
        );
        if (t > 0.0) {
          closest = t;
          hitId = 4 + cell;
        }
      }

      if (hitId < 0) {
        const a: f32 = 0.5 * (dy / length3(dx, dy, dz) + 1.0);
        colR += attR * ((1.0 - a) * 1.0 + a * 0.5);
        colG += attG * ((1.0 - a) * 1.0 + a * 0.7);
        colB += attB * ((1.0 - a) * 1.0 + a * 1.0);
        attR = 0.0;
        attG = 0.0;
        attB = 0.0;
      } else {
        let cx: f32 = 0.0;
        let cy: f32 = 0.0;
        let cz: f32 = 0.0;
        let radius: f32 = 0.2;
        let mat: i32 = MAT_LAMBERT;
        let albedoR: f32 = 1.0;
        let albedoG: f32 = 1.0;
        let albedoB: f32 = 1.0;
        let fuzz: f32 = 0.0;
        if (hitId < 4) {
          cx = heroCX(hitId);
          cy = heroCY(hitId);
          cz = heroCZ(hitId);
          radius = heroRadius(hitId);
          mat = heroMat(hitId);
          albedoR = heroAlbedoR(hitId);
          albedoG = heroAlbedoG(hitId);
          albedoB = heroAlbedoB(hitId);
        } else {
          const cell: i32 = hitId - 4;
          const a: i32 = cell / GRID + GRID_A0;
          const b: i32 = cell % GRID + GRID_A0;
          cx = cellCX(a, b);
          cy = cellCY(a, b, rayTime);
          cz = cellCZ(a, b);
          mat = cellMat(a, b);
          albedoR = cellAlbedoR(a, b);
          albedoG = cellAlbedoG(a, b);
          albedoB = cellAlbedoB(a, b);
          fuzz = cellFuzz(a, b);
        }

        const hx: f32 = ox + dx * closest;
        const hy: f32 = oy + dy * closest;
        const hz: f32 = oz + dz * closest;
        const outwardX: f32 = (hx - cx) / radius;
        const outwardY: f32 = (hy - cy) / radius;
        const outwardZ: f32 = (hz - cz) / radius;
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

        if (mat == MAT_LAMBERT) {
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
        } else if (mat == MAT_METAL) {
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
