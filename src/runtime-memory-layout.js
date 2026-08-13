export const CANVAS_SIZE = 256;
export const INPUT_BYTES = 16;
export const PIXEL_OUTPUT_BYTES = CANVAS_SIZE * CANVAS_SIZE * 3 * 4;
export const MEMORY_BYTES = 4 * 1024 * 1024;
export const MEMORY_PAGES = MEMORY_BYTES / 65536;

export function createDefaultMemoryLayout(memorySize = MEMORY_BYTES) {
    return {
        inputs: { byteOffset: 0, byteLength: INPUT_BYTES },
        outputs: { byteOffset: INPUT_BYTES, byteLength: PIXEL_OUTPUT_BYTES },
        state: {
            byteOffset: INPUT_BYTES + PIXEL_OUTPUT_BYTES,
            byteLength: memorySize - INPUT_BYTES - PIXEL_OUTPUT_BYTES,
        },
    };
}
