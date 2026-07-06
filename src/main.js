import { demoCatalog, demoGroups, loadDemoSource } from '../shader-source.js';
import Prism from './prism.js';
import 'prismjs/themes/prism-tomorrow.css';
import {
    loadAssemblyScriptCompiler,
    loadGasmCompiler,
    loadGPUExecutorModule,
} from './load-compilers.js';

const demoLibrary = demoCatalog;

const INITIAL_WGSL = '// Click Compile & Run to generate WGSL from your AssemblyScript shader.';
const DEFAULT_DEMO = 'flagshipSdfScene';
const MEMORY_BYTES = 4 * 1024 * 1024;
const MEMORY_PAGES = MEMORY_BYTES / 65536;

let currentWGSL = INITIAL_WGSL;
let currentSource = '';
let currentDemo = 'starter';
let currentDemoLoadId = 0;
const pointerInput = { x: -1, y: -1, buttons: 0 };

function escapeHTML(value) {
    return String(value)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');
}

function renderDemoNavigation() {
    const groupsElement = document.getElementById('demoGroups');
    const selectElement = document.getElementById('demoSelect');
    const entries = Object.entries(demoCatalog);
    let demoIndex = 0;

    groupsElement.innerHTML = Object.entries(demoGroups).map(([groupId, label]) => {
        const groupEntries = entries.filter(([, demo]) => demo.group === groupId);
        if (groupEntries.length === 0) return '';
        const items = groupEntries.map(([id, demo]) => {
            demoIndex++;
            const features = demo.features
                .map(feature => `<span class="demo-feature">${escapeHTML(feature)}</span>`)
                .join('');
            return `<li><button class="demo-item" data-demo="${escapeHTML(id)}" role="option"
                title="${escapeHTML(demo.description)}">
                <span class="demo-idx">${String(demoIndex).padStart(2, '0')}</span>
                <span class="demo-copy">
                    <span class="demo-name">${escapeHTML(demo.name)}</span>
                    <span class="demo-description">${escapeHTML(demo.description)}</span>
                    <span class="demo-features">${features}</span>
                </span>
            </button></li>`;
        }).join('');
        return `<div class="sidebar-group">
            <div class="sidebar-group-label">${escapeHTML(label)}</div>
            <ul class="demo-list" role="listbox" aria-label="${escapeHTML(label)} demos">${items}</ul>
        </div>`;
    }).join('');

    selectElement.innerHTML = entries
        .map(([id, demo]) => `<option value="${escapeHTML(id)}">${escapeHTML(demo.name)}</option>`)
        .join('');
}

renderDemoNavigation();

function slugifyDemo(value) {
    return String(value)
        .trim()
        .replace(/([a-z0-9])([A-Z])/g, '$1-$2')
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+|-+$/g, '');
}

function getDemoSlug(id) {
    return demoCatalog[id]?.slug ?? slugifyDemo(id);
}

function resolveDemoName(value) {
    const requested = slugifyDemo(value);
    if (!requested) return DEFAULT_DEMO;
    if (demoCatalog[value]) return value;

    const exact = Object.entries(demoCatalog).find(([id, demo]) => {
        return requested === slugifyDemo(id)
            || requested === slugifyDemo(demo.name)
            || requested === slugifyDemo(demo.slug ?? '');
    });
    if (exact) return exact[0];

    const prefixMatches = Object.entries(demoCatalog).filter(([id, demo]) => {
        return slugifyDemo(id).startsWith(requested)
            || slugifyDemo(demo.name).startsWith(requested)
            || slugifyDemo(demo.slug ?? '').startsWith(requested);
    });
    return prefixMatches.length === 1 ? prefixMatches[0][0] : DEFAULT_DEMO;
}

function getInitialDemoName() {
    const params = new URLSearchParams(window.location.search);
    return resolveDemoName(params.get('demo') ?? DEFAULT_DEMO);
}

