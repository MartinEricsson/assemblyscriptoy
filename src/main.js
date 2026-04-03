import { BrowserGPUExecutor, compileWithDiagnostics } from '@gasm-compiler/core/browser';
import { wgslCode as initialWGSL } from '../build/shader.js';
import { compileString } from 'assemblyscript/dist/asc.js';
import {
    shaderFlagshipSdfScene,
    shaderFlagshipMandelbrot,
    shaderFlagshipClouds,
    shaderFlagshipFire,
    shaderCornellBoxGi,
    shaderStarter
} from '../shader-source.js';

const demoLibrary = {
    'starter': { name: 'Starter Template', code: shaderStarter },
    'flagshipSdfScene': { name: 'Raymarched SDF Scene', code: shaderFlagshipSdfScene },
    'flagshipMandelbrot': { name: 'Deep Mandelbrot Zoom', code: shaderFlagshipMandelbrot },
    'flagshipClouds': { name: 'Volumetric Clouds', code: shaderFlagshipClouds },

    'flagshipFire': { name: 'Turbulent Fire', code: shaderFlagshipFire },
    'cornellBoxGi': { name: 'Cornell Box (Path Tracing)', code: shaderCornellBoxGi }
};

let currentWGSL = initialWGSL;
let currentSource = shaderStarter;
let currentDemo = 'starter';

// ── Compiler results builder ─────────────────────────────────────
function buildCompilerResultsHTML({ asStderr, asBinarySize, gasmResult, renderMode }) {
    const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    let html = '';

    // ── AS Compiler section ──
    html += `<div style="margin-bottom: 16px;">`;
    html += `<h3 style="color: #4ec9b0; margin: 0 0 8px 0; font-size: 14px;">AssemblyScript Compiler</h3>`;
    html += `<div style="background: #1e1e1e; border: 1px solid #333; border-radius: 4px; padding: 10px; font-family: 'Courier New', monospace; font-size: 13px;">`;
    if (asBinarySize != null) {
        html += `<div style="color: #4ec9b0;">✓ Compiled successfully (${asBinarySize} bytes)</div>`;
    }
    if (asStderr) {
        const trimmed = asStderr.trim();
        if (trimmed) {
            html += `<div style="color: #dcdcaa; margin-top: 6px;"><strong>stderr:</strong></div>`;
            html += `<pre style="color: #d4d4d4; margin: 4px 0 0 0; white-space: pre-wrap; font-size: 13px;">${esc(trimmed)}</pre>`;
        }
    } else if (asBinarySize != null) {
        html += `<div style="color: #6a9955; margin-top: 4px;">No warnings</div>`;
    }
    html += `</div></div>`;

    // ── Gasm Compiler section ──
    if (renderMode === 'gpu' && gasmResult) {
        const diag = gasmResult.diagnostics;
        html += `<div style="margin-bottom: 16px;">`;
        html += `<h3 style="color: #4ec9b0; margin: 0 0 8px 0; font-size: 14px;">Gasm Compiler (Wasm → WGSL)</h3>`;
        html += `<div style="background: #1e1e1e; border: 1px solid #333; border-radius: 4px; padding: 10px; font-family: 'Courier New', monospace; font-size: 13px;">`;

        if (gasmResult.ok) {
            const wgslLines = gasmResult.wgsl.split('\n').length;
            html += `<div style="color: #4ec9b0;">✓ Compiled successfully (${wgslLines} lines of WGSL)</div>`;
        } else {
            html += `<div style="color: #f48771;">✗ Compilation failed</div>`;
        }

        // Errors
        if (diag.errors.length > 0) {
            html += `<div style="color: #f48771; margin-top: 8px;"><strong>Errors (${diag.errors.length}):</strong></div>`;
            for (const e of diag.errors) {
                html += `<div style="color: #f48771; margin: 2px 0 2px 12px;">● [${esc(e.code)}] ${esc(e.message)}`;
                if (e.functionName) html += ` <span style="color: #888;">(in ${esc(e.functionName)})</span>`;
                html += `</div>`;
            }
        }

        // Warnings
        if (diag.warnings.length > 0) {
            html += `<div style="color: #dcdcaa; margin-top: 8px;"><strong>Warnings (${diag.warnings.length}):</strong></div>`;
            for (const w of diag.warnings) {
                html += `<div style="color: #dcdcaa; margin: 2px 0 2px 12px;">▲ [${esc(w.code)}] ${esc(w.message)}`;
                if (w.functionName) html += ` <span style="color: #888;">(in ${esc(w.functionName)})</span>`;
                html += `</div>`;
            }
        }

        // Demotions
        if (diag.demotions.length > 0) {
            html += `<div style="color: #ce9178; margin-top: 8px;"><strong>Demotions (${diag.demotions.length}):</strong></div>`;
            for (const d of diag.demotions) {
                html += `<div style="color: #ce9178; margin: 2px 0 2px 12px;">↓ ${esc(d.kind)}`;
                if (d.functionName) html += ` <span style="color: #888;">(in ${esc(d.functionName)})</span>`;
                html += `</div>`;
            }
        }

        // Features used
        const feat = diag.featuresUsed;
        const usedFeatures = [];
        if (feat.usesF64) usedFeatures.push('f64');
        if (feat.usesI64) usedFeatures.push('i64');
        if (feat.usesF64Memory) usedFeatures.push('f64 memory');
        if (feat.usesI64Memory) usedFeatures.push('i64 memory');
        if (feat.usesSimdF64x2) usedFeatures.push('SIMD f64x2');
        if (feat.usesSimdI64x2) usedFeatures.push('SIMD i64x2');
        if (feat.usesSimdEmulation) usedFeatures.push('SIMD emulation');
        if (usedFeatures.length > 0) {
            html += `<div style="color: #569cd6; margin-top: 8px;"><strong>Features detected:</strong> ${usedFeatures.join(', ')}</div>`;
        }

        // Clean compile summary
        if (gasmResult.ok && diag.errors.length === 0 && diag.warnings.length === 0 && diag.demotions.length === 0) {
            html += `<div style="color: #6a9955; margin-top: 4px;">No warnings or demotions</div>`;
        }

        html += `</div></div>`;
    } else if (renderMode === 'cpu') {
        html += `<div style="margin-bottom: 16px;">`;
        html += `<h3 style="color: #4ec9b0; margin: 0 0 8px 0; font-size: 14px;">Execution Mode</h3>`;
        html += `<div style="background: #1e1e1e; border: 1px solid #333; border-radius: 4px; padding: 10px; font-family: 'Courier New', monospace; font-size: 13px;">`;
        html += `<div style="color: #569cd6;">Running directly via WebAssembly (CPU mode — Gasm compiler not invoked)</div>`;
        html += `</div></div>`;
    }

    return html;
}

