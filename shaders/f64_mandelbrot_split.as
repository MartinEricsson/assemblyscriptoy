// ============================================================
//  F64 Split Mandelbrot - hot-loop demotion exhibit
// ============================================================
//  Left half (x < 128) iterates the Seahorse Mandelbrot in f32.
//  Right half (x >= 128) uses the same centre and zoom with an
//  f64 iterator. Gasm demotes that iterator to f32; colour stores
//  stay i32 palettes so we do not hit the f64-store-drop bug.
//
//  Precision Julia remains the unused-probe demo. Deep Mandelbrot
//  remains the pretty f32 zoom. This file is the honest hot loop.
// ============================================================

const WIDTH: i32 = 256;
const MAX_ITER: i32 = 80;
const PI: f32 = 3.14159265;
const TWO_PI: f32 = 6.28318530;

function clamp255(value: i32): i32 {
  return value < 0 ? 0 : value > 255 ? 255 : value;
}

function triWave(value: i32): i32 {
  const phase: i32 = value & 255;
  return phase < 128 ? phase * 2 : 511 - phase * 2;
}

function sinF(x: f32): f32 {
  x = x - Mathf.floor(x / TWO_PI + 0.5) * TWO_PI;
  if (x > PI * 0.5) x = PI - x;
  if (x < -PI * 0.5) x = -PI - x;
  const x2: f32 = x * x;
  return x * (1.0 - x2 / 6.0 * (1.0 - x2 / 20.0 * (1.0 - x2 / 42.0)));
}

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

export function main(): void {
  const frame: f32 = load<f32>(0);
  const time: f32 = frame * 0.02;
  const centerX: f32 = -0.745;
  const centerY: f32 = 0.186;
  const zoom: f32 = exp2F(3.5 + 1.5 * sinF(time));
  const invZoom: f32 = 1.0 / zoom;

  for (let i: i32 = 0; i < WIDTH * WIDTH; i++) {
    const x: i32 = i & 255;
    const y: i32 = i >> 8;
    const uvx: f32 = (<f32>x - 128.0) / 64.0;
    const uvy: f32 = (<f32>y - 128.0) / 64.0;
    let iter: i32 = 0;

    if (x < 128) {
      let zr: f32 = 0.0;
      let zi: f32 = 0.0;
      const cr: f32 = centerX + uvx * invZoom;
      const ci: f32 = centerY + uvy * invZoom;
      for (; iter < MAX_ITER; iter++) {
        const zr2: f32 = zr * zr;
        const zi2: f32 = zi * zi;
        if (zr2 + zi2 > 4.0) {
          break;
        }
        zi = 2.0 * zr * zi + ci;
        zr = zr2 - zi2 + cr;
      }
    }

    if (x >= 128) {
      let zr: f64 = 0.0;
      let zi: f64 = 0.0;
      const cr: f64 = <f64>centerX + <f64>(uvx * invZoom);
      const ci: f64 = <f64>centerY + <f64>(uvy * invZoom);
      for (; iter < MAX_ITER; iter++) {
        const zr2: f64 = zr * zr;
        const zi2: f64 = zi * zi;
        if (zr2 + zi2 > 4.0) {
          // do not break from a nested helper; this is a single inner for —
          // a break here is the same shape as Precision Julia and is OK
          break;
        }
        zi = 2.0 * zr * zi + ci;
        zr = zr2 - zi2 + cr;
      }
    }

    const escaped: bool = iter < MAX_ITER;
    let r: i32 = escaped ? triWave(iter * 9) : 8;
    let g: i32 = escaped ? triWave(iter * 9 + 85) : 8;
    let b: i32 = escaped ? triWave(iter * 9 + 170) : 8;
    if (x == 127 || x == 128) {
      r = 255;
      g = 255;
      b = 255;
    }

    const offset: i32 = 16 + i * 12;
    store<i32>(offset, clamp255(r));
    store<i32>(offset + 4, clamp255(g));
    store<i32>(offset + 8, clamp255(b));
  }
}
