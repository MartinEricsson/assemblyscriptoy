// ============================================================
//  Cable Drop Lab - Verlet ropes draped over a cylinder
// ============================================================
//  Nine independent cables fall under gravity and settle over a
//  horizontal cylinder. Positions live in Wasm linear memory and the
//  solver advances in five race-free dispatches: Verlet prediction,
//  three Jacobi distance projections, and commit.
//
//  Rendering is analytic rather than host-assisted. Rays intersect the
//  simulated cable capsules, finite cylinder, and floor directly. Two
//  area-light samples provide soft shadows, while contact-aware ambient
//  occlusion grounds the cable bundle against the cylinder and floor.
//  The entire simulation and renderer are compiled AS -> Wasm -> WGSL.
// ============================================================

const WIDTH: i32 = 256;
const HEIGHT: i32 = 256;
const PIXELS: i32 = WIDTH * HEIGHT;
const OUTPUT_OFFSET: i32 = 16;
const STATE_OFFSET: i32 = OUTPUT_OFFSET + PIXELS * 12;

const MAGIC: i32 = 1128352837; // CABE
const MAGIC_OFFSET: i32 = STATE_OFFSET;
const HEADER_BYTES: i32 = 32;

const ROPE_COUNT: i32 = 9;
const NODES_PER_ROPE: i32 = 24;
const NODE_COUNT: i32 = ROPE_COUNT * NODES_PER_ROPE;
const SEGMENT_COUNT: i32 = ROPE_COUNT * (NODES_PER_ROPE - 1);
const VEC3_BYTES: i32 = NODE_COUNT * 12;

const CURRENT_POS: i32 = STATE_OFFSET + HEADER_BYTES;
const PREVIOUS_POS: i32 = CURRENT_POS + VEC3_BYTES;
const SOLVE_A: i32 = PREVIOUS_POS + VEC3_BYTES;
const SOLVE_B: i32 = SOLVE_A + VEC3_BYTES;

const PI: f32 = 3.14159265;
const TWO_PI: f32 = 6.28318530;
const REST_LENGTH: f32 = 0.148;
const CABLE_RADIUS: f32 = 0.052;
const DT: f32 = 0.034;
const GRAVITY: f32 = -9.81;
const DAMPING: f32 = 0.992;
const PHASES: i32 = 5;
const RESET_FRAMES: i32 = 900;

const FLOOR_Y: f32 = -1.12;
const CYLINDER_Y: f32 = -0.36;
const CYLINDER_RADIUS: f32 = 0.62;
const CYLINDER_HALF_LENGTH: f32 = 1.38;

function clampF(value: f32, low: f32, high: f32): f32 {
  return Mathf.min(Mathf.max(value, low), high);
}

function saturate(value: f32): f32 {
  return clampF(value, 0.0, 1.0);
}

