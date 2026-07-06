// ============================================================
// Interactive Ripple Tank - persistent signed 16-bit waves
// ============================================================
// Drag across the canvas to inject energy. Two 128x128 i16 fields
// ping-pong between current and previous height. Surface gradients
// bend a moving light into bright caustic streaks.
// ============================================================

const WIDTH: i32 = 256;
const FIELD: i32 = 128;
const CELLS: i32 = FIELD * FIELD;
const STATE_OFFSET: i32 = 16 + WIDTH * WIDTH * 12;
const MAGIC_OFFSET: i32 = STATE_OFFSET;
const BUFFER_A: i32 = STATE_OFFSET + 16;
const BUFFER_B: i32 = BUFFER_A + CELLS * 2;
const MAGIC: i32 = 1380994124; // RIPL

function wrap(value: i32): i32 {
  return value < 0 ? value + FIELD : value >= FIELD ? value - FIELD : value;
}

function address(base: i32, x: i32, y: i32): i32 {
  return base + (wrap(y) * FIELD + wrap(x)) * 2;
}

function sample(base: i32, x: i32, y: i32): i32 {
  return <i32>load<i16>(address(base, x, y));
}

function clampWave(value: i32): i32 {
  return value < -30000 ? -30000 : value > 30000 ? 30000 : value;
}

function clamp255(value: i32): i32 {
  return value < 0 ? 0 : value > 255 ? 255 : value;
}

export function main(): void {
  const frame: i32 = <i32>load<f32>(0);
  const pointerX: i32 = load<i32>(4) >> 1;
  const pointerY: i32 = load<i32>(8) >> 1;
  const pointerButtons: i32 = load<i32>(12);
  const initializing: bool = frame < 2;
  const initialized: bool = !initializing;
  const readBase: i32 = (frame & 1) == 0 ? BUFFER_A : BUFFER_B;
  const writeBase: i32 = (frame & 1) == 0 ? BUFFER_B : BUFFER_A;

  for (let i: i32 = 0; i < WIDTH * WIDTH; i++) {
    if (i < CELLS / 2) {
      for (let lane: i32 = 0; lane < 2; lane++) {
        const cell: i32 = i * 2 + lane;
        const sx: i32 = cell & 127;
        const sy: i32 = cell >> 7;

        if (initializing) {
          const dx: i32 = sx - 64;
          const dy: i32 = sy - 64;
          const d2: i32 = dx * dx + dy * dy;
          const seed: i32 = d2 < 100 ? (100 - d2) * 260 : 0;
          store<i16>(BUFFER_A + cell * 2, <i16>seed);
          store<i16>(BUFFER_B + cell * 2, <i16>seed);
        } else {
          const neighbors: i32 =
            sample(readBase, sx - 1, sy)
            + sample(readBase, sx + 1, sy)
            + sample(readBase, sx, sy - 1)
            + sample(readBase, sx, sy + 1);
          let next: i32 = (neighbors >> 1) - sample(writeBase, sx, sy);
          next = next * 250 >> 8;

          if (pointerButtons != 0 && pointerX >= 0 && pointerY >= 0) {
            const pdx: i32 = sx - pointerX;
            const pdy: i32 = sy - pointerY;
            const pd2: i32 = pdx * pdx + pdy * pdy;
            if (pd2 < 25) next += (25 - pd2) * 700;
          }

          const autoX: i32 = 32 + ((frame * 3 >> 2) & 63);
          const autoY: i32 = 64 + (((frame >> 1) & 31) - 16);
          const adx: i32 = sx - autoX;
          const ady: i32 = sy - autoY;
          if ((frame % 120) < 2 && adx * adx + ady * ady < 16) next += 18000;

          store<i16>(writeBase + cell * 2, <i16>clampWave(next));
        }
      }
      if (i == 0 && initializing) store<i32>(MAGIC_OFFSET, MAGIC);
    }

    const x: i32 = i & 255;
    const y: i32 = i >> 8;
    const sx: i32 = x >> 1;
    const sy: i32 = y >> 1;
    const h: i32 = initialized ? sample(readBase, sx, sy) : 0;
    const gx: i32 = initialized ? sample(readBase, sx + 1, sy) - sample(readBase, sx - 1, sy) : 0;
    const gy: i32 = initialized ? sample(readBase, sx, sy + 1) - sample(readBase, sx, sy - 1) : 0;
    const caustic: i32 = clamp255(80 + ((gx - gy) >> 5));
    const crest: i32 = clamp255(128 + (h >> 6));
    const checker: i32 = ((sx >> 3) ^ (sy >> 3)) & 1;
    const r: i32 = clamp255(8 + caustic / 3 + checker * 5);
    const g: i32 = clamp255(28 + caustic + crest / 5);
    const b: i32 = clamp255(70 + crest + caustic / 2);

    const pixelOffset: i32 = 16 + i * 12;
    store<i32>(pixelOffset, r);
    store<i32>(pixelOffset + 4, g);
    store<i32>(pixelOffset + 8, b);
  }
}
