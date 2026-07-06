// ============================================================
// Gray-Scott Coral Lab - persistent unsigned 16-bit chemistry
// ============================================================
// Four u16 fields hold U/V chemicals for two ping-pong generations.
// Drag to paint reagent V. Diffusion and reaction grow spots, folds,
// and coral-like fronts from compact 128x128 state.
// ============================================================

const WIDTH: i32 = 256;
const FIELD: i32 = 128;
const CELLS: i32 = FIELD * FIELD;
const FIELD_BYTES: i32 = CELLS * 2;
const STATE_OFFSET: i32 = 16 + WIDTH * WIDTH * 12;
const MAGIC_OFFSET: i32 = STATE_OFFSET;
const A_U: i32 = STATE_OFFSET + 16;
const A_V: i32 = A_U + FIELD_BYTES;
const B_U: i32 = A_V + FIELD_BYTES;
const B_V: i32 = B_U + FIELD_BYTES;
const MAGIC: i32 = 1129270348; // CORL

function wrap(value: i32): i32 {
  return value < 0 ? value + FIELD : value >= FIELD ? value - FIELD : value;
}

function address(base: i32, x: i32, y: i32): i32 {
  return base + (wrap(y) * FIELD + wrap(x)) * 2;
}

function sample(base: i32, x: i32, y: i32): f32 {
  return <f32>load<u16>(address(base, x, y)) / 65535.0;
}

function clampF(value: f32, low: f32, high: f32): f32 {
  return Mathf.min(Mathf.max(value, low), high);
}

function storeChemical(base: i32, index: i32, value: f32): void {
  store<u16>(base + index * 2, <u16>(clampF(value, 0.0, 1.0) * 65535.0));
}

function seedV(x: i32, y: i32): f32 {
  const dx1: i32 = x - 42;
  const dy1: i32 = y - 58;
  const dx2: i32 = x - 84;
  const dy2: i32 = y - 70;
  const hash: i32 = ((x * 37) ^ (y * 91) ^ (x * y * 7)) & 255;
  if (dx1 * dx1 + dy1 * dy1 < 90) return 0.92;
  if (dx2 * dx2 + dy2 * dy2 < 130) return 0.82;
  return hash > 249 ? 0.72 : 0.0;
}

export function main(): void {
  const frame: i32 = <i32>load<f32>(0);
  const pointerX: i32 = load<i32>(4) >> 1;
  const pointerY: i32 = load<i32>(8) >> 1;
  const pointerButtons: i32 = load<i32>(12);
  const initializing: bool = frame < 2;
  const initialized: bool = !initializing;
  const readU: i32 = (frame & 1) == 0 ? A_U : B_U;
  const readV: i32 = (frame & 1) == 0 ? A_V : B_V;
  const writeU: i32 = (frame & 1) == 0 ? B_U : A_U;
  const writeV: i32 = (frame & 1) == 0 ? B_V : A_V;

  for (let i: i32 = 0; i < WIDTH * WIDTH; i++) {
    if (i < CELLS / 2) {
      for (let lane: i32 = 0; lane < 2; lane++) {
        const cell: i32 = i * 2 + lane;
        const x: i32 = cell & 127;
        const y: i32 = cell >> 7;

        if (initializing) {
          const v0: f32 = seedV(x, y);
          storeChemical(A_U, cell, 1.0 - v0 * 0.55);
          storeChemical(A_V, cell, v0);
          storeChemical(B_U, cell, 1.0 - v0 * 0.55);
          storeChemical(B_V, cell, v0);
        } else {
          const u: f32 = sample(readU, x, y);
          const v: f32 = sample(readV, x, y);
          const lapU: f32 =
            (sample(readU, x - 1, y) + sample(readU, x + 1, y)
            + sample(readU, x, y - 1) + sample(readU, x, y + 1)) * 0.2
            + (sample(readU, x - 1, y - 1) + sample(readU, x + 1, y - 1)
            + sample(readU, x - 1, y + 1) + sample(readU, x + 1, y + 1)) * 0.05
            - u;
          const lapV: f32 =
            (sample(readV, x - 1, y) + sample(readV, x + 1, y)
            + sample(readV, x, y - 1) + sample(readV, x, y + 1)) * 0.2
            + (sample(readV, x - 1, y - 1) + sample(readV, x + 1, y - 1)
            + sample(readV, x - 1, y + 1) + sample(readV, x + 1, y + 1)) * 0.05
            - v;
          const reaction: f32 = u * v * v;
          const feed: f32 = 0.0345;
          const kill: f32 = 0.0615;
          let nextU: f32 = u + 0.16 * lapU - reaction + feed * (1.0 - u);
          let nextV: f32 = v + 0.08 * lapV + reaction - (feed + kill) * v;

          if (pointerButtons != 0 && pointerX >= 0 && pointerY >= 0) {
            const dx: i32 = x - pointerX;
            const dy: i32 = y - pointerY;
            if (dx * dx + dy * dy < 36) {
              nextU = 0.18;
              nextV = 0.92;
            }
          }

          storeChemical(writeU, cell, nextU);
          storeChemical(writeV, cell, nextV);
        }
      }
      if (i == 0 && initializing) store<i32>(MAGIC_OFFSET, MAGIC);
    }

    const px: i32 = i & 255;
    const py: i32 = i >> 8;
    const sx: i32 = px >> 1;
    const sy: i32 = py >> 1;
    const v: f32 = initialized ? sample(readV, sx, sy) : seedV(sx, sy);
    const u: f32 = initialized ? sample(readU, sx, sy) : 1.0 - v * 0.55;
    const edge: f32 = clampF(Mathf.abs(sample(initialized ? readV : A_V, sx + 1, sy)
      - sample(initialized ? readV : A_V, sx - 1, sy)) * 9.0, 0.0, 1.0);
    const coral: f32 = clampF(v * 2.6, 0.0, 1.0);
    const water: f32 = clampF(u - v, 0.0, 1.0);
    const r: f32 = clampF(0.04 + coral * 0.95 + edge * 0.35, 0.0, 1.0);
    const g: f32 = clampF(0.08 + coral * coral * 0.48 + water * 0.16, 0.0, 1.0);
    const b: f32 = clampF(0.14 + water * 0.52 + (1.0 - coral) * 0.16, 0.0, 1.0);

    const pixelOffset: i32 = 16 + i * 12;
    store<i32>(pixelOffset, <i32>(r * 255.0));
    store<i32>(pixelOffset + 4, <i32>(g * 255.0));
    store<i32>(pixelOffset + 8, <i32>(b * 255.0));
  }
}
