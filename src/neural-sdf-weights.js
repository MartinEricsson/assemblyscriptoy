import { MEMORY_BYTES, createDefaultMemoryLayout } from './runtime-memory-layout.js';

export const MLP_MAGIC = 0x4D4C5031;
export const MLP_INPUT_SIZE = 24;
export const MLP_HIDDEN1 = 32;
export const MLP_HIDDEN2 = 32;
export const MLP_OUTPUT_SIZE = 1;
export const MLP_WEIGHT_COUNT = 1889;

const STATE_OFFSET = 786448;
const WEIGHT_BYTE_OFFSET = STATE_OFFSET + 64;
const END_OFFSET = WEIGHT_BYTE_OFFSET + MLP_WEIGHT_COUNT * 4;

const W1_SIZE = MLP_HIDDEN1 * MLP_INPUT_SIZE;
const B1_SIZE = MLP_HIDDEN1;
const W2_SIZE = MLP_HIDDEN2 * MLP_HIDDEN1;
const B2_SIZE = MLP_HIDDEN2;
const W3_SIZE = MLP_HIDDEN2;
const B3_SIZE = 1;

const W1_OFFSET = 0;
const B1_OFFSET = W1_OFFSET + W1_SIZE;
const W2_OFFSET = B1_OFFSET + B1_SIZE;
const B2_OFFSET = W2_OFFSET + W2_SIZE;
const W3_OFFSET = B2_OFFSET + B2_SIZE;
const B3_OFFSET = W3_OFFSET + W3_SIZE;

const TORUS_R = 0.72;
const TORUS_R_TUBE = 0.24;
const SAMPLE_MIN = -1.4;
const SAMPLE_SPAN = 2.8;
const SAMPLE_COUNT = 1024;
const TRAIN_ITERS = 600;
const LEARNING_RATE = 0.012;
const WEIGHT_CLAMP = 4;
const MAX_MAE = 0.18;
const PI = 3.14159265;
const TWO_PI = 6.28318530;

let cachedWeights = null;
let cachedMae = 0;

function createMulberry32(seed) {
    let state = seed >>> 0;
    return function next() {
        state = (state + 0x6D2B79F5) >>> 0;
        let t = state;
        t = Math.imul(t ^ (t >>> 15), t | 1);
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}

function sinF(x) {
    let value = x - Math.floor(x / TWO_PI + 0.5) * TWO_PI;
    if (value > PI * 0.5) value = PI - value;
    if (value < -PI * 0.5) value = -PI - value;
    const x2 = value * value;
    return value * (1.0 - x2 / 6.0 * (1.0 - x2 / 20.0 * (1.0 - x2 / 42.0)));
}

function cosF(x) {
    return sinF(x + PI * 0.5);
}

function encodeInput(px, py, pz, dest) {
    dest[0] = px;
    dest[1] = py;
    dest[2] = pz;
    let offset = 3;
    let scale = 1;
    for (let k = 0; k < 3; k++) {
        dest[offset++] = sinF(scale * px);
        dest[offset++] = cosF(scale * px);
        dest[offset++] = sinF(scale * py);
        dest[offset++] = cosF(scale * py);
        dest[offset++] = sinF(scale * pz);
        dest[offset++] = cosF(scale * pz);
        scale *= 2;
    }
    dest[21] = sinF(8 * px);
    dest[22] = sinF(8 * py);
    dest[23] = sinF(8 * pz);
}

function sdTorus(px, py, pz, major, minor) {
    const qx = Math.sqrt(px * px + pz * pz) - major;
    return Math.sqrt(qx * qx + py * py) - minor;
}

function randn(rng) {
    const u1 = Math.max(rng(), 1e-7);
    const u2 = rng();
    return Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math.PI * u2);
}

function heFill(weights, offset, count, fanIn, rng) {
    const std = Math.sqrt(2 / fanIn);
    for (let i = 0; i < count; i++) {
        weights[offset + i] = randn(rng) * std;
    }
}

