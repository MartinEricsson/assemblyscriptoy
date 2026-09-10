// ============================================================
//  Staged Tessendorf FFT Ocean - Phillips spectrum, inverse FFT
// ============================================================
//  A 256×256 height field is synthesized from a frozen Phillips
//  spectrum and an inverse radix-2 FFT. Work is staged across 18
//  dispatches (spectrum, 8 row butterflies, 8 column butterflies,
//  render) so each invocation owns a frequency bin or a butterfly
//  pair. Butterflies are out-of-place and pair-owned: only the
//  lower index of (idx, idx^half) reads both complexes and writes
//  both outputs. No atomics, no extra exports, no Gerstner fallback.
//
//  Height is the real part of the buffer that finished the last
//  column stage, scaled by 1/N² in the renderer. The displaced
//  plane is ray-marched with bilinear wrap sampling.
// ============================================================

const WIDTH: i32 = 256;
const HEIGHT: i32 = 256;
const PIXELS: i32 = WIDTH * HEIGHT;
const OUTPUT_OFFSET: i32 = 16;
const STATE_OFFSET: i32 = OUTPUT_OFFSET + PIXELS * 12;

const FFT_N: i32 = 256;
const FIELD_BYTES: i32 = FFT_N * FFT_N * 4;
const HEADER_BYTES: i32 = 64;

const MAGIC: i32 = 0x4F434541; // OCEA
const MAGIC_OFFSET: i32 = STATE_OFFSET;
const TIME_SAMPLE_OFFSET: i32 = MAGIC_OFFSET + 4;
const H0_RE: i32 = STATE_OFFSET + HEADER_BYTES;
const H0_IM: i32 = H0_RE + FIELD_BYTES;
const BUF_A_RE: i32 = H0_IM + FIELD_BYTES;
const BUF_A_IM: i32 = BUF_A_RE + FIELD_BYTES;
const BUF_B_RE: i32 = BUF_A_IM + FIELD_BYTES;
const BUF_B_IM: i32 = BUF_B_RE + FIELD_BYTES;

const PI: f32 = 3.14159265;
const TWO_PI: f32 = 6.28318530;
const PATCH: f32 = 200.0;
const GRAVITY: f32 = 9.81;
const WIND: f32 = 32.0;
const PHILLIPS_A: f32 = 0.00035;
const WIND_X: f32 = 1.0;
const WIND_Z: f32 = 0.0;
const HEIGHT_SCALE: f32 = 4.5;
const INV_N2: f32 = 1.0 / 65536.0;
const TEXEL_WORLD: f32 = PATCH / 256.0;
const TEXEL_PER_METER: f32 = 256.0 / PATCH;

function sinF(x: f32): f32 {
  x = x - Mathf.floor(x / TWO_PI + 0.5) * TWO_PI;
  if (x > PI * 0.5) x = PI - x;
  if (x < -PI * 0.5) x = -PI - x;
  const x2: f32 = x * x;
  return x * (1.0 - x2 / 6.0 * (1.0 - x2 / 20.0 * (1.0 - x2 / 42.0)));
}

function cosF(x: f32): f32 {
  return sinF(x + PI * 0.5);
}

function logF(x: f32): f32 {
  if (x <= 0.0) return -100.0;
  let n: i32 = 0;
  let m: f32 = x;
  while (m >= 2.0) { m *= 0.5; n++; }
  while (m < 1.0) { m *= 2.0; n--; }
  const t: f32 = (m - 1.0) / (m + 1.0);
  const t2: f32 = t * t;
  return <f32>n * 0.6931472 + 2.0 * t * (1.0 + t2 * (0.3333333 + t2 * 0.2));
}

function expF(x: f32): f32 {
  if (x < -20.0) return 0.0;
  if (x > 20.0) return 485165195.0;
  const n: f32 = Mathf.floor(x * 1.4426950);
  const f: f32 = x - n * 0.6931472;
  const ef: f32 = 1.0 + f * (1.0 + f * (0.5 + f * (0.1666667 + f * 0.04166667)));
  const ni: i32 = <i32>n;
  let p: f32 = 1.0;
  if (ni > 0) { for (let i: i32 = 0; i < ni; i++) p *= 2.0; }
  else { const nn: i32 = -ni; for (let i: i32 = 0; i < nn; i++) p *= 0.5; }
  return p * ef;
}

