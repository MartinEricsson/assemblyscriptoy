import { readFile, readdir } from 'node:fs/promises';
import { basename } from 'node:path';

import { compileString } from 'assemblyscript/dist/asc.js';

import { demoCatalog } from '../shader-source.js';
import { compileGasmIntegrator } from '../src/gasm-integrator.js';
import {
    PHOTOREAL_FIELD_SIZE,
    PHOTOREAL_MESH_MAGIC,
} from '../src/photoreal-scene-builder.js';
import { MEMORY_BYTES, createDefaultMemoryLayout } from '../src/runtime-memory-layout.js';

const shaderDirectory = new URL('../shaders/', import.meta.url);
const shaderDirectoryFiles = await readdir(shaderDirectory);
const nativeWgslFiles = shaderDirectoryFiles.filter(file => file.endsWith('.wgsl'));
if (nativeWgslFiles.length > 0) {
    throw new Error(`Handwritten WGSL demos are not allowed: ${nativeWgslFiles.join(', ')}`);
}
const shaderFiles = shaderDirectoryFiles
    .filter(file => file.endsWith('.as'))
    .sort();
const catalogEntries = Object.entries(demoCatalog);
const MEMORY_PAGES = 64;
const DEFAULT_LAYOUT = createDefaultMemoryLayout(MEMORY_BYTES);