function trainWeights() {
    const rng = createMulberry32(1);
    const weights = new Float32Array(MLP_WEIGHT_COUNT);
    heFill(weights, W1_OFFSET, W1_SIZE, MLP_INPUT_SIZE, rng);
    heFill(weights, W2_OFFSET, W2_SIZE, MLP_HIDDEN1, rng);
    heFill(weights, W3_OFFSET, W3_SIZE, MLP_HIDDEN2, rng);

    const samplesX = new Float32Array(SAMPLE_COUNT * 3);
    const targets = new Float32Array(SAMPLE_COUNT);
    for (let n = 0; n < SAMPLE_COUNT; n++) {
        const px = SAMPLE_MIN + rng() * SAMPLE_SPAN;
        const py = SAMPLE_MIN + rng() * SAMPLE_SPAN;
        const pz = SAMPLE_MIN + rng() * SAMPLE_SPAN;
        samplesX[n * 3] = px;
        samplesX[n * 3 + 1] = py;
        samplesX[n * 3 + 2] = pz;
        targets[n] = sdTorus(px, py, pz, TORUS_R, TORUS_R_TUBE);
    }

    const grad = new Float32Array(MLP_WEIGHT_COUNT);
    const x = new Float32Array(MLP_INPUT_SIZE);
    const z1 = new Float32Array(MLP_HIDDEN1);
    const h1 = new Float32Array(MLP_HIDDEN1);
    const z2 = new Float32Array(MLP_HIDDEN2);
    const h2 = new Float32Array(MLP_HIDDEN2);
    const dz1 = new Float32Array(MLP_HIDDEN1);
    const dz2 = new Float32Array(MLP_HIDDEN2);
    const invBatch = 1 / SAMPLE_COUNT;

    for (let iter = 0; iter < TRAIN_ITERS; iter++) {
        grad.fill(0);
        for (let n = 0; n < SAMPLE_COUNT; n++) {
            encodeInput(samplesX[n * 3], samplesX[n * 3 + 1], samplesX[n * 3 + 2], x);

            for (let j = 0; j < MLP_HIDDEN1; j++) {
                let sum = weights[B1_OFFSET + j];
                const row = W1_OFFSET + j * MLP_INPUT_SIZE;
                for (let i = 0; i < MLP_INPUT_SIZE; i++) {
                    sum += weights[row + i] * x[i];
                }
                z1[j] = sum;
                h1[j] = sum > 0 ? sum : 0;
            }

            for (let k = 0; k < MLP_HIDDEN2; k++) {
                let sum = weights[B2_OFFSET + k];
                const row = W2_OFFSET + k * MLP_HIDDEN1;
                for (let j = 0; j < MLP_HIDDEN1; j++) {
                    sum += weights[row + j] * h1[j];
                }
                z2[k] = sum;
                h2[k] = sum > 0 ? sum : 0;
            }

            let y = weights[B3_OFFSET];
            for (let k = 0; k < MLP_HIDDEN2; k++) {
                y += weights[W3_OFFSET + k] * h2[k];
            }

            const dy = y - targets[n];
            grad[B3_OFFSET] += dy;
            for (let k = 0; k < MLP_HIDDEN2; k++) {
                grad[W3_OFFSET + k] += dy * h2[k];
                dz2[k] = dy * weights[W3_OFFSET + k] * (z2[k] > 0 ? 1 : 0);
            }

            for (let j = 0; j < MLP_HIDDEN1; j++) {
                dz1[j] = 0;
            }
            for (let k = 0; k < MLP_HIDDEN2; k++) {
                const row = W2_OFFSET + k * MLP_HIDDEN1;
                const gk = dz2[k];
                grad[B2_OFFSET + k] += gk;
                for (let j = 0; j < MLP_HIDDEN1; j++) {
                    grad[row + j] += gk * h1[j];
                    dz1[j] += weights[row + j] * gk;
                }
            }

            for (let j = 0; j < MLP_HIDDEN1; j++) {
                const gj = dz1[j] * (z1[j] > 0 ? 1 : 0);
                grad[B1_OFFSET + j] += gj;
                const row = W1_OFFSET + j * MLP_INPUT_SIZE;
                for (let i = 0; i < MLP_INPUT_SIZE; i++) {
                    grad[row + i] += gj * x[i];
                }
            }
        }

        for (let w = 0; w < MLP_WEIGHT_COUNT; w++) {
            let next = weights[w] - LEARNING_RATE * grad[w] * invBatch;
            if (next > WEIGHT_CLAMP) next = WEIGHT_CLAMP;
            if (next < -WEIGHT_CLAMP) next = -WEIGHT_CLAMP;
            weights[w] = next;
        }
    }

    let absError = 0;
    for (let n = 0; n < SAMPLE_COUNT; n++) {
        encodeInput(samplesX[n * 3], samplesX[n * 3 + 1], samplesX[n * 3 + 2], x);
        for (let j = 0; j < MLP_HIDDEN1; j++) {
            let sum = weights[B1_OFFSET + j];
            const row = W1_OFFSET + j * MLP_INPUT_SIZE;
            for (let i = 0; i < MLP_INPUT_SIZE; i++) {
                sum += weights[row + i] * x[i];
            }
            h1[j] = sum > 0 ? sum : 0;
        }
        for (let k = 0; k < MLP_HIDDEN2; k++) {
            let sum = weights[B2_OFFSET + k];
            const row = W2_OFFSET + k * MLP_HIDDEN1;
            for (let j = 0; j < MLP_HIDDEN1; j++) {
                sum += weights[row + j] * h1[j];
            }
            h2[k] = sum > 0 ? sum : 0;
        }
        let y = weights[B3_OFFSET];
        for (let k = 0; k < MLP_HIDDEN2; k++) {
            y += weights[W3_OFFSET + k] * h2[k];
        }
        absError += Math.abs(y - targets[n]);
    }

    const mae = absError / SAMPLE_COUNT;
    if (!Number.isFinite(mae) || mae > MAX_MAE) {
        throw new Error(
            `Neural SDF MAE after ${TRAIN_ITERS} iters is ${mae}, which exceeds ${MAX_MAE}.`,
        );
    }

    return { weights, mae };
}