function saturate(value: f32): f32 {
  return Mathf.min(Mathf.max(value, 0.0), 1.0);
}

function absF(value: f32): f32 {
  return value < 0.0 ? -value : value;
}

function bitReverse8(x: i32): i32 {
  let v: i32 = x & 255;
  v = ((v & 0xF0) >> 4) | ((v & 0x0F) << 4);
  v = ((v & 0xCC) >> 2) | ((v & 0x33) << 2);
  v = ((v & 0xAA) >> 1) | ((v & 0x55) << 1);
  return v;
}

function hash01(value: i32): f32 {
  let state: u32 = <u32>value * 747796405 + 2891336453;
  const word: u32 = ((state >> ((state >> 28) + 4)) ^ state) * 277803737;
  const h: u32 = (word >> 22) ^ word;
  const u: f32 = <f32>(h & 2147483647) / 2147483647.0;
  return u < 0.000001 ? 0.000001 : u;
}

function gaussian(n: i32): f32 {
  const u1: f32 = hash01(n);
  const u2: f32 = hash01(n + 1973);
  return Mathf.sqrt(-2.0 * logF(u1)) * cosF(TWO_PI * u2);
}

function waveNumber(coord: i32): f32 {
  const n: i32 = coord >= 128 ? coord - 256 : coord;
  return TWO_PI * <f32>n / PATCH;
}

function phillips(kx: f32, kz: f32): f32 {
  const k2: f32 = kx * kx + kz * kz;
  if (k2 < 0.0000001) return 0.0;
  const k: f32 = Mathf.sqrt(k2);
  const L: f32 = WIND * WIND / GRAVITY;
  const kL: f32 = k * L;
  const k4: f32 = k2 * k2;
  const kdWind: f32 = (kx * WIND_X + kz * WIND_Z) / k;
  const ell: f32 = PATCH / 256.0;
  const peak: f32 = expF(-1.0 / (kL * kL));
  const damp: f32 = expF(-k2 * ell * ell);
  return PHILLIPS_A * peak / k4 * (kdWind * kdWind) * damp;
}

function writeH0(i: i32): void {
  const x: i32 = i & 255;
  const y: i32 = i >> 8;
  const amp: f32 = Mathf.sqrt(phillips(waveNumber(x), waveNumber(y)) * 0.5);
  store<f32>(H0_RE + i * 4, gaussian(i) * amp);
  store<f32>(H0_IM + i * 4, gaussian(i + 7919) * amp);
}

function writeSpectrum(i: i32, simTime: f32): void {
  const x: i32 = i & 255;
  const y: i32 = i >> 8;
  const kx: f32 = waveNumber(x);
  const kz: f32 = waveNumber(y);
  const k: f32 = Mathf.sqrt(kx * kx + kz * kz);
  const omega: f32 = Mathf.sqrt(GRAVITY * k);
  const h0r: f32 = load<f32>(H0_RE + i * 4);
  const h0i: f32 = load<f32>(H0_IM + i * 4);
  const xNeg: i32 = (FFT_N - x) & 255;
  const yNeg: i32 = (FFT_N - y) & 255;
  const iNeg: i32 = (yNeg << 8) + xNeg;
  const h0nr: f32 = load<f32>(H0_RE + iNeg * 4);
  const h0ni: f32 = load<f32>(H0_IM + iNeg * 4);
  const wr: f32 = cosF(omega * simTime);
  const wi: f32 = sinF(omega * simTime);
  const pRe: f32 = h0r * wr - h0i * wi;
  const pIm: f32 = h0r * wi + h0i * wr;
  const nRe: f32 = h0nr * wr - h0ni * wi;
  const nIm: f32 = -h0nr * wi - h0ni * wr;
  store<f32>(BUF_A_RE + i * 4, pRe + nRe);
  store<f32>(BUF_A_IM + i * 4, pIm + nIm);
}

