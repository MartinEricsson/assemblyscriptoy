// ============================================================
// Procedural Planet - displaced terrain and volumetric weather
// ============================================================
// Heavy single-dispatch planet renderer. The ray marches a thin
// displaced surface shell, reconstructs terrain normals from
// procedural height samples, and integrates a soft cloud volume in
// front of the surface.
// ============================================================

@external("gasm", "sin_f32")
declare function gasmSin(value: f32): f32;
@external("gasm", "cos_f32")
declare function gasmCos(value: f32): f32;
@external("gasm", "pow_f32")
declare function gasmPow(base: f32, exponent: f32): f32;

const WIDTH: i32 = 256;
const PI: f32 = 3.14159265;
const BASE_RADIUS: f32 = 0.825;
const OUTER_RADIUS: f32 = 0.975;
const CLOUD_INNER: f32 = 0.875;
const CLOUD_OUTER: f32 = 1.105;

function clampF(value: f32, low: f32, high: f32): f32 {
  return Mathf.min(Mathf.max(value, low), high);
}

function saturate(value: f32): f32 {
  return clampF(value, 0.0, 1.0);
}

function mixF(a: f32, b: f32, amount: f32): f32 {
  return a + (b - a) * amount;
}

function smoothstep(edge0: f32, edge1: f32, x: f32): f32 {
  const t: f32 = saturate((x - edge0) / (edge1 - edge0));
  return t * t * (3.0 - 2.0 * t);
}

function fract(value: f32): f32 {
  return value - Mathf.floor(value);
}

function hash2(x: i32, y: i32): i32 {
  let value: i32 = x * 374761393 + y * 668265263;
  value = (value ^ (value >> 13)) * 1274126177;
  return value ^ (value >> 16);
}

function hash3(x: i32, y: i32, z: i32): i32 {
  let value: i32 = x * 1597334677 + y * 3812015801 + z * 2798796415;
  value = (value ^ (value >> 15)) * 2246822519;
  value = (value ^ (value >> 13)) * 3266489917;
  return value ^ (value >> 16);
}

function rand3(x: i32, y: i32, z: i32): f32 {
  return <f32>(hash3(x, y, z) & 65535) / 65535.0;
}

function valueNoise3(x: f32, y: f32, z: f32): f32 {
  const ix: i32 = <i32>Mathf.floor(x);
  const iy: i32 = <i32>Mathf.floor(y);
  const iz: i32 = <i32>Mathf.floor(z);
  const fx: f32 = fract(x);
  const fy: f32 = fract(y);
  const fz: f32 = fract(z);
  const ux: f32 = fx * fx * (3.0 - 2.0 * fx);
  const uy: f32 = fy * fy * (3.0 - 2.0 * fy);
  const uz: f32 = fz * fz * (3.0 - 2.0 * fz);

  const n000: f32 = rand3(ix, iy, iz);
  const n100: f32 = rand3(ix + 1, iy, iz);
  const n010: f32 = rand3(ix, iy + 1, iz);
  const n110: f32 = rand3(ix + 1, iy + 1, iz);
  const n001: f32 = rand3(ix, iy, iz + 1);
  const n101: f32 = rand3(ix + 1, iy, iz + 1);
  const n011: f32 = rand3(ix, iy + 1, iz + 1);
  const n111: f32 = rand3(ix + 1, iy + 1, iz + 1);

  const x00: f32 = mixF(n000, n100, ux);
  const x10: f32 = mixF(n010, n110, ux);
  const x01: f32 = mixF(n001, n101, ux);
  const x11: f32 = mixF(n011, n111, ux);
  const y0: f32 = mixF(x00, x10, uy);
  const y1: f32 = mixF(x01, x11, uy);
  return mixF(y0, y1, uz);
}

function ridged(value: f32): f32 {
  const r: f32 = 1.0 - Mathf.abs(value * 2.0 - 1.0);
  return r * r;
}

