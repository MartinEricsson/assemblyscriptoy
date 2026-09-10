// ============================================================
//  Compute Triangle Rasterizer - barycentric coverage, z-test
// ============================================================
//  A unit cube (12 triangles) and a ground quad (2 triangles) are
//  filled per pixel: project vertices, test the pixel centre with
//  edge functions, and keep the nearest interpolated camera-space
//  depth. There is no host mesh packer, no BVH, and no framebuffer
//  atomics. Vertices are functions of a corner id; the cube spins
//  about Y while the ground stays put.
//
//  Interpolation is affine (not perspective-correct). Triangles
//  with a vertex behind the near plane are skipped rather than
//  clipped. Lambertian shading uses the face geometric normal.
// ============================================================

const WIDTH: i32 = 256;
const HEIGHT: i32 = 256;
const TIME_OFFSET: i32 = 0;
const OUTPUT_OFFSET: i32 = 16;
const TRI_COUNT: i32 = 14;
const PI: f32 = 3.14159265;
const TWO_PI: f32 = 6.28318530;
const NEAR_Z: f32 = -0.05;
const FOV: f32 = 1.7;
const HALF: f32 = 128.0;
const SKY_R: f32 = 0.55;
const SKY_G: f32 = 0.72;
const SKY_B: f32 = 0.90;

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

function cubeCorner(id: i32, component: i32): f32 {
  if (component == 0) {
    if ((id & 1) != 0) return 0.85;
    return -0.85;
  }
  if (component == 1) {
    if ((id & 2) != 0) return 0.85;
    return -0.85;
  }
  if ((id & 4) != 0) return 0.85;
  return -0.85;
}

function groundCorner(id: i32, component: i32): f32 {
  if (component == 1) return 0.0;
  if (component == 0) {
    if (id == 1) return 3.0;
    if (id == 2) return 3.0;
    return -3.0;
  }
  if (id >= 2) return 3.0;
  return -3.0;
}

function faceIndex(face: i32, corner: i32): i32 {
  if (face == 0) {
    if (corner == 0) return 0;
    if (corner == 1) return 1;
    if (corner == 2) return 3;
    return 2;
  }
  if (face == 1) {
    if (corner == 0) return 5;
    if (corner == 1) return 4;
    if (corner == 2) return 6;
    return 7;
  }
  if (face == 2) {
    if (corner == 0) return 4;
    if (corner == 1) return 0;
    if (corner == 2) return 2;
    return 6;
  }
  if (face == 3) {
    if (corner == 0) return 1;
    if (corner == 1) return 5;
    if (corner == 2) return 7;
    return 3;
  }
  if (face == 4) {
    if (corner == 0) return 4;
    if (corner == 1) return 5;
    if (corner == 2) return 1;
    return 0;
  }
  if (corner == 0) return 2;
  if (corner == 1) return 3;
  if (corner == 2) return 7;
  return 6;
}

function rotateY(x: f32, z: f32, c: f32, s: f32, axis: i32): f32 {
  if (axis == 0) return x * c - z * s;
  return x * s + z * c;
}

function project(pCam: f32, zCam: f32): f32 {
  return (pCam / -zCam) * HALF * FOV + HALF;
}

function edge(ax: f32, ay: f32, bx: f32, by: f32, px: f32, py: f32): f32 {
  return (px - ax) * (by - ay) - (py - ay) * (bx - ax);
}

function triShade(nx: f32, ny: f32, nz: f32, lx: f32, ly: f32, lz: f32): f32 {
  const d: f32 = nx * lx + ny * ly + nz * lz;
  if (d > 0.0) return d;
  return 0.0;
}

function faceCorner(t: i32, k: i32): i32 {
  const local: i32 = t & 1;
  if (k == 0) return 0;
  if (k == 1) {
    if (local == 0) return 1;
    return 2;
  }
  if (local == 0) return 2;
  return 3;
}

function vertexWorld(t: i32, k: i32, axis: i32, rc: f32, rs: f32): f32 {
  const corner: i32 = faceCorner(t, k);
  if (t >= 12) return groundCorner(corner, axis);
  const id: i32 = faceIndex(t >> 1, corner);
  const x: f32 = cubeCorner(id, 0);
  const z: f32 = cubeCorner(id, 2);
  if (axis == 0) return rotateY(x, z, rc, rs, 0);
  if (axis == 1) return cubeCorner(id, 1) + 0.85;
  return rotateY(x, z, rc, rs, 2);
}