function syncDemoQueryParam(demoName) {
    const url = new URL(window.location.href);
    url.searchParams.set('demo', getDemoSlug(demoName));
    window.history.replaceState(null, '', url);
}

const gasmMathImports = {
    sin_f32: Math.sin,
    cos_f32: Math.cos,
    tan_f32: Math.tan,
    asin_f32: Math.asin,
    acos_f32: Math.acos,
    atan_f32: Math.atan,
    atan2_f32: Math.atan2,
    sinh_f32: Math.sinh,
    cosh_f32: Math.cosh,
    tanh_f32: Math.tanh,
    asinh_f32: Math.asinh,
    acosh_f32: Math.acosh,
    atanh_f32: Math.atanh,
    exp_f32: Math.exp,
    exp2_f32: value => 2 ** value,
    log_f32: Math.log,
    log2_f32: Math.log2,
    pow_f32: Math.pow,
    sqrt_f32: Math.sqrt,
    inverseSqrt_f32: value => 1 / Math.sqrt(value),
    abs_f32: Math.abs,
    sign_f32: Math.sign,
    floor_f32: Math.floor,
    ceil_f32: Math.ceil,
    trunc_f32: Math.trunc,
    round_f32: Math.round,
    fract_f32: value => value - Math.floor(value),
    min_f32: Math.min,
    max_f32: Math.max,
    clamp_f32: (value, low, high) => Math.min(Math.max(value, low), high),
    saturate_f32: value => Math.min(Math.max(value, 0), 1),
    mix_f32: (a, b, amount) => a * (1 - amount) + b * amount,
    step_f32: (edge, value) => value < edge ? 0 : 1,
    smoothstep_f32: (low, high, value) => {
        const amount = Math.min(Math.max((value - low) / (high - low), 0), 1);
        return amount * amount * (3 - 2 * amount);
    },
    fma_f32: (a, b, c) => a * b + c,
    abs_i32: Math.abs,
    min_i32: Math.min,
    max_i32: Math.max,
    clamp_i32: (value, low, high) => Math.min(Math.max(value, low), high),
};

function getCurrentDemoConfig() {
    return demoCatalog[currentDemo] ?? demoCatalog.starter;
}

function writeFrameInputs(f32View, i32View, time) {
    f32View[0] = time;
    i32View[1] = pointerInput.x;
    i32View[2] = pointerInput.y;
    i32View[3] = pointerInput.buttons;
}

function updatePointerInput(event) {
    const canvas = document.getElementById('canvas');
    const bounds = canvas.getBoundingClientRect();
    pointerInput.x = Math.max(0, Math.min(255, Math.floor((event.clientX - bounds.left) * 256 / bounds.width)));
    pointerInput.y = Math.max(0, Math.min(255, Math.floor((event.clientY - bounds.top) * 256 / bounds.height)));
    pointerInput.buttons = event.buttons;
}

const outputCanvas = document.getElementById('canvas');
outputCanvas.addEventListener('pointermove', updatePointerInput);
outputCanvas.addEventListener('pointerdown', event => {
    outputCanvas.setPointerCapture?.(event.pointerId);
    updatePointerInput(event);
});
outputCanvas.addEventListener('pointerup', updatePointerInput);
outputCanvas.addEventListener('pointercancel', () => {
    pointerInput.x = -1;
    pointerInput.y = -1;
    pointerInput.buttons = 0;
});
outputCanvas.addEventListener('pointerleave', event => {
    if (event.buttons === 0) {
        pointerInput.x = -1;
        pointerInput.y = -1;
        pointerInput.buttons = 0;
    }
});

