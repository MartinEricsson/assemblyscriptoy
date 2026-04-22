// ============================================================
//  voxel_raycaster.as — DDA traversal of a procedural voxel grid
// ============================================================
//  Classic voxel-style renderer:
//    • 16×16×16 procedural voxel grid (per-cell hash → solid/empty).
//    • Perspective camera orbits the grid.
//    • Per-pixel Amanatides-Woo DDA stepping finds the first solid
//      voxel along the ray.
//    • Shading = face normal · light + cheap distance fog.
//
//  Showcases MIXED integer + float codegen in the WAT/WGSL
//  output: the inner loop is dominated by i32 DDA state
//  while the setup and shading use f32 arithmetic.
// ============================================================

const WIDTH:  i32 = 256;
const HEIGHT: i32 = 256;
const TIME_OFFSET: i32 = 0;
const PI:     f32 = 3.14159265;
const TWO_PI: f32 = 6.28318530;

const GRID: i32 = 16;         // voxel grid is GRID³
// Camera sits well outside the grid, so the DDA spends the first
// ~15 steps walking through empty space before entering the volume.
// Worst case ≈ outside approach + 3·GRID inside.
const MAX_STEPS: i32 = 96;

// ── f32-only sin/cos ─────────────────────────────────────────
function sinF(x: f32): f32 {
  x = x - Mathf.floor(x / TWO_PI + 0.5) * TWO_PI;
  if (x > PI * 0.5)  x = PI  - x;
  if (x < -PI * 0.5) x = -PI - x;
  const x2: f32 = x * x;
  return x * (1.0 - x2 / 6.0 * (1.0 - x2 / 20.0 * (1.0 - x2 / 42.0)));
}
function cosF(x: f32): f32 { return sinF(x + PI * 0.5); }
function clampF(v: f32, lo: f32, hi: f32): f32 { return Mathf.min(Mathf.max(v, lo), hi); }

// ── Integer hash → voxel solidity (deterministic, cheap) ─────
// Returns 1 if voxel (ix,iy,iz) is solid, else 0.
function voxelAt(ix: i32, iy: i32, iz: i32): i32 {
  // Out-of-bounds voxels are always empty.
  if (ix < 0 || iy < 0 || iz < 0) return 0;
  if (ix >= GRID || iy >= GRID || iz >= GRID) return 0;

  // Build a simple 3D heightmap + carve-outs:
  //   1. Ground plane at iy == 0 is always solid (floor).
  //   2. Heightmap on top derived from a 2D hash (X,Z).
  //   3. A few carved-out "windows" using a bitwise pattern.
  if (iy == 0) return 1;

  // Lightweight i32 hash of the (ix,iz) column.
  let h: i32 = ix * 374761393 + iz * 668265263;
  h = (h ^ (h >> 13)) * 1274126177;
  h = h ^ (h >> 16);
  const height: i32 = ((h & 7) + 1);   // 1..8 blocks above floor

  if (iy > height) return 0;

  // Carve a recognisable pattern so the voxel structure is obvious.
  if (((ix ^ iy ^ iz) & 3) == 0 && iy > 2) return 0;

  return 1;
}

// ── Tint a voxel by its coordinates so adjacent faces differ ─
function voxelTintR(ix: i32, iy: i32, iz: i32): f32 {
  return 0.35 + 0.45 * <f32>((ix * 11 + iy * 7) & 7) * 0.125;
}
function voxelTintG(ix: i32, iy: i32, iz: i32): f32 {
  return 0.30 + 0.50 * <f32>((iy * 13 + iz * 5) & 7) * 0.125;
}
function voxelTintB(ix: i32, iy: i32, iz: i32): f32 {
  return 0.25 + 0.55 * <f32>((iz * 17 + ix * 3) & 7) * 0.125;
}

