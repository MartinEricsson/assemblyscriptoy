import { compileWithRuntimeInfo } from '@gasm-compiler/core/browser';

export const DEFAULT_GASM_COMPILE_OPTIONS = {
    optimize: true,
    demotionPolicy: { i64: 'allow-lossy', f64: 'allow' },
    sourceMapping: 'detailed',
};

/**
 * Gasm 0.5 integrator compile path: prepareModule + compileWithRuntimeInfo.
 * Retries with specVersion "0.1" when compile-time f64 demotion is required
 * but the Wasm module has no static f64 types for prepareModule to detect.
 */
export function compileGasmIntegrator(wasmBytes, options = {}) {
    const opts = { ...DEFAULT_GASM_COMPILE_OPTIONS, ...options };
    let result = compileWithRuntimeInfo(wasmBytes, opts);
    if (result.ok) return result;

    const err = result.diagnostics.errors[0];
    if (
        err?.code === 'ERR_F64_DEMOTION_REQUIRED' &&
        opts.demotionPolicy?.f64 === 'allow' &&
        opts.specVersion !== '0.1'
    ) {
        result = compileWithRuntimeInfo(wasmBytes, { ...opts, specVersion: '0.1' });
        if (result.ok) {
            result.diagnostics.advisories = [
                ...(result.diagnostics.advisories ?? []),
                {
                    severity: 'advisory',
                    code: 'GASM_ADVISORY_F64_DEMOTION_V01_COMPAT',
                    message:
                        'Compile-time f64 demotion was required; retried with specVersion "0.1".',
                },
            ];
        }
    }

    return result;
}
