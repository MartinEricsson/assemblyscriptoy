// ============================================================
//  Tiny Sphere Tracer - animated ray-sphere study
// ============================================================
//  A small ray tracer with one glassy foreground sphere, nine large
//  drifting spheres behind it, a moving point light, caustic-like
//  highlights, sky tint, and a soft screen-space wave texture.
//
//  It demonstrates direct ray/sphere intersection, nearest-hit
//  selection, simple shadowing, reflected sky color, and f32-only
//  math helpers that remain compatible with both CPU and GPU modes.
// ============================================================

const WIDTH: i32 = 256;
const HEIGHT: i32 = 256;
const TIME_OFFSET: i32 = 0;

const PI: f32 = 3.14159265;
const TWO_PI: f32 = 6.28318530;
const NO_HIT: f32 = -1.0;

function sinF(x: f32): f32 {
  x = x - Mathf.floor(x / TWO_PI + 0.5) * TWO_PI;
  if (x > PI * 0.5) x = PI - x;
  if (x < -PI * 0.5) x = -PI - x;
  const x2: f32 = x * x;
  return x * (1.0 - x2 / 6.0 * (1.0 - x2 / 20.0 * (1.0 - x2 / 42.0)));
}

function clamp0(v: f32): f32 {
  return v < 0.0 ? 0.0 : v;
}

function clamp255(v: f32): i32 {
  if (v < 0.0) return 0;
  if (v > 255.0) return 255;
  return <i32>v;
}

function absF(v: f32): f32 {
  return v < 0.0 ? -v : v;
}

function causticPow(base: f32, power: f32): f32 {
  const b2: f32 = base * base;
  const b4: f32 = b2 * b2;
  return b4 * (1.0 - 0.45 * power) + b2 * 0.45 * power;
}

function sphereT(
  cx: f32, cy: f32, cz: f32, radius: f32,
  ox: f32, oy: f32, oz: f32,
  dx: f32, dy: f32, dz: f32,
): f32 {
  const otcX: f32 = cx - ox;
  const otcY: f32 = cy - oy;
  const otcZ: f32 = cz - oz;
  const v: f32 = otcX * dx + otcY * dy + otcZ * dz;
  const disc: f32 = radius - (otcX * otcX + otcY * otcY + otcZ * otcZ) + v * v;
  return disc < 0.0 ? NO_HIT : v - Mathf.sqrt(disc);
}

function chooseT(a: f32, b: f32): f32 {
  if (a < 0.0) return b;
  if (b < 0.0) return a;
  return a <= b ? a : b;
}

function nearestT(
  ox: f32, oy: f32, oz: f32,
  dx: f32, dy: f32, dz: f32,
  angle: f32,
  sphereX: f32, sphereY: f32, sphereZ: f32,
): f32 {
  let hitT: f32 = sphereT(sphereX, sphereY, sphereZ, 1.0, ox, oy, oz, dx, dy, dz);

  for (let i: i32 = 0; i < 9; i++) {
    const col: i32 = i % 3;
    const row: f32 = <f32>(i / 3);
    const bigX: f32 = -4.0 + <f32>col * 4.0;
    const bigY: f32 = 4.0 + sinF(angle + <f32>col + row);
    const bigZ: f32 = 4.0 + row * 4.0;
    hitT = chooseT(hitT, sphereT(bigX, bigY, bigZ, 5.0, ox, oy, oz, dx, dy, dz));
  }

  return hitT;
}

function hitId(
  t: f32,
  ox: f32, oy: f32, oz: f32,
  dx: f32, dy: f32, dz: f32,
  sphereX: f32, sphereY: f32, sphereZ: f32,
): f32 {
  const frontT: f32 = sphereT(sphereX, sphereY, sphereZ, 1.0, ox, oy, oz, dx, dy, dz);
  return absF(frontT - t) < 0.001 ? 1.0 : 5.0;
}

