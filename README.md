# AssemblyScript Toy - Gasm Compiler Demo

An in-browser playground that compiles AssemblyScript → Wasm → WGSL (via the Gasm compiler) and renders the result with WebGPU, all client-side. No server-side compilation step is needed to write or run shaders.

## Quick Start

### 1. Install dependencies

```bash
pnpm install
```

### 2. Run the dev server

```bash
pnpm dev
```

This will open your browser at http://localhost:3001 with the interactive demo.

`pnpm dev` starts Vite. Demo source is loaded on demand, and shader compilation
happens in the browser when a demo runs.

## Creating a New Shader

The fastest way to start is to copy the annotated starter template and edit the effect region.

### Step 1 – Copy the starter template

```bash
cp shaders/starter.as shaders/my_effect.as
```

Open `shaders/my_effect.as` and replace the `// ── YOUR EFFECT HERE ──` block with your own logic.

### Step 2 – Register the import in `shader-source.js`

```javascript
// add near the top, with the other imports:
import myEffectRaw from './shaders/my_effect.as?raw';

// add near the bottom, with the other exports:
export const shaderMyEffect = myEffectRaw;
```

### Step 3 – Add to `demoLibrary` in `src/main.js`

```javascript
// 1. Add to the destructured import block:
import {
    // ...existing entries...
    shaderMyEffect,
} from '../shader-source.js';

// 2. Add an entry inside demoLibrary:
const demoLibrary = {
    // ...existing entries...
    'myEffect': { name: 'My Effect', code: shaderMyEffect },
};
```

### Step 4 – Add an `<option>` in `index.html`

Find the relevant `<optgroup>` (or create a new one) inside the `<select id="demoSelect">` element:

```html
<optgroup label="My Shaders">
    <option value="myEffect">My Effect</option>
</optgroup>
```

### Memory contract quick-reference

| Content | Byte offset | Type | Notes |
|---|---|---|---|
| `time` (frame counter) | `0` | `f32` | Read with `load<f32>(0)` |
| Pixel `i` — Red | `16 + i * 12` | `i32` | 0 – 255 |
| Pixel `i` — Green | `16 + i * 12 + 4` | `i32` | 0 – 255 |
| Pixel `i` — Blue | `16 + i * 12 + 8` | `i32` | 0 – 255 |

Canvas is always **256 × 256**. Pixel index: `i = y * 256 + x`.

### Math constraints

