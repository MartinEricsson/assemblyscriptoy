// Flagship: Magical Stylized Fire — FBM domain warping, cosine hue palette,
// spiral spark particles, pulsing aura rings, ACES tonemapping
// 7-octave FBM + double domain warp — showcases GPU parallel noise computation
const WIDTH: i32 = 256;
const HEIGHT: i32 = 256;
const TIME_OFFSET: i32 = 0;
const PI: f32 = 3.14159265;
const TWO_PI: f32 = 6.28318530;

// --- f32-only math (avoids AS runtime i64/f64) ------------------------------

function sinF(x: f32): f32 {
  x = x - Mathf.floor(x / TWO_PI + 0.5) * TWO_PI;
  if (x > PI * 0.5) x = PI - x;
  if (x < -PI * 0.5) x = -PI - x;
  const x2: f32 = x * x;
  return x * (1.0 - x2 / 6.0 * (1.0 - x2 / 20.0 * (1.0 - x2 / 42.0)));
}
function cosF(x: f32): f32 { return sinF(x + PI * 0.5); }

function expF(x: f32): f32 {
  if (x < -20.0) return 0.0;
  if (x > 20.0) return 485165195.0;
  const nf: f32 = Mathf.floor(x * 1.4426950);
  const f: f32 = x - nf * 0.6931472;
  const ef: f32 = 1.0 + f * (1.0 + f * (0.5 + f * (0.1666667 + f * 0.04166667)));
  const ni: i32 = <i32>nf;
  let p: f32 = 1.0;
  if (ni > 0) { for (let i: i32 = 0; i < ni; i++) p *= 2.0; }
  else { const nn: i32 = -ni; for (let i: i32 = 0; i < nn; i++) p *= 0.5; }
  return p * ef;
}

function powF(b: f32, e: f32): f32 {
  if (b <= 0.0) return 0.0;
  let n: i32 = 0; let m: f32 = b;
  while (m >= 2.0) { m *= 0.5; n++; }
  while (m < 1.0) { m *= 2.0; n--; }
  const t: f32 = (m - 1.0) / (m + 1.0);
  const t2: f32 = t * t;
  const lnb: f32 = <f32>n * 0.6931472 + 2.0 * t * (1.0 + t2 * (0.3333333 + t2 * 0.2));
  return expF(e * lnb);
}