// ── Compiler results builder ─────────────────────────────────────
function buildCompilerResultsHTML({ asStderr, asBinarySize, gasmResult, renderMode }) {
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
            html += `<pre style="color: #d4d4d4; margin: 4px 0 0 0; white-space: pre-wrap; font-size: 13px;">${escapeHTML(trimmed)}</pre>`;
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
                html += `<div style="color: #f48771; margin: 2px 0 2px 12px;">● [${escapeHTML(e.code)}] ${escapeHTML(e.message)}`;
                if (e.functionName) html += ` <span style="color: #888;">(in ${escapeHTML(e.functionName)})</span>`;
                html += `</div>`;
            }
        }

        // Warnings
        if (diag.warnings.length > 0) {
            html += `<div style="color: #dcdcaa; margin-top: 8px;"><strong>Warnings (${diag.warnings.length}):</strong></div>`;
            for (const w of diag.warnings) {
                html += `<div style="color: #dcdcaa; margin: 2px 0 2px 12px;">▲ [${escapeHTML(w.code)}] ${escapeHTML(w.message)}`;
                if (w.functionName) html += ` <span style="color: #888;">(in ${escapeHTML(w.functionName)})</span>`;
                html += `</div>`;
            }
        }

        // Advisories (integrator-mode decisions from Gasm 0.5+)
        const advisories = diag.advisories ?? [];
        if (advisories.length > 0) {
            html += `<div style="color: #9cdcfe; margin-top: 8px;"><strong>Advisories (${advisories.length}):</strong></div>`;
            for (const a of advisories) {
                html += `<div style="color: #9cdcfe; margin: 2px 0 2px 12px;">ℹ [${escapeHTML(a.code)}] ${escapeHTML(a.message)}`;
                if (a.functionName) html += ` <span style="color: #888;">(in ${escapeHTML(a.functionName)})</span>`;
                html += `</div>`;
            }
        }

        // Demotions
        if (diag.demotions.length > 0) {
            html += `<div style="color: #ce9178; margin-top: 8px;"><strong>Demotions (${diag.demotions.length}):</strong></div>`;
            for (const d of diag.demotions) {
                html += `<div style="color: #ce9178; margin: 2px 0 2px 12px;">↓ ${escapeHTML(d.kind)}`;
                if (d.functionName) html += ` <span style="color: #888;">(in ${escapeHTML(d.functionName)})</span>`;
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
        if (gasmResult.ok && diag.errors.length === 0 && diag.warnings.length === 0 && advisories.length === 0 && diag.demotions.length === 0) {
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

function updateWGSLDisplay(wgsl) {
    const codeElement = document.getElementById('wgslCodeElement');
    codeElement.textContent = wgsl;
    Prism.highlightElement(codeElement);
    updateReadonlyLineNumbers(wgsl, document.getElementById('wgslLineNumbers'));
}

document.getElementById('watCodePre').addEventListener('scroll', function () {
    document.getElementById('watLineNumbers').scrollTop = this.scrollTop;
});

document.getElementById('wgslCodePre').addEventListener('scroll', function () {
    document.getElementById('wgslLineNumbers').scrollTop = this.scrollTop;
});


// Display initial values
updateWGSLDisplay(currentWGSL);
setEditorContent(currentSource);

const copyWGSLBtn = document.getElementById('copyWGSLBtn');

async function copyTextToClipboard(text) {
    if (navigator.clipboard?.writeText) {
        try {
            await navigator.clipboard.writeText(text);
            return;
        } catch {
            // Fall through for browsers that expose the API but deny the call.
        }
    }

    const textarea = document.createElement('textarea');
    textarea.value = text;
    textarea.style.position = 'fixed';
    textarea.style.opacity = '0';
    document.body.appendChild(textarea);
    textarea.select();
    const copied = document.execCommand('copy');
    textarea.remove();
    if (!copied) throw new Error('Clipboard copy was rejected.');
}

copyWGSLBtn.addEventListener('click', async () => {
    const originalLabel = copyWGSLBtn.textContent;
    try {
        await copyTextToClipboard(currentWGSL);
        copyWGSLBtn.textContent = 'COPIED';
    } catch {
        copyWGSLBtn.textContent = 'COPY FAILED';
    }
    window.setTimeout(() => {
        copyWGSLBtn.textContent = originalLabel;
    }, 1400);
});

document.getElementById('minifyWGSL').addEventListener('change', () => {
    if (document.getElementById('renderMode').value === 'gpu') {
        compileAndRun();
    }
});



// Load demo by name
window.loadDemo = async function (demoName) {
    const demo = demoLibrary[demoName];
    if (!demo) return;
    const loadId = ++currentDemoLoadId;

    // Update select value if called programmatically
    const select = document.getElementById('demoSelect');
    if (select && select.value !== demoName) {
        select.value = demoName;
    }

    // Highlight active item in the brutalist sidebar
    document.querySelectorAll('.demo-item').forEach(el => {
        el.classList.toggle('active', el.dataset.demo === demoName);
    });

    // Update source
    const source = await loadDemoSource(demoName);
    if (loadId !== currentDemoLoadId) return;

    currentDemo = demoName;
    currentSource = source;
    syncDemoQueryParam(demoName);
    setEditorContent(currentSource);

    // Auto-compile
    await compileAndRun();
};

function isCurrentSession(sessionId) {
    return sessionId === currentSessionId;
}

async function disposeExecutor(target) {
    if (target) await target.destroy();
}

function cancelAnimationLoop() {
    if (animationFrameId) {
        cancelAnimationFrame(animationFrameId);
        animationFrameId = null;
    }
    isAnimating = false;
    document.getElementById('stopBtn').style.display = 'none';
    const fps = document.getElementById('statusFps');
    if (fps) fps.textContent = '-- FPS';
}

function buildErrorResultHTML(message) {
    return `<div style="margin-bottom: 16px;"><h3 style="color: #f48771; margin: 0 0 8px 0; font-size: 14px;">Error</h3><div style="background: #1e1e1e; border: 1px solid #f48771; border-radius: 4px; padding: 10px; font-family: 'Courier New', monospace; font-size: 13px;"><pre style="color: #f48771; margin: 0; white-space: pre-wrap;">${escapeHTML(message)}</pre></div></div>`;
}

function showRuntimeError(error, sessionId) {
    if (!isCurrentSession(sessionId)) return;

    const message = error instanceof Error ? error.message : String(error);
    currentSessionId++;
    cancelAnimationLoop();
    setStatusChip('ERROR', 'error');
    document.getElementById('status').innerHTML =
        '<span class="error">Execution Error. See Compiler Results.</span>';

    const results = document.getElementById('results');
    results.innerHTML = buildErrorResultHTML(message) + (results.innerHTML || '');
    results.style.display = 'block';
    switchTab('results');
    document.getElementById('compileRunBtn').disabled = false;
    console.error('Animation error:', error);
}

// Compile and run with animation loop
window.compileAndRun = async function () {
    const compileRunBtn = document.getElementById('compileRunBtn');
    const stopBtn = document.getElementById('stopBtn');
    const status = document.getElementById('status');
    const results = document.getElementById('results');
    const renderMode = document.getElementById('renderMode').value;
    const source = getEditorContent();
    const sessionId = ++currentSessionId;
    let nextExecutor = null;
    let preparedExecutor = null;

    compileRunBtn.disabled = true;
    currentSource = source;
    cancelAnimationLoop();
    setStatusChip('COMPILING', 'compiling');
    setStatusMode(renderMode);

    try {
        const previousExecutor = executor;
        executor = null;
        wasmInstance = null;
        wasmMemory = null;
        try {
            await disposeExecutor(previousExecutor);
        } catch (error) {
            if (!isCurrentSession(sessionId)) return;
            throw new Error(`Failed to destroy the previous GPU executor: ${error}`);
        }
        if (!isCurrentSession(sessionId)) return;

        status.innerHTML = '<span class="output">Compiling AS → Wasm...</span>';

        const { compileString } = await loadAssemblyScriptCompiler();
        if (!isCurrentSession(sessionId)) return;

        // Compile ONCE
        const demoConfig = getCurrentDemoConfig();
        const { binary, text, stderr } = await compileString(source, {
            optimize: true,
            runtime: 'stub',
            initialMemory: MEMORY_PAGES,
            maximumMemory: MEMORY_PAGES,
            noAssert: true,
            ...(demoConfig.assemblyScriptOptions ?? {}),
        });
        if (!isCurrentSession(sessionId)) return;

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

            const { compileGasmIntegrator } = await loadGasmCompiler();
            if (!isCurrentSession(sessionId)) return;
            const { BrowserGPUExecutor } = await loadGPUExecutorModule();
            if (!isCurrentSession(sessionId)) return;

            const minify = document.getElementById('minifyWGSL').checked;
            const result = compileGasmIntegrator(binary, {
                ...(demoConfig.compileOptions ?? {}),
                minify,
            });
            if (!isCurrentSession(sessionId)) return;

            // Populate Compiler Results with both AS and Gasm output
            results.innerHTML = buildCompilerResultsHTML({ asStderr, asBinarySize, gasmResult: result, renderMode });
            results.style.display = 'block';

            if (!result.ok) {
                const errors = result.diagnostics.errors.map(e => `${e.code}: ${e.message}`).join('\n');
                throw new Error(`Gasm compilation failed:\n${errors}`);
            }

            currentWGSL = result.wgsl;
            updateWGSLDisplay(currentWGSL);

            // Create fresh executor
            nextExecutor = new BrowserGPUExecutor();

            // Prepare the animation fast path — compile pipeline, allocate
            // GPU buffers, bind group, staging buffer ONCE. The GPU memory
            // buffer remains authoritative between frames; only the small
            // input region is uploaded and the pixel output region is read back.
            const dispatch = result.dispatchInfo;
            const wgCount = [
                Math.max(1, Math.ceil(dispatch.workItemsX / dispatch.workgroupSizeX)),
                Math.max(1, Math.ceil(dispatch.workItemsY / dispatch.workgroupSizeY)),
                Math.max(1, Math.ceil(dispatch.workItemsZ / dispatch.workgroupSizeZ)),
            ];
            const memorySize = MEMORY_BYTES;
            const inputBytes = 16;
            const outputBytes = 256 * 256 * 3 * 4;
            const memBuf = new Int32Array(memorySize / 4);
            await nextExecutor.prepareAnimation(
                currentWGSL,
                memBuf,
                'i32',
                memorySize,
                'i32',
                wgCount,
                {
                    layout: {
                        inputs: { byteOffset: 0, byteLength: inputBytes },
                        outputs: { byteOffset: inputBytes, byteLength: outputBytes },
                        state: {
                            byteOffset: inputBytes + outputBytes,
                            byteLength: memorySize - inputBytes - outputBytes,
                        },
                    },
                },
            );
            if (!isCurrentSession(sessionId)) {
                await disposeExecutor(nextExecutor);
                nextExecutor = null;
                return;
            }
            preparedExecutor = nextExecutor;
            executor = nextExecutor;
            nextExecutor = null;
        } else {
            status.innerHTML = '<span class="output">Instantiating Wasm for CPU...</span>';
            const { instance } = await WebAssembly.instantiate(binary, {
                env: {
                    abort: () => console.error('Wasm aborted'),
                    seed: () => Math.random() * 2147483647,
                },
                gasm: gasmMathImports,
            });
            if (!isCurrentSession(sessionId)) return;
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
        const memorySize = MEMORY_BYTES;

        // Shared buffer so we can write f32 time and i32 pixels into the same memory.
        const memoryBufferBytes = new ArrayBuffer(memorySize);
        const memoryBufferF32 = new Float32Array(memoryBufferBytes);
        const memoryBufferI32 = new Int32Array(memoryBufferBytes);

        // Pre-allocate ImageData and Uint32 view ONCE — reused every frame.
        const imageData = ctx.createImageData(width, height);
        const pixelsU32 = new Uint32Array(imageData.data.buffer);

        // Pre-allocate wasm views (memory is fixed at 16 pages, buffer won't change)
        const runWasmInstance = wasmInstance;
        const runWasmMemory = wasmMemory;
        const wasmF32View = runWasmMemory ? new Float32Array(runWasmMemory.buffer) : null;
        const wasmI32View = runWasmMemory ? new Int32Array(runWasmMemory.buffer) : null;
        const runExecutor = preparedExecutor;
        const useSteppedClock = getCurrentDemoConfig().clock === 'step';

        const startTime = performance.now();
        let frameCount = 0;
        let dispatchCount = 0;

        // ── Double-buffer + zero-allocation architecture ─────────────
        // RAF callback is ALWAYS synchronous — just blits the latest
        // completed frame. GPU work runs async via executeFrame() which
        // allocates zero JS objects per frame (all buffers, bind groups,
        // typed arrays pre-allocated in prepareAnimation).
        let hasNewFrame = false;
        let gpuPending = false;
        let animError = null;

        // Fast pixel copy: pack 3 × i32 (R,G,B) into 1 × u32 (ABGR).
        function copyPixels(resultBuffer, srcIdx = 4) {
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
            if (!isCurrentSession(sessionId)) return;
            const frameInput = useSteppedClock ? dispatchCount : time;
            dispatchCount++;
            writeFrameInputs(memoryBufferF32, memoryBufferI32, frameInput);
            try {
                // executeFrame: no Maps, no Object.entries, no bind group
                // recreation, no new arrays, no template-literal keys.
                const result = await runExecutor.executeFrame(memoryBufferI32);
                if (!isCurrentSession(sessionId)) return;
                copyPixels(result, 0);
                hasNewFrame = true;
                frameCount++;
            } catch (error) {
                if (!isCurrentSession(sessionId)) return;
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
                showRuntimeError(animError, sessionId);
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
                try {
                    if (!runWasmInstance || !runWasmMemory) return;
                    const frameInput = useSteppedClock ? dispatchCount : timeSeconds;
                    dispatchCount++;
                    writeFrameInputs(wasmF32View, wasmI32View, frameInput);
                    runWasmInstance.exports.main();
                    copyPixels(new Int32Array(runWasmMemory.buffer));
                    ctx.putImageData(imageData, 0, 0);
                    frameCount++;
                } catch (error) {
                    showRuntimeError(error, sessionId);
                    return;
                }
            }

            // Update status sparingly
            if (frameCount > 0 && frameCount % 30 === 0) {
                const elapsed = (performance.now() - startTime) / 1000.0;
                const fpsVal = (frameCount / elapsed).toFixed(1);
                const fpsEl = document.getElementById('statusFps');
                if (fpsEl) fpsEl.textContent = fpsVal + ' FPS';
                if (frameCount % 120 === 0) {
                    status.textContent = 'Animating · frame ' + frameCount;
                }
            }
        };

        isAnimating = true;
        stopBtn.style.display = 'inline-flex';
        compileRunBtn.disabled = false;
        setStatusChip('RUNNING', 'running');
        const meta = document.getElementById('canvasMeta');
        if (meta) meta.textContent = `256×256 · ${renderMode.toUpperCase()}`;

        // results already populated with detailed compiler output above

        animationFrameId = requestAnimationFrame(animate);

    } catch (error) {
        if (nextExecutor) {
            try {
                await disposeExecutor(nextExecutor);
            } catch (cleanupError) {
                if (isCurrentSession(sessionId)) {
                    console.error('Error destroying executor after failed preparation:', cleanupError);
                }
            }
        }
        if (!isCurrentSession(sessionId)) return;
        setStatusChip('ERROR', 'error');
        status.innerHTML = `<span class="error">Compilation/Execution Error. See Compiler Results.</span>`;
        // Prepend the error to any existing compiler diagnostics already rendered
        const existingHTML = results.innerHTML || '';
        const message = error instanceof Error ? error.message : String(error);
        results.innerHTML = buildErrorResultHTML(message) + existingHTML;
        results.style.display = 'block';
        switchTab('results');
        console.error(error);
        compileRunBtn.disabled = false;
    }
};

window.stopAnimation = function () {
    currentSessionId++; // Invalidate any pending animation loops
    cancelAnimationLoop();
    document.getElementById('status').innerHTML = '<span class="output">⏹ Stopped</span>';
    setStatusChip('STOPPED', 'stopped');
    const meta = document.getElementById('canvasMeta');
    if (meta) meta.textContent = '256×256 · IDLE';
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
    loadDemo(getInitialDemoName()).catch(console.error);
}, 100);

// ── Shell interactions: status chip, sidebar, drawer, shortcuts ──

function setStatusChip(label, state) {
    const chip = document.getElementById('statusChip');
    if (!chip) return;
    chip.textContent = label;
    if (state) chip.dataset.state = state;
    else delete chip.dataset.state;
}

function setStatusMode(mode) {
    const el = document.getElementById('statusMode');
    if (el) el.textContent = (mode || '').toUpperCase();
}

// Sidebar demo buttons — bridge to legacy <select id="demoSelect">
document.querySelectorAll('.demo-item').forEach(btn => {
    btn.addEventListener('click', () => {
        const name = btn.dataset.demo;
        if (name) loadDemo(name);
        closeDrawer();
    });
});

// Render mode select keeps the status bar in sync
const renderModeEl = document.getElementById('renderMode');
if (renderModeEl) {
    setStatusMode(renderModeEl.value);
    renderModeEl.addEventListener('change', e => setStatusMode(e.target.value));
}

// ── Mobile drawer ────────────────────────────────────────────
const drawerToggle = document.getElementById('drawerToggle');
const sidebar = document.getElementById('sidebar');
const drawerScrim = document.getElementById('drawerScrim');

function openDrawer() {
    if (!sidebar) return;
    sidebar.classList.add('open');
    if (drawerScrim) drawerScrim.classList.add('open');
    if (drawerToggle) drawerToggle.setAttribute('aria-expanded', 'true');
}
function closeDrawer() {
    if (!sidebar) return;
    sidebar.classList.remove('open');
    if (drawerScrim) drawerScrim.classList.remove('open');
    if (drawerToggle) drawerToggle.setAttribute('aria-expanded', 'false');
}
if (drawerToggle) {
    drawerToggle.addEventListener('click', () => {
        const open = sidebar && sidebar.classList.contains('open');
        if (open) closeDrawer(); else openDrawer();
    });
}
if (drawerScrim) drawerScrim.addEventListener('click', closeDrawer);

// ── Keyboard shortcuts ───────────────────────────────────────
const tabOrder = ['as', 'wat', 'wgsl', 'results', 'readme'];
document.addEventListener('keydown', (e) => {
    const mod = e.metaKey || e.ctrlKey;

    // ⌘/Ctrl+Enter — compile & run
    if (mod && e.key === 'Enter') {
        e.preventDefault();
        compileAndRun();
        return;
    }
    // ⌘/Ctrl+. — stop
    if (mod && e.key === '.') {
        e.preventDefault();
        stopAnimation();
        return;
    }
    // Esc — close drawer
    if (e.key === 'Escape' && sidebar && sidebar.classList.contains('open')) {
        e.preventDefault();
        closeDrawer();
        return;
    }
    // 1–5 tab switch — only when not typing in the editor / form field
    const t = e.target;
    const isTyping = t && (t.tagName === 'TEXTAREA' || t.tagName === 'INPUT' || t.isContentEditable);
    if (!isTyping && !mod && /^[1-5]$/.test(e.key)) {
        e.preventDefault();
        switchTab(tabOrder[parseInt(e.key, 10) - 1]);
    }
});

// Initial chip state
setStatusChip('READY', 'ready');
