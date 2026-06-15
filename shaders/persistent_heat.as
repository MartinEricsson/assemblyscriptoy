// ============================================================
//  Persistent Heat - diffusion with retained state
// ============================================================
//  A 128x128 heat field is diffused, cooled, and fed by two moving
//  sources. Each simulation cell is displayed as a 2x2 pixel block.
//
//  The two i32 state buffers ping-pong so every new value is based
//  on the same previous frame. The weighted centre sample controls
//  how quickly heat spreads; 246/256 applies cooling, and
//  clampHeat() prevents sources from growing without bound.
//
//  State starts at byte 786448. The two 128x128 buffers consume
//  131,072 bytes plus metadata and fit inside the 1 MiB memory.
//  A magic value distinguishes an initialized zero-temperature
//  field from fresh memory. Recompiling resets the simulation.
//
//  Colours are derived from heat >> 4, so changing the heat range
//  may also require changing the palette scaling.
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
const MAGIC: i32 = 1212502356; // HEAT

function clamp255(v: i32): i32 {
  if (v < 0) return 0;
  if (v > 255) return 255;
  return v;
}


function clampHeat(v: i32): i32 {
  if (v < 0) return 0;
  if (v > 4096) return 4096;
  return v;
}

function cellOffset(base: i32, idx: i32): i32 {
  return base + idx * 4;
}

function wrapCoord(v: i32): i32 {
  if (v < 0) return v + FIELD;
  if (v >= FIELD) return v - FIELD;
  return v;
}

function triWave(v: i32): i32 {
  const x: i32 = v & 255;
  return x < 128 ? x * 2 : 511 - x * 2;
}

function sample(base: i32, x: i32, y: i32): i32 {
  const sx: i32 = wrapCoord(x);
  const sy: i32 = wrapCoord(y);
  return load<i32>(cellOffset(base, sy * FIELD + sx));
}

function sourceHeat(x: i32, y: i32, frame: i32): i32 {
  const sx0: i32 = 20 + (triWave(frame * 2) >> 1);
  const sy0: i32 = 24 + (triWave(frame * 3 + 70) >> 2);
  const sx1: i32 = 108 - (triWave(frame * 2 + 110) >> 1);
  const sy1: i32 = 104 - (triWave(frame + 30) >> 2);

  const dx0: i32 = x - sx0;
  const dy0: i32 = y - sy0;
  const dx1: i32 = x - sx1;
  const dy1: i32 = y - sy1;
  const d0: i32 = dx0 * dx0 + dy0 * dy0;
  const d1: i32 = dx1 * dx1 + dy1 * dy1;

  let heat: i32 = 0;
  if (d0 < 90) heat += 3600 - d0 * 24;
  if (d1 < 70) heat += 3000 - d1 * 26;
  return heat;
}

function writePixel(i: i32, r: i32, g: i32, b: i32): void {
  const pixelOffset: i32 = OUTPUT_OFFSET + i * 12;
  store<i32>(pixelOffset, clamp255(r));
  store<i32>(pixelOffset + 4, clamp255(g));
  store<i32>(pixelOffset + 8, clamp255(b));
}

export function main(): void {
  const frame: i32 = i32(load<f32>(TIME_OFFSET));
  const initialized: bool = load<i32>(MAGIC_OFFSET) == MAGIC;
  const readBase: i32 = (frame & 1) == 0 ? BUFFER_A : BUFFER_B;
  const writeBase: i32 = (frame & 1) == 0 ? BUFFER_B : BUFFER_A;

  for (let i: i32 = 0; i < WIDTH * HEIGHT; i++) {
    if (!initialized && i < CELLS) {
      store<i32>(cellOffset(BUFFER_A, i), 0);
      store<i32>(cellOffset(BUFFER_B, i), 0);
      if (i == 0) store<i32>(MAGIC_OFFSET, MAGIC);
    } else if (initialized && i < CELLS) {
      const x: i32 = i % FIELD;
      const y: i32 = i / FIELD;

      const c: i32 = sample(readBase, x, y) * 4;
      const n: i32 = sample(readBase, x, y - 1);
      const s: i32 = sample(readBase, x, y + 1);
      const e: i32 = sample(readBase, x + 1, y);
      const w: i32 = sample(readBase, x - 1, y);
      let next: i32 = (c + n + s + e + w) / 8;
      next = (next * 246) / 256;
      next += sourceHeat(x, y, frame);
      store<i32>(cellOffset(writeBase, i), clampHeat(next));
    }

    const px: i32 = i % WIDTH;
    const py: i32 = i / WIDTH;
    const lx: i32 = px >> 1;
    const ly: i32 = py >> 1;
    const heat: i32 = load<i32>(cellOffset(readBase, ly * FIELD + lx));
    const v: i32 = heat >> 4;

    const r: i32 = v + (v >> 1);
    const g: i32 = v - 40;
    const b: i32 = 180 - v;
    writePixel(i, r, g, b);
  }
}
