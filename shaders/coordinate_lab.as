// ============================================================
// Coordinate Lab - four foundations in one shader
// ============================================================
// The quadrants demonstrate normalized gradients, integer grids,
// radial distance, and polar wedges. Change one formula at a time
// to see how the same pixel loop can produce very different images.
// ============================================================

const WIDTH: i32 = 256;
const HEIGHT: i32 = 256;
const PI: f32 = 3.14159265;
const TWO_PI: f32 = 6.28318530;

function clampF(value: f32, low: f32, high: f32): f32 {
  return Mathf.min(Mathf.max(value, low), high);
}

function sinF(value: f32): f32 {
  let x: f32 = value - Mathf.floor(value / TWO_PI + 0.5) * TWO_PI;
  if (x > PI * 0.5) x = PI - x;
  if (x < -PI * 0.5) x = -PI - x;
  const x2: f32 = x * x;
  return x * (1.0 - x2 / 6.0 * (1.0 - x2 / 20.0));
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

export function main(): void {
  const time: f32 = load<f32>(0) * 0.025;

  for (let i: i32 = 0; i < WIDTH * HEIGHT; i++) {
    const x: i32 = i & 255;
    const y: i32 = i >> 8;
    const panelX: i32 = x >> 7;
    const panelY: i32 = y >> 7;
    const localX: i32 = x & 127;
    const localY: i32 = y & 127;
    const u: f32 = (<f32>localX + 0.5) / 128.0;
    const v: f32 = (<f32>localY + 0.5) / 128.0;

    let r: f32 = 0.0;
    let g: f32 = 0.0;
    let b: f32 = 0.0;

    if (panelX == 0 && panelY == 0) {
      r = u;
      g = v;
      b = 0.5 + 0.5 * sinF((u + v) * 8.0 - time);
    } else if (panelX == 1 && panelY == 0) {
      const gridX: i32 = (localX + <i32>(time * 10.0)) & 15;
      const gridY: i32 = (localY - <i32>(time * 7.0)) & 15;
      const line: bool = gridX < 2 || gridY < 2;
      const checker: i32 = ((localX >> 4) ^ (localY >> 4)) & 1;
      r = line ? 0.95 : 0.08 + <f32>checker * 0.12;
      g = line ? 0.35 : 0.12;
      b = line ? 0.75 : 0.24 + <f32>checker * 0.18;
    } else if (panelX == 0) {
      const dx: f32 = u - 0.5;
      const dy: f32 = v - 0.5;
      const distance: f32 = Mathf.sqrt(dx * dx + dy * dy);
      const rings: f32 = 0.5 + 0.5 * sinF(distance * 70.0 - time * 4.0);
      const glow: f32 = clampF(1.0 - distance * 1.7, 0.0, 1.0);
      r = rings * glow;
      g = glow * (0.3 + 0.7 * (1.0 - rings));
      b = 0.45 + rings * 0.5;
    } else {
      const dx: f32 = u - 0.5;
      const dy: f32 = v - 0.5;
      const distance: f32 = Mathf.sqrt(dx * dx + dy * dy);
      const angle: f32 = atan2F(dy, dx);
      const wedge: i32 = <i32>Mathf.floor((angle + PI + time) * 6.0 / TWO_PI);
      const bright: f32 = ((wedge & 1) == 0) ? 1.0 : 0.18;
      r = bright * (0.4 + distance);
      g = bright * 0.85;
      b = 1.0 - bright * 0.45 + distance * 0.3;
    }

    if (localX == 0 || localY == 0 || localX == 127 || localY == 127) {
      r = 0.02;
      g = 0.02;
      b = 0.02;
    }

    const offset: i32 = 16 + i * 12;
    store<i32>(offset, <i32>(clampF(r, 0.0, 1.0) * 255.0));
    store<i32>(offset + 4, <i32>(clampF(g, 0.0, 1.0) * 255.0));
    store<i32>(offset + 8, <i32>(clampF(b, 0.0, 1.0) * 255.0));
  }
}
