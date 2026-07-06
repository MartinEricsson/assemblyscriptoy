// ============================================================
// Flow-Field Ink - persistent f32 advection
// ============================================================
// Two 256x256 RGB fields ping-pong through a procedural curl-like
// velocity field. Bilinear backtracing transports color smoothly.
// Drag to inject bright ink into the moving flow.
// ============================================================

const WIDTH: i32 = 256;
const FIELD: i32 = 256;
const CELLS: i32 = FIELD * FIELD;
const BUFFER_BYTES: i32 = CELLS * 12;
const STATE_OFFSET: i32 = 16 + WIDTH * WIDTH * 12;
const MAGIC_OFFSET: i32 = STATE_OFFSET;
const BUFFER_A: i32 = STATE_OFFSET + 16;
const BUFFER_B: i32 = BUFFER_A + BUFFER_BYTES;
const MAGIC: i32 = 1229866071; // INKW
const PI: f32 = 3.14159265;
const TWO_PI: f32 = 6.28318530;

function sinF(value: f32): f32 {
  let x: f32 = value - Mathf.floor(value / TWO_PI + 0.5) * TWO_PI;
  if (x > PI * 0.5) x = PI - x;
  if (x < -PI * 0.5) x = -PI - x;
  const x2: f32 = x * x;
  return x * (1.0 - x2 / 6.0 * (1.0 - x2 / 20.0));
}

function cosF(value: f32): f32 {
  return sinF(value + PI * 0.5);
}

function clampF(value: f32, low: f32, high: f32): f32 {
  return Mathf.min(Mathf.max(value, low), high);
}

function wrap(value: i32): i32 {
  return value < 0 ? value + FIELD : value >= FIELD ? value - FIELD : value;
}

function componentAddress(base: i32, x: i32, y: i32, channel: i32): i32 {
  return base + (wrap(y) * FIELD + wrap(x)) * 12 + channel * 4;
}

function sampleBilinear(base: i32, x: f32, y: f32, channel: i32): f32 {
  const x0: i32 = <i32>Mathf.floor(x);
  const y0: i32 = <i32>Mathf.floor(y);
  const fx: f32 = x - Mathf.floor(x);
  const fy: f32 = y - Mathf.floor(y);
  const a: f32 = load<f32>(componentAddress(base, x0, y0, channel));
  const b: f32 = load<f32>(componentAddress(base, x0 + 1, y0, channel));
  const c: f32 = load<f32>(componentAddress(base, x0, y0 + 1, channel));
  const d: f32 = load<f32>(componentAddress(base, x0 + 1, y0 + 1, channel));
  return (a + (b - a) * fx) * (1.0 - fy) + (c + (d - c) * fx) * fy;
}

function sampleLuma(base: i32, x: i32, y: i32): f32 {
  const r: f32 = load<f32>(componentAddress(base, x, y, 0));
  const g: f32 = load<f32>(componentAddress(base, x, y, 1));
  const b: f32 = load<f32>(componentAddress(base, x, y, 2));
  return r * 0.2126 + g * 0.7152 + b * 0.0722;
}

function filmic(value: f32): f32 {
  const exposed: f32 = value * 1.02;
  const white: f32 = 5.0;
  return clampF((exposed * (1.0 + exposed / (white * white))) / (1.0 + exposed), 0.0, 0.82);
}

function seedColor(x: i32, y: i32, channel: i32): f32 {
  const dx: f32 = <f32>x - 128.0;
  const dy: f32 = <f32>y - 128.0;
  const dist: f32 = Mathf.sqrt(dx * dx + dy * dy);
  const ringA: f32 = clampF(1.0 - Mathf.abs(dist - 58.0) / 13.0, 0.0, 1.0);
  const ringB: f32 = clampF(1.0 - Mathf.abs(dist - 92.0) / 10.0, 0.0, 1.0);
  const strength: f32 = Mathf.max(ringA, ringB * 0.72);
  if (strength <= 0.0) return 0.0;
  if (channel == 0) return strength * (0.85 + 0.15 * sinF(<f32>y * 0.10));
  if (channel == 1) return strength * (0.45 + 0.45 * sinF(<f32>x * 0.075 + 2.0));
  return strength * (0.75 + 0.25 * cosF(<f32>(x + y) * 0.065));
}

