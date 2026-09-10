// ============================================================
//  Ray Tracing in One Weekend — Antialiasing
// ============================================================
//  Four jittered samples per pixel average the same two-sphere
//  normal scene, softening silhouette jaggies.
// ============================================================

const WIDTH: i32 = 256;
const HEIGHT: i32 = 256;
const IMAGE_WIDTH: i32 = 256;
const IMAGE_HEIGHT: i32 = 144;
const LETTERBOX: i32 = 56;
const SAMPLES: i32 = 4;

const VIEWPORT_HEIGHT: f32 = 2.0;
const FOCAL_LENGTH: f32 = 1.0;
const TMIN: f32 = 0.001;
const TMAX: f32 = 100000.0;

function colorByte(v: f32): i32 {
  let c: f32 = v;
  if (c < 0.0) c = 0.0;
  if (c > 1.0) c = 1.0;
  return <i32>(c * 255.0);
}

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

function rayColorR(dx: f32, dy: f32, dz: f32): f32 {
  let closest: f32 = TMAX;
  let hitId: i32 = -1;
  const t0: f32 = sphereHitT(0.0, 0.0, 0.0, dx, dy, dz, 0.0, 0.0, -1.0, 0.5, TMIN, closest);
  if (t0 > 0.0) {
    closest = t0;
    hitId = 0;
  }
  const t1: f32 = sphereHitT(0.0, 0.0, 0.0, dx, dy, dz, 0.0, -100.5, -1.0, 100.0, TMIN, closest);
  if (t1 > 0.0) {
    closest = t1;
    hitId = 1;
  }
  if (hitId < 0) {
    const a: f32 = 0.5 * (dy / length3(dx, dy, dz) + 1.0);
    return (1.0 - a) * 1.0 + a * 0.5;
  }
  const radius: f32 = hitId == 0 ? 0.5 : 100.0;
  const cy: f32 = hitId == 0 ? 0.0 : -100.5;
  return 0.5 * ((dy * closest - cy) / radius + 1.0);
}

function rayColorG(dx: f32, dy: f32, dz: f32): f32 {
  let closest: f32 = TMAX;
  let hitId: i32 = -1;
  const t0: f32 = sphereHitT(0.0, 0.0, 0.0, dx, dy, dz, 0.0, 0.0, -1.0, 0.5, TMIN, closest);
  if (t0 > 0.0) {
    closest = t0;
    hitId = 0;
  }
  const t1: f32 = sphereHitT(0.0, 0.0, 0.0, dx, dy, dz, 0.0, -100.5, -1.0, 100.0, TMIN, closest);
  if (t1 > 0.0) {
    closest = t1;
    hitId = 1;
  }
  if (hitId < 0) {
    const a: f32 = 0.5 * (dy / length3(dx, dy, dz) + 1.0);
    return (1.0 - a) * 1.0 + a * 0.7;
  }
  const radius: f32 = hitId == 0 ? 0.5 : 100.0;
  const cy: f32 = hitId == 0 ? 0.0 : -100.5;
  return 0.5 * ((dy * closest - cy) / radius + 1.0);
}

function rayColorB(dx: f32, dy: f32, dz: f32): f32 {
  let closest: f32 = TMAX;
  let hitId: i32 = -1;
  const t0: f32 = sphereHitT(0.0, 0.0, 0.0, dx, dy, dz, 0.0, 0.0, -1.0, 0.5, TMIN, closest);
  if (t0 > 0.0) {
    closest = t0;
    hitId = 0;
  }
  const t1: f32 = sphereHitT(0.0, 0.0, 0.0, dx, dy, dz, 0.0, -100.5, -1.0, 100.0, TMIN, closest);
  if (t1 > 0.0) {
    closest = t1;
    hitId = 1;
  }
  if (hitId < 0) {
    const a: f32 = 0.5 * (dy / length3(dx, dy, dz) + 1.0);
    return (1.0 - a) * 1.0 + a * 1.0;
  }
  const nz: f32 = (dz * closest + 1.0) / (hitId == 0 ? 0.5 : 100.0);
  return 0.5 * (nz + 1.0);
}

export function main(): void {
  const viewportWidth: f32 = VIEWPORT_HEIGHT * <f32>IMAGE_WIDTH / <f32>IMAGE_HEIGHT;
  const deltaUX: f32 = viewportWidth / <f32>IMAGE_WIDTH;
  const deltaVY: f32 = -VIEWPORT_HEIGHT / <f32>IMAGE_HEIGHT;
  const pixel00X: f32 = -0.5 * viewportWidth + 0.5 * deltaUX;
  const pixel00Y: f32 = 0.5 * VIEWPORT_HEIGHT + 0.5 * deltaVY;
  const pixel00Z: f32 = -FOCAL_LENGTH;
  const invSamples: f32 = 1.0 / <f32>SAMPLES;

  for (let i: i32 = 0; i < WIDTH * HEIGHT; i++) {
    const x: i32 = i % WIDTH;
    const y: i32 = i / WIDTH;
    const imageY: i32 = y - LETTERBOX;

    let r: i32 = 0;
    let g: i32 = 0;
    let b: i32 = 0;

    if (imageY >= 0 && imageY < IMAGE_HEIGHT) {
      let sumR: f32 = 0.0;
      let sumG: f32 = 0.0;
      let sumB: f32 = 0.0;
      let seed: u32 = hashU(<u32>(x * 1973 + imageY * 9277 + 1) | 1);
      for (let s: i32 = 0; s < SAMPLES; s++) {
        seed = hashU(seed);
        const ox: f32 = randomF(seed) - 0.5;
        seed = hashU(seed);
        const oy: f32 = randomF(seed) - 0.5;
        const dx: f32 = pixel00X + (<f32>x + ox) * deltaUX;
        const dy: f32 = pixel00Y + (<f32>imageY + oy) * deltaVY;
        const dz: f32 = pixel00Z;
        sumR += rayColorR(dx, dy, dz);
        sumG += rayColorG(dx, dy, dz);
        sumB += rayColorB(dx, dy, dz);
      }
      r = colorByte(sumR * invSamples);
      g = colorByte(sumG * invSamples);
      b = colorByte(sumB * invSamples);
    }

    const pixelOffset: i32 = 16 + i * 12;
    store<i32>(pixelOffset, r);
    store<i32>(pixelOffset + 4, g);
    store<i32>(pixelOffset + 8, b);
  }
}