function fftStage(readRe: i32, readIm: i32, writeRe: i32, writeIm: i32, stage: i32, dim: i32, pixel: i32): void {
  const x: i32 = pixel & 255;
  const y: i32 = pixel >> 8;
  const idx: i32 = dim == 0 ? x : y;
  const batch: i32 = dim == 0 ? y : x;
  const half: i32 = 1 << stage;
  const paired: i32 = idx ^ half;
  if (idx < paired) {
    const m: i32 = half << 1;
    const k: i32 = idx & (half - 1);
    let src0: i32 = idx;
    let src1: i32 = paired;
    if (stage == 0) {
      src0 = bitReverse8(idx);
      src1 = bitReverse8(paired);
    }
    let i0: i32 = (batch << 8) + src0;
    let i1: i32 = (batch << 8) + src1;
    let o0: i32 = (batch << 8) + idx;
    let o1: i32 = (batch << 8) + paired;
    if (dim == 1) {
      i0 = (src0 << 8) + batch;
      i1 = (src1 << 8) + batch;
      o0 = (idx << 8) + batch;
      o1 = (paired << 8) + batch;
    }
    const ar: f32 = load<f32>(readRe + i0 * 4);
    const ai: f32 = load<f32>(readIm + i0 * 4);
    const br: f32 = load<f32>(readRe + i1 * 4);
    const bi: f32 = load<f32>(readIm + i1 * 4);
    const angle: f32 = TWO_PI * <f32>k / <f32>m;
    const wr: f32 = cosF(angle);
    const wi: f32 = sinF(angle);
    const tr: f32 = wr * br - wi * bi;
    const ti: f32 = wr * bi + wi * br;
    store<f32>(writeRe + o0 * 4, ar + tr);
    store<f32>(writeIm + o0 * 4, ai + ti);
    store<f32>(writeRe + o1 * 4, ar - tr);
    store<f32>(writeIm + o1 * 4, ai - ti);
  }
}

function loadReal(ix: i32, iy: i32): f32 {
  const idx: i32 = ((iy & 255) << 8) + (ix & 255);
  return load<f32>(BUF_A_RE + idx * 4);
}

function sampleHeight(worldX: f32, worldZ: f32): f32 {
  const u: f32 = worldX * TEXEL_PER_METER + 128.0;
  const v: f32 = worldZ * TEXEL_PER_METER + 128.0;
  const xFloor: f32 = Mathf.floor(u);
  const yFloor: f32 = Mathf.floor(v);
  const fx: f32 = u - xFloor;
  const fy: f32 = v - yFloor;
  const x0: i32 = <i32>xFloor;
  const y0: i32 = <i32>yFloor;
  const h00: f32 = loadReal(x0, y0);
  const h10: f32 = loadReal(x0 + 1, y0);
  const h01: f32 = loadReal(x0, y0 + 1);
  const h11: f32 = loadReal(x0 + 1, y0 + 1);
  const h0: f32 = h00 + (h10 - h00) * fx;
  const h1: f32 = h01 + (h11 - h01) * fx;
  return (h0 + (h1 - h0) * fy) * HEIGHT_SCALE * INV_N2;
}

function writePixel(pixel: i32, red: f32, green: f32, blue: f32): void {
  const output: i32 = OUTPUT_OFFSET + pixel * 12;
  store<i32>(output, <i32>(Mathf.sqrt(saturate(red)) * 255.0));
  store<i32>(output + 4, <i32>(Mathf.sqrt(saturate(green)) * 255.0));
  store<i32>(output + 8, <i32>(Mathf.sqrt(saturate(blue)) * 255.0));
}

