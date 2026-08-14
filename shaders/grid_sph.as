// ============================================================
//  8K CELL-OWNED GRID SPH
// ============================================================
//  This demo stays entirely inside the AssemblyScript -> Wasm -> Gasm ->
//  WGSL pipeline. It avoids atomics by reversing ownership: one invocation
//  owns each uniform-grid cell and scans the particles to fill that cell's
//  compact bucket. The same rule builds the 32^3 density field: one
//  invocation owns one voxel and gathers nearby particles through the grid.
//
//  The playground has one global dispatch per animation tick, so barriers
//  between SPH stages are expressed as persistent phases across ticks:
//    bootstrap grid -> density -> integrate -> rebuild grid -> field -> render
//  Completed particle, grid, and field buffers remain GPU-resident throughout.
//  Rendering raymarches only the flat linear-memory density field; it never
//  performs a pixels-times-particles scan.
// ============================================================

const WIDTH: i32 = 256;
const HEIGHT: i32 = 256;
const PIXELS: i32 = WIDTH * HEIGHT;
const OUTPUT_OFFSET: i32 = 16;
const STATE_OFFSET: i32 = OUTPUT_OFFSET + PIXELS * 12;

const MAGIC: i32 = 1196578865; // GSP1
const PARTICLE_COUNT: i32 = 8192;
const GRID_X: i32 = 20;
const GRID_Y: i32 = 15;
const GRID_Z: i32 = 14;
const GRID_CELLS: i32 = GRID_X * GRID_Y * GRID_Z;
const MAX_PER_CELL: i32 = 96;
const FIELD_RES: i32 = 32;
const FIELD_CELLS: i32 = FIELD_RES * FIELD_RES * FIELD_RES;

const HEADER_BYTES: i32 = 64;
const VEC3_BYTES: i32 = PARTICLE_COUNT * 12;
const SCALAR_BYTES: i32 = PARTICLE_COUNT * 4;
const MAGIC_OFFSET: i32 = STATE_OFFSET;
const POSITION_A: i32 = STATE_OFFSET + HEADER_BYTES;
const POSITION_B: i32 = POSITION_A + VEC3_BYTES;
const VELOCITY_A: i32 = POSITION_B + VEC3_BYTES;
const VELOCITY_B: i32 = VELOCITY_A + VEC3_BYTES;
const DENSITY: i32 = VELOCITY_B + VEC3_BYTES;
const PRESSURE: i32 = DENSITY + SCALAR_BYTES;
const GRID_COUNTS: i32 = PRESSURE + SCALAR_BYTES;
const GRID_ENTRIES: i32 = GRID_COUNTS + GRID_CELLS * 4;
const DENSITY_FIELD: i32 = GRID_ENTRIES + GRID_CELLS * MAX_PER_CELL * 4;

const PI: f32 = 3.14159265;
const TWO_PI: f32 = 6.28318530;
const DT: f32 = 0.008;
const GRAVITY: f32 = -9.81;
const H: f32 = 0.105;
const REST_DENSITY: f32 = 11.5;
const STIFFNESS: f32 = 44.0;
const VISCOSITY: f32 = 0.34;
const MAX_SPEED: f32 = 5.5;

const DOMAIN_MIN_X: f32 = -1.20;
const DOMAIN_MIN_Y: f32 = -0.88;
const DOMAIN_MIN_Z: f32 = -0.80;
const DOMAIN_MAX_X: f32 = 1.20;
const DOMAIN_MAX_Y: f32 = 0.92;
const DOMAIN_MAX_Z: f32 = 0.80;
const OBSTACLE_X: f32 = 0.0;
const OBSTACLE_Y: f32 = -0.47;
const OBSTACLE_Z: f32 = 0.0;
const OBSTACLE_RADIUS: f32 = 0.285;
const COLLISION_RADIUS: f32 = 0.315;

function clampF(value: f32, low: f32, high: f32): f32 {
  return Mathf.min(Mathf.max(value, low), high);
}

