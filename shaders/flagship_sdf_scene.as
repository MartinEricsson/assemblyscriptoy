// Flagship: Raymarched SDF Scene with perspective, lighting, soft shadows & AO
// Uses f32 only — compute-heavy for GPU showcase
const WIDTH: i32 = 256;
const HEIGHT: i32 = 256;
const TIME_OFFSET: i32 = 0;
const MAX_STEPS: i32 = 180;
const MAX_DIST: f32 = 50.0;
const SURF_DIST: f32 = 0.001;
const PI: f32 = 3.14159265;
const TWO_PI: f32 = 6.28318530;

// f32-only sin/cos/pow/exp (avoids AS runtime i64/f64)
function sinF(x: f32): f32 {
  // Range reduce to [-PI, PI]
  x = x - Mathf.floor(x / TWO_PI + 0.5) * TWO_PI;
  // Fold into [-PI/2, PI/2] where the Taylor series is accurate
  if (x > PI * 0.5) x = PI - x;
  if (x < -PI * 0.5) x = -PI - x;
  const x2: f32 = x * x;
  return x * (1.0 - x2 / 6.0 * (1.0 - x2 / 20.0 * (1.0 - x2 / 42.0)));
}
function cosF(x: f32): f32 { return sinF(x + PI * 0.5); }

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
function powF(b: f32, e: f32): f32 {
  if (b <= 0.0) return 0.0;
  return expF(e * logF(b));
}

function clampF(v: f32, lo: f32, hi: f32): f32 { return Mathf.min(Mathf.max(v, lo), hi); }

function smoothMin(a: f32, b: f32, k: f32): f32 {
  const h: f32 = Mathf.max(k - Mathf.abs(a - b), 0.0) / k;
  return Mathf.min(a, b) - h * h * k * 0.25;
}

function sdSphere(px: f32, py: f32, pz: f32, cx: f32, cy: f32, cz: f32, r: f32): f32 {
  const dx: f32 = px - cx; const dy: f32 = py - cy; const dz: f32 = pz - cz;
  return Mathf.sqrt(dx * dx + dy * dy + dz * dz) - r;
}

function sdBox(px: f32, py: f32, pz: f32, bx: f32, by: f32, bz: f32): f32 {
  const dx: f32 = Mathf.abs(px) - bx;
  const dy: f32 = Mathf.abs(py) - by;
  const dz: f32 = Mathf.abs(pz) - bz;
  const mx: f32 = Mathf.max(dx, 0.0); const my: f32 = Mathf.max(dy, 0.0); const mz: f32 = Mathf.max(dz, 0.0);
  return Mathf.sqrt(mx * mx + my * my + mz * mz) + Mathf.min(Mathf.max(dx, Mathf.max(dy, dz)), 0.0);
}

function sdTorus(px: f32, py: f32, pz: f32, R: f32, r: f32): f32 {
  const qx: f32 = Mathf.sqrt(px * px + pz * pz) - R;
  return Mathf.sqrt(qx * qx + py * py) - r;
}

function sceneSDF(px: f32, py: f32, pz: f32, time: f32): f32 {
  const ground: f32 = py + 1.0;
  const sphereY: f32 = sinF(time * 2.0) * 0.5;
  const d1: f32 = sdSphere(px, py, pz, 0.0, sphereY, 0.0, 0.8);
  const ca: f32 = cosF(time * 0.7); const sa: f32 = sinF(time * 0.7);
  const rpx: f32 = px - 2.2; const rpy: f32 = py - 0.3;
  const d2: f32 = sdTorus(rpx * ca - rpy * sa, rpx * sa + rpy * ca, pz, 0.6, 0.2);
  const bpx: f32 = px + 2.0;
  const cb: f32 = cosF(time * 0.5); const sb: f32 = sinF(time * 0.5);
  const d3: f32 = sdBox(bpx * cb - pz * sb, py, bpx * sb + pz * cb, 0.5, 0.5, 0.5) - 0.08;
  const ox: f32 = cosF(time * 3.0) * 1.5; const oz: f32 = sinF(time * 3.0) * 1.5;
  const d4: f32 = sdSphere(px, py, pz, ox, 0.8, oz, 0.25);
  let d: f32 = smoothMin(d1, d4, 0.5);
  d = Mathf.min(d, d2); d = Mathf.min(d, d3); d = Mathf.min(d, ground);
  return d;
}

function softShadow(ox: f32, oy: f32, oz: f32, dx: f32, dy: f32, dz: f32, mint: f32, maxt: f32, time: f32): f32 {
  let res: f32 = 1.0; let t: f32 = mint;
  for (let i: i32 = 0; i < 16; i++) {
    if (t >= maxt) break;
    const h: f32 = sceneSDF(ox + dx * t, oy + dy * t, oz + dz * t, time);
    res = Mathf.min(res, 8.0 * h / t);
    if (h < 0.001) return 0.0;
    t += h;
  }
  return Mathf.max(res, 0.0);
}