function bakedWeights() {
    if (!cachedWeights) {
        const trained = trainWeights();
        cachedWeights = trained.weights;
        cachedMae = trained.mae;
    }
    return { weights: cachedWeights, mae: cachedMae };
}

export function initializeNeuralSdfMemory({ memoryI32, memoryF32, memoryBytes, layout }) {
    const stateEnd = layout.state.byteOffset + layout.state.byteLength;
    if (END_OFFSET > stateEnd) {
        throw new Error(
            `Neural SDF weights need endOffset ${END_OFFSET}, which exceeds persistent state ending at ${stateEnd}.`,
        );
    }

    const { weights } = bakedWeights();
    const header = STATE_OFFSET >> 2;
    memoryI32[header] = MLP_MAGIC;
    memoryI32[header + 1] = 0;
    memoryI32[header + 2] = 0;
    memoryI32[header + 3] = 0;
    memoryI32[header + 4] = MLP_INPUT_SIZE;
    memoryI32[header + 5] = MLP_HIDDEN1;
    memoryI32[header + 6] = MLP_HIDDEN2;
    memoryI32[header + 7] = MLP_OUTPUT_SIZE;
    memoryI32[header + 8] = MLP_WEIGHT_COUNT;

    const weightWord = WEIGHT_BYTE_OFFSET >> 2;
    for (let i = 0; i < MLP_WEIGHT_COUNT; i++) {
        memoryF32[weightWord + i] = weights[i];
    }

    return {
        endOffset: END_OFFSET,
        weightCount: MLP_WEIGHT_COUNT,
        inputSize: MLP_INPUT_SIZE,
        hidden1: MLP_HIDDEN1,
        hidden2: MLP_HIDDEN2,
        magic: MLP_MAGIC,
    };
}

export const MLP_LAYOUT = {
    magicOffset: STATE_OFFSET,
    weightOffset: WEIGHT_BYTE_OFFSET,
    endOffset: END_OFFSET,
    defaultLayout: createDefaultMemoryLayout(MEMORY_BYTES),
};
