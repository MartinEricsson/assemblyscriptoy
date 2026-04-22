// ============================================================
//  plasma.as — Classic demoscene plasma
// ============================================================
//  Four overlapping sine waves (two linear, two radial) summed
//  into a scalar field, then run through a cosine-palette lookup.
//
//  This is the natural second lesson after starter.as: it
//  introduces f32 sinF/cosF without the 400-line math prelude
//  used by the flagship shaders. Read starter.as first if you
//  are new to the memory layout.
// ============================================================

const WIDTH:  i32 = 256;
const HEIGHT: i32 = 256;
const TIME_OFFSET: i32 = 0;
const PI:     f32 = 3.14159265;
const TWO_PI: f32 = 6.28318530;

// ── f32-only sin/cos (avoids AS runtime i64/f64) ─────────────
function sinF(x: f32): f32 {
  x = x - Mathf.floor(x / TWO_PI + 0.5) * TWO_PI;
  if (x > PI * 0.5)  x = PI  - x;
  if (x < -PI * 0.5) x = -PI - x;
  const x2: f32 = x * x;
  return x * (1.0 - x2 / 6.0 * (1.0 - x2 / 20.0 * (1.0 - x2 / 42.0)));
}
function cosF(x: f32): f32 { return sinF(x + PI * 0.5); }

function clampF(v: f32, lo: f32, hi: f32): f32 {
  return Mathf.min(Mathf.max(v, lo), hi);
}

// Inigo Quilez cosine palette:  col = a + b * cos(2π(c·t + d))
// Warm → magenta → teal, cycles every unit of t.
function palR(t: f32): f32 { return clampF(0.5 + 0.5 * cosF(TWO_PI * (t + 0.00)), 0.0, 1.0); }
function palG(t: f32): f32 { return clampF(0.5 + 0.5 * cosF(TWO_PI * (t + 0.33)), 0.0, 1.0); }
function palB(t: f32): f32 { return clampF(0.5 + 0.5 * cosF(TWO_PI * (t + 0.66)), 0.0, 1.0); }

export function main(): void {
  // Slow the frame counter down so the animation is easy on the eyes.
  const time: f32 = load<f32>(TIME_OFFSET) * 0.016;

  const invW: f32 = 1.0 / <f32>WIDTH;
  const invH: f32 = 1.0 / <f32>HEIGHT;

  // Two radial wave centres drift slowly in circles.
  const cxA: f32 = 0.5 + 0.35 * cosF(time * 0.7);
  const cyA: f32 = 0.5 + 0.35 * sinF(time * 0.9);
  const cxB: f32 = 0.5 + 0.35 * cosF(time * 1.3 + 1.7);
  const cyB: f32 = 0.5 + 0.35 * sinF(time * 1.1 + 0.6);

  for (let i: i32 = 0; i < WIDTH * HEIGHT; i++) {
    const px: i32 = i % WIDTH;
    const py: i32 = i / WIDTH;

    // Normalised coords in [0,1].
    const u: f32 = <f32>px * invW;
    const v: f32 = <f32>py * invH;

    // Two linear waves moving in different directions.
    const w1: f32 = sinF(u * 12.0 + time * 2.0);
    const w2: f32 = sinF((u + v) * 8.0 - time * 1.3);

    // Two radial waves.
    const dxA: f32 = u - cxA; const dyA: f32 = v - cyA;
    const rA:  f32 = Mathf.sqrt(dxA * dxA + dyA * dyA);
    const w3:  f32 = sinF(rA * 24.0 - time * 2.5);

    const dxB: f32 = u - cxB; const dyB: f32 = v - cyB;
    const rB:  f32 = Mathf.sqrt(dxB * dxB + dyB * dyB);
    const w4:  f32 = sinF(rB * 18.0 + time * 1.8);

    // Combine into a scalar field in roughly [-1, 1], then remap to [0,1].
    const field: f32 = (w1 + w2 + w3 + w4) * 0.25 + 0.5;

    // Palette phase drifts with time for a subtle colour-cycling effect.
    const p: f32 = field + time * 0.05;

    const r: f32 = palR(p);
    const g: f32 = palG(p);
    const b: f32 = palB(p);

    const pixelOffset: i32 = 16 + i * 12;
    store<i32>(pixelOffset,     <i32>(r * 255.0));
    store<i32>(pixelOffset + 4, <i32>(g * 255.0));
    store<i32>(pixelOffset + 8, <i32>(b * 255.0));
  }
}
