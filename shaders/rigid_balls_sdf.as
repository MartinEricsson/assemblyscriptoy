// ============================================================
//  Rigid Ball SDF Physics - elastic balls in a 3D box
// ============================================================
//  Four rigid spheres bounce inside an open room. Horizontal motion
//  uses closed-form wall bounces; vertical motion uses a parabolic
//  flight arc so the balls visibly accelerate under gravity.
//
//  The scene is visualised as signed distance geometry: a conservative
//  ray march finds the visible surface of the union of all balls, while
//  bounded room planes provide the gridded enclosure. This keeps the
//  renderer stable even when the animation paths interpenetrate.
// ============================================================

const WIDTH: i32 = 256;
const HEIGHT: i32 = 256;
const TIME_OFFSET: i32 = 0;

const PI: f32 = 3.14159265;
const TWO_PI: f32 = 6.28318530;

const ROOM_X: f32 = 2.10;
const ROOM_Y: f32 = 1.35;
const ROOM_Z: f32 = 1.60;

const R0: f32 = 0.34;
const R1: f32 = 0.29;
const R2: f32 = 0.25;
const R3: f32 = 0.31;
const BALL_STEPS: i32 = 128;
const BALL_SURF_DIST: f32 = 0.0012;
const BALL_MAX_DIST: f32 = 9.0;

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

function saturate(v: f32): f32 {
  return clampF(v, 0.0, 1.0);
}

function smoothstep(edge0: f32, edge1: f32, x: f32): f32 {
  const t: f32 = saturate((x - edge0) / (edge1 - edge0));
  return t * t * (3.0 - 2.0 * t);
}

function fractF(v: f32): f32 {
  return v - Mathf.floor(v);
}

function expF(x: f32): f32 {
  if (x < -20.0) return 0.0;
  if (x > 20.0) return 485165195.0;
  const n: f32 = Mathf.floor(x * 1.4426950);
  const f: f32 = x - n * 0.6931472;
  const ef: f32 = 1.0 + f * (1.0 + f * (0.5 + f * (0.1666667 + f * 0.04166667)));
  const ni: i32 = <i32>n;
  let p: f32 = 1.0;
  if (ni > 0) {
    for (let i: i32 = 0; i < ni; i++) p *= 2.0;
  } else {
    const nn: i32 = -ni;
    for (let i: i32 = 0; i < nn; i++) p *= 0.5;
  }
  return p * ef;
}

function powF(base: f32, power: f32): f32 {
  if (base <= 0.0) return 0.0;
  // Small exponent set used by this shader; multiplication is cheaper and
  // avoids requiring a full logarithm approximation.
  if (power == 16.0) {
    const b2: f32 = base * base;
    const b4: f32 = b2 * b2;
    const b8: f32 = b4 * b4;
    return b8 * b8;
  }
  return base;
}

function bounceCoord(start: f32, velocity: f32, limit: f32, time: f32): f32 {
  const span: f32 = limit * 2.0;
  const period: f32 = span * 2.0;
  let q: f32 = start + velocity * time + limit;
  q = q - Mathf.floor(q / period) * period;
  if (q > span) q = period - q;
  return q - limit;
}

function gravityBounce(floorY: f32, ceilingY: f32, radius: f32, phase: f32, speed: f32, time: f32): f32 {
  let p: f32 = fractF(phase + time * speed);
  const arc: f32 = 4.0 * p * (1.0 - p);
  const travel: f32 = ceilingY - floorY - radius * 2.0;
  return floorY + radius + arc * travel;
}

function sdSphere(px: f32, py: f32, pz: f32, cx: f32, cy: f32, cz: f32, radius: f32): f32 {
  const dx: f32 = px - cx;
  const dy: f32 = py - cy;
  const dz: f32 = pz - cz;
  return Mathf.sqrt(dx * dx + dy * dy + dz * dz) - radius;
}

function ball0X(time: f32): f32 { return bounceCoord(-1.45, 0.56, ROOM_X - R0, time); }
function ball0Y(time: f32): f32 { return gravityBounce(-ROOM_Y, ROOM_Y, R0, 0.04, 0.34, time); }
function ball0Z(time: f32): f32 { return bounceCoord(-0.55, -0.24, ROOM_Z - R0, time); }