function camDot(
  wx: f32, wy: f32, wz: f32,
  ox: f32, oy: f32, oz: f32,
  ax: f32, ay: f32, az: f32,
): f32 {
  return (wx - ox) * ax + (wy - oy) * ay + (wz - oz) * az;
}

function faceNormal(t: i32, axis: i32): f32 {
  if (t >= 12) {
    if (axis == 1) return 1.0;
    return 0.0;
  }
  const face: i32 = t >> 1;
  if (face == 0) {
    if (axis == 2) return -1.0;
    return 0.0;
  }
  if (face == 1) {
    if (axis == 2) return 1.0;
    return 0.0;
  }
  if (face == 2) {
    if (axis == 0) return -1.0;
    return 0.0;
  }
  if (face == 3) {
    if (axis == 0) return 1.0;
    return 0.0;
  }
  if (face == 4) {
    if (axis == 1) return -1.0;
    return 0.0;
  }
  if (axis == 1) return 1.0;
  return 0.0;
}

function triAlbedo(t: i32, hitX: f32, hitZ: f32, channel: i32): f32 {
  if (t >= 12) {
    const cell: i32 = <i32>Mathf.floor(hitX) + <i32>Mathf.floor(hitZ);
    if ((cell & 1) != 0) {
      if (channel == 0) return 0.18;
      if (channel == 1) return 0.22;
      return 0.16;
    }
    if (channel == 0) return 0.58;
    if (channel == 1) return 0.60;
    return 0.48;
  }
  const face: i32 = t >> 1;
  if (face == 0) {
    if (channel == 0) return 0.86;
    if (channel == 1) return 0.32;
    return 0.24;
  }
  if (face == 1) {
    if (channel == 0) return 0.18;
    if (channel == 1) return 0.72;
    return 0.68;
  }
  if (face == 2) {
    if (channel == 0) return 0.26;
    if (channel == 1) return 0.42;
    return 0.90;
  }
  if (face == 3) {
    if (channel == 0) return 0.92;
    if (channel == 1) return 0.78;
    return 0.22;
  }
  if (face == 4) {
    if (channel == 0) return 0.58;
    if (channel == 1) return 0.30;
    return 0.80;
  }
  if (channel == 0) return 0.95;
  if (channel == 1) return 0.55;
  return 0.18;
}

function tone(v: f32): i32 {
  let c: f32 = v;
  if (c < 0.0) c = 0.0;
  if (c > 1.0) c = 1.0;
  const s: f32 = Mathf.sqrt(c) * 255.0;
  if (s > 255.0) return 255;
  return <i32>s;
}

