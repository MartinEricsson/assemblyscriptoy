export const PBF_SCENE_HYDROSTATIC = 0;

export const PBF_FLUID_COUNT = 3500;
export const PBF_OBSTACLE = Object.freeze({
    x: 0,
    y: -0.42,
    z: 0,
    collisionRadius: 0.32,
});
export const PBF_HEADER_BYTES = 64;
export const PBF_MAGIC = 0x50424633; // PBF3

export const PBF_HEADER = Object.freeze({
    magic: 0,
    scene: 4,
    testMode: 8,
    viewMode: 12,
    previousButtons: 16,
    cameraYaw: 20,
    cameraPitch: 24,
    meanDensityError: 28,
    maxDensityError: 32,
});

export const PBF_STATE = Object.freeze({
    committedPositions: PBF_HEADER_BYTES,
    velocities: PBF_HEADER_BYTES + PBF_FLUID_COUNT * 3 * 4,
    positionA: PBF_HEADER_BYTES + PBF_FLUID_COUNT * 6 * 4,
    positionB: PBF_HEADER_BYTES + PBF_FLUID_COUNT * 9 * 4,
    density: PBF_HEADER_BYTES + PBF_FLUID_COUNT * 12 * 4,
    lambda: PBF_HEADER_BYTES + PBF_FLUID_COUNT * 13 * 4,
    neighborCount: PBF_HEADER_BYTES + PBF_FLUID_COUNT * 14 * 4,
    boundaryPsi: PBF_HEADER_BYTES + PBF_FLUID_COUNT * 15 * 4,
    committedAlternate: PBF_HEADER_BYTES + PBF_FLUID_COUNT * 15 * 4 + 513 * 4,
});

export function initializePbfHydrostaticMemory({ memoryI32, layout }) {
    const stateByteOffset = layout.state.byteOffset;
    const stateWordOffset = stateByteOffset / 4;
    memoryI32[stateWordOffset + PBF_HEADER.magic / 4] = 0;
    memoryI32[stateWordOffset + PBF_HEADER.scene / 4] = PBF_SCENE_HYDROSTATIC;
    memoryI32[stateWordOffset + PBF_HEADER.testMode / 4] = 0;
    memoryI32[stateWordOffset + PBF_HEADER.viewMode / 4] = 0;
    memoryI32[stateWordOffset + PBF_HEADER.previousButtons / 4] = 0;

    return {
        endOffset: stateByteOffset + PBF_STATE.committedAlternate + PBF_FLUID_COUNT * 3 * 4,
    };
}