function clampI(value: i32, low: i32, high: i32): i32 {
  return value < low ? low : value > high ? high : value;
}

function saturate(value: f32): f32 {
  return clampF(value, 0.0, 1.0);
}

function absF(value: f32): f32 {
  return value < 0.0 ? -value : value;
}

function sinF(value: f32): f32 {
  let x: f32 = value - Mathf.floor(value / TWO_PI + 0.5) * TWO_PI;
  if (x > PI * 0.5) x = PI - x;
  if (x < -PI * 0.5) x = -PI - x;
  const x2: f32 = x * x;
  return x * (1.0 - x2 / 6.0 * (1.0 - x2 / 20.0 * (1.0 - x2 / 42.0)));
}

function cosF(value: f32): f32 {
  return sinF(value + PI * 0.5);
}

function vecAddress(base: i32, particle: i32, component: i32): i32 {
  return base + (particle * 3 + component) * 4;
}

function loadX(base: i32, particle: i32): f32 {
  return load<f32>(vecAddress(base, particle, 0));
}

function loadY(base: i32, particle: i32): f32 {
  return load<f32>(vecAddress(base, particle, 1));
}

function loadZ(base: i32, particle: i32): f32 {
  return load<f32>(vecAddress(base, particle, 2));
}

function storeVec(base: i32, particle: i32, x: f32, y: f32, z: f32): void {
  store<f32>(vecAddress(base, particle, 0), x);
  store<f32>(vecAddress(base, particle, 1), y);
  store<f32>(vecAddress(base, particle, 2), z);
}

function hash01(value: i32): f32 {
  let h: i32 = value * 1103515245 + 12345;
  h = h ^ (h >> 16);
  return <f32>(h & 1023) / 1023.0;
}

function seedParticle(particle: i32): void {
  const ix: i32 = particle & 31;
  const iy: i32 = (particle >> 5) & 15;
  const iz: i32 = particle >> 9;
  const jitter: f32 = (hash01(particle) - 0.5) * 0.002;
  const x: f32 = -0.5425 + <f32>ix * 0.035 + jitter;
  const y: f32 = -0.08 + <f32>iy * 0.035;
  const z: f32 = -0.2625 + <f32>iz * 0.035 - jitter;
  storeVec(POSITION_A, particle, x, y, z);
  storeVec(POSITION_B, particle, x, y, z);
  storeVec(VELOCITY_A, particle, 0.0, 0.0, 0.0);
  storeVec(VELOCITY_B, particle, 0.0, 0.0, 0.0);
  store<f32>(DENSITY + particle * 4, REST_DENSITY);
  store<f32>(PRESSURE + particle * 4, 0.0);
}

function gridX(x: f32): i32 {
  return clampI(<i32>Mathf.floor((x - DOMAIN_MIN_X) * <f32>GRID_X / (DOMAIN_MAX_X - DOMAIN_MIN_X)), 0, GRID_X - 1);
}

function gridY(y: f32): i32 {
  return clampI(<i32>Mathf.floor((y - DOMAIN_MIN_Y) * <f32>GRID_Y / (DOMAIN_MAX_Y - DOMAIN_MIN_Y)), 0, GRID_Y - 1);
}

function gridZ(z: f32): i32 {
  return clampI(<i32>Mathf.floor((z - DOMAIN_MIN_Z) * <f32>GRID_Z / (DOMAIN_MAX_Z - DOMAIN_MIN_Z)), 0, GRID_Z - 1);
}

function gridIndex(x: i32, y: i32, z: i32): i32 {
  return x + y * GRID_X + z * GRID_X * GRID_Y;
}

function particleCell(base: i32, particle: i32): i32 {
  return gridIndex(
    gridX(loadX(base, particle)),
    gridY(loadY(base, particle)),
    gridZ(loadZ(base, particle)),
  );
}