let animationFrameId = null;
let isAnimating = false;
let executor = null;
let wasmInstance = null;
let wasmMemory = null;
let currentSessionId = 0;

// Helper functions for the editable code block

// Switch Tab functionality
window.switchTab = function (tabName) {
    document.querySelectorAll('.tab-btn').forEach(btn => btn.classList.remove('active'));
    document.getElementById('btn-' + tabName).classList.add('active');

    document.getElementById('tab-as').style.display = 'none';
    document.getElementById('tab-wat').style.display = 'none';
    document.getElementById('tab-wgsl').style.display = 'none';
    document.getElementById('tab-results').style.display = 'none';
    document.getElementById('tab-readme').style.display = 'none';

    // as/wat/wgsl use flex layout; results and readme use block
    const flexTabs = ['as', 'wat', 'wgsl'];
    document.getElementById('tab-' + tabName).style.display = flexTabs.includes(tabName) ? 'flex' : 'block';
};

// ── AS editor helpers ──────────────────────────────────────────────

function getEditorContent() {
    return document.getElementById('asSourceEditor').value;
}

function updateEditorHighlight() {
    const textarea = document.getElementById('asSourceEditor');
    const codeEl = document.getElementById('asSourceEditorCode');
    // Trailing newline keeps the highlighted block vertically in sync
    codeEl.textContent = textarea.value + '\n';
    Prism.highlightElement(codeEl);
}

function updateLineNumbers() {
    const textarea = document.getElementById('asSourceEditor');
    const lineNumbers = document.getElementById('asLineNumbers');
    const count = textarea.value.split('\n').length;
    lineNumbers.innerHTML = Array.from({ length: count }, (_, i) => `<div>${i + 1}</div>`).join('');
    lineNumbers.scrollTop = textarea.scrollTop;
}

