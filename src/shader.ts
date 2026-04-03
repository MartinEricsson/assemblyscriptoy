// Voronoi cellular diagram - animated seeds
const WIDTH: i32 = 128;
const HEIGHT: i32 = 128;
const TIME_OFFSET: i32 = 0;

function hash2(x: i32, y: i32): i32 {
  let h: i32 = x * 374761393 + y * 668265263;
  h = (h ^ (h >> 13)) * 1274126177;
  return (h >> 16) & 255;
}

export function main(): void {
  const t: i32 = load<i32>(TIME_OFFSET) & 255;
  const total: i32 = WIDTH * HEIGHT;

  const CELLS_X: i32 = 8;
  const CELLS_Y: i32 = 8;
  const cellW: i32 = WIDTH / CELLS_X;
  const cellH: i32 = HEIGHT / CELLS_Y;

  for (let i: i32 = 0; i < total; i = i + 1) {
    const x: i32 = i % WIDTH;
    const y: i32 = i / WIDTH;

    let best: i32 = 2147483647;
    let bestHue: i32 = 0;

    for (let cy: i32 = 0; cy < CELLS_Y; cy = cy + 1) {
      for (let cx: i32 = 0; cx < CELLS_X; cx = cx + 1) {
        const jh: i32 = hash2(cx, cy);
        const sx: i32 = cx * cellW + ((jh + t) & (cellW - 1));
        const sy: i32 = cy * cellH + (((jh >> 3) + t * 3) & (cellH - 1));
        const dx: i32 = x - sx;
        const dy: i32 = y - sy;
        const d2: i32 = dx * dx + dy * dy;
        if (d2 < best) {
          best = d2;
          bestHue = jh;
        }
      }
    }

    const hue: i32 = bestHue & 255;
    const r: i32 = (hue * 2) & 255;
    const g: i32 = (hue * 3) & 255;
    const b: i32 = (255 - hue) & 255;

    const off: i32 = 16 + i * 12;
    store<i32>(off, r);
    store<i32>(off + 4, g);
    store<i32>(off + 8, b);
  }
}