export function main(): void {
  const time: f32 = load<f32>(TIME_OFFSET) * 0.016;
  const rc: f32 = cosF(time);
  const rs: f32 = sinF(time);

  const camX: f32 = cosF(time * 0.3) * 5.0;
  const camY: f32 = 2.2 + sinF(time * 0.2) * 0.5;
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

  const sunX: f32 = 0.40;
  const sunY: f32 = 0.85;
  const sunZ: f32 = 0.35;
  const sunLen: f32 = Mathf.sqrt(sunX * sunX + sunY * sunY + sunZ * sunZ);
  const ldx: f32 = sunX / sunLen;
  const ldy: f32 = sunY / sunLen;
  const ldz: f32 = sunZ / sunLen;

  for (let i: i32 = 0; i < WIDTH * HEIGHT; i++) {
    const px: f32 = <f32>(i & 255) + 0.5;
    const py: f32 = <f32>(i >> 8) + 0.5;
    let bestDepth: f32 = 1e9;
    let red: f32 = SKY_R;
    let green: f32 = SKY_G;
    let blue: f32 = SKY_B;

    for (let t: i32 = 0; t < TRI_COUNT; t++) {
      const wx0: f32 = vertexWorld(t, 0, 0, rc, rs);
      const wy0: f32 = vertexWorld(t, 0, 1, rc, rs);
      const wz0: f32 = vertexWorld(t, 0, 2, rc, rs);
      const wx1: f32 = vertexWorld(t, 1, 0, rc, rs);
      const wy1: f32 = vertexWorld(t, 1, 1, rc, rs);
      const wz1: f32 = vertexWorld(t, 1, 2, rc, rs);
      const wx2: f32 = vertexWorld(t, 2, 0, rc, rs);
      const wy2: f32 = vertexWorld(t, 2, 1, rc, rs);
      const wz2: f32 = vertexWorld(t, 2, 2, rc, rs);

      const cx0: f32 = camDot(wx0, wy0, wz0, camX, camY, camZ, rdx, 0.0, rdz);
      const cy0: f32 = camDot(wx0, wy0, wz0, camX, camY, camZ, ux, uy, uz);
      const cz0: f32 = -camDot(wx0, wy0, wz0, camX, camY, camZ, fdx, fdy, fdz);
      const cx1: f32 = camDot(wx1, wy1, wz1, camX, camY, camZ, rdx, 0.0, rdz);
      const cy1: f32 = camDot(wx1, wy1, wz1, camX, camY, camZ, ux, uy, uz);
      const cz1: f32 = -camDot(wx1, wy1, wz1, camX, camY, camZ, fdx, fdy, fdz);
      const cx2: f32 = camDot(wx2, wy2, wz2, camX, camY, camZ, rdx, 0.0, rdz);
      const cy2: f32 = camDot(wx2, wy2, wz2, camX, camY, camZ, ux, uy, uz);
      const cz2: f32 = -camDot(wx2, wy2, wz2, camX, camY, camZ, fdx, fdy, fdz);

      if (cz0 < NEAR_Z) {
        if (cz1 < NEAR_Z) {
          if (cz2 < NEAR_Z) {
            const sx0: f32 = project(cx0, cz0);
            const sy0: f32 = project(-cy0, cz0);
            const sx1: f32 = project(cx1, cz1);
            const sy1: f32 = project(-cy1, cz1);
            const sx2: f32 = project(cx2, cz2);
            const sy2: f32 = project(-cy2, cz2);

            const w0: f32 = edge(sx1, sy1, sx2, sy2, px, py);
            const w1: f32 = edge(sx2, sy2, sx0, sy0, px, py);
            const w2: f32 = edge(sx0, sy0, sx1, sy1, px, py);
            const inside: i32 = (w0 >= 0.0 && w1 >= 0.0 && w2 >= 0.0) ? 1 : 0;
            const insideBack: i32 = (w0 <= 0.0 && w1 <= 0.0 && w2 <= 0.0) ? 1 : 0;
            if (inside != 0 || insideBack != 0) {
              const area: f32 = w0 + w1 + w2;
              if (area != 0.0) {
                const iw: f32 = 1.0 / area;
                const zHit: f32 = (w0 * cz0 + w1 * cz1 + w2 * cz2) * iw;
                const depth: f32 = -zHit;
                if (depth > 0.0 && depth < bestDepth) {
                  bestDepth = depth;
                  const hitX: f32 = (w0 * wx0 + w1 * wx1 + w2 * wx2) * iw;
                  const hitZ: f32 = (w0 * wz0 + w1 * wz1 + w2 * wz2) * iw;
                  let nx: f32 = faceNormal(t, 0);
                  let ny: f32 = faceNormal(t, 1);
                  let nz: f32 = faceNormal(t, 2);
                  if (t < 12) {
                    const nrx: f32 = rotateY(nx, nz, rc, rs, 0);
                    nz = rotateY(nx, nz, rc, rs, 2);
                    nx = nrx;
                  }
                  const lit: f32 = 0.18 + 0.82 * triShade(nx, ny, nz, ldx, ldy, ldz);
                  red = triAlbedo(t, hitX, hitZ, 0) * lit;
                  green = triAlbedo(t, hitX, hitZ, 1) * lit;
                  blue = triAlbedo(t, hitX, hitZ, 2) * lit;
                }
              }
            }
          }
        }
      }
    }

    const outOff: i32 = OUTPUT_OFFSET + i * 12;
    store<i32>(outOff, tone(red));
    store<i32>(outOff + 4, tone(green));
    store<i32>(outOff + 8, tone(blue));
  }
}