// Cell-owned construction: only the invocation for `cell` writes its count
// and entries. The O(cells * particles) scan replaces atomic insertion while
// retaining bounded neighborhood queries in the following phases.
function buildGridCell(base: i32, cell: i32): void {
  let stored: i32 = 0;
  for (let particle: i32 = 0; particle < PARTICLE_COUNT; particle++) {
    if (particleCell(base, particle) == cell) {
      if (stored < MAX_PER_CELL) {
        store<i32>(GRID_ENTRIES + (cell * MAX_PER_CELL + stored) * 4, particle);
        stored++;
      }
    }
  }
  store<i32>(GRID_COUNTS + cell * 4, stored);
}

function compactKernel(distance: f32): f32 {
  const q: f32 = Mathf.max(1.0 - distance / H, 0.0);
  return q * q * q;
}

function solveDensity(base: i32, particle: i32): void {
  const px: f32 = loadX(base, particle);
  const py: f32 = loadY(base, particle);
  const pz: f32 = loadZ(base, particle);
  const cx: i32 = gridX(px);
  const cy: i32 = gridY(py);
  const cz: i32 = gridZ(pz);
  let density: f32 = 1.0;

  for (let oz: i32 = -1; oz <= 1; oz++) {
    const gz: i32 = cz + oz;
    if (gz >= 0 && gz < GRID_Z) {
      for (let oy: i32 = -1; oy <= 1; oy++) {
        const gy: i32 = cy + oy;
        if (gy >= 0 && gy < GRID_Y) {
          for (let ox: i32 = -1; ox <= 1; ox++) {
            const gx: i32 = cx + ox;
            if (gx >= 0 && gx < GRID_X) {
              const cell: i32 = gridIndex(gx, gy, gz);
              const count: i32 = load<i32>(GRID_COUNTS + cell * 4);
              for (let slot: i32 = 0; slot < count; slot++) {
                const other: i32 = load<i32>(GRID_ENTRIES + (cell * MAX_PER_CELL + slot) * 4);
                if (other != particle) {
                  const dx: f32 = px - loadX(base, other);
                  const dy: f32 = py - loadY(base, other);
                  const dz: f32 = pz - loadZ(base, other);
                  const r2: f32 = dx * dx + dy * dy + dz * dz;
                  if (r2 < H * H) density += compactKernel(Mathf.sqrt(r2));
                }
              }
            }
          }
        }
      }
    }
  }

  store<f32>(DENSITY + particle * 4, density);
  store<f32>(PRESSURE + particle * 4, Mathf.max((density - REST_DENSITY) * STIFFNESS, 0.0));
}

function constrainParticle(px0: f32, py0: f32, pz0: f32, vx0: f32, vy0: f32, vz0: f32, particle: i32, positionBase: i32, velocityBase: i32): void {
  let px: f32 = px0;
  let py: f32 = py0;
  let pz: f32 = pz0;
  let vx: f32 = vx0;
  let vy: f32 = vy0;
  let vz: f32 = vz0;
  const margin: f32 = 0.025;
  const damping: f32 = -0.38;

  if (px < DOMAIN_MIN_X + margin) { px = DOMAIN_MIN_X + margin; vx *= damping; }
  if (px > DOMAIN_MAX_X - margin) { px = DOMAIN_MAX_X - margin; vx *= damping; }
  if (py < DOMAIN_MIN_Y + margin) { py = DOMAIN_MIN_Y + margin; vy *= damping; }
  if (py > DOMAIN_MAX_Y - margin) { py = DOMAIN_MAX_Y - margin; vy *= damping; }
  if (pz < DOMAIN_MIN_Z + margin) { pz = DOMAIN_MIN_Z + margin; vz *= damping; }
  if (pz > DOMAIN_MAX_Z - margin) { pz = DOMAIN_MAX_Z - margin; vz *= damping; }

  let dx: f32 = px - OBSTACLE_X;
  let dy: f32 = py - OBSTACLE_Y;
  let dz: f32 = pz - OBSTACLE_Z;
  const distance2: f32 = dx * dx + dy * dy + dz * dz;
  if (distance2 < COLLISION_RADIUS * COLLISION_RADIUS) {
    let distance: f32 = Mathf.sqrt(Mathf.max(distance2, 0.0000001));
    if (distance2 <= 0.0000001) { dx = 0.0; dy = 1.0; dz = 0.0; distance = 1.0; }
    const nx: f32 = dx / distance;
    const ny: f32 = dy / distance;
    const nz: f32 = dz / distance;
    px = OBSTACLE_X + nx * COLLISION_RADIUS;
    py = OBSTACLE_Y + ny * COLLISION_RADIUS;
    pz = OBSTACLE_Z + nz * COLLISION_RADIUS;
    const inward: f32 = vx * nx + vy * ny + vz * nz;
    if (inward < 0.0) {
      vx -= nx * inward * 1.35;
      vy -= ny * inward * 1.35;
      vz -= nz * inward * 1.35;
    }
  }

  storeVec(positionBase, particle, px, py, pz);
  storeVec(velocityBase, particle, vx, vy, vz);
}

