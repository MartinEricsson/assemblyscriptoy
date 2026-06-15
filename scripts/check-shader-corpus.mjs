import { readFile, readdir } from 'node:fs/promises';
import { basename } from 'node:path';

import { compileString } from 'assemblyscript/dist/asc.js';

import { demoCatalog } from '../shader-source.js';
import { compileGasmIntegrator } from '../src/gasm-integrator.js';

const shaderDirectory = new URL('../shaders/', import.meta.url);
const shaderFiles = (await readdir(shaderDirectory))
    .filter(file => file.endsWith('.as'))
    .sort();
const catalogEntries = Object.entries(demoCatalog);

if (catalogEntries.length !== shaderFiles.length) {
    throw new Error(
        `Shader catalog has ${catalogEntries.length} entries, but shaders/ contains ${shaderFiles.length} .as files.`,
    );
}

const catalogByFile = new Map();
for (const [demoId, entry] of catalogEntries) {
    const match = entry.load.toString().match(/shaders\/([^?'"]+\.as)\?raw/);
    if (!match) {
        throw new Error(`Could not determine the shader file for catalog entry "${demoId}".`);
    }
    if (catalogByFile.has(match[1])) {
        throw new Error(`Shader file "${match[1]}" is registered more than once.`);
    }
    catalogByFile.set(match[1], { demoId, name: entry.name });
}

let passed = 0;
for (const shaderFile of shaderFiles) {
    const catalogEntry = catalogByFile.get(shaderFile);
    if (!catalogEntry) {
        throw new Error(`Shader file "${shaderFile}" is not registered in demoCatalog.`);
    }

    const source = await readFile(new URL(shaderFile, shaderDirectory), 'utf8');
    const { binary, stderr } = await compileString(source, {
        optimize: true,
        runtime: 'stub',
        initialMemory: 16,
        maximumMemory: 16,
        noAssert: true,
    });

    if (!binary) {
        throw new Error(
            `${catalogEntry.demoId}: AssemblyScript compilation failed:\n${stderr || 'Unknown error'}`,
        );
    }

    const gasmResult = compileGasmIntegrator(binary);
    if (!gasmResult.ok) {
        const errors = gasmResult.diagnostics.errors
            .map(error => `${error.code}: ${error.message}`)
            .join('\n');
        throw new Error(`${catalogEntry.demoId}: Gasm compilation failed:\n${errors}`);
    }
    if (typeof gasmResult.wgsl !== 'string' || gasmResult.wgsl.trim() === '') {
        throw new Error(`${catalogEntry.demoId}: Gasm returned no WGSL text.`);
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

console.log(`${passed}/${shaderFiles.length} shaders compiled successfully`);