function smoothstep(low: f32, high: f32, value: f32): f32 {
  const t: f32 = saturate((value - low) / (high - low));
  return t * t * (3.0 - 2.0 * t);
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

function vecAddress(base: i32, node: i32, component: i32): i32 {
  return base + (node * 3 + component) * 4;
}

function loadX(base: i32, node: i32): f32 { return load<f32>(vecAddress(base, node, 0)); }
function loadY(base: i32, node: i32): f32 { return load<f32>(vecAddress(base, node, 1)); }
function loadZ(base: i32, node: i32): f32 { return load<f32>(vecAddress(base, node, 2)); }

function storeVec(base: i32, node: i32, x: f32, y: f32, z: f32): void {
  store<f32>(vecAddress(base, node, 0), x);
  store<f32>(vecAddress(base, node, 1), y);
  store<f32>(vecAddress(base, node, 2), z);
}

function initialX(node: i32): f32 {
  const point: i32 = node % NODES_PER_ROPE;
  const rope: i32 = node / NODES_PER_ROPE;
  const offset: f32 = (<f32>((rope * 7) % 5) - 2.0) * 0.018;
  return (<f32>point - 11.5) * REST_LENGTH + offset;
}

function initialY(node: i32): f32 {
  const point: i32 = node % NODES_PER_ROPE;
  const rope: i32 = node / NODES_PER_ROPE;
  const arch: f32 = 0.028 * (1.0 - Mathf.abs(<f32>point - 11.5) / 11.5);
  return 1.34 + <f32>(rope & 1) * 0.035 + arch;
}

function initialZ(node: i32): f32 {
  const rope: i32 = node / NODES_PER_ROPE;
  return (<f32>rope - 4.0) * 0.225;
}

function seedNode(node: i32): void {
  const x: f32 = initialX(node);
  const y: f32 = initialY(node);
  const z: f32 = initialZ(node);
  storeVec(CURRENT_POS, node, x, y, z);
  storeVec(PREVIOUS_POS, node, x, y, z);
  storeVec(SOLVE_A, node, x, y, z);
  storeVec(SOLVE_B, node, x, y, z);
}

function projectCollisions(x: f32, y: f32, z: f32, component: i32): f32 {
  let px: f32 = x;
  let py: f32 = Mathf.max(y, FLOOR_Y + CABLE_RADIUS);
  let pz: f32 = z;
  if (Mathf.abs(pz) < CYLINDER_HALF_LENGTH + CABLE_RADIUS) {
    const dx: f32 = px;
    const dy: f32 = py - CYLINDER_Y;
    const radius: f32 = CYLINDER_RADIUS + CABLE_RADIUS;
    const distance2: f32 = dx * dx + dy * dy;
    if (distance2 < radius * radius) {
      const distance: f32 = Mathf.sqrt(Mathf.max(distance2, 0.000001));
      const scale: f32 = radius / distance;
      px = dx * scale;
      py = CYLINDER_Y + dy * scale;
    }
  }
  if (component == 0) return px;
  if (component == 1) return py;
  return pz;
}

function integrateNode(node: i32): void {
  const x: f32 = loadX(CURRENT_POS, node);
  const y: f32 = loadY(CURRENT_POS, node);
  const z: f32 = loadZ(CURRENT_POS, node);
  const oldX: f32 = loadX(PREVIOUS_POS, node);
  const oldY: f32 = loadY(PREVIOUS_POS, node);
  const oldZ: f32 = loadZ(PREVIOUS_POS, node);
  const vx: f32 = (x - oldX) * DAMPING;
  const vy: f32 = (y - oldY) * DAMPING;
  const vz: f32 = (z - oldZ) * DAMPING;
  const nextX: f32 = x + vx;
  const nextY: f32 = y + vy + GRAVITY * DT * DT;
  const nextZ: f32 = z + vz;
  storeVec(
    SOLVE_A,
    node,
    projectCollisions(nextX, nextY, nextZ, 0),
    projectCollisions(nextX, nextY, nextZ, 1),
    projectCollisions(nextX, nextY, nextZ, 2),
  );
}

function solveNode(readBase: i32, writeBase: i32, node: i32): void {
  const local: i32 = node % NODES_PER_ROPE;
  let px: f32 = loadX(readBase, node);
  let py: f32 = loadY(readBase, node);
  let pz: f32 = loadZ(readBase, node);
  let cx: f32 = 0.0;
  let cy: f32 = 0.0;
  let cz: f32 = 0.0;

  if (local > 0) {
    const neighbor: i32 = node - 1;
    const dx: f32 = loadX(readBase, neighbor) - px;
    const dy: f32 = loadY(readBase, neighbor) - py;
    const dz: f32 = loadZ(readBase, neighbor) - pz;
    const distance: f32 = Mathf.sqrt(Mathf.max(dx * dx + dy * dy + dz * dz, 0.000001));
    const amount: f32 = 0.5 * (distance - REST_LENGTH) / distance;
    cx += dx * amount;
    cy += dy * amount;
    cz += dz * amount;
  }
  if (local < NODES_PER_ROPE - 1) {
    const neighbor: i32 = node + 1;
    const dx: f32 = loadX(readBase, neighbor) - px;
    const dy: f32 = loadY(readBase, neighbor) - py;
    const dz: f32 = loadZ(readBase, neighbor) - pz;
    const distance: f32 = Mathf.sqrt(Mathf.max(dx * dx + dy * dy + dz * dz, 0.000001));
    const amount: f32 = 0.5 * (distance - REST_LENGTH) / distance;
    cx += dx * amount;
    cy += dy * amount;
    cz += dz * amount;
  }

  px += cx * 0.92;
  py += cy * 0.92;
  pz += cz * 0.92;
  storeVec(
    writeBase,
    node,
    projectCollisions(px, py, pz, 0),
    projectCollisions(px, py, pz, 1),
    projectCollisions(px, py, pz, 2),
  );
}

function commitNode(node: i32): void {
  const x: f32 = loadX(CURRENT_POS, node);
  const y: f32 = loadY(CURRENT_POS, node);
  const z: f32 = loadZ(CURRENT_POS, node);
  storeVec(PREVIOUS_POS, node, x, y, z);
  storeVec(CURRENT_POS, node, loadX(SOLVE_B, node), loadY(SOLVE_B, node), loadZ(SOLVE_B, node));
}

function nodeX(base: i32, node: i32, resetting: bool): f32 {
  return resetting ? initialX(node) : loadX(base, node);
}

function nodeY(base: i32, node: i32, resetting: bool): f32 {
  return resetting ? initialY(node) : loadY(base, node);
}

function nodeZ(base: i32, node: i32, resetting: bool): f32 {
  return resetting ? initialZ(node) : loadZ(base, node);
}

function segmentNode(segment: i32): i32 {
  const rope: i32 = segment / (NODES_PER_ROPE - 1);
  const local: i32 = segment % (NODES_PER_ROPE - 1);
  return rope * NODES_PER_ROPE + local;
}

function raySphereT(
  ox: f32, oy: f32, oz: f32,
  dx: f32, dy: f32, dz: f32,
  cx: f32, cy: f32, cz: f32, radius: f32,
): f32 {
  const qx: f32 = ox - cx;
  const qy: f32 = oy - cy;
  const qz: f32 = oz - cz;
  const b: f32 = qx * dx + qy * dy + qz * dz;
  const c: f32 = qx * qx + qy * qy + qz * qz - radius * radius;
  const h: f32 = b * b - c;
  if (h < 0.0) return 9999.0;
  const root: f32 = Mathf.sqrt(h);
  const nearT: f32 = -b - root;
  if (nearT > 0.004) return nearT;
  const farT: f32 = -b + root;
  return farT > 0.004 ? farT : 9999.0;
}

function rayCapsuleT(
  ox: f32, oy: f32, oz: f32,
  dx: f32, dy: f32, dz: f32,
  ax: f32, ay: f32, az: f32,
  bx: f32, by: f32, bz: f32,
  radius: f32,
): f32 {
  const bax: f32 = bx - ax;
  const bay: f32 = by - ay;
  const baz: f32 = bz - az;
  const oax: f32 = ox - ax;
  const oay: f32 = oy - ay;
  const oaz: f32 = oz - az;
  const baba: f32 = bax * bax + bay * bay + baz * baz;
  const bard: f32 = bax * dx + bay * dy + baz * dz;
  const baoa: f32 = bax * oax + bay * oay + baz * oaz;
  const rdoa: f32 = dx * oax + dy * oay + dz * oaz;
  const oaoa: f32 = oax * oax + oay * oay + oaz * oaz;
  const qa: f32 = baba - bard * bard;
  const qb: f32 = baba * rdoa - baoa * bard;
  const qc: f32 = baba * oaoa - baoa * baoa - radius * radius * baba;
  const h: f32 = qb * qb - qa * qc;
  if (h >= 0.0 && Mathf.abs(qa) > 0.000001) {
    const t: f32 = (-qb - Mathf.sqrt(h)) / qa;
    const y: f32 = baoa + t * bard;
    if (t > 0.004 && y > 0.0 && y < baba) return t;
  }
  return Mathf.min(
    raySphereT(ox, oy, oz, dx, dy, dz, ax, ay, az, radius),
    raySphereT(ox, oy, oz, dx, dy, dz, bx, by, bz, radius),
  );
}

function rayCylinderT(ox: f32, oy: f32, oz: f32, dx: f32, dy: f32, dz: f32): f32 {
  const qy: f32 = oy - CYLINDER_Y;
  const a: f32 = dx * dx + dy * dy;
  const b: f32 = ox * dx + qy * dy;
  const c: f32 = ox * ox + qy * qy - CYLINDER_RADIUS * CYLINDER_RADIUS;
  let best: f32 = 9999.0;
  const h: f32 = b * b - a * c;
  if (h >= 0.0 && a > 0.000001) {
    const root: f32 = Mathf.sqrt(h);
    let t: f32 = (-b - root) / a;
    let z: f32 = oz + dz * t;
    if (t > 0.004 && Mathf.abs(z) <= CYLINDER_HALF_LENGTH) best = t;
    t = (-b + root) / a;
    z = oz + dz * t;
    if (t > 0.004 && t < best && Mathf.abs(z) <= CYLINDER_HALF_LENGTH) best = t;
  }
  if (Mathf.abs(dz) > 0.000001) {
    let t: f32 = (-CYLINDER_HALF_LENGTH - oz) / dz;
    let x: f32 = ox + dx * t;
    let y: f32 = qy + dy * t;
    if (t > 0.004 && t < best && x * x + y * y <= CYLINDER_RADIUS * CYLINDER_RADIUS) best = t;
    t = (CYLINDER_HALF_LENGTH - oz) / dz;
    x = ox + dx * t;
    y = qy + dy * t;
    if (t > 0.004 && t < best && x * x + y * y <= CYLINDER_RADIUS * CYLINDER_RADIUS) best = t;
  }
  return best;
}

function pointSegmentDistance(
  px: f32, py: f32, pz: f32,
  ax: f32, ay: f32, az: f32,
  bx: f32, by: f32, bz: f32,
): f32 {
  const abx: f32 = bx - ax;
  const aby: f32 = by - ay;
  const abz: f32 = bz - az;
  const apx: f32 = px - ax;
  const apy: f32 = py - ay;
  const apz: f32 = pz - az;
  const denom: f32 = Mathf.max(abx * abx + aby * aby + abz * abz, 0.000001);
  const t: f32 = saturate((apx * abx + apy * aby + apz * abz) / denom);
  const qx: f32 = ax + abx * t;
  const qy: f32 = ay + aby * t;
  const qz: f32 = az + abz * t;
  const dx: f32 = px - qx;
  const dy: f32 = py - qy;
  const dz: f32 = pz - qz;
  return Mathf.sqrt(dx * dx + dy * dy + dz * dz);
}

function shadowRay(
  ox: f32, oy: f32, oz: f32,
  lx: f32, ly: f32, lz: f32,
  base: i32, resetting: bool, skipSegment: i32, skipCylinder: bool,
): f32 {
  let dx: f32 = lx - ox;
  let dy: f32 = ly - oy;
  let dz: f32 = lz - oz;
  const distance: f32 = Mathf.sqrt(dx * dx + dy * dy + dz * dz);
  dx /= distance;
  dy /= distance;
  dz /= distance;
  if (!skipCylinder && rayCylinderT(ox, oy, oz, dx, dy, dz) < distance) return 0.18;
  for (let segment: i32 = 0; segment < SEGMENT_COUNT; segment++) {
    if (segment == skipSegment) continue;
    const node: i32 = segmentNode(segment);
    const hit: f32 = rayCapsuleT(
      ox, oy, oz, dx, dy, dz,
      nodeX(base, node, resetting), nodeY(base, node, resetting), nodeZ(base, node, resetting),
      nodeX(base, node + 1, resetting), nodeY(base, node + 1, resetting), nodeZ(base, node + 1, resetting),
      CABLE_RADIUS,
    );
    if (hit < distance) return 0.28;
  }
  return 1.0;
}

function ambientOcclusion(
  px: f32, py: f32, pz: f32,
  material: i32, base: i32, resetting: bool, skipSegment: i32,
): f32 {
  let ao: f32 = 1.0;
  if (material == 3) {
    const floorGap: f32 = py - CABLE_RADIUS - FLOOR_Y;
    const radial: f32 = Mathf.sqrt(px * px + (py - CYLINDER_Y) * (py - CYLINDER_Y));
    const cylinderGap: f32 = Mathf.abs(radial - CYLINDER_RADIUS) - CABLE_RADIUS;
    ao *= 0.58 + 0.42 * smoothstep(0.0, 0.24, Mathf.min(floorGap, cylinderGap));
  } else {
    let nearest: f32 = 2.0;
    for (let segment: i32 = 0; segment < SEGMENT_COUNT; segment++) {
      if (segment == skipSegment) continue;
      const node: i32 = segmentNode(segment);
      const distance: f32 = pointSegmentDistance(
        px, py, pz,
        nodeX(base, node, resetting), nodeY(base, node, resetting), nodeZ(base, node, resetting),
        nodeX(base, node + 1, resetting), nodeY(base, node + 1, resetting), nodeZ(base, node + 1, resetting),
      ) - CABLE_RADIUS;
      nearest = Mathf.min(nearest, distance);
    }
    ao *= 0.52 + 0.48 * smoothstep(0.015, 0.30, nearest);
    if (material == 1) {
      const cylinderGap: f32 = Mathf.sqrt(px * px + (py - CYLINDER_Y) * (py - CYLINDER_Y)) - CYLINDER_RADIUS;
      ao *= 0.66 + 0.34 * smoothstep(0.0, 0.42, cylinderGap);
    }
  }
  return saturate(ao);
}

function ropeColor(rope: i32, channel: i32): f32 {
  const palette: i32 = rope % 5;
  if (palette == 0) return channel == 0 ? 0.92 : channel == 1 ? 0.19 : 0.10;
  if (palette == 1) return channel == 0 ? 0.98 : channel == 1 ? 0.52 : 0.08;
  if (palette == 2) return channel == 0 ? 0.10 : channel == 1 ? 0.55 : 0.94;
  if (palette == 3) return channel == 0 ? 0.20 : channel == 1 ? 0.82 : 0.54;
  return channel == 0 ? 0.72 : channel == 1 ? 0.28 : 0.92;
}

function renderPixel(pixel: i32, base: i32, resetting: bool, frame: i32): void {
  const px: i32 = pixel & 255;
  const py: i32 = pixel >> 8;
  const screenX: f32 = (<f32>px + 0.5) / 128.0 - 1.0;
  const screenY: f32 = 1.0 - (<f32>py + 0.5) / 128.0;

  const pointerX: i32 = load<i32>(4);
  const pointerButtons: i32 = load<i32>(12);
  const autoYaw: f32 = -0.54 + sinF(<f32>frame * 0.0022) * 0.10;
  const yaw: f32 = pointerButtons != 0 && pointerX >= 0
    ? -1.10 + <f32>pointerX / 255.0 * 1.30
    : autoYaw;
  const cameraRadius: f32 = 5.25;
  const cameraX: f32 = sinF(yaw) * cameraRadius;
  const cameraY: f32 = 2.30;
  const cameraZ: f32 = cosF(yaw) * cameraRadius;
  const targetY: f32 = -0.05;

  let forwardX: f32 = -cameraX;
  let forwardY: f32 = targetY - cameraY;
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
  const fov: f32 = 0.58;
  let rayX: f32 = forwardX + rightX * screenX * fov + upX * screenY * fov;
  let rayY: f32 = forwardY + upY * screenY * fov;
  let rayZ: f32 = forwardZ + rightZ * screenX * fov + upZ * screenY * fov;
  const rayLength: f32 = Mathf.sqrt(rayX * rayX + rayY * rayY + rayZ * rayZ);
  rayX /= rayLength;
  rayY /= rayLength;
  rayZ /= rayLength;

  let bestT: f32 = 9999.0;
  let material: i32 = 0;
  let bestSegment: i32 = -1;

  if (rayY < -0.00001) {
    const floorT: f32 = (FLOOR_Y - cameraY) / rayY;
    if (floorT > 0.0) {
      bestT = floorT;
      material = 1;
    }
  }
  const cylinderT: f32 = rayCylinderT(cameraX, cameraY, cameraZ, rayX, rayY, rayZ);
  if (cylinderT < bestT) {
    bestT = cylinderT;
    material = 2;
  }
  for (let segment: i32 = 0; segment < SEGMENT_COUNT; segment++) {
    const node: i32 = segmentNode(segment);
    const hit: f32 = rayCapsuleT(
      cameraX, cameraY, cameraZ, rayX, rayY, rayZ,
      nodeX(base, node, resetting), nodeY(base, node, resetting), nodeZ(base, node, resetting),
      nodeX(base, node + 1, resetting), nodeY(base, node + 1, resetting), nodeZ(base, node + 1, resetting),
      CABLE_RADIUS,
    );
    if (hit < bestT) {
      bestT = hit;
      material = 3;
      bestSegment = segment;
    }
  }

  let red: f32;
  let green: f32;
  let blue: f32;
  if (material == 0) {
    const sky: f32 = saturate(rayY * 0.65 + 0.62);
    red = 0.030 + sky * 0.055;
    green = 0.045 + sky * 0.070;
    blue = 0.075 + sky * 0.095;
  } else {
    const hitX: f32 = cameraX + rayX * bestT;
    const hitY: f32 = cameraY + rayY * bestT;
    const hitZ: f32 = cameraZ + rayZ * bestT;
    let normalX: f32 = 0.0;
    let normalY: f32 = 1.0;
    let normalZ: f32 = 0.0;

    if (material == 2) {
      if (Mathf.abs(Mathf.abs(hitZ) - CYLINDER_HALF_LENGTH) < 0.004) {
        normalX = 0.0;
        normalY = 0.0;
        normalZ = hitZ > 0.0 ? 1.0 : -1.0;
      } else {
        normalX = hitX / CYLINDER_RADIUS;
        normalY = (hitY - CYLINDER_Y) / CYLINDER_RADIUS;
        normalZ = 0.0;
      }
    } else if (material == 3) {
      const node: i32 = segmentNode(bestSegment);
      const ax: f32 = nodeX(base, node, resetting);
      const ay: f32 = nodeY(base, node, resetting);
      const az: f32 = nodeZ(base, node, resetting);
      const bx: f32 = nodeX(base, node + 1, resetting);
      const by: f32 = nodeY(base, node + 1, resetting);
      const bz: f32 = nodeZ(base, node + 1, resetting);
      const abx: f32 = bx - ax;
      const aby: f32 = by - ay;
      const abz: f32 = bz - az;
      const ab2: f32 = Mathf.max(abx * abx + aby * aby + abz * abz, 0.000001);
      const along: f32 = saturate(((hitX - ax) * abx + (hitY - ay) * aby + (hitZ - az) * abz) / ab2);
      normalX = hitX - (ax + abx * along);
      normalY = hitY - (ay + aby * along);
      normalZ = hitZ - (az + abz * along);
      const normalLength: f32 = Mathf.sqrt(Mathf.max(normalX * normalX + normalY * normalY + normalZ * normalZ, 0.000001));
      normalX /= normalLength;
      normalY /= normalLength;
      normalZ /= normalLength;
    }

    const bias: f32 = material == 3 ? 0.060 : 0.018;
    const originX: f32 = hitX + normalX * bias;
    const originY: f32 = hitY + normalY * bias;
    const originZ: f32 = hitZ + normalZ * bias;
    const shadowA: f32 = shadowRay(originX, originY, originZ, -3.2, 4.8, -2.4, base, resetting, bestSegment, material == 2);
    const shadowB: f32 = shadowRay(originX, originY, originZ, -2.4, 4.5, -1.6, base, resetting, bestSegment, material == 2);
    const shadow: f32 = 0.5 * (shadowA + shadowB);
    let lightX: f32 = -2.8 - hitX;
    let lightY: f32 = 4.65 - hitY;
    let lightZ: f32 = -2.0 - hitZ;
    const lightLength: f32 = Mathf.sqrt(lightX * lightX + lightY * lightY + lightZ * lightZ);
    lightX /= lightLength;
    lightY /= lightLength;
    lightZ /= lightLength;
    const diffuse: f32 = saturate(normalX * lightX + normalY * lightY + normalZ * lightZ);
    const facing: f32 = saturate(-(normalX * rayX + normalY * rayY + normalZ * rayZ));
    const rim: f32 = (1.0 - facing) * (1.0 - facing);
    const ao: f32 = ambientOcclusion(hitX, hitY, hitZ, material, base, resetting, bestSegment);
    let baseR: f32;
    let baseG: f32;
    let baseB: f32;
    let specular: f32 = 0.08;

    if (material == 1) {
      const tileX: i32 = <i32>Mathf.floor(hitX * 1.4);
      const tileZ: i32 = <i32>Mathf.floor(hitZ * 1.4);
      const checker: f32 = ((tileX + tileZ) & 1) == 0 ? 0.025 : 0.0;
      baseR = 0.16 + checker;
      baseG = 0.18 + checker;
      baseB = 0.21 + checker;
      specular = 0.04;
    } else if (material == 2) {
      const bands: f32 = 0.5 + 0.5 * sinF(hitZ * 32.0);
      baseR = 0.19 + bands * 0.025;
      baseG = 0.22 + bands * 0.030;
      baseB = 0.25 + bands * 0.035;
      specular = 0.34;
    } else {
      const rope: i32 = bestSegment / (NODES_PER_ROPE - 1);
      const braid: f32 = 0.82 + 0.18 * sinF((hitX + hitY + hitZ) * 72.0 + <f32>rope * 1.7);
      baseR = ropeColor(rope, 0) * braid;
      baseG = ropeColor(rope, 1) * braid;
      baseB = ropeColor(rope, 2) * braid;
      specular = 0.20;
    }

    const halfX0: f32 = lightX - rayX;
    const halfY0: f32 = lightY - rayY;
    const halfZ0: f32 = lightZ - rayZ;
    const halfLength: f32 = Mathf.sqrt(halfX0 * halfX0 + halfY0 * halfY0 + halfZ0 * halfZ0);
    const halfDot: f32 = saturate((normalX * halfX0 + normalY * halfY0 + normalZ * halfZ0) / halfLength);
    const half2: f32 = halfDot * halfDot;
    const half4: f32 = half2 * half2;
    const half8: f32 = half4 * half4;
    const half16: f32 = half8 * half8;
    const highlight: f32 = half16 * half16 * specular * shadow;
    const lighting: f32 = (0.18 + diffuse * shadow * 0.82) * ao;
    red = baseR * lighting + highlight + rim * 0.035;
    green = baseG * lighting + highlight + rim * 0.045;
    blue = baseB * lighting + highlight + rim * 0.060;

    const fog: f32 = saturate((bestT - 5.0) * 0.13);
    red = red * (1.0 - fog) + 0.050 * fog;
    green = green * (1.0 - fog) + 0.070 * fog;
    blue = blue * (1.0 - fog) + 0.105 * fog;
  }

  red = Mathf.sqrt(saturate(red / (1.0 + red)));
  green = Mathf.sqrt(saturate(green / (1.0 + green)));
  blue = Mathf.sqrt(saturate(blue / (1.0 + blue)));
  const output: i32 = OUTPUT_OFFSET + pixel * 12;
  store<i32>(output, <i32>(red * 255.0));
  store<i32>(output + 4, <i32>(green * 255.0));
  store<i32>(output + 8, <i32>(blue * 255.0));
}

export function main(): void {
  const frame: i32 = <i32>load<f32>(0);
  const cycleFrame: i32 = frame % RESET_FRAMES;
  const resetting: bool = cycleFrame == 0;
  const activeFrame: i32 = cycleFrame - 1;
  const phase: i32 = activeFrame < 0 ? 0 : activeFrame % PHASES;

  for (let i: i32 = 0; i < PIXELS; i++) {
    if (resetting) {
      if (i < NODE_COUNT) seedNode(i);
      if (i == 0) store<i32>(MAGIC_OFFSET, MAGIC);
    } else if (i < NODE_COUNT) {
      if (phase == 0) integrateNode(i);
      else if (phase == 1) solveNode(SOLVE_A, SOLVE_B, i);
      else if (phase == 2) solveNode(SOLVE_B, SOLVE_A, i);
      else if (phase == 3) solveNode(SOLVE_A, SOLVE_B, i);
      else commitNode(i);
    }
    renderPixel(i, CURRENT_POS, resetting, frame);
  }
}