- No `Math.sin` / `Math.cos` — not available in the Gasm-compatible subset.
- `f32` and `i32` arithmetic both work fine.
- Use `triWave(val: i32): i32` (from `starter.as`) as a smooth sin-substitute.
- `f64`/`i64` are allowed but will be demoted by Gasm (you'll see demotion warnings in the compiler output panel).

---

## How It Works

### 1. Write AssemblyScript (in `shaders/`)

Edit any `.as` file in the `shaders/` directory — or create a new one (see *Creating a New Shader* above). The entry point must be a function named `main()`:

```typescript
export function main(): void {
  const t: f32 = load<f32>(0);       // read time (frame counter)
  // write pixels into memory starting at offset 16
}
```

**Important**: Gasm will automatically wrap `main()` with a `@compute` shader entry point.

### 2. In-Browser Compilation Pipeline

When you click **Compile & Run** in the UI, `src/main.js` runs the full pipeline entirely in the browser — no build step required:

1. **AssemblyScript → Wasm**: `compileString()` from the bundled `assemblyscript` package.
2. **Wasm → WGSL**: `compileGasmIntegrator()` (`src/gasm-integrator.js`) wraps Gasm 0.5's `compileWithRuntimeInfo()` integrator path — extension inference, binding metadata, and mutable-global handling without manual Wasm patching.
3. **GPU execution**: `BrowserGPUExecutor` initialises WebGPU, then calls `prepareAnimation()` once to allocate all GPU resources (pipeline, bind groups, staging buffers), followed by `executeFrame()` per frame with zero JS allocations.

Both **GPU mode** (WebGPU via the full Gasm pipeline) and **CPU mode** (direct WebAssembly execution in the browser, skipping Gasm) are supported via the render-mode toggle in the UI.

### 3. Production Build

`pnpm build` creates the Vite production bundle. It does not precompile a seed
shader; demo AssemblyScript and Gasm compilation remain browser-side.

## Working with BrowserGPUExecutor

The app uses a two-phase animation API designed for zero-JS-allocation per frame:

```typescript
import { BrowserGPUExecutor } from './src/browser-gpu-executor.js';

const executor = new BrowserGPUExecutor();

// Phase 1 — one-time setup: compiles the pipeline, allocates all GPU
// buffers, bind groups, and the staging buffer.
const wgCount = [Math.ceil(256 * 256 / 64), 1, 1];
const memorySize = 1024 * 1024; // 1 MB shared memory buffer
const inputBytes = 16;
const outputBytes = 256 * 256 * 3 * 4;
const memBuf = new Int32Array(memorySize / 4);
await executor.prepareAnimation(wgslCode, memBuf, 'i32', memorySize, 'i32', wgCount, {
    layout: {
        inputs: { byteOffset: 0, byteLength: inputBytes },
        outputs: { byteOffset: inputBytes, byteLength: outputBytes },
        state: {
            byteOffset: inputBytes + outputBytes,
            byteLength: memorySize - inputBytes - outputBytes,
        },
    },
});

// Phase 2 — per-frame: uploads only inputs, dispatches GPU, reads back outputs.
memBuf[0] = timeAsI32; // write frame time before each dispatch
const result = await executor.executeFrame(memBuf);

// Optional: submit this frame while returning the previous completed frame.
const previous = await executor.executeFrame(memBuf, { pipelined: true });
if (previous.outputs) render(previous.outputs, previous.frameIndex);

// Optional host-side memory control for resets, seeds, and debugging.
executor.resetMemory();
executor.writeMemory(inputBytes + outputBytes, initialState);
const snapshot = await executor.readMemory(inputBytes + outputBytes, 4096);

// Cleanup
await executor.destroy();
```

Gasm-compiled shaders use a single `memory` buffer (both read and write):

```wgsl
@group(0) @binding(0) var<storage, read_write> memory: array<u32>;
```

`prepareAnimation` / `executeFrame` handle this correctly — the same GPU buffer is uploaded, mutated by the compute shader, and read back each frame.

### Buffer Types

`'f32'` (Float32Array), `'i32'` (Int32Array), `'u32'` (Uint32Array).

## Project Structure

```
assemblyscript-toy/
├── src/
│   ├── browser-gpu-executor.js # WebGPU execution adapter.
│   ├── gasm-integrator.js      # Gasm browser compilation integration.
│   ├── load-compilers.js       # Lazy compiler module loading.
│   └── main.js                 # Browser app entry point.
├── shaders/            # ← Write your shaders here (.as files, AssemblyScript)
│   ├── starter.as
│   ├── flagship_sdf_scene.as
│   ├── flagship_mandelbrot.as
│   ├── flagship_clouds.as
│   ├── flagship_fire.as
│   └── cornell_box_gi.as
├── shader-source.js    # Catalog of lazily loaded shader sources.
├── dist/               # Vite production output (generated by pnpm build).
├── index.html          # Interactive demo UI
├── package.json
├── vite.config.ts
└── README.md
```

## Requirements

- WebGPU-compatible browser (Chrome 113+, Edge 113+)
- Node.js 18+
- pnpm

## Verification

Install Chromium once for the browser smoke test:

```bash
pnpm exec playwright install chromium
```

Run the complete pre-push gate with:

```bash
pnpm check
```

This checks JavaScript syntax, compiles the full shader corpus through
AssemblyScript and Gasm, creates the production bundle, and runs the playground
in CPU mode in Chromium.

For a manual report of every browser demo, start the dev server and run:

```bash
node scripts/collect-browser-demos.mjs
```

The collector writes its report under `docs/`.
