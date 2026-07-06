// ============================================================
// Progressive Path Tracer - persistent per-cell accumulation
// ============================================================
// A 128x128 tracer accumulates RGB radiance sums and an f32 sample count
// in GPU-resident memory. Each work item owns one cell and writes a
// 2x2 output block, avoiding races while retaining the 256x256 UI.
// Recompile to clear the accumulation and begin a fresh render.
// ============================================================

const WIDTH: i32 = 256;
const FIELD: i32 = 128;
const CELLS: i32 = FIELD * FIELD;
const STATE_OFFSET: i32 = 16 + WIDTH * WIDTH * 12;
const MAGIC_OFFSET: i32 = STATE_OFFSET;
const SUM_OFFSET: i32 = STATE_OFFSET + 16;
const COUNT_OFFSET: i32 = SUM_OFFSET + CELLS * 12;
const MAGIC: i32 = 1347702868; // PAT4
const INF: f32 = 100000.0;
const EPSILON: f32 = 0.002;

function clampF(value: f32, low: f32, high: f32): f32 {
  return Mathf.min(Mathf.max(value, low), high);
}

function hashU(value: u32): u32 {
  let state: u32 = value * 747796405 + 2891336453;
  const word: u32 = ((state >> ((state >> 28) + 4)) ^ state) * 277803737;
  return (word >> 22) ^ word;
}

function randomF(value: u32): f32 {
  return <f32>value / 4294967296.0;
}

function sphereHit(
  ox: f32, oy: f32, oz: f32,
  dx: f32, dy: f32, dz: f32,
  cx: f32, cy: f32, cz: f32, radius: f32,
): f32 {
  const ex: f32 = ox - cx;
  const ey: f32 = oy - cy;
  const ez: f32 = oz - cz;
  const b: f32 = ex * dx + ey * dy + ez * dz;
  const c: f32 = ex * ex + ey * ey + ez * ez - radius * radius;
  const discriminant: f32 = b * b - c;
  if (discriminant < 0.0) return -1.0;
  const root: f32 = Mathf.sqrt(discriminant);
  let t: f32 = -b - root;
  if (t < EPSILON) t = -b + root;
  return t < EPSILON ? -1.0 : t;
}

function writeBlock(cellX: i32, cellY: i32, r: i32, g: i32, b: i32): void {
  const x: i32 = cellX * 2;
  const y: i32 = cellY * 2;
  for (let oy: i32 = 0; oy < 2; oy++) {
    for (let ox: i32 = 0; ox < 2; ox++) {
      const pixel: i32 = (y + oy) * WIDTH + x + ox;
      const offset: i32 = 16 + pixel * 12;
      store<i32>(offset, r);
      store<i32>(offset + 4, g);
      store<i32>(offset + 8, b);
    }
  }
}