function traceR(
  ox: f32, oy: f32, oz: f32,
  dx: f32, dy: f32, dz: f32,
  angle: f32,
  sphereX: f32, sphereY: f32, sphereZ: f32,
  sceneLX: f32, sceneLY: f32, sceneLZ: f32,
): f32 {
  const hitT: f32 = nearestT(ox, oy, oz, dx, dy, dz, angle, sphereX, sphereY, sphereZ);
  if (hitT <= 0.0) return 32.0 * dx + 192.0 - dy * 64.0;

  const hx: f32 = ox + dx * hitT;
  const hy: f32 = oy + dy * hitT;
  const hz: f32 = oz + dz * hitT;

  let nx: f32 = 0.0;
  let ny: f32 = 0.0;
  let nz: f32 = 0.0;
  const id: f32 = hitId(hitT, ox, oy, oz, dx, dy, dz, sphereX, sphereY, sphereZ);
  if (id == 1.0) {
    nx = hx - sphereX;
    ny = hy - sphereY;
    nz = hz - sphereZ;
  } else {
    for (let i: i32 = 0; i < 9; i++) {
      const col: i32 = i % 3;
      const row: f32 = <f32>(i / 3);
      const bx: f32 = -4.0 + <f32>col * 4.0;
      const by: f32 = 4.0 + sinF(angle + <f32>col + row);
      const bz: f32 = 4.0 + row * 4.0;
      const bt: f32 = sphereT(bx, by, bz, 5.0, ox, oy, oz, dx, dy, dz);
      if (absF(bt - hitT) < 0.001) {
        nx = hx - bx;
        ny = hy - by;
        nz = hz - bz;
      }
    }
  }

  const llx: f32 = sceneLX - hx;
  const lly: f32 = sceneLY - hy;
  const llz: f32 = sceneLZ - hz;
  const llen: f32 = Mathf.sqrt(llx * llx + lly * lly + llz * llz);
  const ldx: f32 = llx / llen;
  const ldy: f32 = lly / llen;
  const ldz: f32 = llz / llen;

  const shadowT: f32 = sphereT(sphereX, sphereY, sphereZ, 1.0, hx, hy, hz, ldx, ldy, ldz);
  let shade: f32 = shadowT < -1.0 ? 1.0 : (shadowT < 0.0 ? 0.2 + 0.8 * -shadowT : 0.2);

  if (shade < 1.0) {
    const lvx0: f32 = sceneLX - sphereX;
    const lvy0: f32 = sceneLY - sphereY;
    const lvz0: f32 = sceneLZ - sphereZ;
    const lvLen: f32 = Mathf.sqrt(lvx0 * lvx0 + lvy0 * lvy0 + lvz0 * lvz0);
    const lvx: f32 = lvx0 / lvLen;
    const lvy: f32 = lvy0 / lvLen;
    const lvz: f32 = lvz0 / lvLen;
    let focal: f32 = (hx - sphereX) * lvx + (hy - sphereY) * lvy + (hz - sphereZ) * lvz;
    const cox: f32 = sphereX + lvx * focal - hx;
    const coy: f32 = sphereY + lvy * focal - hy;
    const coz: f32 = sphereZ + lvz * focal - hz;
    focal -= 0.5;
    const fad: f32 = focal < 0.0 ? -focal : focal;
    const causticBase: f32 = clamp0(1.0 - Mathf.sqrt(cox * cox + coy * coy + coz * coz));
    shade += causticPow(causticBase, fad) * fad;
  }

  const diffuse: f32 = clamp0((ldx * nx + ldy * ny + ldz * nz) * 12.0 * shade);
  let colR: f32 = (hx + 5.0) * diffuse;

  if (id == 1.0) {
    const cl: f32 = nx * dx + ny * dy + nz * dz;
    const reflX: f32 = dx - nx * 2.0 * cl;
    const reflY: f32 = dy - ny * 2.0 * cl;
    const reflZ: f32 = dz - nz * 2.0 * cl;
    const reflLen: f32 = Mathf.sqrt(reflX * reflX + reflY * reflY + reflZ * reflZ);
    const rdx: f32 = reflX / reflLen;
    const rdy: f32 = reflY / reflLen;
    colR += (32.0 * rdx + 192.0 - rdy * 64.0) * 0.2;

    const nn: f32 = 2.0 / 3.0;
    const bend: f32 = nn * -cl - Mathf.sqrt(1.0 - nn * nn * (1.0 - cl * cl));
    const rrX: f32 = nx * bend + dx * nn;
    const rrY: f32 = ny * bend + dy * nn;
    colR += (32.0 * rrX + 192.0 - rrY * 64.0) * 0.5;
  }

  return colR;
}

