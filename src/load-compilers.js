/** Lazy-loaded compiler modules — keeps ~12MB of ASC/Gasm out of the initial bundle. */

let ascModulePromise;
let gasmModulePromise;
let gpuExecutorModulePromise;

export function loadAssemblyScriptCompiler() {
    ascModulePromise ??= import('assemblyscript/dist/asc.js');
    return ascModulePromise;
}

export function loadGasmCompiler() {
    gasmModulePromise ??= import('./gasm-integrator.js');
    return gasmModulePromise;
}

export function loadGPUExecutorModule() {
    gpuExecutorModulePromise ??= import('./browser-gpu-executor.js');
    return gpuExecutorModulePromise;
}
