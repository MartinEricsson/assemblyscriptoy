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

> **Note**: `pnpm dev` automatically runs `pnpm build` first. The build step compiles `src/shader.ts` into `build/shader.js` (a pre-baked module used only to populate the initial WGSL tab on first load). This file is immediately replaced when the app auto-loads the first demo. **You do not need to re-run `pnpm build` when writing new shaders** — all compilation happens in the browser.

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
2. **Wasm → WGSL**: `compileWithDiagnostics()` from `@gasm-compiler/core/browser`.
3. **GPU execution**: `BrowserGPUExecutor` initialises WebGPU, then calls `prepareAnimation()` once to allocate all GPU resources (pipeline, bind groups, staging buffers), followed by `executeFrame()` per frame with zero JS allocations.

Both **GPU mode** (WebGPU via the full Gasm pipeline) and **CPU mode** (direct WebAssembly execution in the browser, skipping Gasm) are supported via the render-mode toggle in the UI.

### 3. Build Script ([src/build.ts](src/build.ts)) and [src/shader.ts](src/shader.ts)

`src/build.ts` is a Node build script that compiles `src/shader.ts` → `build/shader.js` (a pre-baked Wasm + WGSL bundle). `main.js` imports `initialWGSL` from this file to populate the WGSL tab on first load. The app immediately discards it by auto-loading the first demo. These files are **not** the place to write new shaders; they exist only to avoid an empty WGSL tab on cold start.

## Working with BrowserGPUExecutor

The app uses a two-phase animation API designed for zero-JS-allocation per frame:

```typescript
import { BrowserGPUExecutor } from '@gasm-compiler/core/browser';

const executor = new BrowserGPUExecutor();

// Phase 1 — one-time setup: compiles the pipeline, allocates all GPU
// buffers, bind groups, and the staging buffer.
const wgCount = [Math.ceil(256 * 256 / 64), 1, 1];
const memorySize = 1024 * 1024; // 1 MB shared memory buffer
const memBuf = new Int32Array(memorySize / 4);
await executor.prepareAnimation(wgslCode, memBuf, 'i32', memorySize, 'i32', wgCount);

// Phase 2 — per-frame: uploads CPU data, dispatches GPU, reads back result.
// No Maps, no new arrays, no bind-group recreation per frame.
memBuf[0] = timeAsI32; // write frame time before each dispatch
const result = await executor.executeFrame(memBuf);

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
│   ├── shader.ts       # Pre-compile seed — compiled by build.ts to seed build/shader.js.
│   │                   # Not the place to write user shaders.
│   ├── build.ts        # Node build script (run once at dev-server start via pnpm dev).
│   │                   # Compiles src/shader.ts → build/shader.js.
│   └── main.js         # Browser app entry point — in-browser AS + Gasm pipeline.
├── shaders/            # ← Write your shaders here (.as files, AssemblyScript)
│   ├── starter.as
│   ├── flagship_sdf_scene.as
│   ├── flagship_mandelbrot.as
│   ├── flagship_clouds.as
│   ├── flagship_fire.as
│   └── cornell_box_gi.as
├── shader-source.js    # Imports shaders/ as raw text, re-exports for main.js
├── build/              # Generated files (gitignored, produced by pnpm build)
│   ├── shader.wasm
│   ├── shader.wgsl
│   └── shader.js
├── index.html          # Interactive demo UI
├── package.json
├── vite.config.ts
└── README.md
```

## Requirements

- WebGPU-compatible browser (Chrome 113+, Edge 113+)
- Node.js 18+ (for the one-time build step)
- pnpm