function renderPixel(pixel: i32): void {
  const px: i32 = pixel & 255;
  const py: i32 = pixel >> 8;
  const cameraX: f32 = 0.0;
  const cameraY: f32 = 18.0;
  const cameraZ: f32 = 28.0;
  let forwardX: f32 = -cameraX;
  let forwardY: f32 = -cameraY;
  let forwardZ: f32 = -cameraZ;
  const forwardLength: f32 = Mathf.sqrt(forwardX * forwardX + forwardY * forwardY + forwardZ * forwardZ);
  forwardX /= forwardLength; forwardY /= forwardLength; forwardZ /= forwardLength;
  let rightX: f32 = -forwardZ;
  let rightZ: f32 = forwardX;
  const rightLength: f32 = Mathf.sqrt(rightX * rightX + rightZ * rightZ);
  rightX /= rightLength; rightZ /= rightLength;
  const upX: f32 = -forwardY * rightZ;
  const upY: f32 = rightZ * forwardX - rightX * forwardZ;
  const upZ: f32 = forwardY * rightX;
  const sx: f32 = (<f32>px + 0.5) / 128.0 - 1.0;
  const sy: f32 = 1.0 - (<f32>py + 0.5) / 128.0;
  let rayX: f32 = forwardX + rightX * sx * 0.70 + upX * sy * 0.70;
  let rayY: f32 = forwardY + upY * sy * 0.70;
  let rayZ: f32 = forwardZ + rightZ * sx * 0.70 + upZ * sy * 0.70;
  const rayLength: f32 = Mathf.sqrt(rayX * rayX + rayY * rayY + rayZ * rayZ);
  rayX /= rayLength; rayY /= rayLength; rayZ /= rayLength;

  const skyT: f32 = saturate(rayY * 0.75 + 0.25);
  const skyR: f32 = 0.25 + (0.95 - 0.25) * skyT;
  const skyG: f32 = 0.45 + (0.95 - 0.45) * skyT;
  const skyB: f32 = 0.75 + (0.98 - 0.75) * skyT;
  let red: f32 = skyR;
  let green: f32 = skyG;
  let blue: f32 = skyB;

  let tPlane: f32 = 80.0;
  if (rayY < -0.0001) tPlane = (0.0 - cameraY) / rayY;
  const t0: f32 = Mathf.max(tPlane - 14.0, 0.5);
  const t1: f32 = tPlane + 18.0;
  const dt: f32 = (t1 - t0) / 48.0;
  let t: f32 = t0;
  let hitT: f32 = -1.0;
  let prevY: f32 = cameraY + rayY * t0;
  let prevH: f32 = sampleHeight(cameraX + rayX * t0, cameraZ + rayZ * t0);
  for (let step: i32 = 0; step < 48; step++) {
    t += dt;
    const sampleX: f32 = cameraX + rayX * t;
    const sampleY: f32 = cameraY + rayY * t;
    const sampleZ: f32 = cameraZ + rayZ * t;
    const fieldH: f32 = sampleHeight(sampleX, sampleZ);
    const crossed: bool = prevY >= prevH && sampleY <= fieldH;
    if (hitT < 0.0) {
      if (crossed) hitT = t;
    }
    prevY = sampleY;
    prevH = fieldH;
  }

  if (hitT > 0.0) {
    const hx: f32 = cameraX + rayX * hitT;
    const hz: f32 = cameraZ + rayZ * hitT;
    const u: f32 = hx * TEXEL_PER_METER + 128.0;
    const v: f32 = hz * TEXEL_PER_METER + 128.0;
    const ix: i32 = <i32>Mathf.floor(u);
    const iy: i32 = <i32>Mathf.floor(v);
    const hL: f32 = loadReal(ix - 1, iy) * HEIGHT_SCALE * INV_N2;
    const hR: f32 = loadReal(ix + 1, iy) * HEIGHT_SCALE * INV_N2;
    const hD: f32 = loadReal(ix, iy - 1) * HEIGHT_SCALE * INV_N2;
    const hU: f32 = loadReal(ix, iy + 1) * HEIGHT_SCALE * INV_N2;
    let nx: f32 = hL - hR;
    let ny: f32 = 2.0 * TEXEL_WORLD;
    let nz: f32 = hD - hU;
    const nLen: f32 = Mathf.sqrt(Mathf.max(nx * nx + ny * ny + nz * nz, 0.000001));
    nx /= nLen; ny /= nLen; nz /= nLen;

    let sunX: f32 = 0.35;
    let sunY: f32 = 0.75;
    let sunZ: f32 = 0.55;
    const sunLen: f32 = Mathf.sqrt(sunX * sunX + sunY * sunY + sunZ * sunZ);
    sunX /= sunLen; sunY /= sunLen; sunZ /= sunLen;
    const diffuse: f32 = saturate(nx * sunX + ny * sunY + nz * sunZ);
    const ndotv: f32 = saturate(-(nx * rayX + ny * rayY + nz * rayZ));
    const oneMinus: f32 = 1.0 - ndotv;
    const om2: f32 = oneMinus * oneMinus;
    const fresnel: f32 = 0.02 + 0.98 * om2 * om2 * oneMinus;
    let hxS: f32 = sunX - rayX;
    let hyS: f32 = sunY - rayY;
    let hzS: f32 = sunZ - rayZ;
    const hLen: f32 = Mathf.sqrt(Mathf.max(hxS * hxS + hyS * hyS + hzS * hzS, 0.000001));
    hxS /= hLen; hyS /= hLen; hzS /= hLen;
    let spec: f32 = saturate(nx * hxS + ny * hyS + nz * hzS);
    spec = spec * spec;
    spec = spec * spec;
    spec = spec * spec;
    spec = spec * spec;
    spec = spec * spec;
    spec = spec * spec;
    const twoNdotR: f32 = 2.0 * (nx * rayX + ny * rayY + nz * rayZ);
    const reflY: f32 = rayY - twoNdotR * ny;
    const reflT: f32 = saturate(reflY * 0.75 + 0.25);
    const reflR: f32 = 0.25 + (0.95 - 0.25) * reflT;
    const reflG: f32 = 0.45 + (0.95 - 0.45) * reflT;
    const reflB: f32 = 0.75 + (0.98 - 0.75) * reflT;
    const waterR: f32 = 0.015 + diffuse * 0.05;
    const waterG: f32 = 0.10 + diffuse * 0.22;
    const waterB: f32 = 0.16 + diffuse * 0.30;
    red = waterR * (1.0 - fresnel) + reflR * fresnel + spec * 0.65;
    green = waterG * (1.0 - fresnel) + reflG * fresnel + spec * 0.62;
    blue = waterB * (1.0 - fresnel) + reflB * fresnel + spec * 0.55;
  }

  writePixel(pixel, red, green, blue);
}