function terrainHeightFromDir(nx: f32, ny: f32, nz: f32, time: f32): f32 {
  const cx: f32 = gasmCos(time * 0.31);
  const sx: f32 = gasmSin(time * 0.31);
  const rx: f32 = nx * cx - nz * sx;
  const rz: f32 = nx * sx + nz * cx;
  const warp: f32 = valueNoise3(rx * 2.2 + 8.0, ny * 2.2 - 1.7, rz * 2.2 + 3.1) - 0.5;

  let height: f32 = -0.16;
  height += valueNoise3(rx * 1.3 + warp * 1.4, ny * 1.3, rz * 1.3) * 0.58;
  height += valueNoise3(rx * 3.0 - 3.0, ny * 3.0 + warp, rz * 3.0 + 1.5) * 0.30;
  height += valueNoise3(rx * 7.2 + 11.0, ny * 7.2 - 6.0, rz * 7.2 + warp * 3.0) * 0.17;

  const mountainA: f32 = ridged(valueNoise3(rx * 10.0 + warp * 2.0, ny * 10.0, rz * 10.0 - 4.0));
  const mountainB: f32 = ridged(valueNoise3(rx * 22.0 - 2.5, ny * 22.0 + warp * 6.0, rz * 22.0 + 6.0));
  const continent: f32 = smoothstep(0.34, 0.63, height);
  height += mountainA * continent * 0.23;
  height += mountainB * continent * 0.08;
  height -= smoothstep(0.72, 0.95, Mathf.abs(ny)) * 0.08;
  return height;
}

function surfaceRadius(nx: f32, ny: f32, nz: f32, time: f32): f32 {
  const height: f32 = terrainHeightFromDir(nx, ny, nz, time);
  const land: f32 = smoothstep(0.42, 0.56, height);
  const oceanFloor: f32 = clampF(height + 0.25, 0.0, 1.0);
  return BASE_RADIUS + land * (height - 0.49) * 0.150 - (1.0 - land) * (1.0 - oceanFloor) * 0.024;
}

function sphereNear(originZ: f32, rayX: f32, rayY: f32, rayZ: f32, radius: f32): f32 {
  const bTerm: f32 = originZ * rayZ;
  const cTerm: f32 = originZ * originZ - radius * radius;
  const d: f32 = bTerm * bTerm - cTerm;
  if (d < 0.0) {
    return -1.0;
  }
  return -bTerm - Mathf.sqrt(d);
}

function sphereFar(originZ: f32, rayX: f32, rayY: f32, rayZ: f32, radius: f32): f32 {
  const bTerm: f32 = originZ * rayZ;
  const cTerm: f32 = originZ * originZ - radius * radius;
  const d: f32 = bTerm * bTerm - cTerm;
  if (d < 0.0) {
    return -1.0;
  }
  return -bTerm + Mathf.sqrt(d);
}

function cloudDensity(px: f32, py: f32, pz: f32, radius: f32, time: f32): f32 {
  const nx: f32 = px / radius;
  const ny: f32 = py / radius;
  const nz: f32 = pz / radius;
  const altitude: f32 = saturate((radius - CLOUD_INNER) / (CLOUD_OUTER - CLOUD_INNER));
  const shell: f32 = smoothstep(0.00, 0.46, altitude) * (1.0 - smoothstep(0.58, 1.0, altitude));
  const windA: f32 = time * 0.55;
  const windB: f32 = time * 1.15;
  const qx: f32 = px + nx * 0.42;
  const qy: f32 = py + ny * 0.18;
  const qz: f32 = pz + nz * 0.42;

  const band: f32 =
    gasmSin(ny * 18.0 + gasmSin(nx * 9.0 + windA) * 1.6)
    + gasmSin(ny * 31.0 - nz * 8.0 + windB) * 0.42;
  const storm: f32 = valueNoise3(qx * 4.3 + windA, qy * 4.3 + 2.0, qz * 4.3 - windA);
  const towers: f32 = valueNoise3(qx * 11.5 - 4.0, qy * 11.5 + windB, qz * 11.5 + 7.0);
  const wisps: f32 = valueNoise3(qx * 27.0 + windB, qy * 27.0 - 11.0, qz * 27.0 + windA);
  const erosion: f32 = valueNoise3(qx * 54.0 - windB * 2.0, qy * 54.0 + 19.0, qz * 54.0 + windA * 2.0);
  let density: f32 = storm * 0.78 + towers * 0.32 + wisps * 0.18 + band * 0.07 - erosion * 0.17 - 0.50;
  density = smoothstep(0.02, 0.38, density);
  density *= 0.78 + wisps * 0.46;
  density *= shell;
  density *= smoothstep(0.96, 0.18, Mathf.abs(ny));
  return density;
}

