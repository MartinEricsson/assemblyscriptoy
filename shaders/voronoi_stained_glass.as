// ============================================================
// Voronoi Stained Glass - nested search and moving feature points
// ============================================================
// Each pixel searches a 3x3 neighborhood of procedural feature
// points. The closest point colors the pane; the gap between the
// two closest distances becomes the luminous lead border.
// ============================================================

const WIDTH: i32 = 256;
const PI: f32 = 3.14159265;
const TWO_PI: f32 = 6.28318530;

function hashI(x: i32, y: i32, salt: i32): i32 {
  let value: i32 = x * 1103515245 + y * 12345 + salt * 374761393;
  value ^= value >> 16;
  value *= 1274126177;
  return value ^ (value >> 13);
}

function hashF(x: i32, y: i32, salt: i32): f32 {
  return <f32>(hashI(x, y, salt) & 65535) / 65535.0;
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
  const time: f32 = load<f32>(0) * 0.012;
  const scale: f32 = 9.0;

  for (let i: i32 = 0; i < WIDTH * WIDTH; i++) {
    const px: f32 = (<f32>(i & 255) + 0.5) / 256.0 * scale;
    const py: f32 = (<f32>(i >> 8) + 0.5) / 256.0 * scale;
    const cellX: i32 = <i32>Mathf.floor(px);
    const cellY: i32 = <i32>Mathf.floor(py);
    let nearest: f32 = 1000.0;
    let second: f32 = 1000.0;
    let nearestX: i32 = 0;
    let nearestY: i32 = 0;

    for (let oy: i32 = -1; oy <= 1; oy++) {
      for (let ox: i32 = -1; ox <= 1; ox++) {
        const gx: i32 = cellX + ox;
        const gy: i32 = cellY + oy;
        const seed: f32 = hashF(gx, gy, 7) * TWO_PI;
        const fx: f32 = <f32>gx + 0.5
          + sinF(time * 0.9 + seed) * 0.28;
        const fy: f32 = <f32>gy + 0.5
          + sinF(time * 0.7 + seed * 1.73) * 0.28;
        const dx: f32 = fx - px;
        const dy: f32 = fy - py;
        const distance: f32 = dx * dx + dy * dy;
        if (distance < nearest) {
          second = nearest;
          nearest = distance;
          nearestX = gx;
          nearestY = gy;
        } else if (distance < second) {
          second = distance;
        }
      }
    }

    const edgeDistance: f32 = Mathf.sqrt(second) - Mathf.sqrt(nearest);
    const lead: f32 = clampF((0.095 - edgeDistance) * 16.0, 0.0, 1.0);
    const innerGlow: f32 = clampF(1.0 - Mathf.sqrt(nearest) * 0.85, 0.0, 1.0);
    const hue: f32 = hashF(nearestX, nearestY, 31) + time * 0.025;
    const shimmer: f32 = 0.75 + 0.25 * sinF((px + py) * 2.0 - time * 2.0);

    let r: f32 = (0.45 + 0.42 * sinF((hue + 0.00) * TWO_PI)) * innerGlow * shimmer;
    let g: f32 = (0.45 + 0.42 * sinF((hue + 0.33) * TWO_PI)) * innerGlow * shimmer;
    let b: f32 = (0.45 + 0.42 * sinF((hue + 0.66) * TWO_PI)) * innerGlow * shimmer;
    r = r * (1.0 - lead) + lead * 0.98;
    g = g * (1.0 - lead) + lead * 0.82;
    b = b * (1.0 - lead) + lead * 0.42;

    const offset: i32 = 16 + i * 12;
    store<i32>(offset, <i32>(clampF(r, 0.0, 1.0) * 255.0));
    store<i32>(offset + 4, <i32>(clampF(g, 0.0, 1.0) * 255.0));
    store<i32>(offset + 8, <i32>(clampF(b, 0.0, 1.0) * 255.0));
  }
}
