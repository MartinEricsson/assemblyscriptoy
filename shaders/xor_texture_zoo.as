// ============================================================
//  xor_texture_zoo.as — Gallery of classic bitwise patterns
// ============================================================
//  A 2×4 grid of 128×64 tiles showing the famous integer/bitwise
//  "hello world" shaders. Pure i32 arithmetic — this produces
//  unusually short, readable WAT and WGSL output.
//
//  Layout (each tile is 128 wide, 64 tall):
//     ┌──────────────┬──────────────┐
//     │ 0  xor       │ 1  munching  │
//     │ 2  sierpinski│ 3  moire     │
//     │ 4  mul-mod   │ 5  checkers  │
//     │ 6  stripes   │ 7  circles   │
//     └──────────────┴──────────────┘
// ============================================================

const WIDTH:  i32 = 256;
const HEIGHT: i32 = 256;
const TIME_OFFSET: i32 = 0;

function clamp255(v: i32): i32 {
  if (v < 0) return 0;
  if (v > 255) return 255;
  return v;
}

// Simple integer palette: map an i32 value to a pleasing RGB triple
// using three different bit-rotations + masks. Deterministic, no
// transcendentals required.
function paletteR(v: i32): i32 { return (v * 7)  & 255; }
function paletteG(v: i32): i32 { return (v * 13) & 255; }
function paletteB(v: i32): i32 { return (v * 29) & 255; }

export function main(): void {
  const time: f32 = load<f32>(TIME_OFFSET);
  const t: i32 = i32(time);                   // integer frame counter

  for (let i: i32 = 0; i < WIDTH * HEIGHT; i++) {
    const x: i32 = i % WIDTH;
    const y: i32 = i / WIDTH;

    // Which tile? Columns 0..1, rows 0..3.
    const col: i32 = x / 128;
    const row: i32 = y / 64;
    const tile: i32 = row * 2 + col;

    // Local coordinates inside the tile (0..127, 0..63).
    const lx: i32 = x - col * 128;
    const ly: i32 = y - row * 64;

    let v: i32 = 0;

    if (tile == 0) {
      // Classic XOR texture, animated.
      v = (lx ^ ly) + t;
    } else if (tile == 1) {
      // Munching squares: t ^ (x & y).
      v = t ^ ((lx & ly) * 2);
    } else if (tile == 2) {
      // Sierpinski triangle (bitwise AND test).
      v = ((lx & ly) == 0) ? 255 : 32;
      // Gentle time tint.
      v = (v + t) & 255;
    } else if (tile == 3) {
      // Moire interference: two shifted XOR patterns.
      const a: i32 = (lx + t) ^ (ly + t);
      const b: i32 = ((lx - t) ^ (ly + t / 2));
      v = (a + b) & 255;
    } else if (tile == 4) {
      // Multiply-mod. Classic "music visualiser" vibe.
      v = ((lx * ly) + t) & 255;
    } else if (tile == 5) {
      // Animated binary-depth checkerboard.
      const sz: i32 = 2 + ((t / 30) & 7);
      const cx: i32 = lx / sz;
      const cy: i32 = ly / sz;
      v = (((cx ^ cy) + t) & 1) != 0 ? 220 : 40;
    } else if (tile == 6) {
      // Scrolling bit-stripes.
      v = ((lx + (ly << 1) + t) & 15) * 16;
    } else {
      // Circle distance (integer): iso-bands by bit masking.
      const dx: i32 = lx - 64;
      const dy: i32 = ly - 32;
      const d2: i32 = dx * dx + dy * dy;
      v = ((d2 + t * 32) >> 4) & 255;
    }

    // Draw thin black tile separators so the grid is easy to see.
    const onBorder: boolean = (lx == 0) || (ly == 0) || (lx == 127) || (ly == 63);

    const pixelOffset: i32 = 16 + i * 12;
    if (onBorder) {
      store<i32>(pixelOffset,     0);
      store<i32>(pixelOffset + 4, 0);
      store<i32>(pixelOffset + 8, 0);
    } else {
      store<i32>(pixelOffset,     clamp255(paletteR(v)));
      store<i32>(pixelOffset + 4, clamp255(paletteG(v)));
      store<i32>(pixelOffset + 8, clamp255(paletteB(v)));
    }
  }
}
