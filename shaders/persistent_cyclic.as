// ============================================================
//  persistent_cyclic.as - Cyclic cellular automaton
// ============================================================
//  A different flavor of persistent memory demo: every cell has
//  a color state from 0..15. A cell advances only when a neighbor
//  has the next state, producing chasing fronts and spiral waves.
//  The entire automaton lives in GPU-resident state memory.
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
const MAGIC: i32 = 1128353356; // CYCL

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

function seedState(x: i32, y: i32): i32 {
  const h: i32 = hash2(x, y);
  const rings: i32 = ((x - 64) * (x - 64) + (y - 64) * (y - 64)) >> 7;
  return (h + rings) & 15;
}

function sample(base: i32, x: i32, y: i32): i32 {
  const sx: i32 = wrapCoord(x);
  const sy: i32 = wrapCoord(y);
  return load<i32>(cellOffset(base, sy * FIELD + sx));
}

function hasNextNeighbor(base: i32, x: i32, y: i32, next: i32): bool {
  if (sample(base, x - 1, y - 1) == next) return true;
  if (sample(base, x,     y - 1) == next) return true;
  if (sample(base, x + 1, y - 1) == next) return true;
  if (sample(base, x - 1, y)     == next) return true;
  if (sample(base, x + 1, y)     == next) return true;
  if (sample(base, x - 1, y + 1) == next) return true;
  if (sample(base, x,     y + 1) == next) return true;
  if (sample(base, x + 1, y + 1) == next) return true;
  return false;
}

function paletteR(state: i32): i32 {
  const phase: i32 = (state * 48) & 255;
  return phase < 128 ? 255 - phase : phase;
}

function paletteG(state: i32): i32 {
  const phase: i32 = (state * 48 + 85) & 255;
  return phase < 128 ? 255 - phase : phase;
}

function paletteB(state: i32): i32 {
  const phase: i32 = (state * 48 + 170) & 255;
  return phase < 128 ? 255 - phase : phase;
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
      const state: i32 = seedState(sx, sy);
      store<i32>(cellOffset(BUFFER_A, i), state);
      store<i32>(cellOffset(BUFFER_B, i), state);
      if (i == 0) store<i32>(MAGIC_OFFSET, MAGIC);
    } else if (initialized && i < CELLS) {
      const x: i32 = i % FIELD;
      const y: i32 = i / FIELD;
      const state: i32 = load<i32>(cellOffset(readBase, i));
      const next: i32 = (state + 1) & 15;
      const advanced: bool = hasNextNeighbor(readBase, x, y, next);
      store<i32>(cellOffset(writeBase, i), advanced ? next : state);
    }

    const px: i32 = i % WIDTH;
    const py: i32 = i / WIDTH;
    const lx: i32 = px >> 1;
    const ly: i32 = py >> 1;
    const stateNow: i32 = load<i32>(cellOffset(readBase, ly * FIELD + lx));
    const checker: i32 = ((lx ^ ly) & 1) * 18;

    writePixel(
      i,
      paletteR(stateNow) - checker,
      paletteG(stateNow) - checker,
      paletteB(stateNow) - checker,
    );
  }
}