function traceG(
  ox: f32, oy: f32, oz: f32,
  dx: f32, dy: f32, dz: f32,
  angle: f32,
  sphereX: f32, sphereY: f32, sphereZ: f32,
  sceneLX: f32, sceneLY: f32, sceneLZ: f32,
): f32 {
  const hitT: f32 = nearestT(ox, oy, oz, dx, dy, dz, angle, sphereX, sphereY, sphereZ);
  if (hitT <= 0.0) return 196.0 - dy * 64.0;

  const hx: f32 = ox + dx * hitT;
  const hy: f32 = oy + dy * hitT;
  const hz: f32 = oz + dz * hitT;
  const id: f32 = hitId(hitT, ox, oy, oz, dx, dy, dz, sphereX, sphereY, sphereZ);
  let nx: f32 = hx - sphereX;
  let ny: f32 = hy - sphereY;
  let nz: f32 = hz - sphereZ;
  if (id != 1.0) {
    for (let i: i32 = 0; i < 9; i++) {
      const col: i32 = i % 3;
      const row: f32 = <f32>(i / 3);
      const bx: f32 = -4.0 + <f32>col * 4.0;
      const by: f32 = 4.0 + sinF(angle + <f32>col + row);
      const bz: f32 = 4.0 + row * 4.0;
      const bt: f32 = sphereT(bx, by, bz, 5.0, ox, oy, oz, dx, dy, dz);
      if (absF(bt - hitT) < 0.001) {
        nx = hx - bx; ny = hy - by; nz = hz - bz;
      }
    }
  }
  const llx: f32 = sceneLX - hx;
  const lly: f32 = sceneLY - hy;
  const llz: f32 = sceneLZ - hz;
  const llen: f32 = Mathf.sqrt(llx * llx + lly * lly + llz * llz);
  const ldx: f32 = llx / llen;
  const ldy: f32 = lly / llen;
  const ldz: f32 = llz / llen;
  const shadowT: f32 = sphereT(sphereX, sphereY, sphereZ, 1.0, hx, hy, hz, ldx, ldy, ldz);
  const shade: f32 = shadowT < -1.0 ? 1.0 : (shadowT < 0.0 ? 0.2 + 0.8 * -shadowT : 0.2);
  let colG: f32 = 9.0 * clamp0((ldx * nx + ldy * ny + ldz * nz) * 12.0 * shade);
  if (id == 1.0) {
    const cl: f32 = nx * dx + ny * dy + nz * dz;
    const reflX: f32 = dx - nx * 2.0 * cl;
    const reflY: f32 = dy - ny * 2.0 * cl;
    const reflZ: f32 = dz - nz * 2.0 * cl;
    const reflLen: f32 = Mathf.sqrt(reflX * reflX + reflY * reflY + reflZ * reflZ);
    colG += (196.0 - (reflY / reflLen) * 64.0) * 0.2;
  }
  return colG;
}

