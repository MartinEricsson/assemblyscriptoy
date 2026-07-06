// ============================================================
// Interactive Ripple Tank - refractive water over cobblestone
// ============================================================
// Drag across the canvas to inject wave energy. Two 128x128 i16
// height fields ping-pong in persistent memory, and the resulting
// normals bend a procedural wet cobblestone floor below the water.
// ============================================================

const WIDTH: i32 = 256;
const FIELD: i32 = 128;
const CELLS: i32 = FIELD * FIELD;
const STATE_OFFSET: i32 = 16 + WIDTH * WIDTH * 12;
const BUFFER_A: i32 = STATE_OFFSET + 16;
const BUFFER_B: i32 = BUFFER_A + CELLS * 2;
const TILE: i32 = 24;

function wrap(value: i32): i32 {
  return value < 0 ? value + FIELD : value >= FIELD ? value - FIELD : value;
}

function address(base: i32, x: i32, y: i32): i32 {
  return base + (wrap(y) * FIELD + wrap(x)) * 2;
}

function sample(base: i32, x: i32, y: i32): i32 {
  return <i32>load<i16>(address(base, x, y));
}

function clampWave(value: i32): i32 {
  return value < -30000 ? -30000 : value > 30000 ? 30000 : value;
}

function clamp255(value: i32): i32 {
  return value < 0 ? 0 : value > 255 ? 255 : value;
}

function clampCoord(value: i32): i32 {
  return value < 0 ? 0 : value > 255 ? 255 : value;
}

function absI(value: i32): i32 {
  return value < 0 ? -value : value;
}

function hash2(x: i32, y: i32): i32 {
  let n: i32 = x * 374761393 + y * 668265263;
  n = (n ^ (n >> 13)) * 1274126177;
  return n ^ (n >> 16);
}

function jitter(hash: i32, shift: i32): i32 {
  return ((hash >> shift) & 15) - 7;
}