function integrateParticle(readPosition: i32, writePosition: i32, readVelocity: i32, writeVelocity: i32, particle: i32): void {
  const px: f32 = loadX(readPosition, particle);
  const py: f32 = loadY(readPosition, particle);
  const pz: f32 = loadZ(readPosition, particle);
  const vx0: f32 = loadX(readVelocity, particle);
  const vy0: f32 = loadY(readVelocity, particle);
  const vz0: f32 = loadZ(readVelocity, particle);
  const pressureI: f32 = load<f32>(PRESSURE + particle * 4);
  const cx: i32 = gridX(px);
  const cy: i32 = gridY(py);
  const cz: i32 = gridZ(pz);
  let ax: f32 = 0.0;
  let ay: f32 = GRAVITY;
  let az: f32 = 0.0;

  for (let oz: i32 = -1; oz <= 1; oz++) {
    const gz: i32 = cz + oz;
    if (gz >= 0 && gz < GRID_Z) {
      for (let oy: i32 = -1; oy <= 1; oy++) {
        const gy: i32 = cy + oy;
        if (gy >= 0 && gy < GRID_Y) {
          for (let ox: i32 = -1; ox <= 1; ox++) {
            const gx: i32 = cx + ox;
            if (gx >= 0 && gx < GRID_X) {
              const cell: i32 = gridIndex(gx, gy, gz);
              const count: i32 = load<i32>(GRID_COUNTS + cell * 4);
              for (let slot: i32 = 0; slot < count; slot++) {
                const other: i32 = load<i32>(GRID_ENTRIES + (cell * MAX_PER_CELL + slot) * 4);
                if (other != particle) {
                  const dx: f32 = px - loadX(readPosition, other);
                  const dy: f32 = py - loadY(readPosition, other);
                  const dz: f32 = pz - loadZ(readPosition, other);
                  const r2: f32 = dx * dx + dy * dy + dz * dz;
                  if (r2 > 0.0000001 && r2 < H * H) {
                    const distance: f32 = Mathf.sqrt(r2);
                    const q: f32 = 1.0 - distance / H;
                    const invDistance: f32 = 1.0 / distance;
                    const pressureJ: f32 = load<f32>(PRESSURE + other * 4);
                    const pressureScale: f32 = (pressureI + pressureJ) * q * q * 0.018;
                    ax += dx * invDistance * pressureScale;
                    ay += dy * invDistance * pressureScale;
                    az += dz * invDistance * pressureScale;
                    const densityJ: f32 = Mathf.max(load<f32>(DENSITY + other * 4), 1.0);
                    const viscosityScale: f32 = VISCOSITY * q / densityJ;
                    ax += (loadX(readVelocity, other) - vx0) * viscosityScale;
                    ay += (loadY(readVelocity, other) - vy0) * viscosityScale;
                    az += (loadZ(readVelocity, other) - vz0) * viscosityScale;
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  let vx: f32 = (vx0 + ax * DT) * 0.999;
  let vy: f32 = (vy0 + ay * DT) * 0.999;
  let vz: f32 = (vz0 + az * DT) * 0.999;
  const speed2: f32 = vx * vx + vy * vy + vz * vz;
  if (speed2 > MAX_SPEED * MAX_SPEED) {
    const scale: f32 = MAX_SPEED / Mathf.sqrt(speed2);
    vx *= scale; vy *= scale; vz *= scale;
  }
  constrainParticle(px + vx * DT, py + vy * DT, pz + vz * DT, vx, vy, vz, particle, writePosition, writeVelocity);
}

function fieldAddress(x: i32, y: i32, z: i32): i32 {
  return DENSITY_FIELD + (x + y * FIELD_RES + z * FIELD_RES * FIELD_RES) * 4;
}

// Voxel-owned density construction. It gathers through the completed grid,
// so every voxel has one writer and no floating-point atomics are required.
function buildDensityVoxel(positionBase: i32, voxel: i32): void {
  const fx: i32 = voxel % FIELD_RES;
  const fy: i32 = (voxel / FIELD_RES) % FIELD_RES;
  const fz: i32 = voxel / (FIELD_RES * FIELD_RES);
  const x: f32 = DOMAIN_MIN_X + (<f32>fx + 0.5) * (DOMAIN_MAX_X - DOMAIN_MIN_X) / <f32>FIELD_RES;
  const y: f32 = DOMAIN_MIN_Y + (<f32>fy + 0.5) * (DOMAIN_MAX_Y - DOMAIN_MIN_Y) / <f32>FIELD_RES;
  const z: f32 = DOMAIN_MIN_Z + (<f32>fz + 0.5) * (DOMAIN_MAX_Z - DOMAIN_MIN_Z) / <f32>FIELD_RES;
  const cx: i32 = gridX(x);
  const cy: i32 = gridY(y);
  const cz: i32 = gridZ(z);
  const radius: f32 = 0.115;
  let field: f32 = 0.0;

  for (let oz: i32 = -1; oz <= 1; oz++) {
    const gz: i32 = cz + oz;
    if (gz >= 0 && gz < GRID_Z) {
      for (let oy: i32 = -1; oy <= 1; oy++) {
        const gy: i32 = cy + oy;
        if (gy >= 0 && gy < GRID_Y) {
          for (let ox: i32 = -1; ox <= 1; ox++) {
            const gx: i32 = cx + ox;
            if (gx >= 0 && gx < GRID_X) {
              const cell: i32 = gridIndex(gx, gy, gz);
              const count: i32 = load<i32>(GRID_COUNTS + cell * 4);
              for (let slot: i32 = 0; slot < count; slot++) {
                const particle: i32 = load<i32>(GRID_ENTRIES + (cell * MAX_PER_CELL + slot) * 4);
                const dx: f32 = x - loadX(positionBase, particle);
                const dy: f32 = y - loadY(positionBase, particle);
                const dz: f32 = z - loadZ(positionBase, particle);
                const r2: f32 = dx * dx + dy * dy + dz * dz;
                if (r2 < radius * radius) {
                  const q: f32 = 1.0 - Mathf.sqrt(r2) / radius;
                  field += q * q;
                }
              }
            }
          }
        }
      }
    }
  }
  store<f32>(DENSITY_FIELD + voxel * 4, field);
}

function loadField(x: i32, y: i32, z: i32): f32 {
  return load<f32>(fieldAddress(clampI(x, 0, FIELD_RES - 1), clampI(y, 0, FIELD_RES - 1), clampI(z, 0, FIELD_RES - 1)));
}

function sampleField(x: f32, y: f32, z: f32): f32 {
  const ux: f32 = clampF((x - DOMAIN_MIN_X) / (DOMAIN_MAX_X - DOMAIN_MIN_X), 0.0, 0.9999) * <f32>FIELD_RES - 0.5;
  const uy: f32 = clampF((y - DOMAIN_MIN_Y) / (DOMAIN_MAX_Y - DOMAIN_MIN_Y), 0.0, 0.9999) * <f32>FIELD_RES - 0.5;
  const uz: f32 = clampF((z - DOMAIN_MIN_Z) / (DOMAIN_MAX_Z - DOMAIN_MIN_Z), 0.0, 0.9999) * <f32>FIELD_RES - 0.5;
  const x0: i32 = <i32>Mathf.floor(ux);
  const y0: i32 = <i32>Mathf.floor(uy);
  const z0: i32 = <i32>Mathf.floor(uz);
  const tx: f32 = ux - <f32>x0;
  const ty: f32 = uy - <f32>y0;
  const tz: f32 = uz - <f32>z0;
  const a00: f32 = loadField(x0, y0, z0) * (1.0 - tx) + loadField(x0 + 1, y0, z0) * tx;
  const a10: f32 = loadField(x0, y0 + 1, z0) * (1.0 - tx) + loadField(x0 + 1, y0 + 1, z0) * tx;
  const a01: f32 = loadField(x0, y0, z0 + 1) * (1.0 - tx) + loadField(x0 + 1, y0, z0 + 1) * tx;
  const a11: f32 = loadField(x0, y0 + 1, z0 + 1) * (1.0 - tx) + loadField(x0 + 1, y0 + 1, z0 + 1) * tx;
  const b0: f32 = a00 * (1.0 - ty) + a10 * ty;
  const b1: f32 = a01 * (1.0 - ty) + a11 * ty;
  return b0 * (1.0 - tz) + b1 * tz;
}

function sphereHit(ox: f32, oy: f32, oz: f32, dx: f32, dy: f32, dz: f32): f32 {
  const sx: f32 = ox - OBSTACLE_X;
  const sy: f32 = oy - OBSTACLE_Y;
  const sz: f32 = oz - OBSTACLE_Z;
  const b: f32 = sx * dx + sy * dy + sz * dz;
  const c: f32 = sx * sx + sy * sy + sz * sz - OBSTACLE_RADIUS * OBSTACLE_RADIUS;
  const discriminant: f32 = b * b - c;
  if (discriminant < 0.0) return 10000.0;
  const distance: f32 = -b - Mathf.sqrt(discriminant);
  return distance > 0.0 ? distance : 10000.0;
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
  const pointerX: i32 = load<i32>(4);
  const pointerY: i32 = load<i32>(8);
  const yaw: f32 = pointerX >= 0 ? (<f32>pointerX / 255.0 - 0.5) * 2.5 : -0.65;
  const pitch: f32 = pointerY >= 0 ? clampF((0.5 - <f32>pointerY / 255.0) * 0.9 + 0.12, -0.18, 0.68) : 0.22;
  const cy: f32 = cosF(yaw);
  const sy: f32 = sinF(yaw);
  const cp: f32 = cosF(pitch);
  const sp: f32 = sinF(pitch);
  const targetY: f32 = -0.02;
  const cameraX: f32 = sy * cp * 3.35;
  const cameraY: f32 = targetY + sp * 3.35;
  const cameraZ: f32 = cy * cp * 3.35;
  let forwardX: f32 = -cameraX;
  let forwardY: f32 = targetY - cameraY;
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
  const syScreen: f32 = 1.0 - (<f32>py + 0.5) / 128.0;
  let rayX: f32 = forwardX + rightX * sx * 0.70 + upX * syScreen * 0.70;
  let rayY: f32 = forwardY + upY * syScreen * 0.70;
  let rayZ: f32 = forwardZ + rightZ * sx * 0.70 + upZ * syScreen * 0.70;
  const rayLength: f32 = Mathf.sqrt(rayX * rayX + rayY * rayY + rayZ * rayZ);
  rayX /= rayLength; rayY /= rayLength; rayZ /= rayLength;

  const horizon: f32 = saturate(1.0 - absF(rayY));
  let red: f32 = 0.018 + horizon * horizon * 0.08;
  let green: f32 = 0.030 + horizon * horizon * 0.13;
  let blue: f32 = 0.060 + horizon * horizon * 0.18;
  let nearest: f32 = 10000.0;

  if (rayY < -0.0001) {
    const floorDistance: f32 = (DOMAIN_MIN_Y - cameraY) / rayY;
    if (floorDistance > 0.0) {
      const floorX: f32 = cameraX + rayX * floorDistance;
      const floorZ: f32 = cameraZ + rayZ * floorDistance;
      if (floorX > DOMAIN_MIN_X && floorX < DOMAIN_MAX_X && floorZ > DOMAIN_MIN_Z && floorZ < DOMAIN_MAX_Z) {
        const checker: i32 = (<i32>Mathf.floor((floorX - DOMAIN_MIN_X) * 5.0) + <i32>Mathf.floor((floorZ - DOMAIN_MIN_Z) * 5.0)) & 1;
        const floorTone: f32 = checker == 0 ? 0.052 : 0.082;
        red = floorTone; green = floorTone * 1.08; blue = floorTone * 1.22;
        nearest = floorDistance;
      }
    }
  }

  const obstacleDistance: f32 = sphereHit(cameraX, cameraY, cameraZ, rayX, rayY, rayZ);
  if (obstacleDistance < nearest) {
    const hx: f32 = cameraX + rayX * obstacleDistance;
    const hy: f32 = cameraY + rayY * obstacleDistance;
    const hz: f32 = cameraZ + rayZ * obstacleDistance;
    const nx: f32 = (hx - OBSTACLE_X) / OBSTACLE_RADIUS;
    const ny: f32 = (hy - OBSTACLE_Y) / OBSTACLE_RADIUS;
    const nz: f32 = (hz - OBSTACLE_Z) / OBSTACLE_RADIUS;
    const diffuse: f32 = saturate(-nx * 0.42 + ny * 0.82 + nz * 0.25);
    const rim: f32 = 1.0 - saturate(-(nx * rayX + ny * rayY + nz * rayZ));
    red = 0.16 + diffuse * 0.52 + rim * rim * 0.16;
    green = 0.045 + diffuse * 0.18 + rim * rim * 0.05;
    blue = 0.018 + diffuse * 0.055;
    nearest = obstacleDistance;
  }

  // Slab intersection with the simulation domain.
  const invX: f32 = 1.0 / rayX;
  const invY: f32 = 1.0 / rayY;
  const invZ: f32 = 1.0 / rayZ;
  const tx0: f32 = (DOMAIN_MIN_X - cameraX) * invX;
  const tx1: f32 = (DOMAIN_MAX_X - cameraX) * invX;
  const ty0: f32 = (DOMAIN_MIN_Y - cameraY) * invY;
  const ty1: f32 = (DOMAIN_MAX_Y - cameraY) * invY;
  const tz0: f32 = (DOMAIN_MIN_Z - cameraZ) * invZ;
  const tz1: f32 = (DOMAIN_MAX_Z - cameraZ) * invZ;
  const nearX: f32 = Mathf.min(tx0, tx1);
  const farX: f32 = Mathf.max(tx0, tx1);
  const nearY: f32 = Mathf.min(ty0, ty1);
  const farY: f32 = Mathf.max(ty0, ty1);
  const nearZ: f32 = Mathf.min(tz0, tz1);
  const farZ: f32 = Mathf.max(tz0, tz1);
  let travel: f32 = Mathf.max(Mathf.max(nearX, nearY), Mathf.max(nearZ, 0.0));
  const travelEnd: f32 = Mathf.min(Mathf.min(farX, farY), Mathf.min(farZ, nearest));
  let waterDistance: f32 = 10000.0;
  let previousDensity: f32 = 0.0;
  const iso: f32 = 0.58;
  for (let step: i32 = 0; step < 72 && travel < travelEnd; step++) {
    const sampleX: f32 = cameraX + rayX * travel;
    const sampleY: f32 = cameraY + rayY * travel;
    const sampleZ: f32 = cameraZ + rayZ * travel;
    const field: f32 = sampleField(sampleX, sampleY, sampleZ);
    if (field >= iso && previousDensity < iso) {
      waterDistance = travel;
      break;
    }
    previousDensity = field;
    travel += 0.032;
  }

  if (waterDistance < nearest) {
    const hx: f32 = cameraX + rayX * waterDistance;
    const hy: f32 = cameraY + rayY * waterDistance;
    const hz: f32 = cameraZ + rayZ * waterDistance;
    const epsilon: f32 = 0.036;
    let nx: f32 = sampleField(hx + epsilon, hy, hz) - sampleField(hx - epsilon, hy, hz);
    let ny: f32 = sampleField(hx, hy + epsilon, hz) - sampleField(hx, hy - epsilon, hz);
    let nz: f32 = sampleField(hx, hy, hz + epsilon) - sampleField(hx, hy, hz - epsilon);
    const normalLength: f32 = Mathf.sqrt(Mathf.max(nx * nx + ny * ny + nz * nz, 0.000001));
    nx /= normalLength; ny /= normalLength; nz /= normalLength;
    const diffuse: f32 = saturate(-nx * 0.45 + ny * 0.82 + nz * 0.30);
    const facing: f32 = saturate(-(nx * rayX + ny * rayY + nz * rayZ));
    const fresnelBase: f32 = 1.0 - facing;
    const fresnel: f32 = 0.06 + 0.80 * fresnelBase * fresnelBase * fresnelBase;
    const reflectY: f32 = rayY - 2.0 * (rayX * nx + rayY * ny + rayZ * nz) * ny;
    const reflectedHorizon: f32 = saturate(1.0 - absF(reflectY));
    const reflectedR: f32 = 0.025 + reflectedHorizon * 0.16;
    const reflectedG: f32 = 0.060 + reflectedHorizon * 0.25;
    const reflectedB: f32 = 0.12 + reflectedHorizon * 0.32;
    const waterR: f32 = 0.012 + diffuse * 0.035;
    const waterG: f32 = 0.13 + diffuse * 0.28;
    const waterB: f32 = 0.21 + diffuse * 0.42;
    red = waterR * (1.0 - fresnel) + reflectedR * fresnel;
    green = waterG * (1.0 - fresnel) + reflectedG * fresnel;
    blue = waterB * (1.0 - fresnel) + reflectedB * fresnel;
  }

  writePixel(pixel, red, green, blue);
}

export function main(): void {
  const frame: i32 = <i32>load<f32>(0);
  const initialized: bool = load<i32>(MAGIC_OFFSET) == MAGIC;

  for (let i: i32 = 0; i < PIXELS; i++) {
    if (!initialized) {
      if (i < PARTICLE_COUNT) seedParticle(i);
      if (i < GRID_CELLS) store<i32>(GRID_COUNTS + i * 4, 0);
      if (i < FIELD_CELLS) store<f32>(DENSITY_FIELD + i * 4, 0.0);
      if (i == 0) store<i32>(MAGIC_OFFSET, MAGIC);
    } else if (frame == 1) {
      if (i < GRID_CELLS) buildGridCell(POSITION_A, i);
    } else if (frame >= 2) {
      const cycle: i32 = (frame - 2) / 5;
      const phase: i32 = (frame - 2) % 5;
      const readPosition: i32 = (cycle & 1) == 0 ? POSITION_A : POSITION_B;
      const writePosition: i32 = (cycle & 1) == 0 ? POSITION_B : POSITION_A;
      const readVelocity: i32 = (cycle & 1) == 0 ? VELOCITY_A : VELOCITY_B;
      const writeVelocity: i32 = (cycle & 1) == 0 ? VELOCITY_B : VELOCITY_A;

      if (phase == 0) {
        if (i < PARTICLE_COUNT) solveDensity(readPosition, i);
      } else if (phase == 1) {
        if (i < PARTICLE_COUNT) integrateParticle(readPosition, writePosition, readVelocity, writeVelocity, i);
      } else if (phase == 2) {
        if (i < GRID_CELLS) buildGridCell(writePosition, i);
      } else if (phase == 3) {
        if (i < FIELD_CELLS) buildDensityVoxel(writePosition, i);
      } else {
        renderPixel(i);
      }
    }
  }
}