function syncEditorScroll() {
    const textarea = document.getElementById('asSourceEditor');
    const pre = document.getElementById('asHighlightPre');
    const lineNumbers = document.getElementById('asLineNumbers');
    pre.scrollTop = textarea.scrollTop;
    pre.scrollLeft = textarea.scrollLeft;
    lineNumbers.scrollTop = textarea.scrollTop;
}

function setEditorContent(code) {
    document.getElementById('asSourceEditor').value = code;
    updateEditorHighlight();
    updateLineNumbers();
}

// Live highlight update — cursor is owned by the textarea so no jumping
document.getElementById('asSourceEditor').addEventListener('input', function () {
    updateEditorHighlight();
    updateLineNumbers();
});

// Tab key: insert 2 spaces instead of leaving the textarea
document.getElementById('asSourceEditor').addEventListener('keydown', function (e) {
    if (e.key === 'Tab') {
        e.preventDefault();
        const start = this.selectionStart;
        const end = this.selectionEnd;
        this.value = this.value.substring(0, start) + '  ' + this.value.substring(end);
        this.selectionStart = this.selectionEnd = start + 2;
        updateEditorHighlight();
        updateLineNumbers();
    }
});

// Keep the highlighted overlay and line numbers scrolled in sync with the textarea
document.getElementById('asSourceEditor').addEventListener('scroll', syncEditorScroll);

// ── Read-only tab line number helpers ─────────────────────────────

function updateReadonlyLineNumbers(text, lineNumEl) {
    const count = text.split('\n').length;
    lineNumEl.innerHTML = Array.from({ length: count }, (_, i) => `<div>${i + 1}</div>`).join('');
}

document.getElementById('watCodePre').addEventListener('scroll', function () {
    document.getElementById('watLineNumbers').scrollTop = this.scrollTop;
});

document.getElementById('wgslCodePre').addEventListener('scroll', function () {
    document.getElementById('wgslLineNumbers').scrollTop = this.scrollTop;
});


// Display initial values
const wgslCodeElement = document.getElementById('wgslCodeElement');
wgslCodeElement.textContent = currentWGSL;
Prism.highlightElement(wgslCodeElement);
updateReadonlyLineNumbers(currentWGSL, document.getElementById('wgslLineNumbers'));
setEditorContent(currentSource);



// Load demo by name
window.loadDemo = function (demoName) {
    const demo = demoLibrary[demoName];
    if (!demo) return;

    // Update select value if called programmatically
    const select = document.getElementById('demoSelect');
    if (select && select.value !== demoName) {
        select.value = demoName;
    }

    // Update source
    currentDemo = demoName;
    currentSource = demo.code;
    setEditorContent(currentSource);

    // Stop animation and destroy executor before switching
    if (isAnimating) {
        stopAnimation();
    }
    if (executor) {
        executor.destroy().catch(e => console.error('Error destroying executor:', e));
        executor = null;
    }
    wasmInstance = null;
    wasmMemory = null;

    // Auto-compile
    window.setTimeout(() => compileAndRun(), 50);
};