export function main(): void {
  const time: f32 = load<f32>(TIME_OFFSET) * 0.016;

  // Camera orbits the grid centre at a comfortable distance.
  const halfG: f32 = <f32>GRID * 0.5;
  const camRadius: f32 = <f32>GRID * 1.4;
  const camX: f32 = halfG + camRadius * cosF(time * 0.3);
  const camY: f32 = halfG + 3.0 + sinF(time * 0.2) * 2.0;
  const camZ: f32 = halfG + camRadius * sinF(time * 0.3);

  // Look at the grid centre; build an orthonormal basis.
  const fwdX: f32 = halfG - camX;
  const fwdY: f32 = halfG - camY;
  const fwdZ: f32 = halfG - camZ;
  const fLen: f32 = Mathf.sqrt(fwdX * fwdX + fwdY * fwdY + fwdZ * fwdZ);
  const fdx: f32 = fwdX / fLen;
  const fdy: f32 = fwdY / fLen;
  const fdz: f32 = fwdZ / fLen;

  // Right = normalise(cross(fd, worldUp)). worldUp = (0,1,0).
  const rxRaw: f32 =  fdz;
  const rzRaw: f32 = -fdx;
  const rLen:  f32 = Mathf.sqrt(rxRaw * rxRaw + rzRaw * rzRaw);
  const rdx: f32 = rxRaw / rLen;
  const rdz: f32 = rzRaw / rLen;

  // Up = cross(right, fwd).
  const ux: f32 = -fdy * rdz;
  const uy: f32 =  fdz * rdx - fdx * rdz;
  const uz: f32 =  fdy * rdx;

  const invW: f32 = 1.0 / <f32>WIDTH;
  const invH: f32 = 1.0 / <f32>HEIGHT;

  // Directional light (normalised).
  const lx: f32 = 0.40; const ly: f32 = 0.80; const lz: f32 = 0.45;

  for (let i: i32 = 0; i < WIDTH * HEIGHT; i++) {
    const px: i32 = i % WIDTH;
    const py: i32 = i / WIDTH;

    const u: f32 = 2.0 * <f32>px * invW - 1.0;
    const v: f32 = -(2.0 * <f32>py * invH - 1.0);

    // Ray direction in world space (focal length 1.2).
    const dirX0: f32 = rdx * u + ux * v + fdx * 1.2;
    const dirY0: f32 =           uy * v + fdy * 1.2;
    const dirZ0: f32 = rdz * u + uz * v + fdz * 1.2;
    const dLen:  f32 = Mathf.sqrt(dirX0 * dirX0 + dirY0 * dirY0 + dirZ0 * dirZ0);
    const ddx: f32 = dirX0 / dLen;
    const ddy: f32 = dirY0 / dLen;
    const ddz: f32 = dirZ0 / dLen;

    // ── Amanatides-Woo DDA setup ────────────────────────────
    // Starting voxel.
    let ix: i32 = <i32>Mathf.floor(camX);
    let iy: i32 = <i32>Mathf.floor(camY);
    let iz: i32 = <i32>Mathf.floor(camZ);

    const stepX: i32 = ddx > 0.0 ? 1 : -1;
    const stepY: i32 = ddy > 0.0 ? 1 : -1;
    const stepZ: i32 = ddz > 0.0 ? 1 : -1;

    // Avoid division by zero with a small epsilon.
    const invAx: f32 = 1.0 / Mathf.max(Mathf.abs(ddx), 1e-8);
    const invAy: f32 = 1.0 / Mathf.max(Mathf.abs(ddy), 1e-8);
    const invAz: f32 = 1.0 / Mathf.max(Mathf.abs(ddz), 1e-8);

    const tDeltaX: f32 = invAx;
    const tDeltaY: f32 = invAy;
    const tDeltaZ: f32 = invAz;

    // Distance from camera to first voxel boundary along each axis.
    const nextX: f32 = ddx > 0.0 ? (<f32>(ix + 1) - camX) : (camX - <f32>ix);
    const nextY: f32 = ddy > 0.0 ? (<f32>(iy + 1) - camY) : (camY - <f32>iy);
    const nextZ: f32 = ddz > 0.0 ? (<f32>(iz + 1) - camZ) : (camZ - <f32>iz);
    let tMaxX: f32 = nextX * invAx;
    let tMaxY: f32 = nextY * invAy;
    let tMaxZ: f32 = nextZ * invAz;

    // Walk the grid. `hitAxis` records which face we crossed: 0=X, 1=Y, 2=Z.
    // NOTE: we intentionally DON'T set a `hit` flag right before `break` —
    // the Gasm WASM→WGSL optimizer currently drops `local.set` that appears
    // immediately before a `br` out of a loop (observed 2026-04-22).
    // Instead we re-test voxelAt() post-loop.
    let hitAxis: i32 = 0;
    let totalT: f32 = 0.0;

    for (let s: i32 = 0; s < MAX_STEPS; s++) {
      if (voxelAt(ix, iy, iz) != 0) break;

      if (tMaxX < tMaxY && tMaxX < tMaxZ) {
        totalT = tMaxX;
        ix += stepX;
        tMaxX += tDeltaX;
        hitAxis = 0;
      } else if (tMaxY < tMaxZ) {
        totalT = tMaxY;
        iy += stepY;
        tMaxY += tDeltaY;
        hitAxis = 1;
      } else {
        totalT = tMaxZ;
        iz += stepZ;
        tMaxZ += tDeltaZ;
        hitAxis = 2;
      }

      // Only bail when we have already passed through the grid in the
      // direction of travel — i.e. we are outside AND moving further
      // away on the relevant axis. MAX_STEPS caps the other cases.
      if (stepX > 0 && ix > GRID) break;
      if (stepX < 0 && ix < -1)   break;
      if (stepY > 0 && iy > GRID) break;
      if (stepY < 0 && iy < -1)   break;
      if (stepZ > 0 && iz > GRID) break;
      if (stepZ < 0 && iz < -1)   break;
    }

    let r: f32; let g: f32; let b: f32;

    // Re-test at the final voxel position. voxelAt() is safely 0 for
    // out-of-range indices, so this works for both "found solid" and
    // "fell out of grid" loop exits.
    const hit: boolean = voxelAt(ix, iy, iz) != 0;

    if (hit) {
      // Face normal based on which plane we crossed.
      let nx: f32 = 0.0; let ny: f32 = 0.0; let nz: f32 = 0.0;
      if (hitAxis == 0)      nx = <f32>-stepX;
      else if (hitAxis == 1) ny = <f32>-stepY;
      else                   nz = <f32>-stepZ;

      // Lambert + ambient.
      const diff: f32 = clampF(nx * lx + ny * ly + nz * lz, 0.0, 1.0);
      const lighting: f32 = 0.25 + 0.75 * diff;

      // Per-voxel tint makes the structure readable.
      const tr: f32 = voxelTintR(ix, iy, iz);
      const tg: f32 = voxelTintG(ix, iy, iz);
      const tb: f32 = voxelTintB(ix, iy, iz);

      // Simple distance fog — fades to sky colour at grid diagonal distance.
      const fog: f32 = clampF(totalT / (<f32>GRID * 1.8), 0.0, 1.0);
      const skyR: f32 = 0.55; const skyG: f32 = 0.70; const skyB: f32 = 0.95;

      r = tr * lighting * (1.0 - fog) + skyR * fog;
      g = tg * lighting * (1.0 - fog) + skyG * fog;
      b = tb * lighting * (1.0 - fog) + skyB * fog;
    } else {
      // Sky gradient from horizon (warm) to zenith (blue).
      const tsky: f32 = clampF(0.5 + 0.5 * ddy, 0.0, 1.0);
      r = 0.90 * (1.0 - tsky) + 0.35 * tsky;
      g = 0.75 * (1.0 - tsky) + 0.55 * tsky;
      b = 0.60 * (1.0 - tsky) + 0.95 * tsky;
    }

    const pixelOffset: i32 = 16 + i * 12;
    store<i32>(pixelOffset,     <i32>(clampF(r, 0.0, 1.0) * 255.0));
    store<i32>(pixelOffset + 4, <i32>(clampF(g, 0.0, 1.0) * 255.0));
    store<i32>(pixelOffset + 8, <i32>(clampF(b, 0.0, 1.0) * 255.0));
  }
}
