import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

import { compileString } from 'assemblyscript/dist/asc.js';

import {
    PBF_FLUID_COUNT,
    PBF_HEADER,
    PBF_MAGIC,
    PBF_OBSTACLE,
    PBF_SCENE_HYDROSTATIC,
    PBF_STATE,
    initializePbfHydrostaticMemory,
} from '../src/pbf-scene-builder.js';
import {
    MEMORY_BYTES,
    MEMORY_PAGES,
    createDefaultMemoryLayout,
} from '../src/runtime-memory-layout.js';

const source = await readFile(new URL('../shaders/pbf_fluid_dynamics.as', import.meta.url), 'utf8');
const { binary, stderr } = await compileString(source, {
    optimize: true,
    runtime: 'stub',
    initialMemory: MEMORY_PAGES,
    maximumMemory: MEMORY_PAGES,
    noAssert: true,
});

if (!binary) {
    throw new Error(`PBF invariant check could not compile the shader:\n${stderr || 'Unknown error'}`);
}

const layout = createDefaultMemoryLayout(MEMORY_BYTES);

function stateWord(relativeByteOffset) {
    return (layout.state.byteOffset + relativeByteOffset) / 4;
}

function particleSnapshot(memoryF32, positionStateOffset = PBF_STATE.committedPositions) {
    const positionStart = stateWord(positionStateOffset);
    const velocityStart = stateWord(PBF_STATE.velocities);
    const particles = [];
    for (let particle = 0; particle < PBF_FLUID_COUNT; particle++) {
        const position = positionStart + particle * 3;
        const velocity = velocityStart + particle * 3;
        particles.push({
            x: memoryF32[position],
            y: memoryF32[position + 1],
            z: memoryF32[position + 2],
            vx: memoryF32[velocity],
            vy: memoryF32[velocity + 1],
            vz: memoryF32[velocity + 2],
        });
    }
    return particles;
}

function validateFiniteAndContained(name, particles, completedStep) {
    for (const [particle, state] of particles.entries()) {
        for (const [key, value] of Object.entries(state)) {
            assert.ok(Number.isFinite(value), `${name}: ${key} for particle ${particle} is non-finite at step ${completedStep}`);
        }
        assert.ok(state.x >= -1.15001 && state.x <= 1.15001, `${name}: particle ${particle} escaped the x boundary`);
        assert.ok(state.y >= -0.84001 && state.y <= 0.84001, `${name}: particle ${particle} escaped the y boundary`);
        assert.ok(state.z >= -0.75001 && state.z <= 0.75001, `${name}: particle ${particle} escaped the z boundary`);
        const obstacleDistance = Math.hypot(
            state.x - PBF_OBSTACLE.x,
            state.y - PBF_OBSTACLE.y,
            state.z - PBF_OBSTACLE.z,
        );
        assert.ok(
            obstacleDistance >= PBF_OBSTACLE.collisionRadius - 0.0001,
            `${name}: particle ${particle} penetrated the static sphere at step ${completedStep}`,
        );
    }
}

function summarize(particles) {
    let minX = Infinity;
    let maxX = -Infinity;
    let speedSum = 0;
    let maxSpeed = 0;
    for (const particle of particles) {
        const speed = Math.hypot(particle.vx, particle.vy, particle.vz);
        minX = Math.min(minX, particle.x);
        maxX = Math.max(maxX, particle.x);
        speedSum += speed;
        maxSpeed = Math.max(maxSpeed, speed);
    }
    return {
        spanX: maxX - minX,
        meanSpeed: speedSum / particles.length,
        maxSpeed,
    };
}

async function runBenchmark({ name, scene, initializeMemory, steps }) {
    const { instance } = await WebAssembly.instantiate(binary, {
        env: {
            abort: () => { throw new Error(`${name}: Wasm aborted`); },
            seed: () => 1,
        },
    });
    const memoryI32 = new Int32Array(instance.exports.memory.buffer);
    const memoryF32 = new Float32Array(instance.exports.memory.buffer);
    initializeMemory({ memoryI32, memoryF32, memoryBytes: MEMORY_BYTES, layout });
    memoryI32[stateWord(PBF_HEADER.testMode)] = 1;

    memoryF32[0] = 0;
    instance.exports.main();
    assert.equal(memoryI32[stateWord(PBF_HEADER.magic)], PBF_MAGIC, `${name}: initialization magic was not written`);
    assert.equal(memoryI32[stateWord(PBF_HEADER.scene)], scene, `${name}: catalog initializer selected the wrong scene`);

    const psiStart = stateWord(PBF_STATE.boundaryPsi);
    for (let boundary = 0; boundary < 513; boundary++) {
        const psi = memoryF32[psiStart + boundary];
        assert.ok(Number.isFinite(psi) && psi > 0, `${name}: invalid calibrated boundary Psi at ${boundary}`);
    }

    const initialParticles = particleSnapshot(memoryF32);
    validateFiniteAndContained(name, initialParticles, 0);
    const initial = summarize(initialParticles);
    for (let frame = 1; frame <= steps * 10; frame++) {
        memoryF32[0] = frame;
        instance.exports.main();
        if (frame % 10 === 0) {
            const completedSteps = frame / 10;
            const committedOffset = completedSteps % 2 === 0
                ? PBF_STATE.committedPositions
                : PBF_STATE.committedAlternate;
            validateFiniteAndContained(name, particleSnapshot(memoryF32, committedOffset), completedSteps);
        }
    }

    const particles = particleSnapshot(memoryF32);
    const summary = summarize(particles);
    summary.initialSpanX = initial.spanX;
    summary.meanDensityError = memoryI32[stateWord(PBF_HEADER.meanDensityError)];
    summary.maxDensityError = memoryI32[stateWord(PBF_HEADER.maxDensityError)];
    return summary;
}

const hydrostatic = await runBenchmark({
    name: 'hydrostatic',
    scene: PBF_SCENE_HYDROSTATIC,
    initializeMemory: initializePbfHydrostaticMemory,
    steps: 720,
});
console.log('PBF hydrostatic metrics', hydrostatic);
assert.ok(hydrostatic.meanDensityError <= 4, `hydrostatic: mean density error ${hydrostatic.meanDensityError}% exceeded 4%`);
assert.ok(hydrostatic.maxDensityError <= 13, `hydrostatic: max density error ${hydrostatic.maxDensityError}% exceeded 13%`);
assert.ok(hydrostatic.meanSpeed <= 0.5, `hydrostatic: residual mean speed ${hydrostatic.meanSpeed} exceeded 0.5`);
// The denser 3,800-particle column has a small fast tail while retaining a
// low mean residual speed. Keep the peak well below the solver's 6 m/s clamp.
assert.ok(hydrostatic.maxSpeed <= 2.0, `hydrostatic: residual max speed ${hydrostatic.maxSpeed} exceeded 2.0`);
console.log('PASS PBF hydrostatic invariants');