export function main(): void {
  const frame: i32 = <i32>load<f32>(0);
  const time: f32 = <f32>frame * 0.02;
  const pointerX: i32 = load<i32>(4);
  const pointerY: i32 = load<i32>(8);
  const pointerButtons: i32 = load<i32>(12);
  const initialized: bool = load<i32>(MAGIC_OFFSET) == MAGIC;
  const readBase: i32 = (frame & 1) == 0 ? BUFFER_A : BUFFER_B;
  const writeBase: i32 = (frame & 1) == 0 ? BUFFER_B : BUFFER_A;

  for (let i: i32 = 0; i < WIDTH * WIDTH; i++) {
    if (i < CELLS) {
      const x: i32 = i & 255;
      const y: i32 = i >> 8;

      if (!initialized) {
        for (let channel: i32 = 0; channel < 3; channel++) {
          const value: f32 = seedColor(x, y, channel);
          store<f32>(componentAddress(BUFFER_A, x, y, channel), value);
          store<f32>(componentAddress(BUFFER_B, x, y, channel), value);
        }
        if (i == 0) store<i32>(MAGIC_OFFSET, MAGIC);
      } else {
        const fx: f32 = <f32>x;
        const fy: f32 = <f32>y;
        const vx: f32 = sinF(fy * 0.040 + time) + 0.65 * cosF((fx + fy) * 0.028 - time * 0.7);
        const vy: f32 = -cosF(fx * 0.038 - time * 0.8) + 0.65 * sinF((fx - fy) * 0.026 + time);
        const backX: f32 = fx - vx * 1.45;
        const backY: f32 = fy - vy * 1.45;

        let nextR: f32 = sampleBilinear(readBase, backX, backY, 0) * 0.982;
        let nextG: f32 = sampleBilinear(readBase, backX, backY, 1) * 0.982;
        let nextB: f32 = sampleBilinear(readBase, backX, backY, 2) * 0.982;

        if (pointerButtons != 0 && pointerX >= 0 && pointerY >= 0) {
          const dx: i32 = x - pointerX;
          const dy: i32 = y - pointerY;
          const pointerDist: i32 = dx * dx + dy * dy;
          if (pointerDist < 441) {
            const pointerInk: f32 = 1.0 - <f32>pointerDist / 441.0;
            nextR += pointerInk * (0.28 + 0.18 * sinF(time * 0.8));
            nextG += pointerInk * (0.18 + 0.14 * sinF(time * 0.8 + 2.1));
            nextB += pointerInk * (0.34 + 0.20 * sinF(time * 0.8 + 4.2));
          }
        }

        const sourceX: f32 = 128.0 + sinF(time * 0.73) * 72.0;
        const sourceY: f32 = 128.0 + cosF(time * 0.57) * 72.0;
        const sdx: f32 = fx - sourceX;
        const sdy: f32 = fy - sourceY;
        const sourceDist: f32 = sdx * sdx + sdy * sdy;
        if (sourceDist < 676.0) {
          const sourceInk: f32 = 1.0 - sourceDist / 676.0;
          nextR += sourceInk * 0.14;
          nextG += sourceInk * 0.07;
          nextB += sourceInk * 0.20;
        }

        const density: f32 = nextR * 0.2126 + nextG * 0.7152 + nextB * 0.0722;
        const densityDamping: f32 = 1.0 / (1.0 + density * 0.055);
        store<f32>(componentAddress(writeBase, x, y, 0), clampF(nextR * densityDamping, 0.0, 4.0));
        store<f32>(componentAddress(writeBase, x, y, 1), clampF(nextG * densityDamping, 0.0, 4.0));
        store<f32>(componentAddress(writeBase, x, y, 2), clampF(nextB * densityDamping, 0.0, 4.0));
      }
    }

    const px: i32 = i & 255;
    const py: i32 = i >> 8;
    const sx: i32 = px;
    const sy: i32 = py;
    const displayBase: i32 = initialized ? readBase : BUFFER_A;
    const r0: f32 = load<f32>(componentAddress(displayBase, sx, sy, 0));
    const g0: f32 = load<f32>(componentAddress(displayBase, sx, sy, 1));
    const b0: f32 = load<f32>(componentAddress(displayBase, sx, sy, 2));
    const luma0: f32 = r0 * 0.2126 + g0 * 0.7152 + b0 * 0.0722;
    const bloom: f32 =
      luma0 * 0.42
      + (sampleLuma(displayBase, sx - 2, sy) + sampleLuma(displayBase, sx + 2, sy)
      + sampleLuma(displayBase, sx, sy - 2) + sampleLuma(displayBase, sx, sy + 2)) * 0.095
      + (sampleLuma(displayBase, sx - 4, sy - 4) + sampleLuma(displayBase, sx + 4, sy - 4)
      + sampleLuma(displayBase, sx - 4, sy + 4) + sampleLuma(displayBase, sx + 4, sy + 4)) * 0.05;
    const glow: f32 = Mathf.max(bloom - 0.22, 0.0);
    const hdrR: f32 = r0 * 1.10 + glow * (0.14 + r0 * 0.06);
    const hdrG: f32 = g0 * 1.10 + glow * (0.14 + g0 * 0.06);
    const hdrB: f32 = b0 * 1.10 + glow * (0.18 + b0 * 0.08);
    const hdrLuma: f32 = Mathf.max(hdrR * 0.2126 + hdrG * 0.7152 + hdrB * 0.0722, 0.0001);
    const mappedLuma: f32 = filmic(hdrLuma);
    const toneScale: f32 = mappedLuma / hdrLuma;
    const chroma: f32 = 0.24 + 0.76 / (1.0 + hdrLuma * 0.12);
    const mappedR: f32 = mappedLuma + (hdrR * toneScale - mappedLuma) * chroma;
    const mappedG: f32 = mappedLuma + (hdrG * toneScale - mappedLuma) * chroma;
    const mappedB: f32 = mappedLuma + (hdrB * toneScale - mappedLuma) * chroma;
    const r: f32 = Mathf.sqrt(clampF(mappedR, 0.0, 0.82));
    const g: f32 = Mathf.sqrt(clampF(mappedG, 0.0, 0.82));
    const b: f32 = Mathf.sqrt(clampF(mappedB, 0.0, 0.82));

    const pixelOffset: i32 = 16 + i * 12;
    store<i32>(pixelOffset, <i32>(r * 255.0));
    store<i32>(pixelOffset + 4, <i32>(g * 255.0));
    store<i32>(pixelOffset + 8, <i32>(b * 255.0));
  }
}
