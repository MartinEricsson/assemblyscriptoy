// Flagship: Deep Mandelbrot Zoom — 500 iterations, smooth coloring, animated zoom
// f32-only math — compute-heavy GPU showcase
// 4×4 stratified-grid supersampling AA (16 samples), rich multi-band cosine palette
const WIDTH: i32 = 256;
const HEIGHT: i32 = 256;
const TIME_OFFSET: i32 = 0;
const MAX_ITER: i32 = 500;
const PI: f32 = 3.14159265;
const TWO_PI: f32 = 6.28318530;
const AA_SAMPLES: i32 = 16;   // 4×4 = 16 samples (manually unrolled)
const INV_AA: f32 = 0.0625;   // 1/16

// f32-only math helpers
function sinF(x: f32): f32 {
  x = x - Mathf.floor(x / TWO_PI + 0.5) * TWO_PI;
  if (x > PI * 0.5) x = PI - x;
  if (x < -PI * 0.5) x = -PI - x;
  const x2: f32 = x * x;
  return x * (1.0 - x2 / 6.0 * (1.0 - x2 / 20.0 * (1.0 - x2 / 42.0)));
}
function cosF(x: f32): f32 { return sinF(x + PI * 0.5); }

function logF(x: f32): f32 {
  if (x <= 0.0) return -100.0;
  let n: i32 = 0; let m: f32 = x;
  while (m >= 2.0) { m *= 0.5; n++; }
  while (m < 1.0) { m *= 2.0; n--; }
  const t: f32 = (m - 1.0) / (m + 1.0);
  const t2: f32 = t * t;
  return <f32>n * 0.6931472 + 2.0 * t * (1.0 + t2 * (0.3333333 + t2 * 0.2));
}

function log2F(x: f32): f32 { return logF(x) * 1.4426950; }

function clampF(v: f32, lo: f32, hi: f32): f32 { return Mathf.min(Mathf.max(v, lo), hi); }

// exp2F: compute 2^x without while loops (avoids breaking parallelization)
function exp2F(x: f32): f32 {
  const n: f32 = Mathf.floor(x);
  const f: f32 = x - n;
  const ln2: f32 = 0.6931472;
  const fl: f32 = f * ln2;
  const ef: f32 = 1.0 + fl * (1.0 + fl * (0.5 + fl * (0.1666667 + fl * 0.04166667)));
  const ni: i32 = <i32>n;
  let p: f32 = 1.0;
  const a: i32 = ni < 0 ? -ni : ni;
  if (a & 1) p *= ni > 0 ? 2.0 : 0.5;
  if (a & 2) p *= ni > 0 ? 4.0 : 0.25;
  if (a & 4) p *= ni > 0 ? 16.0 : 0.0625;
  if (a & 8) p *= ni > 0 ? 256.0 : 0.00390625;
  return p * ef;
}

// ── Rich palette: Inigo Quilez multi-band cosine palette ──
// palette(t) = a + b * cos(2π(c*t + d))
// Warm-to-cool with neon highlights: deep indigo → electric blue → cyan → gold → magenta
function palR(t: f32): f32 {
  return clampF(0.5 + 0.5 * cosF(TWO_PI * (1.0 * t + 0.00)), 0.0, 1.0);
}
function palG(t: f32): f32 {
  return clampF(0.5 + 0.5 * cosF(TWO_PI * (1.0 * t + 0.10)), 0.0, 1.0);
}
function palB(t: f32): f32 {
  return clampF(0.5 + 0.5 * cosF(TWO_PI * (1.0 * t + 0.20)), 0.0, 1.0);
}

// Second layer: additive warm accent (gold/amber band)
function accentR(t: f32): f32 {
  return clampF(0.5 + 0.5 * cosF(TWO_PI * (0.7 * t + 0.80)), 0.0, 1.0);
}
function accentG(t: f32): f32 {
  return clampF(0.3 + 0.4 * cosF(TWO_PI * (0.7 * t + 0.90)), 0.0, 1.0);
}
function accentB(t: f32): f32 {
  return clampF(0.2 + 0.3 * cosF(TWO_PI * (0.7 * t + 1.00)), 0.0, 1.0);
}

// Mix two palettes for richer colour variation
function mixPalR(t: f32, mix: f32): f32 {
  return palR(t) * (1.0 - mix) + accentR(t) * mix;
}
function mixPalG(t: f32, mix: f32): f32 {
  return palG(t) * (1.0 - mix) + accentG(t) * mix;
}
function mixPalB(t: f32, mix: f32): f32 {
  return palB(t) * (1.0 - mix) + accentB(t) * mix;
}

