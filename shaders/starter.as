// ============================================================
//  starter.as  –  Boilerplate / Getting Started Template
// ============================================================
//
//  HOW THIS PROJECT WORKS (read once, then delete these lines)
//  ─────────────────────────────────────────────────────────────
//  1. This file is AssemblyScript – a strict TypeScript subset
//     that compiles to WebAssembly (Wasm).
//
//  2. The Gasm compiler then converts that Wasm binary into a
//     WGSL compute shader that runs on the GPU via WebGPU.
//
//  3. The GPU calls main() once per frame.  Each call must fill
//     the entire 256×256 canvas (65 536 pixels) in one shot.
//
//  SHARED LINEAR MEMORY LAYOUT
//  ─────────────────────────────────────────────────────────────
//  The single Wasm memory page (64 KB) is shared with the GPU.
//
//    Byte  0 .. 3   → f32  time   (elapsed × 60 / 1000 ≈ frame counter)
//    Byte 16 ..     → pixel data, one pixel = 12 bytes:
//                       [+0]  R  as i32  (0 – 255)
//                       [+4]  G  as i32  (0 – 255)
//                       [+8]  B  as i32  (0 – 255)
//
//  Pixel i is at byte offset:  16 + i * 12
//
//  MATH CONSTRAINTS
//  ─────────────────────────────────────────────────────────────
//  • No  Math.sin / Math.cos  – these are not available in the
//    Gasm-compatible subset of AssemblyScript.
//  • f32 arithmetic is fine; i32 arithmetic is fine.
//  • Use triWave() below as a smooth sin-substitute.
//  • Use f32 divisions / multiplications for smoother gradients.
//
//  NEXT STEPS
//  ─────────────────────────────────────────────────────────────
//  1. Edit the "YOUR EFFECT HERE" block below.
//  2. Add more private helper functions above main() as needed.
//  3. See the other shaders/ files for more patterns:
//       checkerboard.as  – pure integer patterns
//       plasma.as        – multi-wave blending with triWave
//       rainbow.as       – hue-wheel with piecewise linear math
//       metaballs.as     – distance-field blobs
// ============================================================

// Canvas dimensions (always 256 × 256)
const WIDTH:  i32 = 256;
const HEIGHT: i32 = 256;

// Byte offset where the runtime writes the current time value
const TIME_OFFSET: i32 = 0;


// ── Helper: clamp an i32 to the valid colour range [0, 255] ──
//
// Always pass your R/G/B through this before storing, unless
// you are 100% certain the value cannot overflow.
function clamp255(v: i32): i32 {
  if (v < 0)   return 0;
  if (v > 255) return 255;
  return v;
}


// ── Helper: triangle wave – a smooth sin substitute ──────────
//
// Input:  any i32 (wraps every 256 steps, like a sawtooth)
// Output: 0 → 255 → 0 over one 256-step cycle  (always ≥ 0)
//
// Use it wherever you would write  (sin(x) * 127 + 128)  in
// GLSL.  Pure integer arithmetic – no floating-point needed.
//
//   triWave(0)   → 0
//   triWave(64)  → 128
//   triWave(128) → 255   (actually 254, but close enough)
//   triWave(192) → 127
//   triWave(256) → 0     (wraps back)
function triWave(val: i32): i32 {
  const v: i32 = val & 255;       // wrap to 0..255
  return v < 128 ? v * 2          // rising  half: 0 → 254
                 : 511 - v * 2;   // falling half: 254 → 0
}


// ── Entry point ───────────────────────────────────────────────
//
// The Gasm compiler looks for EXACTLY this signature.
// Do not rename it.  Do not add parameters.
export function main(): void {

  // ── Read the current time ──────────────────────────────────
  //
  // load<f32>(TIME_OFFSET) reads 4 bytes at address 0 as a
  // 32-bit float.  The value is roughly (elapsed_ms * 60 / 1000)
  // so it increases by ~1 each frame at 60 fps.
  //
  // Cast to i32 when you need an integer step counter:
  //   const frame: i32 = i32(time);
  const time: f32 = load<f32>(TIME_OFFSET);

  // Integer frame counter – useful for discrete animation steps
  const frame: i32 = i32(time);

  const totalPixels: i32 = WIDTH * HEIGHT;   // 65 536

  // ── Pixel loop ────────────────────────────────────────────
  //
  // Iterate over every pixel in row-major order (left→right,
  // top→bottom).  Derive x and y from the index i.
  for (let i: i32 = 0; i < totalPixels; i = i + 1) {

    // Pixel column (0 = left edge, 255 = right edge)
    const x: i32 = i % WIDTH;

    // Pixel row    (0 = top edge,  255 = bottom edge)
    const y: i32 = i / WIDTH;

    // Center-relative coords  (-128 … +127)
    // Useful for radial effects: dist² = cx*cx + cy*cy
    const cx: i32 = x - 128;
    const cy: i32 = y - 128;

    // ── YOUR EFFECT HERE ────────────────────────────────────
    //
    // Compute r, g, b as i32 values in the range 0 – 255.
    //
    // The example below creates three diagonal wave bands that
    // drift over time, one per colour channel.
    //
    //   cx + cy       → position along the NW→SE diagonal
    //   + frame       → shifts the whole pattern each frame
    //   + 0/85/170    → 120° phase offset between channels
    //                    (85 ≈ 256/3, 170 ≈ 2*256/3)
    //
    // Feel free to delete everything in this block and start fresh.

    const diag: i32 = cx + cy;            // diagonal coordinate

    const r: i32 = triWave(diag + frame);
    const g: i32 = triWave(diag + frame + 85);
    const b: i32 = triWave(diag + frame + 170);

    // ── END OF YOUR EFFECT ──────────────────────────────────

    // ── Write the pixel to shared memory ──────────────────
    //
    // Pixel i lives at byte offset  16 + i * 12.
    // R, G, B are each stored as a 32-bit integer (4 bytes).
    // The offsets within one pixel record are 0, 4, 8.
    const pixelOffset: i32 = 16 + i * 12;

    store<i32>(pixelOffset,     clamp255(r));   // Red channel
    store<i32>(pixelOffset + 4, clamp255(g));   // Green channel
    store<i32>(pixelOffset + 8, clamp255(b));   // Blue channel
  }
}
