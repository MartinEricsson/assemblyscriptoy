// ============================================================
//  Neural SDF MLP - host-baked 24-32-32-1 inference
// ============================================================
//  Weights are packed into persistent linear memory by the host
//  (magic MLP1). This shader runs inference only: positional
//  encoding, two ReLU layers, a linear distance head, and a
//  raymarch against min(mlp, analytic ground). There is no
//  training loop. A 16-phase 4x4 tile update keeps dispatches
//  short; other output pixels stay resident.
// ============================================================

const WIDTH: i32 = 256;
const HEIGHT: i32 = 256;
const STATE_OFFSET: i32 = 786448;
const WEIGHT_BASE: i32 = STATE_OFFSET + 64;
const MAGIC: i32 = 0x4D4C5031;
const TILE_PHASES: i32 = 16;
const MAX_STEPS: i32 = 48;
const SURF_DIST: f32 = 0.012;
const MAX_DIST: f32 = 12.0;
const PI: f32 = 3.14159265;
const TWO_PI: f32 = 6.28318530;

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

function clampF(v: f32, lo: f32, hi: f32): f32 {
  return Mathf.min(Mathf.max(v, lo), hi);
}

function encodeInput(px: f32, py: f32, pz: f32, i: i32): f32 {
  if (i == 0) return px;
  if (i == 1) return py;
  if (i == 2) return pz;
  if (i == 3) return sinF(px);
  if (i == 4) return cosF(px);
  if (i == 5) return sinF(py);
  if (i == 6) return cosF(py);
  if (i == 7) return sinF(pz);
  if (i == 8) return cosF(pz);
  if (i == 9) return sinF(px * 2.0);
  if (i == 10) return cosF(px * 2.0);
  if (i == 11) return sinF(py * 2.0);
  if (i == 12) return cosF(py * 2.0);
  if (i == 13) return sinF(pz * 2.0);
  if (i == 14) return cosF(pz * 2.0);
  if (i == 15) return sinF(px * 4.0);
  if (i == 16) return cosF(px * 4.0);
  if (i == 17) return sinF(py * 4.0);
  if (i == 18) return cosF(py * 4.0);
  if (i == 19) return sinF(pz * 4.0);
  if (i == 20) return cosF(pz * 4.0);
  if (i == 21) return sinF(px * 8.0);
  if (i == 22) return sinF(py * 8.0);
  return sinF(pz * 8.0);
}

function hidden1(j: i32, px: f32, py: f32, pz: f32): f32 {
  let sum: f32 = load<f32>(WEIGHT_BASE + 3072 + j * 4);
  const row: i32 = WEIGHT_BASE + j * 96;
  for (let i: i32 = 0; i < 24; i++) {
    sum = sum + load<f32>(row + i * 4) * encodeInput(px, py, pz, i);
  }
  return Mathf.max(sum, 0.0);
}

function pickH1(
  j: i32,
  h00: f32, h01: f32, h02: f32, h03: f32, h04: f32, h05: f32, h06: f32, h07: f32,
  h08: f32, h09: f32, h10: f32, h11: f32, h12: f32, h13: f32, h14: f32, h15: f32,
  h16: f32, h17: f32, h18: f32, h19: f32, h20: f32, h21: f32, h22: f32, h23: f32,
  h24: f32, h25: f32, h26: f32, h27: f32, h28: f32, h29: f32, h30: f32, h31: f32
): f32 {
  if (j == 0) return h00;
  if (j == 1) return h01;
  if (j == 2) return h02;
  if (j == 3) return h03;
  if (j == 4) return h04;
  if (j == 5) return h05;
  if (j == 6) return h06;
  if (j == 7) return h07;
  if (j == 8) return h08;
  if (j == 9) return h09;
  if (j == 10) return h10;
  if (j == 11) return h11;
  if (j == 12) return h12;
  if (j == 13) return h13;
  if (j == 14) return h14;
  if (j == 15) return h15;
  if (j == 16) return h16;
  if (j == 17) return h17;
  if (j == 18) return h18;
  if (j == 19) return h19;
  if (j == 20) return h20;
  if (j == 21) return h21;
  if (j == 22) return h22;
  if (j == 23) return h23;
  if (j == 24) return h24;
  if (j == 25) return h25;
  if (j == 26) return h26;
  if (j == 27) return h27;
  if (j == 28) return h28;
  if (j == 29) return h29;
  if (j == 30) return h30;
  return h31;
}