function traceB(
  ox: f32, oy: f32, oz: f32,
  dx: f32, dy: f32, dz: f32,
  angle: f32,
  sphereX: f32, sphereY: f32, sphereZ: f32,
  sceneLX: f32, sceneLY: f32, sceneLZ: f32,
): f32 {
  const hitT: f32 = nearestT(ox, oy, oz, dx, dy, dz, angle, sphereX, sphereY, sphereZ);
  if (hitT <= 0.0) return 255.0 - dy * 64.0;

  const hx: f32 = ox + dx * hitT;
  const hy: f32 = oy + dy * hitT;
  const hz: f32 = oz + dz * hitT;
  const id: f32 = hitId(hitT, ox, oy, oz, dx, dy, dz, sphereX, sphereY, sphereZ);
  let nx: f32 = hx - sphereX;
  let ny: f32 = hy - sphereY;
  let nz: f32 = hz - sphereZ;
  if (id != 1.0) {
    for (let i: i32 = 0; i < 9; i++) {
      const col: i32 = i % 3;
      const row: f32 = <f32>(i / 3);
      const bx: f32 = -4.0 + <f32>col * 4.0;
      const by: f32 = 4.0 + sinF(angle + <f32>col + row);
      const bz: f32 = 4.0 + row * 4.0;
      const bt: f32 = sphereT(bx, by, bz, 5.0, ox, oy, oz, dx, dy, dz);
      if (absF(bt - hitT) < 0.001) {
        nx = hx - bx; ny = hy - by; nz = hz - bz;
      }
    }
  }
  const llx: f32 = sceneLX - hx;
  const lly: f32 = sceneLY - hy;
  const llz: f32 = sceneLZ - hz;
  const llen: f32 = Mathf.sqrt(llx * llx + lly * lly + llz * llz);
  const ldx: f32 = llx / llen;
  const ldy: f32 = lly / llen;
  const ldz: f32 = llz / llen;
  const shadowT: f32 = sphereT(sphereX, sphereY, sphereZ, 1.0, hx, hy, hz, ldx, ldy, ldz);
  const shade: f32 = shadowT < -1.0 ? 1.0 : (shadowT < 0.0 ? 0.2 + 0.8 * -shadowT : 0.2);
  let colB: f32 = (hz + 5.0) * clamp0((ldx * nx + ldy * ny + ldz * nz) * 12.0 * shade);
  if (id == 1.0) {
    const cl: f32 = nx * dx + ny * dy + nz * dz;
    const reflX: f32 = dx - nx * 2.0 * cl;
    const reflY: f32 = dy - ny * 2.0 * cl;
    const reflZ: f32 = dz - nz * 2.0 * cl;
    const reflLen: f32 = Mathf.sqrt(reflX * reflX + reflY * reflY + reflZ * reflZ);
    colB += (255.0 - (reflY / reflLen) * 64.0) * 0.2;
  }
  return colB;
}

export function main(): void {
  const angle: f32 = load<f32>(TIME_OFFSET) * 0.016;
  const sphereX: f32 = sinF(angle + 1.5);
  const sphereY: f32 = -0.75 + sinF(angle);
  const sphereZ: f32 = 5.0;
  const sceneLX: f32 = sinF(angle * 2.0 + 1.5) * 9.0;
  const sceneLY: f32 = -9.0;
  const sceneLZ: f32 = sinF(angle * 2.0) * 9.0;

  for (let i: i32 = 0; i < WIDTH * HEIGHT; i++) {
    const x: i32 = i % WIDTH;
    const y: i32 = i / WIDTH;
    const rx: f32 = <f32>x / 128.0 - 1.0;
    const ry: f32 = <f32>y / 128.0 - 1.0;
    const rLen: f32 = Mathf.sqrt(rx * rx + ry * ry + 1.0);
    const dx: f32 = rx / rLen;
    const dy: f32 = ry / rLen;
    const dz: f32 = 1.0 / rLen;

    const wave: f32 = 0.5 + 0.5 * (sinF(<f32>x / 85.0) * sinF(<f32>y / 85.0));
    const r: f32 = traceR(0.0, 0.0, 0.0, dx, dy, dz, angle, sphereX, sphereY, sphereZ, sceneLX, sceneLY, sceneLZ) * wave;
    const g: f32 = traceG(0.0, 0.0, 0.0, dx, dy, dz, angle, sphereX, sphereY, sphereZ, sceneLX, sceneLY, sceneLZ) * wave;
    const b: f32 = traceB(0.0, 0.0, 0.0, dx, dy, dz, angle, sphereX, sphereY, sphereZ, sceneLX, sceneLY, sceneLZ) * wave;

    const pixelOffset: i32 = 16 + i * 12;
    store<i32>(pixelOffset, clamp255(r));
    store<i32>(pixelOffset + 4, clamp255(g));
    store<i32>(pixelOffset + 8, clamp255(b));
  }
}