// Compile and run with animation loop
window.compileAndRun = async function () {
    const compileRunBtn = document.getElementById('compileRunBtn');
    const stopBtn = document.getElementById('stopBtn');
    const status = document.getElementById('status');
    const results = document.getElementById('results');
    const renderMode = document.getElementById('renderMode').value;

    compileRunBtn.disabled = true;
    currentSource = getEditorContent();

    // Stop any existing animation
    stopAnimation();
    const sessionId = ++currentSessionId;

    try {
        status.innerHTML = '<span class="output">Compiling AS → Wasm...</span>';

        // Compile ONCE
        const { binary, text, stderr } = await compileString(currentSource, {
            optimize: true,
            runtime: 'stub',
            initialMemory: 16,
            maximumMemory: 16,
            noAssert: true
        });

        const asStderr = stderr ? stderr.toString() : '';
        const asBinarySize = binary ? binary.length : null;

        if (!binary) {
            // Show AS failure in Compiler Results tab
            results.innerHTML = buildCompilerResultsHTML({ asStderr, asBinarySize: null, gasmResult: null, renderMode });
            results.style.display = 'block';
            throw new Error(`AS compilation failed:\n${stderr || 'Unknown error'}`);
        }

        // Display WAT output
        if (text) {
            const watCodeElement = document.getElementById('watCodeElement');
            watCodeElement.textContent = text;
            Prism.highlightElement(watCodeElement);
            updateReadonlyLineNumbers(text, document.getElementById('watLineNumbers'));
        }

        if (renderMode === 'gpu') {
            status.innerHTML = '<span class="output">Compiling Wasm → WGSL...</span>';

            const result = compileWithDiagnostics(binary, {
                optimize: true,
                demotionPolicy: { i64: "allow-lossy", f64: "allow" },
                sourceMapping: "detailed"  // Options: "minimal", "normal", "detailed", "verbose"
            });

            // Populate Compiler Results with both AS and Gasm output
            results.innerHTML = buildCompilerResultsHTML({ asStderr, asBinarySize, gasmResult: result, renderMode });
            results.style.display = 'block';

            if (!result.ok) {
                const errors = result.diagnostics.errors.map(e => `${e.code}: ${e.message}`).join('\n');
                throw new Error(`Gasm compilation failed:\n${errors}`);
            }

            currentWGSL = result.wgsl;
            const wgslCodeElement = document.getElementById('wgslCodeElement');
            wgslCodeElement.textContent = currentWGSL;
            Prism.highlightElement(wgslCodeElement);
            updateReadonlyLineNumbers(currentWGSL, document.getElementById('wgslLineNumbers'));

            // Create fresh executor
            if (executor) {
                executor.destroy().catch(() => { });
            }
            executor = new BrowserGPUExecutor();

            // Prepare the animation fast path — compile pipeline, allocate
            // GPU buffers, bind group, staging buffer ONCE. After this call,
            // executeFrame() does zero JS object allocations per frame.
            const wgCount = [Math.ceil(256 * 256 / 64), 1, 1];
            const memorySize = 1024 * 1024;
            const memBuf = new Int32Array(memorySize / 4);
            await executor.prepareAnimation(
                currentWGSL,
                memBuf,
                'i32',
                memorySize,
                'i32',
                wgCount,
            );
        } else {
            status.innerHTML = '<span class="output">Instantiating Wasm for CPU...</span>';
            const { instance } = await WebAssembly.instantiate(binary, {
                env: {
                    abort: () => console.error('Wasm aborted'),
                    seed: () => Math.random() * 2147483647,
                }
            });
            wasmInstance = instance;
            wasmMemory = instance.exports.memory;

            // Populate Compiler Results for CPU mode
            results.innerHTML = buildCompilerResultsHTML({ asStderr, asBinarySize, gasmResult: null, renderMode });
            results.style.display = 'block';
        }

        status.innerHTML = '<span class="output">Starting animation...</span>';

        const canvas = document.getElementById('canvas');
        // desynchronized: bypass compositor sync (eliminates stalls)
        // alpha: false — canvas is always opaque, skip alpha compositing
        const ctx = canvas.getContext('2d', {
            desynchronized: true,
            alpha: false,
            willReadFrequently: false
        });
        const width = 256;
        const height = 256;
        const totalPixels = width * height;
        const memorySize = 1024 * 1024;

        // Shared buffer so we can write f32 time and i32 pixels into the same memory.
        const memoryBufferBytes = new ArrayBuffer(memorySize);
        const memoryBufferF32 = new Float32Array(memoryBufferBytes);
        const memoryBufferI32 = new Int32Array(memoryBufferBytes);

        // Pre-allocate ImageData and Uint32 view ONCE — reused every frame.
        const imageData = ctx.createImageData(width, height);
        const pixelsU32 = new Uint32Array(imageData.data.buffer);

        // Pre-allocate wasm views (memory is fixed at 16 pages, buffer won't change)
        const wasmF32View = wasmMemory ? new Float32Array(wasmMemory.buffer) : null;

        const startTime = performance.now();
        let frameCount = 0;

        // ── Double-buffer + zero-allocation architecture ─────────────
        // RAF callback is ALWAYS synchronous — just blits the latest
        // completed frame. GPU work runs async via executeFrame() which
        // allocates zero JS objects per frame (all buffers, bind groups,
        // typed arrays pre-allocated in prepareAnimation).
        let hasNewFrame = false;
        let gpuPending = false;
        let animError = null;

        // Fast pixel copy: pack 3 × i32 (R,G,B) into 1 × u32 (ABGR).
        function copyPixels(resultBuffer) {
            let srcIdx = 4; // skip time at i32 offset 0
            for (let i = 0; i < totalPixels; i++) {
                pixelsU32[i] = 0xFF000000
                    | ((resultBuffer[srcIdx + 2] & 0xFF) << 16)
                    | ((resultBuffer[srcIdx + 1] & 0xFF) << 8)
                    |  (resultBuffer[srcIdx]     & 0xFF);
                srcIdx += 3;
            }
        }

        // Async GPU dispatch — zero allocation per frame.
        async function dispatchGPU(time) {
            memoryBufferF32[0] = time;
            try {
                // executeFrame: no Maps, no Object.entries, no bind group
                // recreation, no new arrays, no template-literal keys.
                const result = await executor.executeFrame(memoryBufferI32);
                if (sessionId !== currentSessionId) return;
                copyPixels(result);
                hasNewFrame = true;
                frameCount++;
            } catch (error) {
                animError = error;
            } finally {
                gpuPending = false;
            }
        }

        // ── RAF callback: pure synchronous work only ─────────────────
        const animate = (rafTimestamp) => {
            if (!isAnimating || sessionId !== currentSessionId) return;
            animationFrameId = requestAnimationFrame(animate);

            if (animError) {
                console.error('Animation error:', animError);
                status.textContent = '❌ ' + animError.message;
                stopAnimation();
                return;
            }

            const now = rafTimestamp ?? performance.now();
            const timeSeconds = (now - startTime) * 60.0 / 1000.0;

            if (renderMode === 'gpu') {
                if (hasNewFrame) {
                    ctx.putImageData(imageData, 0, 0);
                    hasNewFrame = false;
                }
                if (!gpuPending) {
                    gpuPending = true;
                    dispatchGPU(timeSeconds);
                }
            } else {
                if (!wasmInstance || !wasmMemory) return;
                wasmF32View[0] = timeSeconds;
                wasmInstance.exports.main();
                copyPixels(new Int32Array(wasmMemory.buffer));
                ctx.putImageData(imageData, 0, 0);
                frameCount++;
            }

            // Update status sparingly
            if (frameCount > 0 && frameCount % 120 === 0) {
                const elapsed = (performance.now() - startTime) / 1000.0;
                const fps = (frameCount / elapsed).toFixed(1);
                status.textContent = 'Animating (' + renderMode.toUpperCase() + ') | FPS: ' + fps + ' | Frame: ' + frameCount;
            }
        };

        isAnimating = true;
        stopBtn.style.display = 'inline-block';
        compileRunBtn.disabled = false;

        // results already populated with detailed compiler output above

        animationFrameId = requestAnimationFrame(animate);

    } catch (error) {
        status.innerHTML = `<span class="error">Compilation/Execution Error. See Compiler Results.</span>`;
        // Prepend the error to any existing compiler diagnostics already rendered
        const existingHTML = results.innerHTML || '';
        const errorHTML = `<div style="margin-bottom: 16px;"><h3 style="color: #f48771; margin: 0 0 8px 0; font-size: 14px;">Error</h3><div style="background: #1e1e1e; border: 1px solid #f48771; border-radius: 4px; padding: 10px; font-family: 'Courier New', monospace; font-size: 13px;"><pre style="color: #f48771; margin: 0; white-space: pre-wrap;">${error.message.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')}</pre></div></div>`;
        results.innerHTML = errorHTML + existingHTML;
        results.style.display = 'block';
        switchTab('results');
        console.error(error);
        compileRunBtn.disabled = false;
    }
};

window.stopAnimation = function () {
    currentSessionId++; // Invalidate any pending animation loops
    if (animationFrameId) {
        cancelAnimationFrame(animationFrameId);
        animationFrameId = null;
    }
    isAnimating = false;
    document.getElementById('stopBtn').style.display = 'none';
    document.getElementById('status').innerHTML = '<span class="output">⏹ Stopped</span>';
};

// Cleanup on page unload
window.addEventListener('beforeunload', async () => {
    stopAnimation();
    if (executor) {
        await executor.destroy();
    }
});

// Auto-load first demo on startup
window.setTimeout(() => {
    loadDemo('flagshipSdfScene');
}, 100);