function mlpSdf(px: f32, py: f32, pz: f32): f32 {
  const h00: f32 = hidden1(0, px, py, pz);
  const h01: f32 = hidden1(1, px, py, pz);
  const h02: f32 = hidden1(2, px, py, pz);
  const h03: f32 = hidden1(3, px, py, pz);
  const h04: f32 = hidden1(4, px, py, pz);
  const h05: f32 = hidden1(5, px, py, pz);
  const h06: f32 = hidden1(6, px, py, pz);
  const h07: f32 = hidden1(7, px, py, pz);
  const h08: f32 = hidden1(8, px, py, pz);
  const h09: f32 = hidden1(9, px, py, pz);
  const h10: f32 = hidden1(10, px, py, pz);
  const h11: f32 = hidden1(11, px, py, pz);
  const h12: f32 = hidden1(12, px, py, pz);
  const h13: f32 = hidden1(13, px, py, pz);
  const h14: f32 = hidden1(14, px, py, pz);
  const h15: f32 = hidden1(15, px, py, pz);
  const h16: f32 = hidden1(16, px, py, pz);
  const h17: f32 = hidden1(17, px, py, pz);
  const h18: f32 = hidden1(18, px, py, pz);
  const h19: f32 = hidden1(19, px, py, pz);
  const h20: f32 = hidden1(20, px, py, pz);
  const h21: f32 = hidden1(21, px, py, pz);
  const h22: f32 = hidden1(22, px, py, pz);
  const h23: f32 = hidden1(23, px, py, pz);
  const h24: f32 = hidden1(24, px, py, pz);
  const h25: f32 = hidden1(25, px, py, pz);
  const h26: f32 = hidden1(26, px, py, pz);
  const h27: f32 = hidden1(27, px, py, pz);
  const h28: f32 = hidden1(28, px, py, pz);
  const h29: f32 = hidden1(29, px, py, pz);
  const h30: f32 = hidden1(30, px, py, pz);
  const h31: f32 = hidden1(31, px, py, pz);

  let sdf: f32 = load<f32>(WEIGHT_BASE + 7552);
  for (let k: i32 = 0; k < 32; k++) {
    let sum: f32 = load<f32>(WEIGHT_BASE + 7296 + k * 4);
    const row: i32 = WEIGHT_BASE + 3200 + k * 128;
    for (let j: i32 = 0; j < 32; j++) {
      const hj: f32 = pickH1(
        j,
        h00, h01, h02, h03, h04, h05, h06, h07,
        h08, h09, h10, h11, h12, h13, h14, h15,
        h16, h17, h18, h19, h20, h21, h22, h23,
        h24, h25, h26, h27, h28, h29, h30, h31
      );
      sum = sum + load<f32>(row + j * 4) * hj;
    }
    sdf = sdf + load<f32>(WEIGHT_BASE + 7424 + k * 4) * Mathf.max(sum, 0.0);
  }
  return sdf;
}

function sceneSdf(px: f32, py: f32, pz: f32): f32 {
  return Mathf.min(mlpSdf(px, py, pz), py + 1.0);
}

function writePixel(x: i32, y: i32, r: i32, g: i32, b: i32): void {
  const offset: i32 = 16 + (y * WIDTH + x) * 12;
  store<i32>(offset, r);
  store<i32>(offset + 4, g);
  store<i32>(offset + 8, b);
}