function ball1X(time: f32): f32 { return bounceCoord(1.35, -0.48, ROOM_X - R1, time); }
function ball1Y(time: f32): f32 { return gravityBounce(-ROOM_Y, ROOM_Y, R1, 0.31, 0.39, time); }
function ball1Z(time: f32): f32 { return bounceCoord(0.18, -0.33, ROOM_Z - R1, time); }

function ball2X(time: f32): f32 { return bounceCoord(-0.10, 0.40, ROOM_X - R2, time); }
function ball2Y(time: f32): f32 { return gravityBounce(-ROOM_Y, ROOM_Y, R2, 0.58, 0.45, time); }
function ball2Z(time: f32): f32 { return bounceCoord(0.90, -0.20, ROOM_Z - R2, time); }

function ball3X(time: f32): f32 { return bounceCoord(0.72, -0.62, ROOM_X - R3, time); }
function ball3Y(time: f32): f32 { return gravityBounce(-ROOM_Y, ROOM_Y, R3, 0.79, 0.32, time); }
function ball3Z(time: f32): f32 { return bounceCoord(-1.05, 0.26, ROOM_Z - R3, time); }

function ballsSDF(px: f32, py: f32, pz: f32, time: f32): f32 {
  let d: f32 = sdSphere(px, py, pz, ball0X(time), ball0Y(time), ball0Z(time), R0);
  d = Mathf.min(d, sdSphere(px, py, pz, ball1X(time), ball1Y(time), ball1Z(time), R1));
  d = Mathf.min(d, sdSphere(px, py, pz, ball2X(time), ball2Y(time), ball2Z(time), R2));
  d = Mathf.min(d, sdSphere(px, py, pz, ball3X(time), ball3Y(time), ball3Z(time), R3));
  return d;
}

function raySphereT(
  ox: f32, oy: f32, oz: f32,
  dx: f32, dy: f32, dz: f32,
  cx: f32, cy: f32, cz: f32,
  radius: f32,
): f32 {
  const px: f32 = ox - cx;
  const py: f32 = oy - cy;
  const pz: f32 = oz - cz;
  const b: f32 = px * dx + py * dy + pz * dz;
  const c: f32 = px * px + py * py + pz * pz - radius * radius;
  const h: f32 = b * b - c;
  if (h < 0.0) return 9999.0;
  const root: f32 = Mathf.sqrt(h);
  const nearT: f32 = -b - root;
  if (nearT > 0.035) return nearT;
  const farT: f32 = -b + root;
  return farT > 0.035 ? farT : 9999.0;
}

function gridLine(a: f32, b: f32): f32 {
  const ca: f32 = Mathf.abs(fractF(a * 1.8) - 0.5);
  const cb: f32 = Mathf.abs(fractF(b * 1.8) - 0.5);
  const d: f32 = Mathf.min(ca, cb);
  return smoothstep(0.080, 0.000, d);
}

