# AssemblyScript Toy

AssemblyScript Toy is an interactive shader playground for writing graphics code in
AssemblyScript and running it in the browser. It compiles the source to WebAssembly,
optionally translates the Wasm to WGSL with Gasm, and renders the result on a
256 x 256 canvas.

Use the app to:

- Explore 13 included demos, from simple color patterns to ray marching, path
  tracing, and persistent cellular simulations.
- Edit AssemblyScript directly and see the result after recompiling.
- Switch between **GPU / Gasm** execution through WebGPU and direct **CPU / Wasm**
  execution.
- Inspect the generated WebAssembly text, WGSL, compiler diagnostics, warnings,
  and type demotions.
- Minify and copy generated WGSL for further inspection.
- Use the annotated starter template to build an effect from scratch.

All compilation and rendering happen locally in the browser. Source code is not
sent to a compilation service.

## Using the playground

The app loads the raymarched SDF scene on startup and starts compiling it
automatically.

1. Choose a demo from the left sidebar.
2. Edit its code in **AS Source**.
3. Select **GPU / Gasm** or **CPU / Wasm**.
4. Click **Compile & Run**.
5. Open **WAT**, **WGSL**, or **Results** to inspect the compilation pipeline.

Selecting another demo replaces unsaved editor changes. **Stop** halts the current
animation without clearing the editor.

### Execution modes

**GPU / Gasm** compiles AssemblyScript to Wasm, translates the Wasm to WGSL, and
runs the compute shader with WebGPU. This mode requires a WebGPU-capable browser.

**CPU / Wasm** compiles AssemblyScript to Wasm and calls the exported `main()`
function directly. It skips Gasm and WebGPU, making it useful for comparing
behavior or working on a device without WebGPU.

### Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `Cmd/Ctrl + Enter` | Compile and run |
| `Cmd/Ctrl + .` | Stop |
| `1` through `5` | Open AS, WAT, WGSL, Results, or README |
| `Esc` | Close the demo drawer on narrow screens |

## Writing a shader

Start with **Starter Template** in the app or copy
[`shaders/starter.as`](shaders/starter.as). A shader must export this entry point:

```ts
export function main(): void {
  // Read inputs and write every output pixel.
}
```

The runtime calls `main()` once per frame. The canvas is always 256 x 256, and the
shader communicates with the runtime through a 1 MiB linear memory buffer.

### Memory layout

| Region | Byte range | Format |
|---|---:|---|
| Frame time | `0..3` | `f32`, approximately one unit per frame at 60 FPS |
| Reserved inputs | `4..15` | Reserved |
| Pixel output | `16..786447` | 65,536 RGB pixels, three `i32` values per pixel |
| Persistent state | `786448..1048575` | Retained between GPU frames |

For pixel index `i = y * 256 + x`, write channels in the range 0 through 255:

```ts
const offset = 16 + i * 12;
store<i32>(offset, red);
store<i32>(offset + 4, green);
store<i32>(offset + 8, blue);
```

The persistent state region is primarily demonstrated by Persistent Life,
Persistent Heat, and Persistent Cyclic. In GPU mode it remains resident between
frames. Recompiling creates a fresh execution session and resets that state.

### Language constraints

- Prefer `i32`, `u32`, and `f32`.
- `i64` and `f64` may be demoted by Gasm; check **Results** for diagnostics.
- `Math.sin` and `Math.cos` are not supported by the current Gasm-compatible
  subset. The starter shader includes `triWave()` as a simple periodic
  alternative.
- Keep the entry point named `main` with no parameters and a `void` return type.

## Local development

Requirements:

- Node.js 24
- pnpm 10
- A WebGPU-capable browser for GPU mode

Install dependencies and start Vite:

```bash
pnpm install
pnpm dev
```

Vite opens the app at [http://localhost:3001](http://localhost:3001). Demo source
files are loaded on demand, and compilation still happens in the browser.

### Add a demo

1. Add an AssemblyScript file under `shaders/`.
2. Add its lazy import and display name to `demoCatalog` in `shader-source.js`.
3. Add the matching sidebar button and hidden select option in `index.html`.

The IDs in all three places must match.

### Verification

Run the complete local and CI gate:

```bash
pnpm check
```

This checks JavaScript syntax, compiles all 13 shaders through AssemblyScript and
Gasm, and creates the production bundle. Browser end-to-end tests are not part of
the gate.

To collect a manual browser report for every demo:

```bash
pnpm exec playwright install chromium
pnpm dev
node scripts/collect-browser-demos.mjs
```

The collector expects the app at `http://localhost:3001` and writes its report
under `docs/`.

## Compilation pipeline

1. `compileString()` from AssemblyScript compiles the editor source to Wasm and
   WebAssembly text.
2. In GPU mode, `compileWithRuntimeInfo()` from Gasm translates Wasm to WGSL and
   reports errors, warnings, advisories, and demotions.
3. `BrowserGPUExecutor` allocates the WebGPU pipeline and memory once, then
   dispatches frames while keeping the persistent state region on the GPU.
4. In CPU mode, the browser instantiates the Wasm directly and calls `main()` on
   each animation frame.

The compiler modules are lazy-loaded so the initial application shell does not
download the large AssemblyScript and Gasm bundles until compilation starts.

## Project structure

```text
assemblyscriptoy/
|-- index.html                    App shell and demo navigation
|-- shader-source.js              Lazy-loaded demo catalog
|-- shaders/                      AssemblyScript demo sources
|-- src/
|   |-- main.js                   Editor, compilation, and animation flow
|   |-- gasm-integrator.js        Wasm-to-WGSL integration
|   |-- browser-gpu-executor.js   WebGPU execution adapter
|   |-- load-compilers.js         Lazy compiler loading
|   `-- style.css                 Application styles
|-- scripts/
|   |-- check-shader-corpus.mjs
|   `-- collect-browser-demos.mjs
|-- vite.config.ts
`-- package.json
```
