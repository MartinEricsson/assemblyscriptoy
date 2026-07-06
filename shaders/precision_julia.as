// ============================================================
// Precision Julia Orbit Traps - deliberate f64 and i64 lowering
// ============================================================
// Exported probe helpers intentionally use f64 and i64 so Gasm reports
// numeric compatibility decisions in Results. The hot fractal loop
// stays in f32, avoiding unnecessary precision work after demotion.
// ============================================================

const WIDTH: i32 = 256;

function clamp255(value: i32): i32 {
  return value < 0 ? 0 : value > 255 ? 255 : value;
}

function triWave(value: i32): i32 {
  const phase: i32 = value & 255;
  return phase < 128 ? phase * 2 : 511 - phase * 2;
}

function absF(value: f32): f32 {
  return value < 0.0 ? -value : value;
}

export function precisionProbe(value: f64): f64 {
  return value * 1.000001 + 0.125;
}

export function integerProbe(value: i64): i64 {
  return (value << 3) ^ (value >> 5);
}

export function main(): void {
  const frame: i32 = <i32>load<f32>(0);

  for (let i: i32 = 0; i < WIDTH * WIDTH; i++) {
    const cycle: i32 = frame & 511;
    const triangle: i32 = cycle < 256 ? cycle : 511 - cycle;
    const morph: f32 = <f32>triangle / 255.0;
    const cr: f32 = -0.82 + morph * 0.18;
    const ci: f32 = 0.18 + (1.0 - morph) * 0.16;
    const x: i32 = i & 255;
    const y: i32 = i >> 8;
    let zx: f32 = (<f32>x - 128.0) / 82.0;
    let zy: f32 = (<f32>y - 128.0) / 82.0;
    let trapLine: f32 = 100.0;
    let trapCircle: f32 = 100.0;
    let iter: i32 = 0;

    for (; iter < 140; iter++) {
      const zx2: f32 = zx * zx;
      const zy2: f32 = zy * zy;
      if (zx2 + zy2 > 16.0) break;
      const nextX: f32 = zx2 - zy2 + cr;
      zy = 2.0 * zx * zy + ci;
      zx = nextX;
      trapLine = absF(zy) < trapLine ? absF(zy) : trapLine;
      const radiusTrap: f32 = absF(zx2 + zy2 - 0.55);
      trapCircle = radiusTrap < trapCircle ? radiusTrap : trapCircle;
    }

    const palette: i32 = (iter * 9 + (frame >> 2)) & 255;
    const lineGlow: i32 = clamp255(<i32>((0.08 - trapLine) * 3600.0));
    const circleGlow: i32 = clamp255(<i32>((0.10 - trapCircle) * 2800.0));
    const escaped: bool = iter < 140;

    let r: i32 = escaped ? triWave(palette) : 3;
    let g: i32 = escaped ? triWave(palette + 85) : 5;
    let b: i32 = escaped ? triWave(palette + 170) : 12;
    r = clamp255(r + circleGlow);
    g = clamp255(g + lineGlow);
    b = clamp255(b + (lineGlow + circleGlow) / 2);

    const offset: i32 = 16 + i * 12;
    store<i32>(offset, r);
    store<i32>(offset + 4, g);
    store<i32>(offset + 8, b);
  }
}
