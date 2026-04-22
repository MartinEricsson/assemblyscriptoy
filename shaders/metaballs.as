// ============================================================
//  metaballs.as — Analytic metaballs with iso-band shading
// ============================================================
//  Six soft blobs drift around the canvas. For each pixel we
//  sum the inverse-square influence of every blob:
//       field(p) = Σ  r_i² / |p - c_i|²
//  then shade based on the field value:
//    field < 1.0            → background (dark)
//    1.0 ≤ field < 1.05     → thin iso-contour outline
//    field ≥ 1.0            → interior, coloured by field gradient
//
//  Complementary to flagship_sdf_scene.as: same "implicit
//  surface" idea, 10× simpler, no raymarching, easy to read.
// ============================================================

const WIDTH:  i32 = 256;
const HEIGHT: i32 = 256;
const TIME_OFFSET: i32 = 0;
const PI:     f32 = 3.14159265;
const TWO_PI: f32 = 6.28318530;
const N_BALLS: i32 = 6;

// ── f32-only sin/cos ─────────────────────────────────────────
function sinF(x: f32): f32 {
  x = x - Mathf.floor(x / TWO_PI + 0.5) * TWO_PI;
  if (x > PI * 0.5)  x = PI  - x;
  if (x < -PI * 0.5) x = -PI - x;
  const x2: f32 = x * x;
  return x * (1.0 - x2 / 6.0 * (1.0 - x2 / 20.0 * (1.0 - x2 / 42.0)));
}
function cosF(x: f32): f32 { return sinF(x + PI * 0.5); }
function clampF(v: f32, lo: f32, hi: f32): f32 { return Mathf.min(Mathf.max(v, lo), hi); }
function saturate(x: f32): f32 { return clampF(x, 0.0, 1.0); }

// Per-ball position on a Lissajous curve so motion looks organic.
// Returns centre.x, centre.y in [-1, 1]; radius is fixed per ball.
function ballCX(k: i32, time: f32): f32 {
  const fk: f32 = <f32>k;
  return 0.55 * cosF(time * (0.37 + fk * 0.11) + fk * 1.7);
}
function ballCY(k: i32, time: f32): f32 {
  const fk: f32 = <f32>k;
  return 0.55 * sinF(time * (0.29 + fk * 0.17) + fk * 2.3);
}
function ballR(k: i32): f32 {
  // Alternating small / large blobs.
  return (k & 1) == 0 ? 0.22 : 0.30;
}

// Cosine palette (IQ): interior colour keyed on the field value.
function palR(t: f32): f32 { return saturate(0.5 + 0.5 * cosF(TWO_PI * (t + 0.00))); }
function palG(t: f32): f32 { return saturate(0.5 + 0.5 * cosF(TWO_PI * (t + 0.18))); }
function palB(t: f32): f32 { return saturate(0.5 + 0.5 * cosF(TWO_PI * (t + 0.40))); }

export function main(): void {
  const time: f32 = load<f32>(TIME_OFFSET) * 0.016;

  // Precompute ball centres (avoids recomputing 65 536 times).
  // Max N_BALLS is 6 so static arrays of that size are fine.
  const cx0: f32 = ballCX(0, time); const cy0: f32 = ballCY(0, time); const r0: f32 = ballR(0);
  const cx1: f32 = ballCX(1, time); const cy1: f32 = ballCY(1, time); const r1: f32 = ballR(1);
  const cx2: f32 = ballCX(2, time); const cy2: f32 = ballCY(2, time); const r2: f32 = ballR(2);
  const cx3: f32 = ballCX(3, time); const cy3: f32 = ballCY(3, time); const r3: f32 = ballR(3);
  const cx4: f32 = ballCX(4, time); const cy4: f32 = ballCY(4, time); const r4: f32 = ballR(4);
  const cx5: f32 = ballCX(5, time); const cy5: f32 = ballCY(5, time); const r5: f32 = ballR(5);

  const invW: f32 = 1.0 / <f32>WIDTH;
  const invH: f32 = 1.0 / <f32>HEIGHT;

  for (let i: i32 = 0; i < WIDTH * HEIGHT; i++) {
    const px: i32 = i % WIDTH;
    const py: i32 = i / WIDTH;

    // Pixel coordinate in [-1, 1]².
    const u: f32 = 2.0 * <f32>px * invW - 1.0;
    const v: f32 = 2.0 * <f32>py * invH - 1.0;

    // Sum inverse-square influences with a small epsilon to avoid NaN.
    let field: f32 = 0.0;

    let dx: f32; let dy: f32; let d2: f32;
    dx = u - cx0; dy = v - cy0; d2 = dx * dx + dy * dy + 0.0005; field += r0 * r0 / d2;
    dx = u - cx1; dy = v - cy1; d2 = dx * dx + dy * dy + 0.0005; field += r1 * r1 / d2;
    dx = u - cx2; dy = v - cy2; d2 = dx * dx + dy * dy + 0.0005; field += r2 * r2 / d2;
    dx = u - cx3; dy = v - cy3; d2 = dx * dx + dy * dy + 0.0005; field += r3 * r3 / d2;
    dx = u - cx4; dy = v - cy4; d2 = dx * dx + dy * dy + 0.0005; field += r4 * r4 / d2;
    dx = u - cx5; dy = v - cy5; d2 = dx * dx + dy * dy + 0.0005; field += r5 * r5 / d2;

    let r: f32; let g: f32; let b: f32;

    if (field < 0.95) {
      // Background: dark vignette tinted by time.
      const bg: f32 = 0.05 + 0.05 * field;
      r = bg * 0.6;
      g = bg * 0.8;
      b = bg * 1.2;
    } else if (field < 1.05) {
      // Thin bright iso-contour — the "skin" of the merged blob.
      r = 1.0; g = 1.0; b = 1.0;
    } else {
      // Interior: palette keyed on field magnitude.
      const t: f32 = clampF((field - 1.0) * 0.35 + time * 0.1, 0.0, 1.0);
      r = palR(t);
      g = palG(t);
      b = palB(t);

      // Extra bright highlight where many blobs overlap.
      const glow: f32 = saturate((field - 1.5) * 0.5);
      r = clampF(r + glow * 0.6, 0.0, 1.0);
      g = clampF(g + glow * 0.4, 0.0, 1.0);
      b = clampF(b + glow * 0.2, 0.0, 1.0);
    }

    const pixelOffset: i32 = 16 + i * 12;
    store<i32>(pixelOffset,     <i32>(r * 255.0));
    store<i32>(pixelOffset + 4, <i32>(g * 255.0));
    store<i32>(pixelOffset + 8, <i32>(b * 255.0));
  }
}