export function main(): void {
  const time: f32 = load<f32>(TIME_OFFSET) * 0.016;

  const b0x: f32 = ball0X(time);
  const b0y: f32 = ball0Y(time);
  const b0z: f32 = ball0Z(time);

  const b1x: f32 = ball1X(time);
  const b1y: f32 = ball1Y(time);
  const b1z: f32 = ball1Z(time);

  const b2x: f32 = ball2X(time);
  const b2y: f32 = ball2Y(time);
  const b2z: f32 = ball2Z(time);

  const b3x: f32 = ball3X(time);
  const b3y: f32 = ball3Y(time);
  const b3z: f32 = ball3Z(time);

  const orbit: f32 = time * 0.20;
  const camX: f32 = cosF(orbit) * 0.45;
  const camY: f32 = 0.62 + sinF(time * 0.21) * 0.14;
  const camZ: f32 = 4.10 + sinF(orbit) * 0.22;

  const targetX: f32 = 0.0;
  const targetY: f32 = -0.10;
  const targetZ: f32 = -0.40;
  const fwdX: f32 = targetX - camX;
  const fwdY: f32 = targetY - camY;
  const fwdZ: f32 = targetZ - camZ;
  const fLen: f32 = Mathf.sqrt(fwdX * fwdX + fwdY * fwdY + fwdZ * fwdZ);
  const fdx: f32 = fwdX / fLen;
  const fdy: f32 = fwdY / fLen;
  const fdz: f32 = fwdZ / fLen;

  const rdx0: f32 = fdz;
  const rdz0: f32 = -fdx;
  const rLen: f32 = Mathf.sqrt(rdx0 * rdx0 + rdz0 * rdz0);
  const rdx: f32 = rdx0 / rLen;
  const rdz: f32 = rdz0 / rLen;

  const ux: f32 = -fdy * rdz;
  const uy: f32 = fdz * rdx - fdx * rdz;
  const uz: f32 = fdy * rdx;

  const lightX: f32 = -0.47;
  const lightY: f32 = 0.78;
  const lightZ: f32 = 0.41;

  const invW: f32 = 1.0 / <f32>WIDTH;
  const invH: f32 = 1.0 / <f32>HEIGHT;

  for (let i: i32 = 0; i < WIDTH * HEIGHT; i++) {
    const px: i32 = i % WIDTH;
    const py: i32 = i / WIDTH;

    const uvx: f32 = (2.0 * <f32>px * invW - 1.0) * 1.05;
    const uvy: f32 = -(2.0 * <f32>py * invH - 1.0);

    const dirX0: f32 = rdx * uvx + ux * uvy + fdx * 1.45;
    const dirY0: f32 = uy * uvy + fdy * 1.45;
    const dirZ0: f32 = rdz * uvx + uz * uvy + fdz * 1.45;
    const dLen: f32 = Mathf.sqrt(dirX0 * dirX0 + dirY0 * dirY0 + dirZ0 * dirZ0);
    const ddx: f32 = dirX0 / dLen;
    const ddy: f32 = dirY0 / dLen;
    const ddz: f32 = dirZ0 / dLen;

    let ballT: f32 = 0.02;
    let ballD: f32 = BALL_MAX_DIST;
    let didHitBall: bool = false;
    for (let s: i32 = 0; s < BALL_STEPS; s++) {
      if (!didHitBall && ballT < BALL_MAX_DIST) {
        ballD = ballsSDF(camX + ddx * ballT, camY + ddy * ballT, camZ + ddz * ballT, time);
        if (ballD < BALL_SURF_DIST) {
          didHitBall = true;
        }
        ballT += Mathf.max(ballD * 0.72, 0.0035);
      }
    }
    ballT -= Mathf.max(ballD * 0.72, 0.0035);

    let roomT: f32 = 9999.0;
    let wallId: i32 = -1;
    if (ddy < -0.0001) {
      const tf: f32 = (-ROOM_Y - camY) / ddy;
      const fx: f32 = camX + ddx * tf;
      const fz: f32 = camZ + ddz * tf;
      if (tf > 0.02 && Mathf.abs(fx) <= ROOM_X && fz >= -ROOM_Z && fz <= 2.15) {
        roomT = tf; wallId = 0;
      }
    }
    if (ddx < -0.0001) {
      const tl: f32 = (-ROOM_X - camX) / ddx;
      const ly: f32 = camY + ddy * tl;
      const lz: f32 = camZ + ddz * tl;
      if (tl > 0.02 && tl < roomT && ly >= -ROOM_Y && ly <= ROOM_Y && lz >= -ROOM_Z && lz <= 2.15) {
        roomT = tl; wallId = 1;
      }
    }
    if (ddx > 0.0001) {
      const tr: f32 = (ROOM_X - camX) / ddx;
      const ry: f32 = camY + ddy * tr;
      const rz: f32 = camZ + ddz * tr;
      if (tr > 0.02 && tr < roomT && ry >= -ROOM_Y && ry <= ROOM_Y && rz >= -ROOM_Z && rz <= 2.15) {
        roomT = tr; wallId = 2;
      }
    }
    if (ddz < -0.0001) {
      const tb: f32 = (-ROOM_Z - camZ) / ddz;
      const bx: f32 = camX + ddx * tb;
      const by: f32 = camY + ddy * tb;
      if (tb > 0.02 && tb < roomT && Mathf.abs(bx) <= ROOM_X && by >= -ROOM_Y && by <= ROOM_Y) {
        roomT = tb; wallId = 3;
      }
    }

    let r: f32;
    let g: f32;
    let b: f32;

    if (didHitBall && ballT < roomT) {
      const t: f32 = ballT;
      const hx: f32 = camX + ddx * t;
      const hy: f32 = camY + ddy * t;
      const hz: f32 = camZ + ddz * t;

      const e: f32 = 0.003;
      let nx: f32 = ballsSDF(hx + e, hy, hz, time) - ballsSDF(hx - e, hy, hz, time);
      let ny: f32 = ballsSDF(hx, hy + e, hz, time) - ballsSDF(hx, hy - e, hz, time);
      let nz: f32 = ballsSDF(hx, hy, hz + e, time) - ballsSDF(hx, hy, hz - e, time);
      const nLen: f32 = Mathf.sqrt(nx * nx + ny * ny + nz * nz);
      nx /= nLen;
      ny /= nLen;
      nz /= nLen;

      const d0: f32 = sdSphere(hx, hy, hz, b0x, b0y, b0z, R0);
      const d1: f32 = sdSphere(hx, hy, hz, b1x, b1y, b1z, R1);
      const d2: f32 = sdSphere(hx, hy, hz, b2x, b2y, b2z, R2);
      const d3: f32 = sdSphere(hx, hy, hz, b3x, b3y, b3z, R3);
      let ballId: i32 = 0;
      let nearestD: f32 = d0;
      if (d1 < nearestD) { nearestD = d1; ballId = 1; }
      if (d2 < nearestD) { nearestD = d2; ballId = 2; }
      if (d3 < nearestD) { ballId = 3; }

      const diff: f32 = saturate(nx * lightX + ny * lightY + nz * lightZ);
      const sx0: f32 = hx + nx * 0.025;
      const sy0: f32 = hy + ny * 0.025;
      const sz0: f32 = hz + nz * 0.025;
      let shadow: f32 = 0.0;
      if (ballId != 0 && raySphereT(sx0, sy0, sz0, lightX, lightY, lightZ, b0x, b0y, b0z, R0) < 4.0) shadow = 1.0;
      if (ballId != 1 && raySphereT(sx0, sy0, sz0, lightX, lightY, lightZ, b1x, b1y, b1z, R1) < 4.0) shadow = 1.0;
      if (ballId != 2 && raySphereT(sx0, sy0, sz0, lightX, lightY, lightZ, b2x, b2y, b2z, R2) < 4.0) shadow = 1.0;
      if (ballId != 3 && raySphereT(sx0, sy0, sz0, lightX, lightY, lightZ, b3x, b3y, b3z, R3) < 4.0) shadow = 1.0;
      const halfX: f32 = lightX - ddx;
      const halfY: f32 = lightY - ddy;
      const halfZ: f32 = lightZ - ddz;
      const hLen: f32 = Mathf.sqrt(halfX * halfX + halfY * halfY + halfZ * halfZ);
      const spec: f32 = powF(saturate((nx * halfX + ny * halfY + nz * halfZ) / hLen), 16.0);

      let matR: f32;
      let matG: f32;
      let matB: f32;
      if (ballId == 0) {
        matR = 0.96; matG = 0.16; matB = 0.11;
      } else if (ballId == 1) {
        matR = 0.10; matG = 0.60; matB = 1.00;
      } else if (ballId == 2) {
        matR = 1.00; matG = 0.77; matB = 0.13;
      } else {
        matR = 0.52; matG = 0.96; matB = 0.30;
      }

      const ao: f32 = saturate(0.62 + 0.38 * ny);
      const direct: f32 = 1.0 - shadow * 0.68;
      const lighting: f32 = 0.24 + diff * 0.84 * direct;
      r = matR * lighting * ao + spec * 0.55 * direct;
      g = matG * lighting * ao + spec * 0.55 * direct;
      b = matB * lighting * ao + spec * 0.55 * direct;

      const fog: f32 = 1.0 - expF(-t * t * 0.020);
      r = r * (1.0 - fog) + 0.08 * fog;
      g = g * (1.0 - fog) + 0.10 * fog;
      b = b * (1.0 - fog) + 0.13 * fog;
    } else if (wallId >= 0) {
      const t: f32 = roomT;
      const hx: f32 = camX + ddx * t;
      const hy: f32 = camY + ddy * t;
      const hz: f32 = camZ + ddz * t;

      let nx: f32 = 0.0; let ny: f32 = 1.0; let nz: f32 = 0.0;
      if (wallId == 1) { nx = 1.0; ny = 0.0; nz = 0.0; }
      else if (wallId == 2) { nx = -1.0; ny = 0.0; nz = 0.0; }
      else if (wallId == 3) { nx = 0.0; ny = 0.0; nz = 1.0; }

      const diff: f32 = saturate(nx * lightX + ny * lightY + nz * lightZ);
      const sx0: f32 = hx + nx * 0.025;
      const sy0: f32 = hy + ny * 0.025;
      const sz0: f32 = hz + nz * 0.025;
      let shadow: f32 = 0.0;
      if (raySphereT(sx0, sy0, sz0, lightX, lightY, lightZ, b0x, b0y, b0z, R0) < 4.0) shadow = 1.0;
      if (raySphereT(sx0, sy0, sz0, lightX, lightY, lightZ, b1x, b1y, b1z, R1) < 4.0) shadow = 1.0;
      if (raySphereT(sx0, sy0, sz0, lightX, lightY, lightZ, b2x, b2y, b2z, R2) < 4.0) shadow = 1.0;
      if (raySphereT(sx0, sy0, sz0, lightX, lightY, lightZ, b3x, b3y, b3z, R3) < 4.0) shadow = 1.0;
      const grid: f32 = wallId == 0 ? gridLine(hx, hz) : (wallId == 3 ? gridLine(hx, hy) : gridLine(hz, hy));
      const checker: i32 = ((<i32>Mathf.floor(hx * 1.5) + <i32>Mathf.floor(hz * 1.5)) & 1);
      const tone: f32 = checker == 0 ? 0.62 : 0.46;
      let contact: f32 = 0.0;
      if (wallId == 0) {
        const c0x: f32 = hx - b0x; const c0z: f32 = hz - b0z;
        const c1x: f32 = hx - b1x; const c1z: f32 = hz - b1z;
        const c2x: f32 = hx - b2x; const c2z: f32 = hz - b2z;
        const c3x: f32 = hx - b3x; const c3z: f32 = hz - b3z;
        const h0: f32 = saturate(1.0 - (b0y + ROOM_Y - R0) * 1.8);
        const h1: f32 = saturate(1.0 - (b1y + ROOM_Y - R1) * 1.8);
        const h2: f32 = saturate(1.0 - (b2y + ROOM_Y - R2) * 1.8);
        const h3: f32 = saturate(1.0 - (b3y + ROOM_Y - R3) * 1.8);
        contact = Mathf.max(contact, smoothstep(0.42, 0.00, Mathf.sqrt(c0x * c0x + c0z * c0z)) * h0);
        contact = Mathf.max(contact, smoothstep(0.36, 0.00, Mathf.sqrt(c1x * c1x + c1z * c1z)) * h1);
        contact = Mathf.max(contact, smoothstep(0.32, 0.00, Mathf.sqrt(c2x * c2x + c2z * c2z)) * h2);
        contact = Mathf.max(contact, smoothstep(0.39, 0.00, Mathf.sqrt(c3x * c3x + c3z * c3z)) * h3);
      }
      const lighting: f32 = (0.24 + diff * 0.54 * (1.0 - shadow * 0.72)) * (1.0 - contact * 0.26);
      r = (tone * 0.34 + grid * 0.16) * lighting;
      g = (tone * 0.40 + grid * 0.34) * lighting;
      b = (tone * 0.50 + grid * 0.48) * lighting;

      const fog: f32 = 1.0 - expF(-t * t * 0.016);
      r = r * (1.0 - fog) + 0.06 * fog;
      g = g * (1.0 - fog) + 0.08 * fog;
      b = b * (1.0 - fog) + 0.11 * fog;
    } else {
      const sky: f32 = saturate(0.5 + ddy * 0.5);
      r = 0.05 + 0.12 * sky;
      g = 0.07 + 0.14 * sky;
      b = 0.10 + 0.20 * sky;
    }

    r = Mathf.sqrt(saturate(r));
    g = Mathf.sqrt(saturate(g));
    b = Mathf.sqrt(saturate(b));

    const off: i32 = 16 + i * 12;
    store<i32>(off, <i32>(r * 255.0));
    store<i32>(off + 4, <i32>(g * 255.0));
    store<i32>(off + 8, <i32>(b * 255.0));
  }
}
