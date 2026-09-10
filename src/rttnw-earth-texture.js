import { MEMORY_BYTES, createDefaultMemoryLayout } from './runtime-memory-layout.js';

export const RTNW_EARTH_MAGIC = 0x52544E57;
export const RTNW_EARTH_WIDTH = 128;
export const RTNW_EARTH_HEIGHT = 64;

const MAGIC_OFFSET = 786448;
const TEX_HEADER_OFFSET = 1835072;
const TEXEL_OFFSET = 1835088;
const END_OFFSET = 1867856;

const PI = Math.PI;
const TWO_PI = 2 * PI;

function hashU(value) {
    let state = (Math.imul(value, 747796405) + 2891336453) >>> 0;
    const word = Math.imul(((state >>> ((state >>> 28) + 4)) ^ state) >>> 0, 277803737) >>> 0;
    return ((word >>> 22) ^ word) >>> 0;
}

function hash01(i, j, salt) {
    return hashU((i * 1973 + j * 9277 + salt * 26699 + 12345) >>> 0) / 4294967296;
}

function wrapLon(delta) {
    let value = delta;
    if (value > PI) value -= TWO_PI;
    if (value < -PI) value += TWO_PI;
    return value;
}

function landAmount(lat, lon) {
    const blobs = [
        { lon: -1.55, lat: 0.35, rx: 0.85, ry: 0.55 },
        { lon: -1.15, lat: -0.45, rx: 0.45, ry: 0.70 },
        { lon: 0.25, lat: 0.55, rx: 0.55, ry: 0.35 },
        { lon: 0.35, lat: 0.05, rx: 0.40, ry: 0.75 },
        { lon: 1.55, lat: 0.45, rx: 1.15, ry: 0.50 },
        { lon: 2.35, lat: -0.45, rx: 0.45, ry: 0.28 },
    ];
    let amount = 0;
    for (let b = 0; b < blobs.length; b++) {
        const blob = blobs[b];
        const nx = wrapLon(lon - blob.lon) / blob.rx;
        const ny = (lat - blob.lat) / blob.ry;
        const falloff = 1.0 + (hash01((b + 1) * 17, 4, 11) - 0.5) * 0.35;
        const d = nx * nx + ny * ny;
        if (d < falloff * falloff) {
            amount = Math.max(amount, 1 - d / (falloff * falloff));
        }
    }
    return amount;
}

function sampleGlobe(i, j) {
    const u = i / RTNW_EARTH_WIDTH;
    const v = j / RTNW_EARTH_HEIGHT;
    const lat = (0.5 - v) * PI;
    const lon = (u - 0.5) * TWO_PI;

    if (Math.abs(lat) > 1.1) {
        return [245, 248, 252];
    }

    const land = landAmount(lat, lon);
    const n = hash01(i, j, 21);
    if (land > 0.12 + n * 0.08) {
        const kind = hash01(i, j, 7);
        if (kind < 0.34) return [102, 118, 42];
        if (kind < 0.72) return [46, 102, 38];
        return [168, 138, 78];
    }

    const deep = 0.55 + 0.45 * Math.max(0, 0.35 - land);
    return [
        Math.round(8 * deep),
        Math.round(18 * deep),
        Math.round(72 + 18 * deep),
    ];
}

export function initializeRttnwEarthMemory({ memoryI32, memoryF32, memoryBytes, layout }) {
    const stateEnd = layout.state.byteOffset + layout.state.byteLength;
    if (END_OFFSET > stateEnd) {
        throw new Error(
            `Earth texture needs endOffset ${END_OFFSET}, which exceeds persistent state ending at ${stateEnd}.`,
        );
    }

    memoryI32[MAGIC_OFFSET >> 2] = RTNW_EARTH_MAGIC;
    memoryI32[(MAGIC_OFFSET >> 2) + 1] = 0;
    memoryI32[(MAGIC_OFFSET >> 2) + 2] = 0;
    memoryI32[(MAGIC_OFFSET >> 2) + 3] = 0;

    memoryI32[TEX_HEADER_OFFSET >> 2] = RTNW_EARTH_WIDTH;
    memoryI32[(TEX_HEADER_OFFSET >> 2) + 1] = RTNW_EARTH_HEIGHT;
    memoryI32[(TEX_HEADER_OFFSET >> 2) + 2] = TEXEL_OFFSET;
    memoryI32[(TEX_HEADER_OFFSET >> 2) + 3] = 0;

    const texelWord = TEXEL_OFFSET >> 2;
    for (let j = 0; j < RTNW_EARTH_HEIGHT; j++) {
        for (let i = 0; i < RTNW_EARTH_WIDTH; i++) {
            const [r, g, b] = sampleGlobe(i, j);
            memoryI32[texelWord + j * RTNW_EARTH_WIDTH + i] = r | (g << 8) | (b << 16);
        }
    }

    return {
        endOffset: END_OFFSET,
        width: RTNW_EARTH_WIDTH,
        height: RTNW_EARTH_HEIGHT,
        texelOffset: TEXEL_OFFSET,
    };
}

export const RTNW_EARTH_LAYOUT = {
    magicOffset: MAGIC_OFFSET,
    texHeaderOffset: TEX_HEADER_OFFSET,
    texelOffset: TEXEL_OFFSET,
    endOffset: END_OFFSET,
    defaultLayout: createDefaultMemoryLayout(MEMORY_BYTES),
};
