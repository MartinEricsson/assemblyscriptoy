// ============================================================
//  persistent_life.as - Conway's Life in GPU-resident memory
// ============================================================
//  Demonstrates the new persistent state region. The CPU uploads
//  only time/uniform bytes each frame; the 128x128 Life grid stays
//  on the GPU and ping-pongs between two state buffers.
// ============================================================

const WIDTH: i32 = 256;
const HEIGHT: i32 = 256;
const FIELD: i32 = 128;
const CELLS: i32 = FIELD * FIELD;
const TIME_OFFSET: i32 = 0;
const OUTPUT_OFFSET: i32 = 16;
const STATE_OFFSET: i32 = OUTPUT_OFFSET + WIDTH * HEIGHT * 12;
const MAGIC_OFFSET: i32 = STATE_OFFSET;
const BUFFER_A: i32 = STATE_OFFSET + 16;
const BUFFER_B: i32 = BUFFER_A + CELLS * 4;
const MAGIC: i32 = 1196379185; // GOL1

function cellOffset(base: i32, idx: i32): i32 {
  return base + idx * 4;
}


function wrapCoord(v: i32): i32 {
  if (v < 0) return v + FIELD;
  if (v >= FIELD) return v - FIELD;
  return v;
}

function hash2(x: i32, y: i32): i32 {
  let h: i32 = x * 374761393 + y * 668265263;
  h = (h ^ (h >> 13)) * 1274126177;
  return h ^ (h >> 16);
}

function seedCell(x: i32, y: i32): i32 {
  const h: i32 = hash2(x, y);
  const sparse: bool = (h & 7) == 0;

  const gx: i32 = x - 60;
  const gy: i32 = y - 60;
  const glider: bool =
    (gx == 1 && gy == 0) ||
    (gx == 2 && gy == 1) ||
    (gx == 0 && gy == 2) ||
    (gx == 1 && gy == 2) ||
    (gx == 2 && gy == 2);

  return sparse || glider ? 255 : 0;
}

function neighborCount(base: i32, x: i32, y: i32): i32 {
  let count: i32 = 0;
  for (let oy: i32 = -1; oy <= 1; oy++) {
    for (let ox: i32 = -1; ox <= 1; ox++) {
      if (ox != 0 || oy != 0) {
        const nx: i32 = wrapCoord(x + ox);
        const ny: i32 = wrapCoord(y + oy);
        const alive: i32 = load<i32>(cellOffset(base, ny * FIELD + nx));
        if (alive != 0) count++;
      }
    }
  }
  return count;
}

function writePixel(i: i32, r: i32, g: i32, b: i32): void {
  const pixelOffset: i32 = OUTPUT_OFFSET + i * 12;
  store<i32>(pixelOffset, r);
  store<i32>(pixelOffset + 4, g);
  store<i32>(pixelOffset + 8, b);
}

export function main(): void {
  const frame: i32 = i32(load<f32>(TIME_OFFSET));
  const initialized: bool = load<i32>(MAGIC_OFFSET) == MAGIC;
  const readBase: i32 = (frame & 1) == 0 ? BUFFER_A : BUFFER_B;
  const writeBase: i32 = (frame & 1) == 0 ? BUFFER_B : BUFFER_A;

  for (let i: i32 = 0; i < WIDTH * HEIGHT; i++) {
    if (!initialized && i < CELLS) {
      const sx: i32 = i % FIELD;
      const sy: i32 = i / FIELD;
      const value: i32 = seedCell(sx, sy);
      store<i32>(cellOffset(BUFFER_A, i), value);
      store<i32>(cellOffset(BUFFER_B, i), value);
      if (i == 0) store<i32>(MAGIC_OFFSET, MAGIC);
    } else if (initialized && i < CELLS) {
      const cx: i32 = i % FIELD;
      const cy: i32 = i / FIELD;
      const alive: bool = load<i32>(cellOffset(readBase, i)) != 0;
      const n: i32 = neighborCount(readBase, cx, cy);
      const nextAlive: bool = alive ? (n == 2 || n == 3) : (n == 3);
      store<i32>(cellOffset(writeBase, i), nextAlive ? 255 : 0);
    }

    const px: i32 = i % WIDTH;
    const py: i32 = i / WIDTH;
    const lx: i32 = px >> 1;
    const ly: i32 = py >> 1;
    const aliveNow: i32 = load<i32>(cellOffset(readBase, ly * FIELD + lx));

    if (aliveNow != 0) {
      const tint: i32 = (lx * 3 + ly * 5 + frame * 4) & 63;
      writePixel(i, 110 + tint, 220, 180 + (tint >> 1));
    } else {
      const grid: i32 = ((lx ^ ly) & 15) == 0 ? 18 : 6;
      writePixel(i, grid, grid + 4, grid + 10);
    }
  }
}