function calcAO(px: f32, py: f32, pz: f32, nx: f32, ny: f32, nz: f32, time: f32): f32 {
  let occ: f32 = 0.0; let sca: f32 = 1.0;
  for (let i: i32 = 0; i < 5; i++) {
    const h: f32 = 0.01 + 0.12 * <f32>i;
    occ += (h - sceneSDF(px + nx * h, py + ny * h, pz + nz * h, time)) * sca;
    sca *= 0.95;
  }
  return 1.0 - 3.0 * occ;
}

export function main(): void {
  const time: f32 = load<f32>(TIME_OFFSET) * 0.016;
  const camX: f32 = cosF(time * 0.3) * 5.0;
  const camY: f32 = 2.0 + sinF(time * 0.2) * 0.5;
  const camZ: f32 = sinF(time * 0.3) * 5.0;
  const fwdX: f32 = -camX; const fwdY: f32 = -camY; const fwdZ: f32 = -camZ;
  const fwdLen: f32 = Mathf.sqrt(fwdX * fwdX + fwdY * fwdY + fwdZ * fwdZ);
  const fdx: f32 = fwdX / fwdLen; const fdy: f32 = fwdY / fwdLen; const fdz: f32 = fwdZ / fwdLen;
  const rLen: f32 = Mathf.sqrt(fdz * fdz + fdx * fdx);
  const rdx: f32 = fdz / rLen; const rdz: f32 = -fdx / rLen;
  const ux: f32 = fdy * rdz; const uy: f32 = fdz * rdx - fdx * rdz; const uz: f32 = -fdy * rdx;
  const lx: f32 = 0.577; const ly: f32 = 0.577; const lz: f32 = -0.577;
  const invW: f32 = 1.0 / <f32>WIDTH; const invH: f32 = 1.0 / <f32>HEIGHT;

  for (let i: i32 = 0; i < WIDTH * HEIGHT; i++) {
    const px: i32 = i % WIDTH; const py: i32 = i / WIDTH;
    const uvx: f32 = 2.0 * <f32>px * invW - 1.0;
    const uvy: f32 = -(2.0 * <f32>py * invH - 1.0);
    const dirX: f32 = rdx * uvx + ux * uvy + fdx * 1.5;
    const dirY: f32 = uy * uvy + fdy * 1.5;
    const dirZ: f32 = rdz * uvx + uz * uvy + fdz * 1.5;
    const dirLen: f32 = Mathf.sqrt(dirX * dirX + dirY * dirY + dirZ * dirZ);
    const ddx: f32 = dirX / dirLen; const ddy: f32 = dirY / dirLen; const ddz: f32 = dirZ / dirLen;

    let t: f32 = 0.0; let lastD: f32 = MAX_DIST;
    for (let s: i32 = 0; s < MAX_STEPS; s++) {
      lastD = sceneSDF(camX + ddx * t, camY + ddy * t, camZ + ddz * t, time);
      if (lastD < SURF_DIST) break;
      if (t > MAX_DIST) break;
      t += lastD;
    }

    let r: f32 = 0.0; let g: f32 = 0.0; let b: f32 = 0.0;
    if (lastD < SURF_DIST) {
      const hx: f32 = camX + ddx * t; const hy: f32 = camY + ddy * t; const hz: f32 = camZ + ddz * t;
      const e: f32 = 0.001;
      let nnx: f32 = sceneSDF(hx + e, hy, hz, time) - sceneSDF(hx - e, hy, hz, time);
      let nny: f32 = sceneSDF(hx, hy + e, hz, time) - sceneSDF(hx, hy - e, hz, time);
      let nnz: f32 = sceneSDF(hx, hy, hz + e, time) - sceneSDF(hx, hy, hz - e, time);
      const nLen: f32 = Mathf.sqrt(nnx * nnx + nny * nny + nnz * nnz);
      nnx /= nLen; nny /= nLen; nnz /= nLen;
      const diff: f32 = clampF(nnx * lx + nny * ly + nnz * lz, 0.0, 1.0);
      const hlfX: f32 = lx - ddx; const hlfY: f32 = ly - ddy; const hlfZ: f32 = lz - ddz;
      const hLen: f32 = Mathf.sqrt(hlfX * hlfX + hlfY * hlfY + hlfZ * hlfZ);
      const spec: f32 = powF(clampF((nnx * hlfX + nny * hlfY + nnz * hlfZ) / hLen, 0.0, 1.0), 32.0);
      const shadow: f32 = softShadow(hx + nnx * 0.02, hy + nny * 0.02, hz + nnz * 0.02, lx, ly, lz, 0.02, 5.0, time);
      const ao: f32 = clampF(calcAO(hx, hy, hz, nnx, nny, nnz, time), 0.0, 1.0);
      
      let isReflective: boolean = false;
      if (sdSphere(hx, hy, hz, 0.0, sinF(time * 2.0) * 0.5, 0.0, 0.8) < 0.05) {
        isReflective = true;
      }

      const cbH: f32 = cosF(time * 0.5); const sbH: f32 = sinF(time * 0.5);
      const bpxH: f32 = hx + 2.0;
      const d3Hit: f32 = sdBox(bpxH * cbH - hz * sbH, hy, bpxH * sbH + hz * cbH, 0.5, 0.5, 0.5) - 0.08;
      const isBox: boolean = d3Hit < 0.05;
      const caT: f32 = cosF(time * 0.7); const saT: f32 = sinF(time * 0.7);
      const trpx: f32 = hx - 2.2; const trpy: f32 = hy - 0.3;
      const isTorus: boolean = sdTorus(trpx * caT - trpy * saT, trpx * saT + trpy * caT, hz, 0.6, 0.2) < 0.05;
      // Torus acts as a warm point light centred at (2.2, 0.3, 0.0)
      const tldx: f32 = 2.2 - hx; const tldy: f32 = 0.3 - hy; const tldz: f32 = -hz;
      const tlDist: f32 = Mathf.sqrt(tldx * tldx + tldy * tldy + tldz * tldz);
      const tldxn: f32 = tldx / tlDist; const tldyn: f32 = tldy / tlDist; const tldzn: f32 = tldz / tlDist;
      const tlDiff: f32 = clampF(nnx * tldxn + nny * tldyn + nnz * tldzn, 0.0, 1.0);
      const tlShadow: f32 = softShadow(hx + nnx * 0.02, hy + nny * 0.02, hz + nnz * 0.02, tldxn, tldyn, tldzn, 0.02, tlDist, time);
      const tlAtten: f32 = 1.0 / (1.0 + tlDist * tlDist * 0.12);
      const torusLight: f32 = tlDiff * tlShadow * tlAtten * 1.8;
      let matR: f32; let matG: f32; let matB: f32;
      if (hy + 1.0 < 0.01) {
        const ck: f32 = (((<i32>Mathf.floor(hx) + <i32>Mathf.floor(hz)) & 1) == 0) ? 0.4 : 0.6;
        matR = ck; matG = ck; matB = ck;
      } else if (isBox) {
        const hue: f32 = hy * 4.0 + hz * 2.5 + hx * 1.5 + time * 1.5;
        matR = 0.5 + 0.5 * sinF(hue);
        matG = 0.5 + 0.5 * sinF(hue + 2.09440);
        matB = 0.5 + 0.5 * sinF(hue + 4.18879);
      } else { matR = 0.8; matG = 0.35; matB = 0.25; }
      if (isTorus) {
        r = 2.0; g = 1.0; b = 0.2; // emissive warm glow
      } else {
        const lighting: f32 = 0.15 + diff * shadow * 0.7 + spec * shadow * 0.4;
        r = matR * (lighting * ao + torusLight * 1.0);
        g = matG * (lighting * ao + torusLight * 0.6);
        b = matB * (lighting * ao + torusLight * 0.1);
      }

      if (isReflective) {
        const rdx2: f32 = ddx - 2.0 * (ddx * nnx + ddy * nny + ddz * nnz) * nnx;
        const rdy2: f32 = ddy - 2.0 * (ddx * nnx + ddy * nny + ddz * nnz) * nny;
        const rdz2: f32 = ddz - 2.0 * (ddx * nnx + ddy * nny + ddz * nnz) * nnz;
        let tRef: f32 = 0.02;
        let refLastD: f32 = 0.0;
        for (let s: i32 = 0; s < 40; s++) {
          refLastD = sceneSDF(hx + rdx2 * tRef, hy + rdy2 * tRef, hz + rdz2 * tRef, time);
          if (refLastD < SURF_DIST) break;
          if (tRef > MAX_DIST) break;
          tRef += refLastD;
        }
        let refR: f32 = 0.0; let refG: f32 = 0.0; let refB: f32 = 0.0;
        if (refLastD < SURF_DIST) {
          const rx: f32 = hx + rdx2 * tRef; const ry: f32 = hy + rdy2 * tRef; const rz: f32 = hz + rdz2 * tRef;
          let rnx: f32 = sceneSDF(rx + e, ry, rz, time) - sceneSDF(rx - e, ry, rz, time);
          let rny: f32 = sceneSDF(rx, ry + e, rz, time) - sceneSDF(rx, ry - e, rz, time);
          let rnz: f32 = sceneSDF(rx, ry, rz + e, time) - sceneSDF(rx, ry, rz - e, time);
          const rnLen: f32 = Mathf.sqrt(rnx * rnx + rny * rny + rnz * rnz);
          rnx /= rnLen; rny /= rnLen; rnz /= rnLen;
          const rdiff: f32 = clampF(rnx * lx + rny * ly + rnz * lz, 0.0, 1.0);
          const rshadow: f32 = softShadow(rx + rnx * 0.02, ry + rny * 0.02, rz + rnz * 0.02, lx, ly, lz, 0.02, 5.0, time);
          const caRT: f32 = cosF(time * 0.7); const saRT: f32 = sinF(time * 0.7);
          const rtrpx: f32 = rx - 2.2; const rtrpy: f32 = ry - 0.3;
          const isTorusR: boolean = sdTorus(rtrpx * caRT - rtrpy * saRT, rtrpx * saRT + rtrpy * caRT, rz, 0.6, 0.2) < 0.05;
          const cbR: f32 = cosF(time * 0.5); const sbR: f32 = sinF(time * 0.5);
          const bpxR: f32 = rx + 2.0;
          const d3HitR: f32 = sdBox(bpxR * cbR - rz * sbR, ry, bpxR * sbR + rz * cbR, 0.5, 0.5, 0.5) - 0.08;
          // Torus point light at reflected hit point
          const rtldx: f32 = 2.2 - rx; const rtldy: f32 = 0.3 - ry; const rtldz: f32 = -rz;
          const rtlDist: f32 = Mathf.sqrt(rtldx * rtldx + rtldy * rtldy + rtldz * rtldz);
          const rtldxn: f32 = rtldx / rtlDist; const rtldyn: f32 = rtldy / rtlDist; const rtldzn: f32 = rtldz / rtlDist;
          const rtlDiff: f32 = clampF(rnx * rtldxn + rny * rtldyn + rnz * rtldzn, 0.0, 1.0);
          const rtlShadow: f32 = softShadow(rx + rnx * 0.02, ry + rny * 0.02, rz + rnz * 0.02, rtldxn, rtldyn, rtldzn, 0.02, rtlDist, time);
          const rtlAtten: f32 = 1.0 / (1.0 + rtlDist * rtlDist * 0.12);
          const rTorusLight: f32 = rtlDiff * rtlShadow * rtlAtten * 1.8;
          if (isTorusR) {
            refR = 2.0; refG = 1.0; refB = 0.2; // emissive in reflection
          } else {
            let refMatR: f32; let refMatG: f32; let refMatB: f32;
            if (ry + 1.0 < 0.01) {
              const ck: f32 = (((<i32>Mathf.floor(rx) + <i32>Mathf.floor(rz)) & 1) == 0) ? 0.4 : 0.6;
              refMatR = ck; refMatG = ck; refMatB = ck;
            } else if (d3HitR < 0.05) {
              const rhue: f32 = ry * 4.0 + rz * 2.5 + rx * 1.5 + time * 1.5;
              refMatR = 0.5 + 0.5 * sinF(rhue);
              refMatG = 0.5 + 0.5 * sinF(rhue + 2.09440);
              refMatB = 0.5 + 0.5 * sinF(rhue + 4.18879);
            } else { refMatR = 0.8; refMatG = 0.35; refMatB = 0.25; }
            const rlight: f32 = 0.15 + rdiff * rshadow * 0.7;
            refR = refMatR * (rlight + rTorusLight * 1.0);
            refG = refMatG * (rlight + rTorusLight * 0.6);
            refB = refMatB * (rlight + rTorusLight * 0.1);
          }
        } else {
          const rSkyT: f32 = clampF(rdy2 * 0.5 + 0.5, 0.0, 1.0);
          refR = 0.3 + 0.4 * rSkyT; refG = 0.4 + 0.3 * rSkyT; refB = 0.6 + 0.4 * rSkyT;
        }
        r = r * 0.3 + refR * 0.7;
        g = g * 0.3 + refG * 0.7;
        b = b * 0.3 + refB * 0.7;
      }

      const fog: f32 = 1.0 - expF(-t * t * 0.003);
      r = r * (1.0 - fog) + 0.4 * fog; g = g * (1.0 - fog) + 0.5 * fog; b = b * (1.0 - fog) + 0.7 * fog;
    } else {
      const skyT: f32 = clampF(ddy * 0.5 + 0.5, 0.0, 1.0);
      r = 0.3 + 0.4 * skyT; g = 0.4 + 0.3 * skyT; b = 0.6 + 0.4 * skyT;
    }
    r = Mathf.sqrt(r); g = Mathf.sqrt(g); b = Mathf.sqrt(b);
    const off: i32 = 16 + i * 12;
    store<i32>(off, <i32>(clampF(r, 0.0, 1.0) * 255.0));
    store<i32>(off + 4, <i32>(clampF(g, 0.0, 1.0) * 255.0));
    store<i32>(off + 8, <i32>(clampF(b, 0.0, 1.0) * 255.0));
  }
}