export function main(): void {
  const frame: i32 = <i32>load<f32>(0);
  const pointerX: i32 = load<i32>(4) >> 1;
  const pointerY: i32 = load<i32>(8) >> 1;
  const pointerButtons: i32 = load<i32>(12);
  const initializing: bool = frame < 2;
  const initialized: bool = !initializing;
  const readBase: i32 = (frame & 1) == 0 ? BUFFER_A : BUFFER_B;
  const writeBase: i32 = (frame & 1) == 0 ? BUFFER_B : BUFFER_A;

  for (let i: i32 = 0; i < WIDTH * WIDTH; i++) {
    if (i < CELLS / 2) {
      for (let lane: i32 = 0; lane < 2; lane++) {
        const cell: i32 = i * 2 + lane;
        const sx: i32 = cell & 127;
        const sy: i32 = cell >> 7;

        if (initializing) {
          const dx0: i32 = sx - 64;
          const dy0: i32 = sy - 64;
          const d20: i32 = dx0 * dx0 + dy0 * dy0;
          const ring: i32 = absI(d20 - 260);
          const seed: i32 = ring < 80 ? (80 - ring) * 170 : 0;
          store<i16>(BUFFER_A + cell * 2, <i16>seed);
          store<i16>(BUFFER_B + cell * 2, <i16>seed);
        } else {
          const neighbors: i32 =
            sample(readBase, sx - 1, sy)
            + sample(readBase, sx + 1, sy)
            + sample(readBase, sx, sy - 1)
            + sample(readBase, sx, sy + 1);
          let next: i32 = (neighbors >> 1) - sample(writeBase, sx, sy);
          next = next * 246 >> 8;

          if (pointerButtons != 0 && pointerX >= 0 && pointerY >= 0) {
            const pdx: i32 = sx - pointerX;
            const pdy: i32 = sy - pointerY;
            const pd2: i32 = pdx * pdx + pdy * pdy;
            if (pd2 < 36) next += (36 - pd2) * 520;
          }

          const autoX: i32 = 64 + (((frame * 5) >> 2) & 31) - 16;
          const autoY: i32 = 34 + (((frame * 3) >> 2) & 63);
          const adx: i32 = sx - autoX;
          const ady: i32 = sy - autoY;
          if ((frame % 96) < 2 && adx * adx + ady * ady < 18) next += 14000;

          store<i16>(writeBase + cell * 2, <i16>clampWave(next));
        }
      }
    }

    const x: i32 = i & 255;
    const y: i32 = i >> 8;
    const sx: i32 = x >> 1;
    const sy: i32 = y >> 1;
    const h: i32 = initialized ? sample(readBase, sx, sy) : 0;
    const gx: i32 = initialized ? sample(readBase, sx + 1, sy) - sample(readBase, sx - 1, sy) : 0;
    const gy: i32 = initialized ? sample(readBase, sx, sy + 1) - sample(readBase, sx, sy - 1) : 0;

    const rx: i32 = clampCoord(x + (gx >> 11));
    const ry: i32 = clampCoord(y + (gy >> 11));
    const tileX: i32 = rx / TILE;
    const tileY: i32 = ry / TILE;
    let nearest: i32 = 1000000;
    let second: i32 = 1000000;
    let nearestHash: i32 = 0;

    for (let oy: i32 = -1; oy <= 1; oy++) {
      for (let ox: i32 = -1; ox <= 1; ox++) {
        const cxTile: i32 = tileX + ox;
        const cyTile: i32 = tileY + oy;
        const hash: i32 = hash2(cxTile, cyTile);
        const cx: i32 = cxTile * TILE + 12 + jitter(hash, 0);
        const cy: i32 = cyTile * TILE + 12 + jitter(hash, 5);
        const dx: i32 = rx - cx;
        const dy: i32 = ry - cy;
        const d2: i32 = dx * dx + dy * dy;
        if (d2 < nearest) {
          second = nearest;
          nearest = d2;
          nearestHash = hash;
        } else if (d2 < second) {
          second = d2;
        }
      }
    }

    const border: i32 = second - nearest;
    const pit: i32 = (hash2(rx >> 1, ry >> 1) & 31) + (hash2(rx >> 3, ry >> 3) & 15);
    const stoneTone: i32 = 112 + (nearestHash & 31) - (pit >> 1);
    const mortar: i32 = border < 130 ? 1 : 0;
    const bevel: i32 = border < 420 ? (420 - border) >> 4 : 0;
    const directional: i32 = ((rx - ry) >> 3) + ((gx - gy) >> 10);
    const caustic: i32 = clamp255(34 + (absI(gx - gy) >> 8) + (absI(gx + gy) >> 9) + (h >> 8));
    const crest: i32 = clamp255(18 + (h >> 7));
    const reflection: i32 = clamp255(24 + ((-gy) >> 9) + crest);
    const groutShade: i32 = mortar != 0 ? 52 : 0;

    let r: i32 = stoneTone + 18 + directional + bevel - groutShade;
    let g: i32 = stoneTone + 13 + (nearestHash >> 4 & 19) + bevel - groutShade;
    let b: i32 = stoneTone + 9 + (nearestHash >> 9 & 15) + (bevel >> 1) - groutShade;

    r = (r * 4 + 16 + caustic + reflection) / 5;
    g = (g * 4 + 34 + caustic + reflection) / 5;
    b = (b * 4 + 62 + caustic * 2 + reflection * 2) / 5;

    const glint: i32 = (caustic > 150 && border > 380) ? (caustic - 130) : 0;
    r = clamp255(r + glint);
    g = clamp255(g + glint);
    b = clamp255(b + glint + crest);

    const pixelOffset: i32 = 16 + i * 12;
    store<i32>(pixelOffset, r);
    store<i32>(pixelOffset + 4, g);
    store<i32>(pixelOffset + 8, b);
  }
}
