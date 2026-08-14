// ============================================================
//  3D Position-Based Fluids (SPH kernels)
// ============================================================
//  A deterministic hydrostatic-column benchmark with 3,800 densely packed
//  fluid particles.
//
//  The host intentionally performs one global compute dispatch per frame,
//  so a physical step is staged across ten rendered frames:
//    predict, then four (density/lambda, correction) pairs, then finalize.
//  Every constraint phase is Jacobi-style: it reads one immutable position
//  buffer and writes the other. The renderer always reads the latest fully
//  completed state, making convergence visible without data races.
//
//  Fluid particles use canonical 3D poly6 density and spiky-gradient
//  kernels. Static boundary particles contribute calibrated Psi volumes.
//  Artificial pressure suppresses tensile clumping and XSPH viscosity is
//  applied during finalization. Neighbor search is deliberately all-pairs:
//  this keeps the demo inside the existing single-dispatch architecture.
//  An analytic raised-sphere constraint is projected after prediction and
//  every Jacobi correction so particles cannot tunnel through the obstacle.
//  The beauty view accumulates projected compact-support kernels into a
//  screen-space metaball field, blending particle normals into one liquid
//  surface without an additional all-particle rendering pass.
//
//  Hold the pointer over the scene to orbit. Hold the VIEW control in the
//  upper-right to cycle beauty, density error, lambda, velocity, and
//  neighbor-count views. Recompiling deterministically resets the benchmark.
// ============================================================

const WIDTH: i32 = 256;
const HEIGHT: i32 = 256;
const PIXELS: i32 = WIDTH * HEIGHT;
const OUTPUT_OFFSET: i32 = 16;
const STATE_OFFSET: i32 = OUTPUT_OFFSET + PIXELS * 12;

const MAGIC: i32 = 1346520627; // PBF3
const MAGIC_OFFSET: i32 = STATE_OFFSET;
const SCENE_OFFSET: i32 = STATE_OFFSET + 4;
const TEST_MODE_OFFSET: i32 = STATE_OFFSET + 8;
const VIEW_MODE_OFFSET: i32 = STATE_OFFSET + 12;
const PREVIOUS_BUTTONS_OFFSET: i32 = STATE_OFFSET + 16;
const CAMERA_YAW_OFFSET: i32 = STATE_OFFSET + 20;
const CAMERA_PITCH_OFFSET: i32 = STATE_OFFSET + 24;
const MEAN_ERROR_OFFSET: i32 = STATE_OFFSET + 28;
const MAX_ERROR_OFFSET: i32 = STATE_OFFSET + 32;

const FLUID_COUNT: i32 = 3800;
const BOUNDARY_COUNT: i32 = 513;
const HEADER_BYTES: i32 = 64;
const VEC3_BYTES: i32 = FLUID_COUNT * 12;
const COMMITTED_POS: i32 = STATE_OFFSET + HEADER_BYTES;
const VELOCITY: i32 = COMMITTED_POS + VEC3_BYTES;
const POSITION_A: i32 = VELOCITY + VEC3_BYTES;
const POSITION_B: i32 = POSITION_A + VEC3_BYTES;
const DENSITY: i32 = POSITION_B + VEC3_BYTES;
const LAMBDA: i32 = DENSITY + FLUID_COUNT * 4;
const NEIGHBOR_COUNT: i32 = LAMBDA + FLUID_COUNT * 4;
const BOUNDARY_PSI: i32 = NEIGHBOR_COUNT + FLUID_COUNT * 4;
const COMMITTED_ALT: i32 = BOUNDARY_PSI + BOUNDARY_COUNT * 4;

const VIEW_BEAUTY: i32 = 0;
const VIEW_DENSITY: i32 = 1;
const VIEW_LAMBDA: i32 = 2;
const VIEW_VELOCITY: i32 = 3;
const VIEW_NEIGHBORS: i32 = 4;
const VIEW_COUNT: i32 = 5;

const PI: f32 = 3.14159265;
const TWO_PI: f32 = 6.28318530;
const DT: f32 = 0.016666667;
const GRAVITY: f32 = -9.81;
const REST_DENSITY: f32 = 1000.0;
const PARTICLE_SPACING: f32 = 0.05;
const PARTICLE_MASS: f32 = 0.125; // rho0 * spacing^3
const H: f32 = 0.32;
const H2: f32 = H * H;
const POLY6_COEFF: f32 = 44527.766; // 315 / (64*pi*h^9)
const SPIKY_GRAD_COEFF: f32 = -13340.213; // -45 / (pi*h^6)
const LAMBDA_EPSILON: f32 = 40.0;
const ARTIFICIAL_PRESSURE_K: f32 = 0.001;
const ARTIFICIAL_PRESSURE_WQ: f32 = 36.0292; // W(0.3h)
const XSPH_C: f32 = 0.07;
const MAX_CORRECTION: f32 = 0.045;
const MAX_SPEED: f32 = 6.0;

const DOMAIN_MIN_X: f32 = -1.15;
const DOMAIN_MAX_X: f32 = 1.15;
const DOMAIN_MIN_Y: f32 = -0.84;
const DOMAIN_MAX_Y: f32 = 0.84;
const DOMAIN_MIN_Z: f32 = -0.75;
const DOMAIN_MAX_Z: f32 = 0.75;
const OBSTACLE_X: f32 = 0.0;
const OBSTACLE_Y: f32 = -0.42;
const OBSTACLE_Z: f32 = 0.0;
const OBSTACLE_RADIUS: f32 = 0.28;
const OBSTACLE_COLLISION_RADIUS: f32 = 0.32;

const PHASES_PER_STEP: i32 = 10;
const HYDRO_STEPS: i32 = 720;
const HOLD_FRAMES: i32 = 90;

function clampF(value: f32, low: f32, high: f32): f32 {
  return Mathf.min(Mathf.max(value, low), high);
}