export function main(): void {
  const frame: i32 = <i32>load<f32>(0);
  const initialized: bool = load<i32>(MAGIC_OFFSET) == MAGIC;

  for (let i: i32 = 0; i < WIDTH * WIDTH; i++) {
    if (i >= CELLS) continue;

    const cellX: i32 = i & 127;
    const cellY: i32 = i >> 7;
    const countAddress: i32 = COUNT_OFFSET + i * 4;
    const sumAddress: i32 = SUM_OFFSET + i * 12;
    const oldCountF: f32 = initialized ? load<f32>(countAddress) : 0.0;
    const oldCount: i32 = <i32>oldCountF;
    let seed: u32 = <u32>(cellX * 1973 + cellY * 9277 + (oldCount + 1) * 26699 + frame * 17) | 1;
    seed = hashU(seed);
    const jitterX: f32 = randomF(seed) - 0.5;
    seed = hashU(seed);
    const jitterY: f32 = randomF(seed) - 0.5;

    const screenX: f32 = ((<f32>cellX + 0.5 + jitterX) / <f32>FIELD) * 2.0 - 1.0;
    const screenY: f32 = 1.0 - ((<f32>cellY + 0.5 + jitterY) / <f32>FIELD) * 2.0;
    let ox: f32 = 0.0;
    let oy: f32 = 0.12;
    let oz: f32 = -3.8;
    let dx: f32 = screenX * 0.78;
    let dy: f32 = screenY * 0.78 - 0.03;
    let dz: f32 = 1.0;
    let rayLength: f32 = Mathf.sqrt(dx * dx + dy * dy + dz * dz);
    dx /= rayLength;
    dy /= rayLength;
    dz /= rayLength;

    let radianceR: f32 = 0.0;
    let radianceG: f32 = 0.0;
    let radianceB: f32 = 0.0;
    let throughputR: f32 = 1.0;
    let throughputG: f32 = 1.0;
    let throughputB: f32 = 1.0;

    for (let bounce: i32 = 0; bounce < 4; bounce++) {
      let bestT: f32 = INF;
      let material: i32 = -1;
      let nx: f32 = 0.0;
      let ny: f32 = 0.0;
      let nz: f32 = 0.0;
      let albedoR: f32 = 0.0;
      let albedoG: f32 = 0.0;
      let albedoB: f32 = 0.0;

      if (dy < -0.0001) {
        const planeT: f32 = (-1.0 - oy) / dy;
        if (planeT > EPSILON && planeT < bestT) {
          bestT = planeT;
          material = 0;
          nx = 0.0; ny = 1.0; nz = 0.0;
          const hx: f32 = ox + dx * planeT;
          const hz: f32 = oz + dz * planeT;
          const checker: i32 = (<i32>Mathf.floor(hx * 1.4) ^ <i32>Mathf.floor(hz * 1.4)) & 1;
          albedoR = checker == 0 ? 0.72 : 0.16;
          albedoG = checker == 0 ? 0.68 : 0.19;
          albedoB = checker == 0 ? 0.58 : 0.24;
        }
      }

      let hitT: f32 = sphereHit(ox, oy, oz, dx, dy, dz, -0.82, -0.20, 0.25, 0.80);
      if (hitT > 0.0 && hitT < bestT) {
        bestT = hitT;
        material = 1;
        const hx: f32 = ox + dx * hitT + 0.82;
        const hy: f32 = oy + dy * hitT + 0.20;
        const hz: f32 = oz + dz * hitT - 0.25;
        nx = hx / 0.80; ny = hy / 0.80; nz = hz / 0.80;
        albedoR = 0.92; albedoG = 0.18; albedoB = 0.08;
      }

      hitT = sphereHit(ox, oy, oz, dx, dy, dz, 0.78, -0.42, 0.58, 0.58);
      if (hitT > 0.0 && hitT < bestT) {
        bestT = hitT;
        material = 2;
        const hx: f32 = ox + dx * hitT - 0.78;
        const hy: f32 = oy + dy * hitT + 0.42;
        const hz: f32 = oz + dz * hitT - 0.58;
        nx = hx / 0.58; ny = hy / 0.58; nz = hz / 0.58;
        albedoR = 0.72; albedoG = 0.86; albedoB = 0.98;
      }

      hitT = sphereHit(ox, oy, oz, dx, dy, dz, 0.05, 1.75, 0.45, 0.48);
      if (hitT > 0.0 && hitT < bestT) {
        bestT = hitT;
        material = 3;
        const hx: f32 = ox + dx * hitT - 0.05;
        const hy: f32 = oy + dy * hitT - 1.75;
        const hz: f32 = oz + dz * hitT - 0.45;
        nx = hx / 0.48; ny = hy / 0.48; nz = hz / 0.48;
      }

      if (material < 0) {
        const sky: f32 = clampF(0.5 + 0.5 * dy, 0.0, 1.0);
        radianceR += throughputR * (0.08 + sky * 0.16);
        radianceG += throughputG * (0.10 + sky * 0.20);
        radianceB += throughputB * (0.16 + sky * 0.34);
        break;
      }

      const hitX: f32 = ox + dx * bestT;
      const hitY: f32 = oy + dy * bestT;
      const hitZ: f32 = oz + dz * bestT;
      ox = hitX + nx * EPSILON;
      oy = hitY + ny * EPSILON;
      oz = hitZ + nz * EPSILON;

      if (material == 3) {
        radianceR += throughputR * 7.5;
        radianceG += throughputG * 5.8;
        radianceB += throughputB * 3.6;
        break;
      }

      throughputR *= albedoR;
      throughputG *= albedoG;
      throughputB *= albedoB;

      if (material == 2) {
        const dot: f32 = dx * nx + dy * ny + dz * nz;
        dx -= 2.0 * dot * nx;
        dy -= 2.0 * dot * ny;
        dz -= 2.0 * dot * nz;
      } else {
        seed = hashU(seed);
        let rx: f32 = randomF(seed) * 2.0 - 1.0;
        seed = hashU(seed);
        let ry: f32 = randomF(seed) * 2.0 - 1.0;
        seed = hashU(seed);
        let rz: f32 = randomF(seed) * 2.0 - 1.0;
        let randomLength: f32 = Mathf.sqrt(rx * rx + ry * ry + rz * rz);
        if (randomLength < 0.001) randomLength = 1.0;
        rx /= randomLength; ry /= randomLength; rz /= randomLength;
        if (rx * nx + ry * ny + rz * nz < 0.0) {
          rx = -rx; ry = -ry; rz = -rz;
        }
        dx = nx + rx;
        dy = ny + ry;
        dz = nz + rz;
        rayLength = Mathf.sqrt(dx * dx + dy * dy + dz * dz);
        dx /= rayLength; dy /= rayLength; dz /= rayLength;
      }
    }

    const oldR: f32 = initialized ? load<f32>(sumAddress) : 0.0;
    const oldG: f32 = initialized ? load<f32>(sumAddress + 4) : 0.0;
    const oldB: f32 = initialized ? load<f32>(sumAddress + 8) : 0.0;
    const sumR: f32 = oldR + radianceR;
    const sumG: f32 = oldG + radianceG;
    const sumB: f32 = oldB + radianceB;
    const newCount: f32 = oldCountF + 1.0;
    const averageR: f32 = sumR / newCount;
    const averageG: f32 = sumG / newCount;
    const averageB: f32 = sumB / newCount;

    store<f32>(sumAddress, sumR);
    store<f32>(sumAddress + 4, sumG);
    store<f32>(sumAddress + 8, sumB);
    store<f32>(countAddress, newCount);
    if (i == 0 && !initialized) store<i32>(MAGIC_OFFSET, MAGIC);

    const mappedR: f32 = Mathf.sqrt(clampF(averageR / (1.0 + averageR), 0.0, 1.0));
    const mappedG: f32 = Mathf.sqrt(clampF(averageG / (1.0 + averageG), 0.0, 1.0));
    const mappedB: f32 = Mathf.sqrt(clampF(averageB / (1.0 + averageB), 0.0, 1.0));
    writeBlock(
      cellX,
      cellY,
      <i32>(mappedR * 255.0),
      <i32>(mappedG * 255.0),
      <i32>(mappedB * 255.0),
    );
  }
}