export function main(): void {
  const time: f32 = load<f32>(0) * 0.008;
  const sunX0: f32 = -0.56;
  const sunY0: f32 = 0.50;
  const sunZ0: f32 = -0.66;
  const sunLen: f32 = Mathf.sqrt(sunX0 * sunX0 + sunY0 * sunY0 + sunZ0 * sunZ0);
  const sunX: f32 = sunX0 / sunLen;
  const sunY: f32 = sunY0 / sunLen;
  const sunZ: f32 = sunZ0 / sunLen;
  const originZ: f32 = 2.75;

  for (let i: i32 = 0; i < WIDTH * WIDTH; i++) {
    const x: i32 = i & 255;
    const y: i32 = i >> 8;
    const u: f32 = (<f32>x - 127.5) / 128.0;
    const v: f32 = (127.5 - <f32>y) / 128.0;
    const rayX0: f32 = u * 0.88;
    const rayY0: f32 = v * 0.88;
    const rayZ0: f32 = -2.05;
    const rayLength: f32 = Mathf.sqrt(rayX0 * rayX0 + rayY0 * rayY0 + rayZ0 * rayZ0);
    const rayX: f32 = rayX0 / rayLength;
    const rayY: f32 = rayY0 / rayLength;
    const rayZ: f32 = rayZ0 / rayLength;

    let surfaceT: f32 = 9999.0;
    let hitX: f32 = 0.0;
    let hitY: f32 = 0.0;
    let hitZ: f32 = 0.0;
    let geoNX: f32 = 0.0;
    let geoNY: f32 = 0.0;
    let geoNZ: f32 = 1.0;
    let didHit: bool = false;

    const enterOuter: f32 = sphereNear(originZ, rayX, rayY, rayZ, OUTER_RADIUS);
    const exitOuter: f32 = sphereFar(originZ, rayX, rayY, rayZ, OUTER_RADIUS);
    if (enterOuter > 0.0) {
      let t: f32 = enterOuter;
      for (let step: i32 = 0; step < 36; step++) {
        if (!didHit && t < exitOuter) {
          const px: f32 = rayX * t;
          const py: f32 = rayY * t;
          const pz: f32 = originZ + rayZ * t;
          const lenP: f32 = Mathf.sqrt(px * px + py * py + pz * pz);
          const nx: f32 = px / lenP;
          const ny: f32 = py / lenP;
          const nz: f32 = pz / lenP;
          const r: f32 = surfaceRadius(nx, ny, nz, time);
          const distance: f32 = lenP - r;
          if (distance < 0.0018) {
            didHit = true;
            surfaceT = t;
            hitX = px;
            hitY = py;
            hitZ = pz;
            geoNX = nx;
            geoNY = ny;
            geoNZ = nz;
          }
          t += Mathf.max(distance * 0.58, 0.0025);
        }
      }
    }

    let r: f32;
    let g: f32;
    let b: f32;

    const enterCloud: f32 = sphereNear(originZ, rayX, rayY, rayZ, CLOUD_OUTER);
    const exitCloud: f32 = sphereFar(originZ, rayX, rayY, rayZ, CLOUD_OUTER);
    let cloudR: f32 = 0.0;
    let cloudG: f32 = 0.0;
    let cloudB: f32 = 0.0;
    let cloudAlpha: f32 = 0.0;

    if (enterCloud > 0.0) {
      const marchEnd: f32 = didHit ? Mathf.min(surfaceT, exitCloud) : exitCloud;
      const segment: f32 = Mathf.max(0.0, marchEnd - enterCloud);
      const stepSize: f32 = segment / 52.0;
      const jitter: f32 = <f32>(hash2(x * 19 + y * 7, y * 23 - x * 5) & 1023) / 1023.0;
      let tCloud: f32 = enterCloud + stepSize * (0.18 + jitter * 0.64);
      for (let cStep: i32 = 0; cStep < 52; cStep++) {
        if (cloudAlpha < 0.985 && tCloud < marchEnd) {
          const cxp: f32 = rayX * tCloud;
          const cyp: f32 = rayY * tCloud;
          const czp: f32 = originZ + rayZ * tCloud;
          const cLen: f32 = Mathf.sqrt(cxp * cxp + cyp * cyp + czp * czp);
          if (cLen > CLOUD_INNER && cLen < CLOUD_OUTER) {
            const cnx: f32 = cxp / cLen;
            const cny: f32 = cyp / cLen;
            const cnz: f32 = czp / cLen;
            const density: f32 = cloudDensity(cxp, cyp, czp, cLen, time);
            if (density > 0.001) {
              let lightOD: f32 = 0.0;
              for (let lStep: i32 = 1; lStep <= 7; lStep++) {
                const lt: f32 = <f32>lStep * 0.024;
                const lpx: f32 = cxp + sunX * lt;
                const lpy: f32 = cyp + sunY * lt;
                const lpz: f32 = czp + sunZ * lt;
                const llen: f32 = Mathf.sqrt(lpx * lpx + lpy * lpy + lpz * lpz);
                if (llen > CLOUD_INNER && llen < CLOUD_OUTER) {
                  lightOD += cloudDensity(lpx, lpy, lpz, llen, time);
                }
              }
              const mu: f32 = saturate(cnx * sunX + cny * sunY + cnz * sunZ);
              const silver: f32 = gasmPow(saturate(1.0 - (rayX * sunX + rayY * sunY + rayZ * sunZ)), 3.4);
              const shadow: f32 = 1.0 / (1.0 + lightOD * 1.45);
              const alphaStep: f32 = saturate(density * stepSize * 3.2);
              const transmit: f32 = (1.0 - cloudAlpha) * alphaStep;
              cloudR += transmit * (0.72 + mu * 0.48 + silver * 0.50) * shadow;
              cloudG += transmit * (0.76 + mu * 0.45 + silver * 0.55) * shadow;
              cloudB += transmit * (0.82 + mu * 0.40 + silver * 0.72) * shadow;
              cloudAlpha += transmit;
            }
          }
        }
        tCloud += stepSize;
      }
    }

    if (didHit) {
      const pLen: f32 = Mathf.sqrt(hitX * hitX + hitY * hitY + hitZ * hitZ);
      const nx: f32 = hitX / pLen;
      const ny: f32 = hitY / pLen;
      const nz: f32 = hitZ / pLen;
      const tangentLen: f32 = Mathf.sqrt(nz * nz + nx * nx);
      let tx: f32 = -nz / Mathf.max(tangentLen, 0.0001);
      let ty: f32 = 0.0;
      let tz: f32 = nx / Mathf.max(tangentLen, 0.0001);
      if (tangentLen < 0.04) {
        tx = 1.0;
        tz = 0.0;
      }
      const bx: f32 = ny * tz - nz * ty;
      const by: f32 = nz * tx - nx * tz;
      const bz: f32 = nx * ty - ny * tx;
      const eps: f32 = 0.018;
      const h0: f32 = surfaceRadius(nx, ny, nz, time);
      const hx1: f32 = surfaceRadius(nx + tx * eps, ny + ty * eps, nz + tz * eps, time);
      const hx0: f32 = surfaceRadius(nx - tx * eps, ny - ty * eps, nz - tz * eps, time);
      const hy1: f32 = surfaceRadius(nx + bx * eps, ny + by * eps, nz + bz * eps, time);
      const hy0: f32 = surfaceRadius(nx - bx * eps, ny - by * eps, nz - bz * eps, time);
      const ddx: f32 = (hx1 - hx0) * 28.0;
      const ddy: f32 = (hy1 - hy0) * 28.0;
      let shadeNX: f32 = nx - tx * ddx - bx * ddy;
      let shadeNY: f32 = ny - ty * ddx - by * ddy;
      let shadeNZ: f32 = nz - tz * ddx - bz * ddy;
      const shadeLen: f32 = Mathf.sqrt(shadeNX * shadeNX + shadeNY * shadeNY + shadeNZ * shadeNZ);
      shadeNX /= shadeLen;
      shadeNY /= shadeLen;
      shadeNZ /= shadeLen;

      const spinC: f32 = gasmCos(time * 0.31);
      const spinS: f32 = gasmSin(time * 0.31);
      const rx: f32 = nx * spinC - nz * spinS;
      const rz: f32 = nx * spinS + nz * spinC;
      const rawHeight: f32 = terrainHeightFromDir(nx, ny, nz, time);
      const land: f32 = smoothstep(0.42, 0.56, rawHeight);
      const highland: f32 = smoothstep(BASE_RADIUS + 0.018, BASE_RADIUS + 0.070, h0);
      const beach: f32 = smoothstep(0.42, 0.53, rawHeight) * (1.0 - smoothstep(0.56, 0.61, rawHeight));
      const ice: f32 = smoothstep(0.64, 0.82, Mathf.abs(ny) + highland * 0.25);

      const diffuse: f32 = saturate(shadeNX * sunX + shadeNY * sunY + shadeNZ * sunZ);
      const geoDiffuse: f32 = saturate(geoNX * sunX + geoNY * sunY + geoNZ * sunZ);
      const viewDot: f32 = saturate(-(nx * rayX + ny * rayY + nz * rayZ));
      const rim: f32 = gasmPow(1.0 - viewDot, 2.2);

      const oceanPattern: f32 =
        valueNoise3(rx * 18.0 + time * 0.8, ny * 18.0, rz * 18.0 - time * 0.5) * 0.035
        + gasmSin((rx + rz) * 70.0 + time * 8.0) * 0.010;
      const oceanDepth: f32 = saturate((0.52 - rawHeight) * 3.2);
      let baseR: f32 = mixF(0.010 + oceanDepth * 0.010 + oceanPattern, 0.20 + rawHeight * 0.22, land);
      let baseG: f32 = mixF(0.075 + oceanDepth * 0.060 + oceanPattern, 0.29 + rawHeight * 0.26, land);
      let baseB: f32 = mixF(0.190 + oceanDepth * 0.260 + oceanPattern, 0.095 + rawHeight * 0.06, land);
      baseR = mixF(baseR, 0.74, beach * 0.62);
      baseG = mixF(baseG, 0.61, beach * 0.62);
      baseB = mixF(baseB, 0.37, beach * 0.62);
      baseR = mixF(baseR, 0.54, highland * land * 0.42);
      baseG = mixF(baseG, 0.50, highland * land * 0.42);
      baseB = mixF(baseB, 0.46, highland * land * 0.42);
      baseR = mixF(baseR, 0.86, ice);
      baseG = mixF(baseG, 0.92, ice);
      baseB = mixF(baseB, 0.98, ice);

      const halfX: f32 = sunX - rayX;
      const halfY: f32 = sunY - rayY;
      const halfZ: f32 = sunZ - rayZ;
      const halfLen: f32 = Mathf.sqrt(halfX * halfX + halfY * halfY + halfZ * halfZ);
      const spec: f32 = gasmPow(saturate((shadeNX * halfX + shadeNY * halfY + shadeNZ * halfZ) / halfLen), 88.0) * (1.0 - land) * 1.2;
      const light: f32 = 0.035 + diffuse * 1.05 + geoDiffuse * 0.10;
      r = baseR * light + spec * 0.80;
      g = baseG * light + spec * 0.92;
      b = baseB * light + spec * 1.00;

      r = r * (1.0 - cloudAlpha) + cloudR;
      g = g * (1.0 - cloudAlpha) + cloudG;
      b = b * (1.0 - cloudAlpha) + cloudB;
      r += rim * 0.035;
      g += rim * 0.160;
      b += rim * 0.420;
    } else {
      const closest: f32 = Mathf.sqrt(Mathf.max(0.0, originZ * originZ - (originZ * rayZ) * (originZ * rayZ)));
      const atmosphere: f32 = smoothstep(1.16, 0.82, closest);
      const starSeed: i32 = hash2(x * 3 + 11, y * 5 - 7);
      const starCore: f32 = ((starSeed & 4095) > 4079) ? 0.85 : 0.0;
      const starBloom: f32 = ((hash2((x >> 1) + 101, (y >> 1) - 33) & 4095) > 4088) ? 0.22 : 0.0;
      const nebula: f32 =
        valueNoise3(u * 2.3 + 10.0, v * 2.3 - 4.0, time * 0.08) * 0.7
        + valueNoise3(u * 6.0 - 1.0, v * 6.0 + 8.0, 2.0) * 0.3;
      r = 0.004 + nebula * 0.012 + starCore + starBloom;
      g = 0.006 + nebula * 0.011 + starCore * 0.88 + starBloom * 0.85;
      b = 0.020 + nebula * 0.038 + starCore * 1.05 + starBloom;
      r = r * (1.0 - cloudAlpha) + cloudR;
      g = g * (1.0 - cloudAlpha) + cloudG;
      b = b * (1.0 - cloudAlpha) + cloudB;
      r += atmosphere * 0.030;
      g += atmosphere * 0.170;
      b += atmosphere * 0.520;
    }

    const exposure: f32 = 1.08;
    r = r * exposure / (1.0 + r * exposure);
    g = g * exposure / (1.0 + g * exposure);
    b = b * exposure / (1.0 + b * exposure);
    r = gasmPow(saturate(r), 0.4545);
    g = gasmPow(saturate(g), 0.4545);
    b = gasmPow(saturate(b), 0.4545);

    const offset: i32 = 16 + i * 12;
    store<i32>(offset, <i32>(saturate(r) * 255.0));
    store<i32>(offset + 4, <i32>(saturate(g) * 255.0));
    store<i32>(offset + 8, <i32>(saturate(b) * 255.0));
  }
}