function saturate(value: f32): f32 {
  return clampF(value, 0.0, 1.0);
}

function absF(value: f32): f32 {
  return value < 0.0 ? -value : value;
}

function clamp255(value: i32): i32 {
  return value < 0 ? 0 : value > 255 ? 255 : value;
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

function initialFluidX(particle: i32): f32 {
  const ix: i32 = particle % 25;
  return (<f32>ix - 12.0) * PARTICLE_SPACING;
}

function initialFluidY(particle: i32): f32 {
  const iy: i32 = (particle / 25) % 14;
  return -0.04 + <f32>iy * PARTICLE_SPACING;
}

function initialFluidZ(particle: i32): f32 {
  const iz: i32 = particle / 350;
  return (<f32>iz - 4.5) * PARTICLE_SPACING;
}

function boundaryX(particle: i32): f32 {
  if (particle < 117) {
    return -1.2 + <f32>(particle % 13) * 0.2;
  }
  if (particle < 279) {
    const q: i32 = particle - 117;
    return q < 81 ? -1.30 : 1.30;
  }
  const q: i32 = particle - 279;
  return -1.2 + <f32>(q % 13) * 0.2;
}

function boundaryY(particle: i32): f32 {
  if (particle < 117) return -1.0;
  if (particle < 279) {
    const q: i32 = (particle - 117) % 81;
    return -0.8 + <f32>(q / 9) * 0.2;
  }
  const q: i32 = (particle - 279) % 117;
  return -0.8 + <f32>(q / 13) * 0.2;
}

function boundaryZ(particle: i32): f32 {
  if (particle < 117) {
    return -0.8 + <f32>(particle / 13) * 0.2;
  }
  if (particle < 279) {
    const q: i32 = (particle - 117) % 81;
    return -0.8 + <f32>(q % 9) * 0.2;
  }
  const q: i32 = particle - 279;
  return q < 117 ? -0.90 : 0.90;
}

function poly6(r2: f32): f32 {
  if (r2 >= H2) return 0.0;
  const q: f32 = H2 - r2;
  return POLY6_COEFF * q * q * q;
}

function spikyGradientScale(r2: f32): f32 {
  if (r2 <= 0.0000001 || r2 >= H2) return 0.0;
  const r: f32 = Mathf.sqrt(r2);
  const q: f32 = H - r;
  return SPIKY_GRAD_COEFF * q * q / r;
}

function seedState(particle: i32): void {
  const x: f32 = initialFluidX(particle);
  const y: f32 = initialFluidY(particle);
  const z: f32 = initialFluidZ(particle);
  storeVec(COMMITTED_POS, particle, x, y, z);
  storeVec(COMMITTED_ALT, particle, x, y, z);
  storeVec(POSITION_A, particle, x, y, z);
  storeVec(POSITION_B, particle, x, y, z);
  storeVec(VELOCITY, particle, 0.0, 0.0, 0.0);
  store<f32>(DENSITY + particle * 4, REST_DENSITY);
  store<f32>(LAMBDA + particle * 4, 0.0);
  store<i32>(NEIGHBOR_COUNT + particle * 4, 0);
}

function calibrateBoundaryPsi(particle: i32): f32 {
  const px: f32 = boundaryX(particle);
  const py: f32 = boundaryY(particle);
  const pz: f32 = boundaryZ(particle);
  let kernelSum: f32 = 0.0;
  for (let j: i32 = 0; j < BOUNDARY_COUNT; j++) {
    const dx: f32 = px - boundaryX(j);
    const dy: f32 = py - boundaryY(j);
    const dz: f32 = pz - boundaryZ(j);
    kernelSum += poly6(dx * dx + dy * dy + dz * dz);
  }
  return kernelSum > 0.0001 ? REST_DENSITY / kernelSum : PARTICLE_MASS;
}

function storeConstrainedPosition(base: i32, particle: i32, x: f32, y: f32, z: f32): void {
  let px: f32 = clampF(x, DOMAIN_MIN_X, DOMAIN_MAX_X);
  let py: f32 = clampF(y, DOMAIN_MIN_Y, DOMAIN_MAX_Y);
  let pz: f32 = clampF(z, DOMAIN_MIN_Z, DOMAIN_MAX_Z);
  let dx: f32 = px - OBSTACLE_X;
  let dy: f32 = py - OBSTACLE_Y;
  let dz: f32 = pz - OBSTACLE_Z;
  const distance2: f32 = dx * dx + dy * dy + dz * dz;
  const radius2: f32 = OBSTACLE_COLLISION_RADIUS * OBSTACLE_COLLISION_RADIUS;
  if (distance2 < radius2) {
    if (distance2 > 0.0000001) {
      const scale: f32 = OBSTACLE_COLLISION_RADIUS / Mathf.sqrt(distance2);
      dx *= scale;
      dy *= scale;
      dz *= scale;
    } else {
      dx = 0.0;
      dy = OBSTACLE_COLLISION_RADIUS;
      dz = 0.0;
    }
    px = OBSTACLE_X + dx;
    py = OBSTACLE_Y + dy;
    pz = OBSTACLE_Z + dz;
  }
  storeVec(base, particle, px, py, pz);
}

function predictParticle(committedBase: i32, particle: i32): void {
  const oldX: f32 = loadX(committedBase, particle);
  const oldY: f32 = loadY(committedBase, particle);
  const oldZ: f32 = loadZ(committedBase, particle);
  const vx: f32 = loadX(VELOCITY, particle) * 0.995;
  const vy: f32 = loadY(VELOCITY, particle) * 0.995 + GRAVITY * DT;
  const vz: f32 = loadZ(VELOCITY, particle) * 0.995;
  storeConstrainedPosition(POSITION_A, particle, oldX + vx * DT, oldY + vy * DT, oldZ + vz * DT);
}

function solveDensityLambda(base: i32, particle: i32): void {
  const px: f32 = loadX(base, particle);
  const py: f32 = loadY(base, particle);
  const pz: f32 = loadZ(base, particle);
  let density: f32 = PARTICLE_MASS * poly6(0.0);
  let gradIX: f32 = 0.0;
  let gradIY: f32 = 0.0;
  let gradIZ: f32 = 0.0;
  let sumGradient2: f32 = 0.0;
  let neighbors: i32 = 0;

  for (let j: i32 = 0; j < FLUID_COUNT; j++) {
    if (j != particle) {
      const dx: f32 = px - loadX(base, j);
      const dy: f32 = py - loadY(base, j);
      const dz: f32 = pz - loadZ(base, j);
      const r2: f32 = dx * dx + dy * dy + dz * dz;
      if (r2 < H2) {
        neighbors++;
        density += PARTICLE_MASS * poly6(r2);
        const factor: f32 = PARTICLE_MASS / REST_DENSITY;
        const scale: f32 = spikyGradientScale(r2) * factor;
        const gx: f32 = scale * dx;
        const gy: f32 = scale * dy;
        const gz: f32 = scale * dz;
        gradIX += gx;
        gradIY += gy;
        gradIZ += gz;
        sumGradient2 += gx * gx + gy * gy + gz * gz;
      }
    }
  }

  for (let j: i32 = 0; j < BOUNDARY_COUNT; j++) {
    const dx: f32 = px - boundaryX(j);
    const dy: f32 = py - boundaryY(j);
    const dz: f32 = pz - boundaryZ(j);
    const r2: f32 = dx * dx + dy * dy + dz * dz;
    if (r2 < H2) {
      neighbors++;
      const psi: f32 = load<f32>(BOUNDARY_PSI + j * 4);
      density += psi * poly6(r2);
      const factor: f32 = psi / REST_DENSITY;
      const scale: f32 = spikyGradientScale(r2) * factor;
      const gx: f32 = scale * dx;
      const gy: f32 = scale * dy;
      const gz: f32 = scale * dz;
      gradIX += gx;
      gradIY += gy;
      gradIZ += gz;
      sumGradient2 += gx * gx + gy * gy + gz * gz;
    }
  }

  sumGradient2 += gradIX * gradIX + gradIY * gradIY + gradIZ * gradIZ;
  const constraint: f32 = density / REST_DENSITY - 1.0;
  const lambda: f32 = -constraint / (sumGradient2 + LAMBDA_EPSILON);
  store<f32>(DENSITY + particle * 4, density);
  store<f32>(LAMBDA + particle * 4, lambda);
  store<i32>(NEIGHBOR_COUNT + particle * 4, neighbors);
}

function artificialPressure(r2: f32): f32 {
  const ratio: f32 = poly6(r2) / ARTIFICIAL_PRESSURE_WQ;
  const ratio2: f32 = ratio * ratio;
  return -ARTIFICIAL_PRESSURE_K * ratio2 * ratio2;
}

function correctParticle(readBase: i32, writeBase: i32, particle: i32): void {
  const px: f32 = loadX(readBase, particle);
  const py: f32 = loadY(readBase, particle);
  const pz: f32 = loadZ(readBase, particle);
  const lambdaI: f32 = load<f32>(LAMBDA + particle * 4);
  let correctionX: f32 = 0.0;
  let correctionY: f32 = 0.0;
  let correctionZ: f32 = 0.0;

  for (let j: i32 = 0; j < FLUID_COUNT; j++) {
    if (j != particle) {
      const dx: f32 = px - loadX(readBase, j);
      const dy: f32 = py - loadY(readBase, j);
      const dz: f32 = pz - loadZ(readBase, j);
      const r2: f32 = dx * dx + dy * dy + dz * dz;
      if (r2 < H2 && r2 > 0.0000001) {
        const scale: f32 = spikyGradientScale(r2) * (PARTICLE_MASS / REST_DENSITY);
        const pressure: f32 = lambdaI + load<f32>(LAMBDA + j * 4) + artificialPressure(r2);
        correctionX += pressure * scale * dx;
        correctionY += pressure * scale * dy;
        correctionZ += pressure * scale * dz;
      }
    }
  }

  for (let j: i32 = 0; j < BOUNDARY_COUNT; j++) {
    const dx: f32 = px - boundaryX(j);
    const dy: f32 = py - boundaryY(j);
    const dz: f32 = pz - boundaryZ(j);
    const r2: f32 = dx * dx + dy * dy + dz * dz;
    if (r2 < H2 && r2 > 0.0000001) {
      const factor: f32 = load<f32>(BOUNDARY_PSI + j * 4) / REST_DENSITY;
      const scale: f32 = spikyGradientScale(r2) * factor;
      correctionX += lambdaI * scale * dx;
      correctionY += lambdaI * scale * dy;
      correctionZ += lambdaI * scale * dz;
    }
  }

  const correction2: f32 = correctionX * correctionX + correctionY * correctionY + correctionZ * correctionZ;
  if (correction2 > MAX_CORRECTION * MAX_CORRECTION) {
    const correctionScale: f32 = MAX_CORRECTION / Mathf.sqrt(correction2);
    correctionX *= correctionScale;
    correctionY *= correctionScale;
    correctionZ *= correctionScale;
  }
  storeConstrainedPosition(writeBase, particle, px + correctionX, py + correctionY, pz + correctionZ);
}

function finalizeParticle(oldCommittedBase: i32, newCommittedBase: i32, particle: i32): void {
  const px: f32 = loadX(POSITION_A, particle);
  const py: f32 = loadY(POSITION_A, particle);
  const pz: f32 = loadZ(POSITION_A, particle);
  const oldX: f32 = loadX(oldCommittedBase, particle);
  const oldY: f32 = loadY(oldCommittedBase, particle);
  const oldZ: f32 = loadZ(oldCommittedBase, particle);
  let vx: f32 = (px - oldX) / DT;
  let vy: f32 = (py - oldY) / DT;
  let vz: f32 = (pz - oldZ) / DT;
  let viscosityX: f32 = 0.0;
  let viscosityY: f32 = 0.0;
  let viscosityZ: f32 = 0.0;

  for (let j: i32 = 0; j < FLUID_COUNT; j++) {
    if (j != particle) {
      const jx: f32 = loadX(POSITION_A, j);
      const jy: f32 = loadY(POSITION_A, j);
      const jz: f32 = loadZ(POSITION_A, j);
      const dx: f32 = px - jx;
      const dy: f32 = py - jy;
      const dz: f32 = pz - jz;
      const weight: f32 = poly6(dx * dx + dy * dy + dz * dz);
      if (weight > 0.0) {
        const densityJ: f32 = Mathf.max(load<f32>(DENSITY + j * 4), REST_DENSITY * 0.1);
        const scale: f32 = PARTICLE_MASS * weight / densityJ;
        const velocityJX: f32 = (jx - loadX(oldCommittedBase, j)) / DT;
        const velocityJY: f32 = (jy - loadY(oldCommittedBase, j)) / DT;
        const velocityJZ: f32 = (jz - loadZ(oldCommittedBase, j)) / DT;
        viscosityX += (velocityJX - vx) * scale;
        viscosityY += (velocityJY - vy) * scale;
        viscosityZ += (velocityJZ - vz) * scale;
      }
    }
  }

  vx += viscosityX * XSPH_C;
  vy += viscosityY * XSPH_C;
  vz += viscosityZ * XSPH_C;
  const speed2: f32 = vx * vx + vy * vy + vz * vz;
  if (speed2 > MAX_SPEED * MAX_SPEED) {
    const speedScale: f32 = MAX_SPEED / Mathf.sqrt(speed2);
    vx *= speedScale;
    vy *= speedScale;
    vz *= speedScale;
  }
  storeVec(newCommittedBase, particle, px, py, pz);
  storeVec(VELOCITY, particle, vx, vy, vz);
}

function updateDensityMetrics(): void {
  let errorSum: f32 = 0.0;
  let errorMax: f32 = 0.0;
  for (let j: i32 = 0; j < FLUID_COUNT; j++) {
    const error: f32 = absF(load<f32>(DENSITY + j * 4) / REST_DENSITY - 1.0);
    errorSum += error;
    errorMax = Mathf.max(errorMax, error);
  }
  store<i32>(MEAN_ERROR_OFFSET, <i32>(errorSum * 100.0 / <f32>FLUID_COUNT));
  store<i32>(MAX_ERROR_OFFSET, <i32>(errorMax * 100.0));
}

function simulationDisplayBase(phase: i32, committedBase: i32): i32 {
  if (phase <= 0) return committedBase;
  if (phase <= 2) return POSITION_A;
  if (phase <= 4) return POSITION_B;
  if (phase <= 6) return POSITION_A;
  if (phase <= 8) return POSITION_B;
  return POSITION_A;
}

function colorRamp(value: f32, channel: i32): f32 {
  const t: f32 = saturate(value);
  if (channel == 0) return saturate(t * 2.2 - 0.55);
  if (channel == 1) return saturate(1.0 - absF(t * 2.0 - 1.0));
  return saturate(1.15 - t * 1.9);
}

function propertyValue(view: i32, particle: i32): f32 {
  if (view == VIEW_DENSITY) {
    return saturate(absF(load<f32>(DENSITY + particle * 4) / REST_DENSITY - 1.0) * 5.0);
  }
  if (view == VIEW_LAMBDA) {
    const value: f32 = absF(load<f32>(LAMBDA + particle * 4));
    return saturate(value / (value + 0.002));
  }
  if (view == VIEW_VELOCITY) {
    const vx: f32 = loadX(VELOCITY, particle);
    const vy: f32 = loadY(VELOCITY, particle);
    const vz: f32 = loadZ(VELOCITY, particle);
    return saturate(Mathf.sqrt(vx * vx + vy * vy + vz * vz) / 3.0);
  }
  return saturate(<f32>load<i32>(NEIGHBOR_COUNT + particle * 4) / 38.0);
}

function glyphRow(code: i32, row: i32): i32 {
  if (code >= 48 && code <= 57) {
    const digit: i32 = code - 48;
    if (digit == 0) return row == 0 || row == 6 ? 14 : row == 1 || row == 5 ? 17 : row == 2 ? 19 : row == 3 ? 21 : 25;
    if (digit == 1) return row == 0 ? 4 : row == 1 ? 12 : row == 6 ? 14 : 4;
    if (digit == 2) return row == 0 ? 14 : row == 1 ? 17 : row == 2 ? 1 : row == 3 ? 2 : row == 4 ? 4 : row == 5 ? 8 : 31;
    if (digit == 3) return row == 0 || row == 6 ? 30 : row == 3 ? 14 : 1;
    if (digit == 4) return row == 0 ? 2 : row == 1 ? 6 : row == 2 ? 10 : row == 3 ? 18 : row == 4 ? 31 : 2;
    if (digit == 5) return row == 0 ? 31 : row == 1 || row == 2 ? 16 : row == 3 ? 30 : row == 6 ? 30 : 1;
    if (digit == 6) return row == 0 || row == 6 ? 14 : row == 1 || row == 2 ? 16 : row == 3 ? 30 : 17;
    if (digit == 7) return row == 0 ? 31 : row == 1 ? 1 : row == 2 ? 2 : row == 3 ? 4 : 8;
    if (digit == 8) return row == 0 || row == 3 || row == 6 ? 14 : 17;
    return row == 0 || row == 6 ? 14 : row == 1 || row == 2 ? 17 : row == 3 ? 15 : 1;
  }
  if (code == 65) return row == 0 ? 14 : row == 3 ? 31 : 17; // A
  if (code == 66) return row == 0 || row == 3 || row == 6 ? 30 : 17; // B
  if (code == 68) return row == 0 || row == 6 ? 30 : 17; // D
  if (code == 69) return row == 0 || row == 3 || row == 6 ? 31 : 16; // E
  if (code == 70) return row == 0 || row == 3 ? 31 : row == 6 ? 16 : 16; // F
  if (code == 72) return row == 3 ? 31 : 17; // H
  if (code == 73) return row == 0 || row == 6 ? 31 : 4; // I
  if (code == 76) return row == 6 ? 31 : 16; // L
  if (code == 77) return row == 0 ? 17 : row == 1 ? 27 : row == 2 ? 21 : 17; // M
  if (code == 78) return row == 0 ? 17 : row == 1 ? 25 : row == 2 ? 21 : row == 3 ? 19 : 17; // N
  if (code == 79) return row == 0 || row == 6 ? 14 : 17; // O
  if (code == 80) return row == 0 || row == 3 ? 30 : row < 3 ? 17 : 16; // P
  if (code == 82) return row == 0 || row == 3 ? 30 : row < 3 ? 17 : row == 4 ? 20 : row == 5 ? 18 : 17; // R
  if (code == 83) return row == 0 || row == 3 || row == 6 ? 15 : row < 3 ? 16 : 1; // S
  if (code == 84) return row == 0 ? 31 : 4; // T
  if (code == 85) return row == 6 ? 14 : 17; // U
  if (code == 86) return row < 5 ? 17 : row == 5 ? 10 : 4; // V
  if (code == 87) return row < 4 ? 17 : row == 4 ? 21 : row == 5 ? 27 : 17; // W
  if (code == 89) return row < 3 ? 17 : row == 3 ? 10 : 4; // Y
  if (code == 47) return 1 << (4 - (row * 4 / 7));
  if (code == 37) return row == 0 || row == 6 ? 17 : row == 1 || row == 5 ? 2 : row == 2 || row == 4 ? 4 : 8;
  if (code == 45) return row == 3 ? 31 : 0;
  return 0;
}

function glyphHit(px: i32, py: i32, x: i32, y: i32, code: i32): bool {
  const gx: i32 = px - x;
  const gy: i32 = py - y;
  if (gx < 0 || gx >= 5 || gy < 0 || gy >= 7) return false;
  return (glyphRow(code, gy) & (16 >> gx)) != 0;
}

function numberGlyphHit(px: i32, py: i32, x: i32, y: i32, value: i32, digits: i32): bool {
  let divisor: i32 = digits == 4 ? 1000 : digits == 3 ? 100 : digits == 2 ? 10 : 1;
  for (let place: i32 = 0; place < digits; place++) {
    const digit: i32 = (value / divisor) % 10;
    if (glyphHit(px, py, x + place * 6, y, 48 + digit)) return true;
    divisor /= 10;
  }
  return false;
}

function fixedLabelHit(px: i32, py: i32, x: i32, y: i32, label: i32): bool {
  // 0 PBF, 1 HYDRO, 3 STEP, 4 E, 5 VIEW, 6 BEAUTY, 7 DENS,
  // 8 LAMBDA, 9 VEL, 10 NBRS, 11 N.
  if (label == 0) return glyphHit(px, py, x, y, 80) || glyphHit(px, py, x + 6, y, 66) || glyphHit(px, py, x + 12, y, 70);
  if (label == 1) return glyphHit(px, py, x, y, 72) || glyphHit(px, py, x + 6, y, 89) || glyphHit(px, py, x + 12, y, 68) || glyphHit(px, py, x + 18, y, 82) || glyphHit(px, py, x + 24, y, 79);
  if (label == 3) return glyphHit(px, py, x, y, 83) || glyphHit(px, py, x + 6, y, 84) || glyphHit(px, py, x + 12, y, 69) || glyphHit(px, py, x + 18, y, 80);
  if (label == 4) return glyphHit(px, py, x, y, 69);
  if (label == 5) return glyphHit(px, py, x, y, 86) || glyphHit(px, py, x + 6, y, 73) || glyphHit(px, py, x + 12, y, 69) || glyphHit(px, py, x + 18, y, 87);
  if (label == 6) return glyphHit(px, py, x, y, 66) || glyphHit(px, py, x + 6, y, 69) || glyphHit(px, py, x + 12, y, 65) || glyphHit(px, py, x + 18, y, 85) || glyphHit(px, py, x + 24, y, 84) || glyphHit(px, py, x + 30, y, 89);
  if (label == 7) return glyphHit(px, py, x, y, 68) || glyphHit(px, py, x + 6, y, 69) || glyphHit(px, py, x + 12, y, 78) || glyphHit(px, py, x + 18, y, 83);
  if (label == 8) return glyphHit(px, py, x, y, 76) || glyphHit(px, py, x + 6, y, 65) || glyphHit(px, py, x + 12, y, 77) || glyphHit(px, py, x + 18, y, 66) || glyphHit(px, py, x + 24, y, 68) || glyphHit(px, py, x + 30, y, 65);
  if (label == 9) return glyphHit(px, py, x, y, 86) || glyphHit(px, py, x + 6, y, 69) || glyphHit(px, py, x + 12, y, 76);
  if (label == 10) return glyphHit(px, py, x, y, 78) || glyphHit(px, py, x + 6, y, 66) || glyphHit(px, py, x + 12, y, 82) || glyphHit(px, py, x + 18, y, 83);
  return glyphHit(px, py, x, y, 78);
}

function hudHit(px: i32, py: i32, view: i32, step: i32, phase: i32): bool {
  let hit: bool = fixedLabelHit(px, py, 7, 7, 0);
  hit = hit || fixedLabelHit(px, py, 7, 16, 1);
  hit = hit || fixedLabelHit(px, py, 7, 27, 3);
  hit = hit || numberGlyphHit(px, py, 34, 27, step % 1000, 3);
  hit = hit || glyphHit(px, py, 54, 36, 80) || glyphHit(px, py, 60, 36, 48 + phase);
  hit = hit || fixedLabelHit(px, py, 7, 36, 4);
  const rawMeanError: i32 = load<i32>(MEAN_ERROR_OFFSET);
  const rawMaxError: i32 = load<i32>(MAX_ERROR_OFFSET);
  const meanError: i32 = rawMeanError < 0 ? 0 : rawMeanError > 99 ? 99 : rawMeanError;
  const maxError: i32 = rawMaxError < 0 ? 0 : rawMaxError > 99 ? 99 : rawMaxError;
  hit = hit || numberGlyphHit(px, py, 16, 36, meanError, 2);
  hit = hit || glyphHit(px, py, 29, 36, 47);
  hit = hit || numberGlyphHit(px, py, 35, 36, maxError, 2);
  hit = hit || glyphHit(px, py, 48, 36, 37);
  hit = hit || fixedLabelHit(px, py, 7, 45, 11);
  hit = hit || numberGlyphHit(px, py, 16, 45, FLUID_COUNT, 4);
  hit = hit || fixedLabelHit(px, py, 221, 7, 5);
  const viewLabel: i32 = view == 0 ? 6 : view == 1 ? 7 : view == 2 ? 8 : view == 3 ? 9 : 10;
  hit = hit || fixedLabelHit(px, py, view == 2 ? 215 : view == 0 ? 215 : 227, 17, viewLabel);
  return hit;
}

function updatePointerControls(pointerX: i32, pointerY: i32, buttons: i32): void {
  const previousButtons: i32 = load<i32>(PREVIOUS_BUTTONS_OFFSET);
  if (buttons != 0 && pointerX >= 0 && pointerY >= 0) {
    if (pointerX >= 208 && pointerY <= 34) {
      if (previousButtons == 0) {
        store<i32>(VIEW_MODE_OFFSET, (load<i32>(VIEW_MODE_OFFSET) + 1) % VIEW_COUNT);
      }
    } else {
      const yaw: f32 = (<f32>pointerX / 255.0 - 0.5) * 2.5;
      const pitch: f32 = clampF((0.5 - <f32>pointerY / 255.0) * 1.05, -0.46, 0.46);
      store<f32>(CAMERA_YAW_OFFSET, yaw);
      store<f32>(CAMERA_PITCH_OFFSET, pitch);
    }
  }
  store<i32>(PREVIOUS_BUTTONS_OFFSET, buttons);
}

function renderPixel(pixel: i32, displayBase: i32, view: i32, step: i32, phase: i32, resetting: bool): void {
  const px: i32 = pixel & 255;
  const py: i32 = pixel >> 8;
  const screenX: f32 = (<f32>px + 0.5) / 128.0 - 1.0;
  const screenY: f32 = 1.0 - (<f32>py + 0.5) / 128.0;
  const yaw: f32 = load<f32>(CAMERA_YAW_OFFSET);
  const pitch: f32 = load<f32>(CAMERA_PITCH_OFFSET);
  const cy: f32 = cosF(yaw);
  const sy: f32 = sinF(yaw);
  const cp: f32 = cosF(pitch);
  const sp: f32 = sinF(pitch);
  const cameraX: f32 = sy * cp * 3.55;
  const cameraY: f32 = 0.02 + sp * 3.55;
  const cameraZ: f32 = -cy * cp * 3.55;
  let forwardX: f32 = -cameraX;
  let forwardY: f32 = -0.08 - cameraY;
  let forwardZ: f32 = -cameraZ;
  const forwardLength: f32 = Mathf.sqrt(forwardX * forwardX + forwardY * forwardY + forwardZ * forwardZ);
  forwardX /= forwardLength;
  forwardY /= forwardLength;
  forwardZ /= forwardLength;
  let rightX: f32 = -forwardZ;
  let rightZ: f32 = forwardX;
  const rightLength: f32 = Mathf.sqrt(rightX * rightX + rightZ * rightZ);
  rightX /= rightLength;
  rightZ /= rightLength;
  const upX: f32 = -forwardY * rightZ;
  const upY: f32 = rightZ * forwardX - rightX * forwardZ;
  const upZ: f32 = forwardY * rightX;
  const tanFov: f32 = 0.67;

  const rayX0: f32 = forwardX + rightX * screenX * tanFov + upX * screenY * tanFov;
  const rayY0: f32 = forwardY + upY * screenY * tanFov;
  const rayZ0: f32 = forwardZ + rightZ * screenX * tanFov + upZ * screenY * tanFov;
  const rayLength: f32 = Mathf.sqrt(rayX0 * rayX0 + rayY0 * rayY0 + rayZ0 * rayZ0);
  const rayX: f32 = rayX0 / rayLength;
  const rayY: f32 = rayY0 / rayLength;
  const rayZ: f32 = rayZ0 / rayLength;

  let red: f32 = 0.025 + <f32>py / 255.0 * 0.030;
  let green: f32 = 0.040 + <f32>py / 255.0 * 0.045;
  let blue: f32 = 0.070 + <f32>py / 255.0 * 0.070;

  if (rayY < -0.0001) {
    const floorT: f32 = (DOMAIN_MIN_Y - cameraY) / rayY;
    if (floorT > 0.0) {
      const floorX: f32 = cameraX + rayX * floorT;
      const floorZ: f32 = cameraZ + rayZ * floorT;
      if (absF(floorX) < 1.30 && absF(floorZ) < 0.90) {
        const gridX: f32 = absF((floorX + 1.2) / 0.2 - Mathf.floor((floorX + 1.2) / 0.2 + 0.5));
        const gridZ: f32 = absF((floorZ + 0.8) / 0.2 - Mathf.floor((floorZ + 0.8) / 0.2 + 0.5));
        const grid: f32 = gridX < 0.035 || gridZ < 0.035 ? 0.085 : 0.0;
        red = 0.055 + grid;
        green = 0.075 + grid;
        blue = 0.105 + grid * 1.25;
      }
    }
  }

  let obstacleDepth: f32 = 10000.0;
  const obstacleDX: f32 = cameraX - OBSTACLE_X;
  const obstacleDY: f32 = cameraY - OBSTACLE_Y;
  const obstacleDZ: f32 = cameraZ - OBSTACLE_Z;
  const obstacleB: f32 = obstacleDX * rayX + obstacleDY * rayY + obstacleDZ * rayZ;
  const obstacleC: f32 = obstacleDX * obstacleDX + obstacleDY * obstacleDY + obstacleDZ * obstacleDZ - OBSTACLE_RADIUS * OBSTACLE_RADIUS;
  const obstacleDiscriminant: f32 = obstacleB * obstacleB - obstacleC;
  if (obstacleDiscriminant >= 0.0) {
    const hitDepth: f32 = -obstacleB - Mathf.sqrt(obstacleDiscriminant);
    if (hitDepth > 0.0) {
      obstacleDepth = hitDepth;
      const hitX: f32 = cameraX + rayX * hitDepth;
      const hitY: f32 = cameraY + rayY * hitDepth;
      const hitZ: f32 = cameraZ + rayZ * hitDepth;
      const normalX: f32 = (hitX - OBSTACLE_X) / OBSTACLE_RADIUS;
      const normalY: f32 = (hitY - OBSTACLE_Y) / OBSTACLE_RADIUS;
      const normalZ: f32 = (hitZ - OBSTACLE_Z) / OBSTACLE_RADIUS;
      const obstacleLight: f32 = saturate(0.30 - normalX * 0.28 + normalY * 0.62 - normalZ * 0.34);
      const obstacleRim: f32 = (1.0 - saturate(-(normalX * rayX + normalY * rayY + normalZ * rayZ))) * 0.18;
      red = 0.20 + obstacleLight * 0.48 + obstacleRim;
      green = 0.075 + obstacleLight * 0.20 + obstacleRim * 0.45;
      blue = 0.035 + obstacleLight * 0.08 + obstacleRim * 0.25;
    }
  }

  let bestDepth: f32 = 10000.0;
  let bestParticle: i32 = -1;
  let bestWeight: f32 = 0.0;
  let bestNX: f32 = 0.0;
  let bestNY: f32 = 0.0;
  let metaballField: f32 = 0.0;
  let metaballNX: f32 = 0.0;
  let metaballNY: f32 = 0.0;
  const renderRadius: f32 = 0.125;
  for (let j: i32 = 0; j < FLUID_COUNT; j++) {
    const particleX: f32 = resetting ? initialFluidX(j) : loadX(displayBase, j);
    const particleY: f32 = resetting ? initialFluidY(j) : loadY(displayBase, j);
    const particleZ: f32 = resetting ? initialFluidZ(j) : loadZ(displayBase, j);
    const relX: f32 = particleX - cameraX;
    const relY: f32 = particleY - cameraY;
    const relZ: f32 = particleZ - cameraZ;
    const depth: f32 = relX * forwardX + relY * forwardY + relZ * forwardZ;
    if (depth > 0.1) {
      const projectedX: f32 = (relX * rightX + relZ * rightZ) / (depth * tanFov);
      const projectedY: f32 = (relX * upX + relY * upY + relZ * upZ) / (depth * tanFov);
      const radius: f32 = renderRadius / (depth * tanFov);
      const dx: f32 = screenX - projectedX;
      const dy: f32 = screenY - projectedY;
      const d2: f32 = dx * dx + dy * dy;
      if (d2 < radius * radius) {
        const radial: f32 = d2 / (radius * radius);
        const weight: f32 = (1.0 - radial) * (1.0 - radial);
        if (view == VIEW_BEAUTY) {
          metaballField += weight;
          metaballNX += dx / radius * weight;
          metaballNY += dy / radius * weight;
        }
        const surfaceDepth: f32 = depth - renderRadius * Mathf.sqrt(1.0 - radial);
        if (surfaceDepth < bestDepth) {
          bestDepth = surfaceDepth;
          bestParticle = j;
          bestWeight = weight;
          bestNX = dx / radius;
          bestNY = dy / radius;
        }
      }
    }
  }

  if (bestParticle >= 0 && bestDepth < obstacleDepth && (view != VIEW_BEAUTY || metaballField > 0.04)) {
    let surfaceNX: f32 = bestNX;
    let surfaceNY: f32 = bestNY;
    if (view == VIEW_BEAUTY) {
      surfaceNX = metaballNX / metaballField;
      surfaceNY = metaballNY / metaballField;
    }
    const normal2: f32 = surfaceNX * surfaceNX + surfaceNY * surfaceNY;
    if (normal2 > 0.96) {
      const normalScale: f32 = Mathf.sqrt(0.96 / normal2);
      surfaceNX *= normalScale;
      surfaceNY *= normalScale;
    }
    const nz: f32 = Mathf.sqrt(Mathf.max(0.0, 1.0 - surfaceNX * surfaceNX - surfaceNY * surfaceNY));
    const diffuse: f32 = saturate(0.35 - surfaceNX * 0.32 + surfaceNY * 0.46 + nz * 0.68);
    if (view == VIEW_BEAUTY) {
      const height: f32 = resetting ? initialFluidY(bestParticle) : loadY(displayBase, bestParticle);
      const heightTone: f32 = saturate((height - DOMAIN_MIN_Y) / (DOMAIN_MAX_Y - DOMAIN_MIN_Y));
      const alpha: f32 = saturate((metaballField - 0.04) * 4.5);
      const fresnel: f32 = (1.0 - nz) * (1.0 - nz);
      let liquidRed: f32 = 0.035 + diffuse * 0.12 + heightTone * 0.025 + fresnel * 0.10;
      let liquidGreen: f32 = 0.23 + diffuse * 0.42 + heightTone * 0.08 + fresnel * 0.18;
      let liquidBlue: f32 = 0.43 + diffuse * 0.50 + heightTone * 0.06 + fresnel * 0.25;
      const highlight: f32 = nz > 0.86 ? (nz - 0.86) * 2.8 : 0.0;
      liquidRed += highlight * 0.55;
      liquidGreen += highlight * 0.65;
      liquidBlue += highlight * 0.72;
      red = red * (1.0 - alpha) + liquidRed * alpha;
      green = green * (1.0 - alpha) + liquidGreen * alpha;
      blue = blue * (1.0 - alpha) + liquidBlue * alpha;
    } else {
      const edge: f32 = 0.48 + bestWeight * 0.52;
      const value: f32 = propertyValue(view, bestParticle);
      red = colorRamp(value, 0) * (0.38 + diffuse * 0.62) * edge;
      green = colorRamp(value, 1) * (0.38 + diffuse * 0.62) * edge;
      blue = colorRamp(value, 2) * (0.38 + diffuse * 0.62) * edge;
    }
  }

  const panel: bool = (px < 74 && py < 56) || (px >= 208 && py < 35);
  if (panel) {
    red = red * 0.35 + 0.025;
    green = green * 0.35 + 0.040;
    blue = blue * 0.35 + 0.070;
  }
  if (hudHit(px, py, view, step, phase)) {
    red = 0.76;
    green = 0.91;
    blue = 1.0;
  }

  if (view != VIEW_BEAUTY && py >= 242 && px >= 48 && px < 208) {
    const value: f32 = <f32>(px - 48) / 159.0;
    red = colorRamp(value, 0);
    green = colorRamp(value, 1);
    blue = colorRamp(value, 2);
  }

  const output: i32 = OUTPUT_OFFSET + pixel * 12;
  store<i32>(output, <i32>(Mathf.sqrt(saturate(red)) * 255.0));
  store<i32>(output + 4, <i32>(Mathf.sqrt(saturate(green)) * 255.0));
  store<i32>(output + 8, <i32>(Mathf.sqrt(saturate(blue)) * 255.0));
}

export function main(): void {
  const frame: i32 = <i32>load<f32>(0);
  const pointerX: i32 = load<i32>(4);
  const pointerY: i32 = load<i32>(8);
  const pointerButtons: i32 = load<i32>(12);
  const benchmarkSteps: i32 = HYDRO_STEPS;
  const cycleFrames: i32 = 1 + benchmarkSteps * PHASES_PER_STEP + HOLD_FRAMES;
  const cycleFrame: i32 = frame % cycleFrames;
  // Reset is derived only from the uniform stepped frame. Reading MAGIC here
  // would race with invocation zero writing it during the reset dispatch.
  const resetting: bool = cycleFrame == 0;
  const activeFrame: i32 = cycleFrame - 1;
  const active: bool = activeFrame >= 0 && activeFrame < benchmarkSteps * PHASES_PER_STEP;
  const unclampedStep: i32 = activeFrame < 0 ? 0 : activeFrame / PHASES_PER_STEP;
  const step: i32 = unclampedStep > benchmarkSteps ? benchmarkSteps : unclampedStep;
  const phase: i32 = active ? activeFrame % PHASES_PER_STEP : 9;
  const committedRead: i32 = (step & 1) == 0 ? COMMITTED_POS : COMMITTED_ALT;
  const committedWrite: i32 = (step & 1) == 0 ? COMMITTED_ALT : COMMITTED_POS;
  const finalCommitted: i32 = (benchmarkSteps & 1) == 0 ? COMMITTED_POS : COMMITTED_ALT;
  const displayBase: i32 = active ? simulationDisplayBase(phase, committedRead) : finalCommitted;
  const testMode: i32 = load<i32>(TEST_MODE_OFFSET);

  for (let i: i32 = 0; i < WIDTH * HEIGHT; i++) {
    if (resetting) {
      if (i < FLUID_COUNT) seedState(i);
      if (i < BOUNDARY_COUNT) store<f32>(BOUNDARY_PSI + i * 4, calibrateBoundaryPsi(i));
      if (i == 0) {
        store<i32>(MAGIC_OFFSET, MAGIC);
        store<i32>(MEAN_ERROR_OFFSET, 0);
        store<i32>(MAX_ERROR_OFFSET, 0);
        if (load<f32>(CAMERA_YAW_OFFSET) == 0.0) store<f32>(CAMERA_YAW_OFFSET, -0.55);
        if (load<f32>(CAMERA_PITCH_OFFSET) == 0.0) store<f32>(CAMERA_PITCH_OFFSET, 0.20);
      }
    } else if (active && i < FLUID_COUNT) {
      if (phase == 0) {
        predictParticle(committedRead, i);
      } else if (phase == 1 || phase == 3 || phase == 5 || phase == 7) {
        const lambdaBase: i32 = phase == 1 || phase == 5 ? POSITION_A : POSITION_B;
        solveDensityLambda(lambdaBase, i);
      } else if (phase == 2) {
        correctParticle(POSITION_A, POSITION_B, i);
      } else if (phase == 4) {
        correctParticle(POSITION_B, POSITION_A, i);
      } else if (phase == 6) {
        correctParticle(POSITION_A, POSITION_B, i);
      } else if (phase == 8) {
        correctParticle(POSITION_B, POSITION_A, i);
      } else {
        finalizeParticle(committedRead, committedWrite, i);
      }
      if ((phase == 2 || phase == 4 || phase == 6 || phase == 8) && i == 0) updateDensityMetrics();
    }

    if (i == 0) updatePointerControls(pointerX, pointerY, pointerButtons);
    if (testMode == 0) {
      const currentView: i32 = load<i32>(VIEW_MODE_OFFSET);
      renderPixel(i, displayBase, currentView, step, phase, resetting);
    }
  }
}
