// ============================================================
//  Ray Tracing in One Weekend — Rays, Camera, and Sky
// ============================================================
//  Viewport rays from a camera at the origin look down -Z. The
//  16:9 image is letterboxed into the 256x256 canvas. Color is a
//  lerp from white to blue based on the unit ray's Y direction.
// ============================================================

const WIDTH: i32 = 256;
const HEIGHT: i32 = 256;
const IMAGE_WIDTH: i32 = 256;
const IMAGE_HEIGHT: i32 = 144;
const LETTERBOX: i32 = 56;

const VIEWPORT_HEIGHT: f32 = 2.0;
const FOCAL_LENGTH: f32 = 1.0;

function colorByte(v: f32): i32 {
  let c: f32 = v;
  if (c < 0.0) c = 0.0;
  if (c > 1.0) c = 1.0;
  return <i32>(c * 255.0);
}

function length3(x: f32, y: f32, z: f32): f32 {
  return Mathf.sqrt(x * x + y * y + z * z);
}

function rayColorR(dx: f32, dy: f32, dz: f32): f32 {
  const inv: f32 = 1.0 / length3(dx, dy, dz);
  const a: f32 = 0.5 * (dy * inv + 1.0);
  return (1.0 - a) * 1.0 + a * 0.5;
}

function rayColorG(dx: f32, dy: f32, dz: f32): f32 {
  const inv: f32 = 1.0 / length3(dx, dy, dz);
  const a: f32 = 0.5 * (dy * inv + 1.0);
  return (1.0 - a) * 1.0 + a * 0.7;
}

function rayColorB(dx: f32, dy: f32, dz: f32): f32 {
  const inv: f32 = 1.0 / length3(dx, dy, dz);
  const a: f32 = 0.5 * (dy * inv + 1.0);
  return (1.0 - a) * 1.0 + a * 1.0;
}

export function main(): void {
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

    let r: i32 = 0;
    let g: i32 = 0;
    let b: i32 = 0;

    if (imageY >= 0 && imageY < IMAGE_HEIGHT) {
      const dx: f32 = pixel00X + <f32>x * deltaUX;
      const dy: f32 = pixel00Y + <f32>imageY * deltaVY;
      const dz: f32 = pixel00Z;
      r = colorByte(rayColorR(dx, dy, dz));
      g = colorByte(rayColorG(dx, dy, dz));
      b = colorByte(rayColorB(dx, dy, dz));
    }

    const pixelOffset: i32 = 16 + i * 12;
    store<i32>(pixelOffset, r);
    store<i32>(pixelOffset + 4, g);
    store<i32>(pixelOffset + 8, b);
  }
}
