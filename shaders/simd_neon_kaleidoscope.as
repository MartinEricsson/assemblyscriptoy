// ============================================================
// SIMD Neon Kaleidoscope - v128 color lanes and Gasm math M0
// ============================================================
// Scalar polar geometry uses direct Gasm sin/cos/atan2 imports.
// RGB values are packed into f32x4 lanes for palette, glow, tone,
// and vignette transforms before being extracted for the framebuffer.
// ============================================================

@external("gasm", "sin_f32")
declare function gasmSin(value: f32): f32;
@external("gasm", "cos_f32")
declare function gasmCos(value: f32): f32;
@external("gasm", "atan2_f32")
declare function gasmAtan2(y: f32, x: f32): f32;

const WIDTH: i32 = 256;
const PI: f32 = 3.14159265;
const TWO_PI: f32 = 6.28318530;

function clampF(value: f32, low: f32, high: f32): f32 {
  return Mathf.min(Mathf.max(value, low), high);
}

function smoothstep(edge0: f32, edge1: f32, value: f32): f32 {
  const t: f32 = clampF((value - edge0) / (edge1 - edge0), 0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

function softLine(distance: f32, width: f32): f32 {
  return 1.0 - smoothstep(0.0, width, Mathf.abs(distance));
}

export function main(): void {
  const time: f32 = load<f32>(0) * 0.015;

  for (let i: i32 = 0; i < WIDTH * WIDTH; i++) {
    const px: f32 = (<f32>(i & 255) - 127.5) / 128.0;
    const py: f32 = (<f32>(i >> 8) - 127.5) / 128.0;
    const radius: f32 = Mathf.sqrt(px * px + py * py);
    const lens: f32 = radius * radius;

    let angle: f32 = gasmAtan2(py, px);
    angle += time * 0.18 + gasmSin(radius * 5.8 - time * 1.3) * 0.23;

    const sectors: f32 = 12.0;
    const sector: f32 = TWO_PI / sectors;
    const folded: f32 = Mathf.abs(angle - Mathf.floor(angle / sector + 0.5) * sector);
    const axisFade: f32 = 1.0 - smoothstep(sector * 0.42, sector * 0.50, folded);

    const ux: f32 = gasmCos(folded) * radius;
    const uy: f32 = gasmSin(folded) * radius;
    const petalCurve: f32 =
      0.045 * gasmSin(ux * 18.0 - time * 1.7)
      + 0.020 * gasmSin(ux * 41.0 + time * 0.7);
    const filament: f32 = softLine(uy - petalCurve, 0.018 + radius * 0.028) * axisFade;
    const outerVein: f32 = softLine(
      uy - (0.18 + 0.035 * gasmSin(ux * 13.0 + time)),
      0.015 + radius * 0.016,
    ) * smoothstep(0.16, 0.72, radius) * axisFade;

    const ringPhase: f32 =
      radius * 9.5
      + gasmSin(folded * 24.0 + time * 0.8) * 0.16
      - time * 0.45;
    const ringDistance: f32 = Mathf.abs(ringPhase - Mathf.floor(ringPhase + 0.5));
    const rings: f32 = softLine(ringDistance, 0.075) * smoothstep(0.10, 0.94, radius);
    const core: f32 = 1.0 / (1.0 + 42.0 * lens);
    const bloom: f32 = filament * 1.10 + outerVein * 0.82 + rings * 0.36 + core * 0.74;

    const phase: f32 = radius * 2.4 + folded * 3.2 - time * 0.25;
    let tint: v128 = v128.splat<f32>(0.0);
    tint = v128.replace_lane<f32>(tint, 0, 0.52 + 0.30 * gasmCos(phase + 0.25));
    tint = v128.replace_lane<f32>(tint, 1, 0.50 + 0.34 * gasmCos(phase - 1.70));
    tint = v128.replace_lane<f32>(tint, 2, 0.58 + 0.32 * gasmCos(phase + 2.20));

    let color: v128 = v128.splat<f32>(0.0);
    color = v128.replace_lane<f32>(color, 0, 0.012 + 0.026 * (1.0 - radius));
    color = v128.replace_lane<f32>(color, 1, 0.016 + 0.020 * (1.0 - radius));
    color = v128.replace_lane<f32>(color, 2, 0.030 + 0.040 * (1.0 - radius));
    color = v128.add<f32>(color, v128.mul<f32>(tint, v128.splat<f32>(bloom)));

    const gold: f32 = rings * 0.18 + softLine(radius - 0.46, 0.055) * 0.10;
    let warm: v128 = v128.splat<f32>(0.0);
    warm = v128.replace_lane<f32>(warm, 0, gold * 1.00);
    warm = v128.replace_lane<f32>(warm, 1, gold * 0.62);
    warm = v128.replace_lane<f32>(warm, 2, gold * 0.18);
    color = v128.add<f32>(color, warm);

    const vignette: f32 = 1.0 - smoothstep(0.76, 1.16, radius);
    const gain: v128 = v128.splat<f32>(vignette * (0.92 + 0.08 * gasmSin(radius * 6.0 - time)));
    color = v128.mul<f32>(color, gain);

    const rTone: f32 = v128.extract_lane<f32>(color, 0);
    const gTone: f32 = v128.extract_lane<f32>(color, 1);
    const bTone: f32 = v128.extract_lane<f32>(color, 2);
    const r: f32 = Mathf.sqrt(clampF(rTone / (1.0 + rTone * 0.42), 0.0, 1.0));
    const g: f32 = Mathf.sqrt(clampF(gTone / (1.0 + gTone * 0.42), 0.0, 1.0));
    const b: f32 = Mathf.sqrt(clampF(bTone / (1.0 + bTone * 0.42), 0.0, 1.0));

    const offset: i32 = 16 + i * 12;
    store<i32>(offset, <i32>(r * 255.0));
    store<i32>(offset + 4, <i32>(g * 255.0));
    store<i32>(offset + 8, <i32>(b * 255.0));
  }
}