const catalogByFile = new Map();
for (const [demoId, entry] of catalogEntries) {
    const match = entry.load.toString().match(/shaders\/([^?'"]+\.as)\?raw/);
    if (!match) {
        throw new Error(`Could not determine the shader file for catalog entry "${demoId}".`);
    }
    const registrations = catalogByFile.get(match[1]) ?? [];
    if (registrations.length > 0 && (!entry.sharedSource || registrations.some(item => !item.sharedSource))) {
        throw new Error(`Shader file "${match[1]}" is registered more than once without sharedSource opt-in.`);
    }
    registrations.push({ demoId, ...entry });
    catalogByFile.set(match[1], registrations);
}

for (const shaderFile of shaderFiles) {
    if (!catalogByFile.has(shaderFile)) {
        throw new Error(`Shader file "${shaderFile}" is not registered in demoCatalog.`);
    }
}

let passed = 0;
for (const [demoId, entry] of catalogEntries) {
    const catalogEntry = { demoId, ...entry };
    const match = catalogEntry.load.toString().match(/shaders\/([^?'\"]+\.as)\?raw/);
    const shaderFile = match[1];

    const source = await readFile(new URL(shaderFile, shaderDirectory), 'utf8');
    const { binary, text, stderr } = await compileString(source, {
        optimize: true,
        runtime: 'stub',
        initialMemory: MEMORY_PAGES,
        maximumMemory: MEMORY_PAGES,
        noAssert: true,
        ...(catalogEntry.assemblyScriptOptions ?? {}),
    });

    if (!binary) {
        throw new Error(
            `${catalogEntry.demoId}: AssemblyScript compilation failed:\n${stderr || 'Unknown error'}`,
        );
    }

    const gasmResult = compileGasmIntegrator(binary, catalogEntry.compileOptions);
    if (!gasmResult.ok) {
        const errors = gasmResult.diagnostics.errors
            .map(error => `${error.code}: ${error.message}`)
            .join('\n');
        throw new Error(`${catalogEntry.demoId}: Gasm compilation failed:\n${errors}`);
    }
    if (typeof gasmResult.wgsl !== 'string' || gasmResult.wgsl.trim() === '') {
        throw new Error(`${catalogEntry.demoId}: Gasm returned no WGSL text.`);
    }
    if (!gasmResult.dispatchInfo.isParallelized) {
        throw new Error(`${catalogEntry.demoId}: Gasm did not parallelize the canonical pixel loop.`);
    }

    if (catalogEntry.demoId === 'compilerGridSph') {
        for (const requiredSource of [
            'const PARTICLE_COUNT: i32 = 8192;',
            'function buildGridCell(',
            'function buildDensityVoxel(',
            'function renderPixel(',
            'const DENSITY_FIELD:',
        ]) {
            if (!source.includes(requiredSource)) {
                throw new Error(`${catalogEntry.demoId}: missing compiler-native SPH contract ${requiredSource}`);
            }
        }
        if (source.includes('atomic.') || /atomic(Add|Load|Store)|atomic</.test(gasmResult.wgsl)) {
            throw new Error(`${catalogEntry.demoId}: cell-owned SPH unexpectedly requires generated atomics.`);
        }
        if (catalogEntry.execution || catalogEntry.sourceType) {
            throw new Error(`${catalogEntry.demoId}: compiler-native SPH must use the default AssemblyScript/Gasm path.`);
        }
    }
    if (gasmResult.dispatchInfo.workItemsX !== 256 * 256) {
        throw new Error(
            `${catalogEntry.demoId}: expected 65,536 work items, got ${gasmResult.dispatchInfo.workItemsX}.`,
        );
    }

    if (typeof catalogEntry.initializeMemory === 'function') {
        const memoryI32 = new Int32Array(MEMORY_BYTES / 4);
        const memoryF32 = new Float32Array(memoryI32.buffer);
        const summary = catalogEntry.initializeMemory({
            memoryI32,
            memoryF32,
            memoryBytes: MEMORY_BYTES,
            layout: DEFAULT_LAYOUT,
        });
        const stateStart = DEFAULT_LAYOUT.state.byteOffset;
        const stateEnd = DEFAULT_LAYOUT.state.byteOffset + DEFAULT_LAYOUT.state.byteLength;
        if (!summary || summary.endOffset > stateEnd) {
            throw new Error(`${catalogEntry.demoId}: memory initializer exceeded the persistent state region.`);
        }
        if (catalogEntry.demoId === 'photorealMeshPathTracer') {
            if (summary.materialOffset % 16 !== 0 || summary.triangleOffset % 16 !== 0 || summary.nodeOffset % 16 !== 0) {
                throw new Error(`${catalogEntry.demoId}: packed scene offsets must be 16-byte aligned.`);
            }
            const header = stateStart / 4;
            if (memoryI32[header] !== PHOTOREAL_MESH_MAGIC) {
                throw new Error('photorealMeshPathTracer: expected packed mesh magic header.');
            }
            if (memoryI32[header + 3] < 4000 || memoryI32[header + 4] < 1000) {
                throw new Error('photorealMeshPathTracer: expected a high-detail triangle mesh and BVH.');
            }
            if (memoryI32[header + 9] !== PHOTOREAL_FIELD_SIZE * PHOTOREAL_FIELD_SIZE) {
                throw new Error('photorealMeshPathTracer: unexpected progressive accumulation cell count.');
            }
        }
    }

    if (catalogEntry.demoId === 'precisionJulia') {
        if (!gasmResult.diagnostics.featuresUsed.usesF64 || !gasmResult.diagnostics.featuresUsed.usesI64) {
            throw new Error('precisionJulia: expected both f64 and i64 feature detection.');
        }
        if (!gasmResult.diagnostics.demotions.some(event => event.kind === 'f64->f32')) {
            throw new Error('precisionJulia: expected an f64->f32 demotion diagnostic.');
        }
    }

    if (catalogEntry.demoId === 'simdKaleidoscope') {
        const advisoryText = gasmResult.diagnostics.advisories.map(item => item.message).join('\n');
        if (!advisoryText.includes('gasm:simd:1.0') || !advisoryText.includes('gasm:math:1.0')) {
            throw new Error('simdKaleidoscope: expected SIMD and math extension advisories.');
        }
        if (!gasmResult.wgsl.includes('vec4<f32>')) {
            throw new Error('simdKaleidoscope: expected vector WGSL output.');
        }
    }

    if (catalogEntry.demoId === 'rippleTank') {
        if (!text.includes('i32.load16_s') || !text.includes('i32.store16')) {
            throw new Error('rippleTank: expected signed 16-bit load/store instructions.');
        }
    }

    if (catalogEntry.demoId === 'grayScottCoral') {
        if (!text.includes('i32.load16_u') || !text.includes('i32.store16')) {
            throw new Error('grayScottCoral: expected unsigned 16-bit load/store instructions.');
        }
    }
    if (shaderFile === 'starter.as') {
        const minifiedResult = compileGasmIntegrator(binary, { minify: true });
        if (!minifiedResult.ok) {
            const errors = minifiedResult.diagnostics.errors
                .map(error => `${error.code}: ${error.message}`)
                .join('\n');
            throw new Error(`${catalogEntry.demoId}: Minified Gasm compilation failed:\n${errors}`);
        }
        if (minifiedResult.wgsl.includes('\n')) {
            throw new Error(`${catalogEntry.demoId}: Minified WGSL was not emitted on one line.`);
        }
    }

    passed++;
    console.log(`PASS ${catalogEntry.demoId} (${basename(shaderFile)})`);
}

console.log(`${passed}/${catalogEntries.length} catalog entries compiled successfully`);