// Mandelbrot iteration for a single sample — returns (r, g, b) packed into memory helper
// Returns smooth iteration count (negative means inside set)
function mandelbrotSmooth(cr: f32, ci: f32): f32 {
  let zr: f32 = 0.0;
  let zi: f32 = 0.0;
  let iter: i32 = 0;
  for (let n: i32 = 0; n < MAX_ITER; n++) {
    const zr2: f32 = zr * zr;
    const zi2: f32 = zi * zi;
    if (zr2 + zi2 > 256.0) break;
    zi = 2.0 * zr * zi + ci;
    zr = zr2 - zi2 + cr;
    iter = n + 1;
  }
  if (iter >= MAX_ITER) return -1.0; // inside set
  const modulus: f32 = Mathf.sqrt(zr * zr + zi * zi);
  return <f32>iter - log2F(log2F(modulus)) + 4.0;
}

export function main(): void {
  const frame: f32 = load<f32>(TIME_OFFSET); // f32 load — no cast needed
  const time: f32 = frame * 0.008;

  // Animated zoom into Seahorse Valley
  const centerX: f32 = -0.745;
  const centerY: f32 = 0.186;
  const zoomPow: f32 = 1.0 + sinF(time * 0.3) * 3.5 + 3.5;
  const zoom: f32 = exp2F(zoomPow);
  const invZoom: f32 = 1.0 / zoom;
  const invW: f32 = 1.0 / <f32>WIDTH;
  const invH: f32 = 1.0 / <f32>HEIGHT;

  // Palette animation phase
  const palPhase: f32 = time * 0.08;
  // Palette mix oscillates gently
  const palMix: f32 = 0.35 + 0.25 * sinF(time * 0.2);

  // 4×4 rotated-grid AA — 16 samples, manually unrolled for GPU compatibility
  // Pre-compute all 16 rotated offsets (26.6° rotation for anti-moiré)
  // Raw offsets: [-0.375, -0.125, 0.125, 0.375] in each axis
  // cos(26.6°) ≈ 0.8944, sin(26.6°) ≈ 0.4472
  const cR: f32 = 0.8944;
  const sR: f32 = 0.4472;

  for (let i: i32 = 0; i < WIDTH * HEIGHT; i++) {
    const px: f32 = <f32>(i % WIDTH);
    const py: f32 = <f32>(i / WIDTH);

    let rAcc: f32 = 0.0;
    let gAcc: f32 = 0.0;
    let bAcc: f32 = 0.0;
    let sIter: f32 = 0.0;
    let tVal: f32 = 0.0;
    let sx: f32 = 0.0;
    let sy: f32 = 0.0;
    let cr: f32 = 0.0;
    let ci: f32 = 0.0;

    // Row 0: rawOy = -0.375
    // (0,0): rawOx=-0.375, rawOy=-0.375
    sx = px + (-0.375 * cR - (-0.375) * sR);
    sy = py + (-0.375 * sR + (-0.375) * cR);
    cr = centerX + (2.0 * sx * invW - 1.0) * 2.0 * invZoom;
    ci = centerY + (2.0 * sy * invH - 1.0) * 2.0 * invZoom;
    sIter = mandelbrotSmooth(cr, ci);
    if (sIter >= 0.0) { tVal = sIter * 0.018 + palPhase; rAcc += mixPalR(tVal, palMix); gAcc += mixPalG(tVal, palMix); bAcc += mixPalB(tVal, palMix); }

    // (1,0): rawOx=-0.125, rawOy=-0.375
    sx = px + (-0.125 * cR - (-0.375) * sR);
    sy = py + (-0.125 * sR + (-0.375) * cR);
    cr = centerX + (2.0 * sx * invW - 1.0) * 2.0 * invZoom;
    ci = centerY + (2.0 * sy * invH - 1.0) * 2.0 * invZoom;
    sIter = mandelbrotSmooth(cr, ci);
    if (sIter >= 0.0) { tVal = sIter * 0.018 + palPhase; rAcc += mixPalR(tVal, palMix); gAcc += mixPalG(tVal, palMix); bAcc += mixPalB(tVal, palMix); }

    // (2,0): rawOx=0.125, rawOy=-0.375
    sx = px + (0.125 * cR - (-0.375) * sR);
    sy = py + (0.125 * sR + (-0.375) * cR);
    cr = centerX + (2.0 * sx * invW - 1.0) * 2.0 * invZoom;
    ci = centerY + (2.0 * sy * invH - 1.0) * 2.0 * invZoom;
    sIter = mandelbrotSmooth(cr, ci);
    if (sIter >= 0.0) { tVal = sIter * 0.018 + palPhase; rAcc += mixPalR(tVal, palMix); gAcc += mixPalG(tVal, palMix); bAcc += mixPalB(tVal, palMix); }

    // (3,0): rawOx=0.375, rawOy=-0.375
    sx = px + (0.375 * cR - (-0.375) * sR);
    sy = py + (0.375 * sR + (-0.375) * cR);
    cr = centerX + (2.0 * sx * invW - 1.0) * 2.0 * invZoom;
    ci = centerY + (2.0 * sy * invH - 1.0) * 2.0 * invZoom;
    sIter = mandelbrotSmooth(cr, ci);
    if (sIter >= 0.0) { tVal = sIter * 0.018 + palPhase; rAcc += mixPalR(tVal, palMix); gAcc += mixPalG(tVal, palMix); bAcc += mixPalB(tVal, palMix); }

    // Row 1: rawOy = -0.125
    // (0,1)
    sx = px + (-0.375 * cR - (-0.125) * sR);
    sy = py + (-0.375 * sR + (-0.125) * cR);
    cr = centerX + (2.0 * sx * invW - 1.0) * 2.0 * invZoom;
    ci = centerY + (2.0 * sy * invH - 1.0) * 2.0 * invZoom;
    sIter = mandelbrotSmooth(cr, ci);
    if (sIter >= 0.0) { tVal = sIter * 0.018 + palPhase; rAcc += mixPalR(tVal, palMix); gAcc += mixPalG(tVal, palMix); bAcc += mixPalB(tVal, palMix); }

    // (1,1)
    sx = px + (-0.125 * cR - (-0.125) * sR);
    sy = py + (-0.125 * sR + (-0.125) * cR);
    cr = centerX + (2.0 * sx * invW - 1.0) * 2.0 * invZoom;
    ci = centerY + (2.0 * sy * invH - 1.0) * 2.0 * invZoom;
    sIter = mandelbrotSmooth(cr, ci);
    if (sIter >= 0.0) { tVal = sIter * 0.018 + palPhase; rAcc += mixPalR(tVal, palMix); gAcc += mixPalG(tVal, palMix); bAcc += mixPalB(tVal, palMix); }

    // (2,1)
    sx = px + (0.125 * cR - (-0.125) * sR);
    sy = py + (0.125 * sR + (-0.125) * cR);
    cr = centerX + (2.0 * sx * invW - 1.0) * 2.0 * invZoom;
    ci = centerY + (2.0 * sy * invH - 1.0) * 2.0 * invZoom;
    sIter = mandelbrotSmooth(cr, ci);
    if (sIter >= 0.0) { tVal = sIter * 0.018 + palPhase; rAcc += mixPalR(tVal, palMix); gAcc += mixPalG(tVal, palMix); bAcc += mixPalB(tVal, palMix); }

    // (3,1)
    sx = px + (0.375 * cR - (-0.125) * sR);
    sy = py + (0.375 * sR + (-0.125) * cR);
    cr = centerX + (2.0 * sx * invW - 1.0) * 2.0 * invZoom;
    ci = centerY + (2.0 * sy * invH - 1.0) * 2.0 * invZoom;
    sIter = mandelbrotSmooth(cr, ci);
    if (sIter >= 0.0) { tVal = sIter * 0.018 + palPhase; rAcc += mixPalR(tVal, palMix); gAcc += mixPalG(tVal, palMix); bAcc += mixPalB(tVal, palMix); }

    // Row 2: rawOy = 0.125
    // (0,2)
    sx = px + (-0.375 * cR - 0.125 * sR);
    sy = py + (-0.375 * sR + 0.125 * cR);
    cr = centerX + (2.0 * sx * invW - 1.0) * 2.0 * invZoom;
    ci = centerY + (2.0 * sy * invH - 1.0) * 2.0 * invZoom;
    sIter = mandelbrotSmooth(cr, ci);
    if (sIter >= 0.0) { tVal = sIter * 0.018 + palPhase; rAcc += mixPalR(tVal, palMix); gAcc += mixPalG(tVal, palMix); bAcc += mixPalB(tVal, palMix); }

    // (1,2)
    sx = px + (-0.125 * cR - 0.125 * sR);
    sy = py + (-0.125 * sR + 0.125 * cR);
    cr = centerX + (2.0 * sx * invW - 1.0) * 2.0 * invZoom;
    ci = centerY + (2.0 * sy * invH - 1.0) * 2.0 * invZoom;
    sIter = mandelbrotSmooth(cr, ci);
    if (sIter >= 0.0) { tVal = sIter * 0.018 + palPhase; rAcc += mixPalR(tVal, palMix); gAcc += mixPalG(tVal, palMix); bAcc += mixPalB(tVal, palMix); }

    // (2,2)
    sx = px + (0.125 * cR - 0.125 * sR);
    sy = py + (0.125 * sR + 0.125 * cR);
    cr = centerX + (2.0 * sx * invW - 1.0) * 2.0 * invZoom;
    ci = centerY + (2.0 * sy * invH - 1.0) * 2.0 * invZoom;
    sIter = mandelbrotSmooth(cr, ci);
    if (sIter >= 0.0) { tVal = sIter * 0.018 + palPhase; rAcc += mixPalR(tVal, palMix); gAcc += mixPalG(tVal, palMix); bAcc += mixPalB(tVal, palMix); }

    // (3,2)
    sx = px + (0.375 * cR - 0.125 * sR);
    sy = py + (0.375 * sR + 0.125 * cR);
    cr = centerX + (2.0 * sx * invW - 1.0) * 2.0 * invZoom;
    ci = centerY + (2.0 * sy * invH - 1.0) * 2.0 * invZoom;
    sIter = mandelbrotSmooth(cr, ci);
    if (sIter >= 0.0) { tVal = sIter * 0.018 + palPhase; rAcc += mixPalR(tVal, palMix); gAcc += mixPalG(tVal, palMix); bAcc += mixPalB(tVal, palMix); }

    // Row 3: rawOy = 0.375
    // (0,3)
    sx = px + (-0.375 * cR - 0.375 * sR);
    sy = py + (-0.375 * sR + 0.375 * cR);
    cr = centerX + (2.0 * sx * invW - 1.0) * 2.0 * invZoom;
    ci = centerY + (2.0 * sy * invH - 1.0) * 2.0 * invZoom;
    sIter = mandelbrotSmooth(cr, ci);
    if (sIter >= 0.0) { tVal = sIter * 0.018 + palPhase; rAcc += mixPalR(tVal, palMix); gAcc += mixPalG(tVal, palMix); bAcc += mixPalB(tVal, palMix); }

    // (1,3)
    sx = px + (-0.125 * cR - 0.375 * sR);
    sy = py + (-0.125 * sR + 0.375 * cR);
    cr = centerX + (2.0 * sx * invW - 1.0) * 2.0 * invZoom;
    ci = centerY + (2.0 * sy * invH - 1.0) * 2.0 * invZoom;
    sIter = mandelbrotSmooth(cr, ci);
    if (sIter >= 0.0) { tVal = sIter * 0.018 + palPhase; rAcc += mixPalR(tVal, palMix); gAcc += mixPalG(tVal, palMix); bAcc += mixPalB(tVal, palMix); }

    // (2,3)
    sx = px + (0.125 * cR - 0.375 * sR);
    sy = py + (0.125 * sR + 0.375 * cR);
    cr = centerX + (2.0 * sx * invW - 1.0) * 2.0 * invZoom;
    ci = centerY + (2.0 * sy * invH - 1.0) * 2.0 * invZoom;
    sIter = mandelbrotSmooth(cr, ci);
    if (sIter >= 0.0) { tVal = sIter * 0.018 + palPhase; rAcc += mixPalR(tVal, palMix); gAcc += mixPalG(tVal, palMix); bAcc += mixPalB(tVal, palMix); }

    // (3,3)
    sx = px + (0.375 * cR - 0.375 * sR);
    sy = py + (0.375 * sR + 0.375 * cR);
    cr = centerX + (2.0 * sx * invW - 1.0) * 2.0 * invZoom;
    ci = centerY + (2.0 * sy * invH - 1.0) * 2.0 * invZoom;
    sIter = mandelbrotSmooth(cr, ci);
    if (sIter >= 0.0) { tVal = sIter * 0.018 + palPhase; rAcc += mixPalR(tVal, palMix); gAcc += mixPalG(tVal, palMix); bAcc += mixPalB(tVal, palMix); }

    // Average AA samples
    let r: f32 = rAcc * INV_AA;
    let g: f32 = gAcc * INV_AA;
    let b: f32 = bAcc * INV_AA;

    // Gamma-correct (sRGB approximate)
    r = Mathf.sqrt(clampF(r, 0.0, 1.0));
    g = Mathf.sqrt(clampF(g, 0.0, 1.0));
    b = Mathf.sqrt(clampF(b, 0.0, 1.0));

    const off: i32 = 16 + i * 12;
    store<i32>(off, <i32>(r * 255.0));
    store<i32>(off + 4, <i32>(g * 255.0));
    store<i32>(off + 8, <i32>(b * 255.0));
  }
}
