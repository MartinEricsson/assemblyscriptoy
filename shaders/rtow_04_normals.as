// ============================================================
//  Ray Tracing in One Weekend — Surface Normals
// ============================================================
//  The sphere hit now returns the nearest positive t. The unit
//  normal is mapped to RGB with 0.5 * (n + 1).
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

function dot3(ax: f32, ay: f32, az: f32, bx: f32, by: f32, bz: f32): f32 {
  return ax * bx + ay * by + az * bz;
}

function hitSphereT(
  ox: f32, oy: f32, oz: f32,
  dx: f32, dy: f32, dz: f32,
  cx: f32, cy: f32, cz: f32,
  radius: f32,
): f32 {
  const ocx: f32 = cx - ox;
  const ocy: f32 = cy - oy;
  const ocz: f32 = cz - oz;
  const a: f32 = dot3(dx, dy, dz, dx, dy, dz);
  const h: f32 = dot3(dx, dy, dz, ocx, ocy, ocz);
  const c: f32 = dot3(ocx, ocy, ocz, ocx, ocy, ocz) - radius * radius;
  const discriminant: f32 = h * h - a * c;
  if (discriminant < 0.0) return -1.0;
  return (h - Mathf.sqrt(discriminant)) / a;
}

function skyR(dx: f32, dy: f32, dz: f32): f32 {
  const a: f32 = 0.5 * (dy / length3(dx, dy, dz) + 1.0);
  return (1.0 - a) * 1.0 + a * 0.5;
}

function skyG(dx: f32, dy: f32, dz: f32): f32 {
  const a: f32 = 0.5 * (dy / length3(dx, dy, dz) + 1.0);
  return (1.0 - a) * 1.0 + a * 0.7;
}

function skyB(dx: f32, dy: f32, dz: f32): f32 {
  const a: f32 = 0.5 * (dy / length3(dx, dy, dz) + 1.0);
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
      const t: f32 = hitSphereT(0.0, 0.0, 0.0, dx, dy, dz, 0.0, 0.0, -1.0, 0.5);
      if (t > 0.0) {
        const hx: f32 = dx * t;
        const hy: f32 = dy * t;
        const hz: f32 = dz * t + 1.0;
        const inv: f32 = 1.0 / length3(hx, hy, hz);
        r = colorByte(0.5 * (hx * inv + 1.0));
        g = colorByte(0.5 * (hy * inv + 1.0));
        b = colorByte(0.5 * (hz * inv + 1.0));
      } else {
        r = colorByte(skyR(dx, dy, dz));
        g = colorByte(skyG(dx, dy, dz));
        b = colorByte(skyB(dx, dy, dz));
      }
    }

    const pixelOffset: i32 = 16 + i * 12;
    store<i32>(pixelOffset, r);
    store<i32>(pixelOffset + 4, g);
    store<i32>(pixelOffset + 8, b);
  }
}