export function main(): void {
  const frameF: f32 = load<f32>(0);
  const frame: i32 = <i32>frameF;
  const time: f32 = frameF * 0.016;
  const phase: i32 = frame & (TILE_PHASES - 1);
  const magic: i32 = load<i32>(STATE_OFFSET);

  const camX: f32 = cosF(time * 0.3) * 5.0;
  const camY: f32 = 2.0 + sinF(time * 0.2) * 0.5;
  const camZ: f32 = sinF(time * 0.3) * 5.0;
  const fwdX: f32 = -camX;
  const fwdY: f32 = -camY;
  const fwdZ: f32 = -camZ;
  const fwdLen: f32 = Mathf.sqrt(fwdX * fwdX + fwdY * fwdY + fwdZ * fwdZ);
  const fdx: f32 = fwdX / fwdLen;
  const fdy: f32 = fwdY / fwdLen;
  const fdz: f32 = fwdZ / fwdLen;
  const rLen: f32 = Mathf.sqrt(fdz * fdz + fdx * fdx);
  const rdx: f32 = fdz / rLen;
  const rdz: f32 = -fdx / rLen;
  const ux: f32 = fdy * rdz;
  const uy: f32 = fdz * rdx - fdx * rdz;
  const uz: f32 = -fdy * rdx;
  const lx: f32 = 0.577;
  const ly: f32 = 0.577;
  const lz: f32 = -0.577;
  const invW: f32 = 1.0 / <f32>WIDTH;
  const invH: f32 = 1.0 / <f32>HEIGHT;

  for (let i: i32 = 0; i < WIDTH * HEIGHT; i++) {
    const px: i32 = i % WIDTH;
    const py: i32 = i / WIDTH;
    const pixelPhase: i32 = (px & 3) | ((py & 3) << 2);

    if (magic != MAGIC) {
      const warn: i32 = ((px >> 3) ^ (py >> 3)) & 1;
      if (warn == 0) {
        writePixel(px, py, 230, 30, 180);
      } else {
        writePixel(px, py, 40, 30, 70);
      }
    } else {
      if (pixelPhase == phase) {
        const uvx: f32 = 2.0 * <f32>px * invW - 1.0;
        const uvy: f32 = -(2.0 * <f32>py * invH - 1.0);
        const dirX: f32 = rdx * uvx + ux * uvy + fdx * 1.5;
        const dirY: f32 = uy * uvy + fdy * 1.5;
        const dirZ: f32 = rdz * uvx + uz * uvy + fdz * 1.5;
        const dirLen: f32 = Mathf.sqrt(dirX * dirX + dirY * dirY + dirZ * dirZ);
        const ddx: f32 = dirX / dirLen;
        const ddy: f32 = dirY / dirLen;
        const ddz: f32 = dirZ / dirLen;

        let t: f32 = 0.0;
        let lastD: f32 = MAX_DIST;
        for (let s: i32 = 0; s < MAX_STEPS; s++) {
          if (t <= MAX_DIST) {
            if (lastD >= SURF_DIST) {
              lastD = sceneSdf(camX + ddx * t, camY + ddy * t, camZ + ddz * t);
              if (lastD >= SURF_DIST) {
                t = t + lastD;
              }
            }
          }
        }

        let r: f32 = 0.0;
        let g: f32 = 0.0;
        let b: f32 = 0.0;
        if (lastD < SURF_DIST) {
          if (t <= MAX_DIST) {
            const hx: f32 = camX + ddx * t;
            const hy: f32 = camY + ddy * t;
            const hz: f32 = camZ + ddz * t;
            const e: f32 = 0.005;
            let nnx: f32 = sceneSdf(hx + e, hy, hz) - sceneSdf(hx - e, hy, hz);
            let nny: f32 = sceneSdf(hx, hy + e, hz) - sceneSdf(hx, hy - e, hz);
            let nnz: f32 = sceneSdf(hx, hy, hz + e) - sceneSdf(hx, hy, hz - e);
            const nLen: f32 = Mathf.sqrt(nnx * nnx + nny * nny + nnz * nnz);
            nnx = nnx / nLen;
            nny = nny / nLen;
            nnz = nnz / nLen;
            const diff: f32 = clampF(nnx * lx + nny * ly + nnz * lz, 0.0, 1.0);
            const lighting: f32 = 0.22 + diff * 0.78;
            let matR: f32 = 0.85;
            let matG: f32 = 0.35;
            let matB: f32 = 0.22;
            if (hy + 1.0 < 0.02) {
              const ck: f32 = (((<i32>Mathf.floor(hx) + <i32>Mathf.floor(hz)) & 1) == 0) ? 0.4 : 0.6;
              matR = ck;
              matG = ck;
              matB = ck;
            }
            r = matR * lighting;
            g = matG * lighting;
            b = matB * lighting;
          } else {
            const skyT: f32 = clampF(ddy * 0.5 + 0.5, 0.0, 1.0);
            r = 0.3 + 0.4 * skyT;
            g = 0.4 + 0.3 * skyT;
            b = 0.6 + 0.4 * skyT;
          }
        } else {
          const skyT: f32 = clampF(ddy * 0.5 + 0.5, 0.0, 1.0);
          r = 0.3 + 0.4 * skyT;
          g = 0.4 + 0.3 * skyT;
          b = 0.6 + 0.4 * skyT;
        }
        r = Mathf.sqrt(r);
        g = Mathf.sqrt(g);
        b = Mathf.sqrt(b);
        writePixel(
          px,
          py,
          <i32>(clampF(r, 0.0, 1.0) * 255.0),
          <i32>(clampF(g, 0.0, 1.0) * 255.0),
          <i32>(clampF(b, 0.0, 1.0) * 255.0)
        );
      }
    }
  }
}
