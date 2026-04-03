// Flagship: Photorealistic Volumetric Clouds with Ocean Reflection
// 48 cloud steps (sky), 32 steps (reflection), 6-octave FBM,
// Henyey-Greenstein phase, Fresnel water, animated waves, ACES tonemapping
const WIDTH: i32 = 256;
const HEIGHT: i32 = 256;
const TIME_OFFSET: i32 = 0;
const PI: f32 = 3.14159265;
const TWO_PI: f32 = 6.28318530;
const CAM_HEIGHT: f32 = 0.35;

// --- Math utilities -----------------------------------------------------------

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
  const x: f32 = e * lnb;
  return expF(x);
}

function clampF(v: f32, lo: f32, hi: f32): f32 { return Mathf.min(Mathf.max(v, lo), hi); }
function mixF(a: f32, b: f32, t: f32): f32 { return a * (1.0 - t) + b * t; }
function smoothstep(e0: f32, e1: f32, x: f32): f32 {
  const t: f32 = clampF((x - e0) / (e1 - e0), 0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}
function saturate(x: f32): f32 { return clampF(x, 0.0, 1.0); }

// --- Henyey-Greenstein phase function -----------------------------------------
function hgPhase(cosTheta: f32, g: f32): f32 {
  const g2: f32 = g * g;
  const denom: f32 = 1.0 + g2 - 2.0 * g * cosTheta;
  return (1.0 - g2) / (4.0 * PI * powF(denom, 1.5));
}

function cloudPhase(cosTheta: f32): f32 {
  const forward: f32 = hgPhase(cosTheta, 0.6);
  const back: f32 = hgPhase(cosTheta, -0.25);
  const silver: f32 = hgPhase(cosTheta, 0.94);
  return mixF(forward, back, 0.2) + silver * 0.12;
}

// --- Noise -------------------------------------------------------------------

function hash(x: f32, y: f32): f32 {
  let n: f32 = sinF(x * 127.1 + y * 311.7) * 43758.5453;
  return n - Mathf.floor(n);
}

function noise(x: f32, y: f32): f32 {
  const ix: f32 = Mathf.floor(x); const iy: f32 = Mathf.floor(y);
  const fx: f32 = x - ix; const fy: f32 = y - iy;
  const ux: f32 = fx * fx * fx * (fx * (fx * 6.0 - 15.0) + 10.0);
  const uy: f32 = fy * fy * fy * (fy * (fy * 6.0 - 15.0) + 10.0);
  const a: f32 = hash(ix, iy);
  const b: f32 = hash(ix + 1.0, iy);
  const c: f32 = hash(ix, iy + 1.0);
  const d: f32 = hash(ix + 1.0, iy + 1.0);
  return mixF(mixF(a, b, ux), mixF(c, d, ux), uy);
}

function fbm(x: f32, y: f32): f32 {
  let v: f32 = 0.0; let a: f32 = 0.5;
  let px: f32 = x; let py: f32 = y;
  for (let i: i32 = 0; i < 6; i++) {
    v += a * noise(px, py);
    const rx: f32 = px * 0.8 - py * 0.6;
    const ry: f32 = px * 0.6 + py * 0.8;
    px = rx * 2.0 + 1.7;
    py = ry * 2.0 + 9.2;
    a *= 0.5;
  }
  return v;
}

function fbmLight(x: f32, y: f32): f32 {
  let v: f32 = 0.0; let a: f32 = 0.5;
  let px: f32 = x; let py: f32 = y;
  for (let i: i32 = 0; i < 3; i++) {
    v += a * noise(px, py);
    const rx: f32 = px * 0.8 - py * 0.6;
    const ry: f32 = px * 0.6 + py * 0.8;
    px = rx * 2.0 + 1.7;
    py = ry * 2.0 + 9.2;
    a *= 0.5;
  }
  return v;
}

function acesTonemap(x: f32): f32 {
  const a: f32 = x * (x * 2.51 + 0.03);
  const b: f32 = x * (x * 2.43 + 0.59) + 0.14;
  return clampF(a / b, 0.0, 1.0);
}

// --- Shared rendering state (set by main before renderSky calls) -------------
let gSlx: f32 = 0.0; let gSly: f32 = 0.0; let gSlz: f32 = 0.0;
let gSunR: f32 = 0.0; let gSunG: f32 = 0.0; let gSunB: f32 = 0.0;
let gSunWarm: f32 = 0.0;
let gAmbR: f32 = 0.0; let gAmbG: f32 = 0.0; let gAmbB: f32 = 0.0;
let gWindX: f32 = 0.0; let gWindZ: f32 = 0.0;
// Render output (HDR, pre-tonemap)
let outR: f32 = 0.0; let outG: f32 = 0.0; let outB: f32 = 0.0;

// --- Render sky + volumetric clouds for a ray direction ----------------------
function renderSky(dx: f32, dy: f32, dz: f32, steps: i32): void {
  const skyH: f32 = saturate(dy * 2.5 + 0.15);
  let skyR: f32 = mixF(0.55 + gSunWarm * 0.2, 0.10, skyH);
  let skyG: f32 = mixF(0.50 + gSunWarm * 0.08, 0.22, skyH);
  let skyB: f32 = mixF(0.62, 0.55, skyH);
  const horizonBlend: f32 = expF(-dy * 7.0);
  skyR += horizonBlend * gSunR * 0.04;
  skyG += horizonBlend * gSunG * 0.025;
  skyB += horizonBlend * gSunB * 0.012;
  const sunDot: f32 = saturate(dx * gSlx + dy * gSly + dz * gSlz);
  skyR += powF(sunDot, 200.0) * 6.0 * gSunR * 0.35 + powF(sunDot, 32.0) * gSunR * 0.10 + powF(sunDot, 5.0) * 0.2 * gSunR * 0.05;
  skyG += powF(sunDot, 200.0) * 6.0 * gSunG * 0.35 + powF(sunDot, 32.0) * gSunG * 0.08 + powF(sunDot, 5.0) * 0.2 * gSunG * 0.035;
  skyB += powF(sunDot, 200.0) * 6.0 * gSunB * 0.35 + powF(sunDot, 32.0) * gSunB * 0.05 + powF(sunDot, 5.0) * 0.2 * gSunB * 0.02;

  let cloudR: f32 = 0.0; let cloudG: f32 = 0.0; let cloudB: f32 = 0.0;
  let transmittance: f32 = 1.0;
  if (dy > 0.001) {
    const cloudBase: f32 = 1.8; const cloudTop: f32 = 5.0;
    const tEnter: f32 = cloudBase / dy;
    const tExit: f32 = cloudTop / dy;
    const stepSize: f32 = (tExit - tEnter) / <f32>steps;
    const cosTheta: f32 = dx * gSlx + dy * gSly + dz * gSlz;
    const phase: f32 = cloudPhase(cosTheta);
    for (let s: i32 = 0; s < steps; s++) {
      if (transmittance < 0.01) break;
      const ct: f32 = tEnter + (<f32>s + 0.5) * stepSize;
      const cpx: f32 = dx * ct; const cpy: f32 = dy * ct; const cpz: f32 = dz * ct;
      const nx: f32 = cpx * 0.35 + gWindX; const nz: f32 = cpz * 0.35 + gWindZ;
      const warp: f32 = fbmLight(nx * 0.5, nz * 0.5) * 2.2;
      let density: f32 = fbm(nx + warp, nz + warp * 0.7);
      const hNorm: f32 = saturate((cpy - cloudBase) / (cloudTop - cloudBase));
      density = clampF(density * smoothstep(0.0, 0.12, hNorm) * smoothstep(1.0, 0.55, hNorm)
        * (1.0 + 0.25 * smoothstep(0.15, 0.4, hNorm) * smoothstep(0.65, 0.4, hNorm)) - 0.22, 0.0, 1.0) * 2.5;
      if (density > 0.001) {
        const sigmaT: f32 = density * 0.55;
        const stepT: f32 = expF(-sigmaT * stepSize);
        const lsOff: f32 = 1.5;
        const lx: f32 = (cpx + gSlx * lsOff) * 0.35 + gWindX;
        const lz: f32 = (cpz + gSlz * lsOff) * 0.35 + gWindZ;
        const lwarp: f32 = fbmLight(lx * 0.5, lz * 0.5) * 2.2;
        const lightDen: f32 = fbm(lx + lwarp, lz + lwarp * 0.7);
        const ly: f32 = cpy + gSly * lsOff;
        const lhNorm: f32 = saturate((ly - cloudBase) / (cloudTop - cloudBase));
        const lDen: f32 = clampF(lightDen * smoothstep(0.0, 0.12, lhNorm) * smoothstep(1.0, 0.55, lhNorm) - 0.22, 0.0, 1.0) * 2.5;
        const lightOD: f32 = lDen * lsOff * 0.55;
        const totalLit: f32 = expF(-lightOD * 2.5) + expF(-lightOD * 0.6) * 0.35;
        const ambStr: f32 = mixF(0.35, 1.0, hNorm) * 0.55;
        const bounce: f32 = (1.0 - hNorm) * 0.07;
        const cr: f32 = gSunR * totalLit * phase + gAmbR * ambStr + 0.4 * bounce;
        const cg: f32 = gSunG * totalLit * phase + gAmbG * ambStr + 0.35 * bounce;
        const cb: f32 = gSunB * totalLit * phase + gAmbB * ambStr + 0.2 * bounce;
        const weight: f32 = transmittance * (1.0 - stepT);
        cloudR += cr * weight; cloudG += cg * weight; cloudB += cb * weight;
        transmittance *= stepT;
      }
    }
  }
  outR = skyR * transmittance + cloudR;
  outG = skyG * transmittance + cloudG;
  outB = skyB * transmittance + cloudB;
  // Aerial perspective
  const rayDist: f32 = (dy > 0.001) ? (3.5 / dy) : 500.0;
  const aerial: f32 = 1.0 - expF(-rayDist * 0.003);
  outR = mixF(outR, mixF(skyR, gSunR * 0.12 + 0.35, 0.3), aerial * 0.35);
  outG = mixF(outG, mixF(skyG, gSunG * 0.10 + 0.32, 0.3), aerial * 0.35);
  outB = mixF(outB, mixF(skyB, gSunB * 0.06 + 0.40, 0.3), aerial * 0.35);
}

// --- Water normal via analytic wave derivatives + noise micro-ripple ---------
let wNx: f32 = 0.0; let wNy: f32 = 1.0; let wNz: f32 = 0.0;

function waterNormal(wx: f32, wz: f32, t: f32, fade: f32): void {
  // Scale up for visible wave density
  const sx: f32 = wx * 4.0; const sz: f32 = wz * 4.0;
  let ddx: f32 = 0.0; let ddz: f32 = 0.0;
  // Wave 1: large swell
  let ph: f32 = (sx * 0.70 + sz * 0.71) * 2.0 + t * 1.2;
  let c: f32 = cosF(ph);
  ddx += 0.020 * c * 0.70 * 2.0;
  ddz += 0.020 * c * 0.71 * 2.0;
  // Wave 2: cross swell
  ph = (sx * -0.50 + sz * 0.87) * 3.5 + t * 1.8;
  c = cosF(ph);
  ddx += 0.012 * c * -0.50 * 3.5;
  ddz += 0.012 * c * 0.87 * 3.5;
  // Wave 3: chop
  ph = (sx * 0.95 + sz * -0.31) * 6.0 + t * 2.5;
  c = cosF(ph);
  ddx += 0.006 * c * 0.95 * 6.0;
  ddz += 0.006 * c * -0.31 * 6.0;
  // Wave 4: fine ripple
  ph = (sx * -0.31 + sz * -0.95) * 10.0 + t * 3.5;
  c = cosF(ph);
  ddx += 0.003 * c * -0.31 * 10.0;
  ddz += 0.003 * c * -0.95 * 10.0;
  // Noise micro-ripple via central differences
  const ns: f32 = 0.003 * fade;
  const eps: f32 = 0.05;
  const n0: f32 = noise(sx * 2.0 + t * 0.4, sz * 2.0 + t * 0.3);
  ddx += (noise((sx + eps) * 2.0 + t * 0.4, sz * 2.0 + t * 0.3) - n0) / eps * ns;
  ddz += (noise(sx * 2.0 + t * 0.4, (sz + eps) * 2.0 + t * 0.3) - n0) / eps * ns;
  // Apply distance fade
  ddx *= fade; ddz *= fade;
  // Normal = normalize(-ddx, 1, -ddz)
  const len: f32 = Mathf.sqrt(ddx * ddx + 1.0 + ddz * ddz);
  wNx = -ddx / len; wNy = 1.0 / len; wNz = -ddz / len;
}

// =============================================================================

export function main(): void {
  const frame: i32 = <i32>load<f32>(TIME_OFFSET);
  const time: f32 = <f32>frame * 0.012;

  // Sun direction (slowly orbiting)
  const sunAngle: f32 = time * 0.12;
  const sunElev: f32 = 0.3 + sinF(time * 0.06) * 0.12;
  const sdx: f32 = cosF(sunAngle) * 0.45;
  const sdy: f32 = sunElev;
  const sdz: f32 = sinF(sunAngle) * 0.45;
  const sLen: f32 = Mathf.sqrt(sdx * sdx + sdy * sdy + sdz * sdz);
  gSlx = sdx / sLen; gSly = sdy / sLen; gSlz = sdz / sLen;
  gSunWarm = 1.0 - smoothstep(0.15, 0.55, gSly);
  gSunR = mixF(1.0, 1.3, gSunWarm) * 3.0;
  gSunG = mixF(0.95, 0.65, gSunWarm) * 3.0;
  gSunB = mixF(0.9, 0.3, gSunWarm) * 3.0;
  gAmbR = 0.14; gAmbG = 0.20; gAmbB = 0.38;
  gWindX = time * 0.25; gWindZ = time * 0.08;

  const invW: f32 = 1.0 / <f32>WIDTH;
  const invH: f32 = 1.0 / <f32>HEIGHT;

  for (let i: i32 = 0; i < WIDTH * HEIGHT; i++) {
    const px: i32 = i % WIDTH;
    const py: i32 = i / WIDTH;
    const uvx: f32 = 2.0 * <f32>px * invW - 1.0;
    const uvy: f32 = -(2.0 * <f32>py * invH - 1.0);

    // Camera ray (horizon near screen centre)
    const rdx: f32 = uvx * 1.2;
    const rdy: f32 = uvy * 0.55 + 0.02;
    const rdz: f32 = 1.0;
    const rdLen: f32 = Mathf.sqrt(rdx * rdx + rdy * rdy + rdz * rdz);
    const dx: f32 = rdx / rdLen;
    const dy: f32 = rdy / rdLen;
    const dz: f32 = rdz / rdLen;

    let r: f32 = 0.0; let g: f32 = 0.0; let b: f32 = 0.0;

    if (dy > 0.0) {
      // --- SKY ---
      renderSky(dx, dy, dz, 48);
      r = outR; g = outG; b = outB;
    } else {
      // --- WATER ---
      // Intersect water plane at y = 0 (camera at y = CAM_HEIGHT)
      const waterT: f32 = CAM_HEIGHT / (-dy + 0.0005);
      const wx: f32 = dx * waterT;
      const wz: f32 = dz * waterT;

      // Distance fade for waves (distant water → smooth)
      const distFade: f32 = expF(-waterT * 0.012);

      // Compute wave normal
      waterNormal(wx, wz, time, distFade);

      // Reflect camera ray off water surface
      const dotDN: f32 = dx * wNx + dy * wNy + dz * wNz;
      let rx: f32 = dx - 2.0 * dotDN * wNx;
      let ry: f32 = dy - 2.0 * dotDN * wNy;
      let rz: f32 = dz - 2.0 * dotDN * wNz;
      // Ensure reflected ray points upward
      if (ry < 0.002) { ry = 0.002; }
      const rLen: f32 = Mathf.sqrt(rx * rx + ry * ry + rz * rz);
      rx = rx / rLen; ry = ry / rLen; rz = rz / rLen;

      // Render reflected sky + clouds (fewer steps for perf)
      renderSky(rx, ry, rz, 32);
      const refR: f32 = outR; const refG: f32 = outG; const refB: f32 = outB;

      // Fresnel (Schlick, F0 ≈ 0.02 for water)
      const cosI: f32 = saturate(-(dx * wNx + dy * wNy + dz * wNz));
      const oneMinusC: f32 = 1.0 - cosI;
      const omc2: f32 = oneMinusC * oneMinusC;
      const fresnel: f32 = 0.02 + 0.98 * omc2 * omc2 * oneMinusC;

      // Deep water colour (dark blue-green)
      const deepR: f32 = 0.005; const deepG: f32 = 0.03; const deepB: f32 = 0.05;

      // Blend reflection with deep water
      r = mixF(deepR, refR, fresnel);
      g = mixF(deepG, refG, fresnel);
      b = mixF(deepB, refB, fresnel);

      // Sun specular glint on water (Blinn-Phong)
      const hx: f32 = -dx + gSlx; const hy: f32 = -dy + gSly; const hz: f32 = -dz + gSlz;
      const hLen: f32 = Mathf.sqrt(hx * hx + hy * hy + hz * hz);
      const ndh: f32 = saturate((wNx * hx + wNy * hy + wNz * hz) / hLen);
      const spec: f32 = powF(ndh, 350.0) * 6.0 * distFade;
      r += gSunR * spec * 0.12;
      g += gSunG * spec * 0.12;
      b += gSunB * spec * 0.12;

      // Broad sun road on water (lower power, wider)
      const sunRoad: f32 = powF(ndh, 16.0) * 0.15 * distFade;
      r += gSunR * sunRoad * 0.05;
      g += gSunG * sunRoad * 0.04;
      b += gSunB * sunRoad * 0.025;

      // Distance haze on water (far water → horizon colour)
      const waterHaze: f32 = 1.0 - expF(-waterT * 0.008);
      const hzR: f32 = 0.45 + gSunWarm * 0.15;
      const hzG: f32 = 0.48 + gSunWarm * 0.06;
      const hzB: f32 = 0.55;
      r = mixF(r, hzR, waterHaze);
      g = mixF(g, hzG, waterHaze);
      b = mixF(b, hzB, waterHaze);
    }

    // Exposure + ACES tonemap + sRGB gamma
    r *= 0.65; g *= 0.65; b *= 0.65;
    r = acesTonemap(r); g = acesTonemap(g); b = acesTonemap(b);
    r = powF(clampF(r, 0.0, 1.0), 0.4545);
    g = powF(clampF(g, 0.0, 1.0), 0.4545);
    b = powF(clampF(b, 0.0, 1.0), 0.4545);

    const off: i32 = 16 + i * 12;
    store<i32>(off, <i32>(r * 255.0));
    store<i32>(off + 4, <i32>(g * 255.0));
    store<i32>(off + 8, <i32>(b * 255.0));
  }
}