function clampF(v: f32, lo: f32, hi: f32): f32 { return Mathf.min(Mathf.max(v, lo), hi); }
function mixF(a: f32, b: f32, t: f32): f32 { return a * (1.0 - t) + b * t; }
function smoothstep(e0: f32, e1: f32, x: f32): f32 {
  const t: f32 = clampF((x - e0) / (e1 - e0), 0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}
function saturate(x: f32): f32 { return clampF(x, 0.0, 1.0); }

// ACES filmic tonemapping (preserves vivid hues better than Reinhard)
function acesTonemap(x: f32): f32 {
  const a: f32 = x * (x * 2.51 + 0.03);
  const b: f32 = x * (x * 2.43 + 0.59) + 0.14;
  return clampF(a / b, 0.0, 1.0);
}

// --- Noise (quintic interpolation for smooth flame silhouettes) -------------

function hash(x: f32, y: f32): f32 {
  let n: f32 = sinF(x * 127.1 + y * 311.7) * 43758.5453;
  return n - Mathf.floor(n);
}

function hash2(x: f32, y: f32): f32 {
  let n: f32 = sinF(x * 269.5 + y * 183.3) * 28461.7231;
  return n - Mathf.floor(n);
}

function noise(x: f32, y: f32): f32 {
  const ix: f32 = Mathf.floor(x); const iy: f32 = Mathf.floor(y);
  const fx: f32 = x - ix; const fy: f32 = y - iy;
  // Quintic interpolation (smoother than cubic, eliminates grid artifacts)
  const ux: f32 = fx * fx * fx * (fx * (fx * 6.0 - 15.0) + 10.0);
  const uy: f32 = fy * fy * fy * (fy * (fy * 6.0 - 15.0) + 10.0);
  const a: f32 = hash(ix, iy); const b: f32 = hash(ix + 1.0, iy);
  const c: f32 = hash(ix, iy + 1.0); const d: f32 = hash(ix + 1.0, iy + 1.0);
  return mixF(mixF(a, b, ux), mixF(c, d, ux), uy);
}

function fbm(x: f32, y: f32): f32 {
  let v: f32 = 0.0; let a: f32 = 0.5;
  let px: f32 = x; let py: f32 = y;
  for (let i: i32 = 0; i < 7; i++) {
    v += a * noise(px, py);
    // Rotate to break grid alignment
    const qx: f32 = px * 0.8 - py * 0.6;
    const qy: f32 = px * 0.6 + py * 0.8;
    px = qx * 2.0 + 1.7; py = qy * 2.0 + 9.2; a *= 0.5;
  }
  return v;
}

// Lighter FBM (3 octaves) for warp offsets — saves GPU cycles
function fbmLight(x: f32, y: f32): f32 {
  let v: f32 = 0.0; let a: f32 = 0.5;
  let px: f32 = x; let py: f32 = y;
  for (let i: i32 = 0; i < 3; i++) {
    v += a * noise(px, py);
    const qx: f32 = px * 0.8 - py * 0.6;
    const qy: f32 = px * 0.6 + py * 0.8;
    px = qx * 2.0 + 1.7; py = qy * 2.0 + 9.2; a *= 0.5;
  }
  return v;
}

// =============================================================================

export function main(): void {
  const frame: i32 = <i32>load<f32>(TIME_OFFSET);
  const time: f32 = <f32>frame * 0.015;
  const invW: f32 = 1.0 / <f32>WIDTH; const invH: f32 = 1.0 / <f32>HEIGHT;

  // Slowly cycling hue offset
  const hueShift: f32 = time * 0.4;

  for (let i: i32 = 0; i < WIDTH * HEIGHT; i++) {
    const px: i32 = i % WIDTH; const py: i32 = i / WIDTH;
    const u: f32 = <f32>px * invW;
    const v: f32 = <f32>py * invH;

    // Centre coordinates: cx ∈ [-0.5, 0.5], cy ∈ [0 = bottom, 1 = top]
    const cx: f32 = u - 0.5;
    const cy: f32 = 1.0 - v;

    // Flame sway
    const sway: f32 = sinF(cy * 4.0 + time * 3.0) * 0.04 * cy;
    const sx: f32 = cx - sway;

    // Fire base coordinates — stretched vertically, rising motion
    const fireX: f32 = sx * 3.5;
    const fireY: f32 = cy * 3.0 - time * 1.8;

    // Precompute full-quality double domain warp at the centre Z slice.
    // Each depth slice will offset into this warped field, giving 3-D variation
    // without repeating the heavy 7-octave warp inside the ray-march loop.
    const warp1x: f32 = fbm(fireX, fireY + time * 0.3);
    const warp1y: f32 = fbm(fireX + 5.2 + time * 0.15, fireY + 1.3);
    const warp2x: f32 = fbm(fireX + warp1x * 2.5 + 1.7 + time * 0.2, fireY + warp1y * 2.5 + 9.2);
    const warp2y: f32 = fbm(fireX + warp1x * 2.5 + 8.3, fireY + warp1y * 2.5 + 2.8 + time * 0.25);

    // Per-pixel shape helpers (Z-independent)
    const baseBoost: f32 = smoothstep(0.0, 0.2, cy);
    const flicker: f32 = 1.0 + (fbmLight(time * 2.0, 0.0) - 0.5) * 0.3;
    const heightMask: f32 = smoothstep(0.0, 0.15, cy) * smoothstep(1.15 * flicker, 0.45, cy);

    // =================================================================
    // Volumetric ray march — 16 steps along the camera Z axis.
    // Front-to-back compositing with Beer's law absorption.
    // Depth-varying noise offsets make the flame a true 3-D volume:
    // the silhouette changes as you look "into" or "out of" the column.
    // =================================================================
    let accR: f32 = 0.0; let accG: f32 = 0.0; let accB: f32 = 0.0;
    let accA: f32 = 0.0;

    const NUM_STEPS: i32 = 16;
    const stepSize: f32 = 1.0 / <f32>NUM_STEPS;   // optical depth dt

    for (let s: i32 = 0; s < NUM_STEPS; s++) {
      if (accA >= 0.99) break;  // early-out once opaque

      // zf ∈ [-0.5, 0.5] — depth position through the volume
      const zf: f32 = (<f32>s + 0.5) * stepSize - 0.5;

      // Sample the 3-D density field at this depth slice.
      // Unique (zf-based) seeds ensure each slice is a distinct noise cross-section.
      let density: f32 = fbmLight(
        fireX + warp2x * 1.8 + zf * 4.3,
        fireY + warp2y * 1.8 + zf * 3.7
      );

      // 3-D ellipsoidal shape: volume is narrower toward the front/back extremes,
      // so the flame appears to have round depth rather than a flat slab.
      const depthFalloff: f32 = Mathf.max(1.0 - zf * zf * 3.5, 0.0);
      const widthMask: f32 = smoothstep(0.55, 0.0, Mathf.abs(sx + zf * 0.1) - cy * 0.35)
                           * depthFalloff;

      density = density * widthMask * heightMask;
      density = density * (1.0 + (1.0 - baseBoost) * 2.5);
      density = clampF(density, 0.0, 1.0);

      if (density > 0.005) {
        // Beer's law: optical thickness → per-step transmittance
        const stepAlpha: f32 = 1.0 - expF(-density * 4.0 * stepSize);
        const weight: f32 = (1.0 - accA) * stepAlpha;

        // Fire colour — interior depth (|zf| small) is the white-hot core
        const t: f32 = density;
        const phase: f32 = t * 2.5 + hueShift - zf * 0.3;
        const pr: f32 = 0.5 + 0.5 * cosF(TWO_PI * (phase + 0.00));
        const pg: f32 = 0.5 + 0.5 * cosF(TWO_PI * (phase + 0.33));
        const pb: f32 = 0.5 + 0.5 * cosF(TWO_PI * (phase + 0.67));

        const core: f32 = powF(t, 0.5);
        const glow: f32 = powF(t, 1.5);

        let sr: f32 = mixF(pr * 1.4, 1.0 + pr * 0.3, core) * glow;
        let sg: f32 = mixF(pg * 1.4, 1.0 + pg * 0.3, core) * glow;
        let sb: f32 = mixF(pb * 1.4, 1.0 + pb * 0.3, core) * glow;

        // Warm base tint
        const warmth: f32 = (1.0 - baseBoost) * 0.6;
        sr += warmth * 0.8;
        sg += warmth * 0.4;
        sb += warmth * 0.05;

        // Saturation boost in mid-range
        const sat: f32 = smoothstep(0.1, 0.4, t) * smoothstep(0.95, 0.65, t);
        sr *= 1.0 + sat * 0.5;
        sg *= 1.0 + sat * 0.3;
        sb *= 1.0 + sat * 0.7;

        // Deep-core boost: slices near z=0 are the flame interior
        const interiorBoost: f32 = 1.0 - zf * zf * 2.0;
        sr *= 1.0 + interiorBoost * 0.4;
        sg *= 1.0 + interiorBoost * 0.2;
        sb *= 1.0 + interiorBoost * 0.4;

        accR += weight * sr;
        accG += weight * sg;
        accB += weight * sb;
        accA += weight;
      }
    }

    let r: f32 = accR;
    let g: f32 = accG;
    let b: f32 = accB;

    // =================================================================
    // Spiral spark particles (8 layers, hue-cycling, trailing glow)
    // =================================================================
    if (cy > 0.05 && cy < 0.95 && Mathf.abs(sx) < 0.45) {
      for (let j: i32 = 0; j < 8; j++) {
        const jf: f32 = <f32>j;
        const ePhase: f32 = hash(jf * 17.3, jf * 31.7);
        const eSpeed: f32 = 0.6 + jf * 0.25;

        const ey: f32 = (cy * 3.0 + <f32>(<i32>time) * eSpeed + ePhase * 10.0) % 3.0;

        // Spiral trajectory (helix around flame centre)
        const spiralAngle: f32 = ey * 3.0 + jf * PI * 0.5 + time * 2.0;
        const spiralRadius: f32 = 0.08 + jf * 0.025;
        const ex: f32 = cosF(spiralAngle) * spiralRadius;
        const eyMapped: f32 = ey * 0.33;

        const dx: f32 = sx - ex;
        const dy: f32 = cy - eyMapped;
        const eDist: f32 = Mathf.sqrt(dx * dx + dy * dy);

        const size: f32 = 0.012 + hash(jf * 5.1, jf * 7.3) * 0.008;

        const sparkGlow: f32 = smoothstep(size, 0.0, eDist)
          * smoothstep(0.0, 0.4, ey) * smoothstep(3.0, 1.2, ey);
        const trailGlow: f32 = smoothstep(size * 3.5, 0.0, eDist) * 0.2
          * smoothstep(0.0, 0.3, ey) * smoothstep(3.0, 1.5, ey);

        const totalGlow: f32 = sparkGlow + trailGlow;

        const sparkHue: f32 = jf * 0.37 + time * 0.8 + ey * 0.5;
        const sr: f32 = 0.5 + 0.5 * cosF(TWO_PI * (sparkHue + 0.0));
        const sg: f32 = 0.5 + 0.5 * cosF(TWO_PI * (sparkHue + 0.33));
        const sb: f32 = 0.5 + 0.5 * cosF(TWO_PI * (sparkHue + 0.67));

        r += totalGlow * (sr * 1.5 + 0.5);
        g += totalGlow * (sg * 1.5 + 0.3);
        b += totalGlow * (sb * 1.5 + 0.3);
      }
    }

    // Soft vignette
    const vigU: f32 = u * 2.0 - 1.0;
    const vigV: f32 = v * 2.0 - 1.0;
    const vig: f32 = 1.0 - (vigU * vigU + vigV * vigV) * 0.25;

    r *= vig * 0.7;
    g *= vig * 0.7;
    b *= vig * 0.7;

    // ACES filmic tonemapping
    r = acesTonemap(r);
    g = acesTonemap(g);
    b = acesTonemap(b);

    // sRGB gamma
    r = powF(clampF(r, 0.0, 1.0), 0.4545);
    g = powF(clampF(g, 0.0, 1.0), 0.4545);
    b = powF(clampF(b, 0.0, 1.0), 0.4545);

    const off: i32 = 16 + i * 12;
    store<i32>(off, <i32>(r * 255.0));
    store<i32>(off + 4, <i32>(g * 255.0));
    store<i32>(off + 8, <i32>(b * 255.0));
  }
}
