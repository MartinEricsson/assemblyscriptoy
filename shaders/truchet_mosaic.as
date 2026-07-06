// ============================================================
// Truchet Mosaic - hashed tiles and arc geometry
// ============================================================
// Every 16x16 tile chooses one of two diagonal arc orientations.
// The integer hash supplies stable variation while time changes
// symmetry and palette without requiring stored state.
// ============================================================

const WIDTH: i32 = 256;
const PI: f32 = 3.14159265;
const TWO_PI: f32 = 6.28318530;

function hash2(x: i32, y: i32): i32 {
  let value: i32 = x * 374761393 + y * 668265263;
  value = (value ^ (value >> 13)) * 1274126177;
  return value ^ (value >> 16);
}

function sinF(value: f32): f32 {
  let x: f32 = value - Mathf.floor(value / TWO_PI + 0.5) * TWO_PI;
  if (x > PI * 0.5) x = PI - x;
  if (x < -PI * 0.5) x = -PI - x;
  const x2: f32 = x * x;
  return x * (1.0 - x2 / 6.0 * (1.0 - x2 / 20.0));
}

function clampF(value: f32, low: f32, high: f32): f32 {
  return Mathf.min(Mathf.max(value, low), high);
}

export function main(): void {
  const frame: i32 = <i32>load<f32>(0);
  const time: f32 = <f32>frame * 0.018;
  const phase: i32 = frame / 90;

  for (let i: i32 = 0; i < WIDTH * WIDTH; i++) {
    const x: i32 = i & 255;
    const y: i32 = i >> 8;
    let tileX: i32 = x >> 4;
    let tileY: i32 = y >> 4;

    if ((phase & 1) != 0) tileX = 15 - tileX;
    if ((phase & 2) != 0) tileY = 15 - tileY;

    const lx: f32 = (<f32>(x & 15) + 0.5) / 16.0;
    const ly: f32 = (<f32>(y & 15) + 0.5) / 16.0;
    const orientation: i32 = hash2(tileX + phase * 3, tileY - phase * 5) & 1;

    let d1: f32;
    let d2: f32;
    if (orientation == 0) {
      d1 = Mathf.abs(Mathf.sqrt(lx * lx + ly * ly) - 0.5);
      const ax: f32 = lx - 1.0;
      const ay: f32 = ly - 1.0;
      d2 = Mathf.abs(Mathf.sqrt(ax * ax + ay * ay) - 0.5);
    } else {
      const ax: f32 = lx - 1.0;
      d1 = Mathf.abs(Mathf.sqrt(ax * ax + ly * ly) - 0.5);
      const by: f32 = ly - 1.0;
      d2 = Mathf.abs(Mathf.sqrt(lx * lx + by * by) - 0.5);
    }

    const distance: f32 = Mathf.min(d1, d2);
    const line: f32 = clampF((0.095 - distance) * 34.0, 0.0, 1.0);
    const glow: f32 = clampF((0.22 - distance) * 4.2, 0.0, 1.0);
    const pulse: f32 = 0.5 + 0.5 * sinF(time * 2.0 + <f32>(tileX + tileY) * 0.35);
    const hue: f32 = <f32>((hash2(tileX, tileY) >> 5) & 255) / 255.0 + time * 0.04;

    let r: f32 = 0.025 + glow * (0.18 + pulse * 0.22);
    let g: f32 = 0.02 + glow * (0.10 + (1.0 - pulse) * 0.25);
    let b: f32 = 0.06 + glow * 0.42;
    r += line * (0.65 + 0.35 * sinF(hue * TWO_PI));
    g += line * (0.65 + 0.35 * sinF((hue + 0.33) * TWO_PI));
    b += line * (0.65 + 0.35 * sinF((hue + 0.66) * TWO_PI));

    const offset: i32 = 16 + i * 12;
    store<i32>(offset, <i32>(clampF(r, 0.0, 1.0) * 255.0));
    store<i32>(offset + 4, <i32>(clampF(g, 0.0, 1.0) * 255.0));
    store<i32>(offset + 8, <i32>(clampF(b, 0.0, 1.0) * 255.0));
  }
}