export function main(): void {
  const frame: i32 = <i32>load<f32>(0);
  const initialized: bool = load<i32>(MAGIC_OFFSET) == MAGIC;

  for (let i: i32 = 0; i < PIXELS; i++) {
    if (!initialized) {
      writeH0(i);
      if (i == 0) store<i32>(MAGIC_OFFSET, MAGIC);
    } else if (frame >= 1) {
      const cycle: i32 = (frame - 1) / 18;
      const phase: i32 = (frame - 1) % 18;
      const simTime: f32 = <f32>cycle * 0.08;
      if (phase == 0) {
        writeSpectrum(i, simTime);
        if (i == 0) store<f32>(TIME_SAMPLE_OFFSET, simTime);
      } else if (phase <= 16) {
        const isRow: bool = phase <= 8;
        const stage: i32 = isRow ? phase - 1 : phase - 9;
        const dim: i32 = isRow ? 0 : 1;
        const fromA: bool = (phase & 1) == 1;
        const readRe: i32 = fromA ? BUF_A_RE : BUF_B_RE;
        const readIm: i32 = fromA ? BUF_A_IM : BUF_B_IM;
        const writeRe: i32 = fromA ? BUF_B_RE : BUF_A_RE;
        const writeIm: i32 = fromA ? BUF_B_IM : BUF_A_IM;
        fftStage(readRe, readIm, writeRe, writeIm, stage, dim, i);
      } else {
        renderPixel(i);
      }
    }
  }
}
