// ============================================================
//  Ray Tracing in One Weekend — Diffuse Materials
// ============================================================
//  Two lambertian spheres bounce paths with a bounded random
//  unit vector. One sample accumulates per frame in persistent
//  memory; recompile to reset. Display uses gamma (square root).
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
const MAGIC: i32 = 0x52544F57;
const MAX_DEPTH: i32 = 8;

const VIEWPORT_HEIGHT: f32 = 2.0;
const FOCAL_LENGTH: f32 = 1.0;
const TMIN: f32 = 0.001;
const TMAX: f32 = 100000.0;

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

export function main(): void {
  const frame: i32 = <i32>load<f32>(0);
  const initialized: bool = load<i32>(MAGIC_OFFSET) == MAGIC;
  const viewportWidth: f32 = VIEWPORT_HEIGHT * <f32>IMAGE_WIDTH / <f32>IMAGE_HEIGHT;
  const deltaUX: f32 = viewportWidth / <f32>IMAGE_WIDTH;
  const deltaVY: f32 = -VIEWPORT_HEIGHT / <f32>IMAGE_HEIGHT;
  const pixel00X: f32 = -0.5 * viewportWidth + 0.5 * deltaUX;
  const pixel00Y: f32 = 0.5 * VIEWPORT_HEIGHT + 0.5 * deltaVY;
  const pixel00Z: f32 = -FOCAL_LENGTH;

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

    let ox: f32 = 0.0;
    let oy: f32 = 0.0;
    let oz: f32 = 0.0;
    let dx: f32 = pixel00X + (<f32>x + jitterX) * deltaUX;
    let dy: f32 = pixel00Y + (<f32>imageY + jitterY) * deltaVY;
    let dz: f32 = pixel00Z;

    let attR: f32 = 1.0;
    let attG: f32 = 1.0;
    let attB: f32 = 1.0;
    let colR: f32 = 0.0;
    let colG: f32 = 0.0;
    let colB: f32 = 0.0;

    for (let depth: i32 = 0; depth < MAX_DEPTH; depth++) {
      let closest: f32 = TMAX;
      let hitId: i32 = -1;
      const t0: f32 = sphereHitT(ox, oy, oz, dx, dy, dz, 0.0, 0.0, -1.0, 0.5, TMIN, closest);
      if (t0 > 0.0) {
        closest = t0;
        hitId = 0;
      }
      const t1: f32 = sphereHitT(ox, oy, oz, dx, dy, dz, 0.0, -100.5, -1.0, 100.0, TMIN, closest);
      if (t1 > 0.0) {
        closest = t1;
        hitId = 1;
      }

      if (hitId < 0) {
        const a: f32 = 0.5 * (dy / length3(dx, dy, dz) + 1.0);
        colR += attR * ((1.0 - a) * 1.0 + a * 0.5);
        colG += attG * ((1.0 - a) * 1.0 + a * 0.7);
        colB += attB * ((1.0 - a) * 1.0 + a * 1.0);
        break;
      }

      const cx: f32 = 0.0;
      const cy: f32 = hitId == 0 ? 0.0 : -100.5;
      const cz: f32 = -1.0;
      const radius: f32 = hitId == 0 ? 0.5 : 100.0;
      const hx: f32 = ox + dx * closest;
      const hy: f32 = oy + dy * closest;
      const hz: f32 = oz + dz * closest;
      let nx: f32 = (hx - cx) / radius;
      let ny: f32 = (hy - cy) / radius;
      let nz: f32 = (hz - cz) / radius;
      if (dot3(dx, dy, dz, nx, ny, nz) > 0.0) {
        nx = -nx;
        ny = -ny;
        nz = -nz;
      }

      let rx: f32 = 0.0;
      let ry: f32 = 0.0;
      let rz: f32 = 0.0;
      for (let k: i32 = 0; k < 8; k++) {
        seed = hashU(seed);
        rx = randomF(seed) * 2.0 - 1.0;
        seed = hashU(seed);
        ry = randomF(seed) * 2.0 - 1.0;
        seed = hashU(seed);
        rz = randomF(seed) * 2.0 - 1.0;
        if (rx * rx + ry * ry + rz * rz < 1.0) break;
      }
      let rlen: f32 = length3(rx, ry, rz);
      if (rlen < 0.000001) rlen = 1.0;
      rx = nx + rx / rlen;
      ry = ny + ry / rlen;
      rz = nz + rz / rlen;
      if (rx * rx + ry * ry + rz * rz < 1.0e-16) {
        rx = nx;
        ry = ny;
        rz = nz;
      }

      attR *= 0.5;
      attG *= 0.5;
      attB *= 0.5;
      ox = hx;
      oy = hy;
      oz = hz;
      dx = rx;
      dy = ry;
      dz = rz;
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
