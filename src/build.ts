import { execSync } from "child_process";
import { readFileSync, writeFileSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
import {
  compileGasmIntegrator,
  DEFAULT_GASM_COMPILE_OPTIONS,
} from "./gasm-integrator.js";
import { setBrowserCompilerBackend } from "@gasm-compiler/core/browser";

setBrowserCompilerBackend("typescript");

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

console.log("🔨 Building shader.as...");

// Step 1: Compile AssemblyScript to Wasm
console.log("  → Compiling AssemblyScript to Wasm...");
try {
  execSync(
    "npx asc --config asconfig.json",
    { cwd: join(__dirname, ".."), stdio: "inherit" }
  );
} catch (error) {
  console.error("❌ AssemblyScript compilation failed");
  process.exit(1);
}

// Step 2: Compile Wasm to WGSL using Gasm
console.log("  → Compiling Wasm to WGSL with Gasm...");
const wasmPath = join(__dirname, "..", "build", "shader.wasm");
const wasmBytes = readFileSync(wasmPath);

const result = compileGasmIntegrator(wasmBytes, {
  ...DEFAULT_GASM_COMPILE_OPTIONS,
  sourceMapping: "normal",
});

if (!result.ok) {
  const errors = result.diagnostics.errors
    .map((e) => `${e.code}: ${e.message}`)
    .join("\n");
  console.error("❌ Gasm compilation failed:\n" + errors);
  process.exit(1);
}

const wgslCode = result.wgsl;

// Step 3: Write WGSL output
const wgslPath = join(__dirname, "..", "build", "shader.wgsl");
writeFileSync(wgslPath, wgslCode);

// Step 4: Write Wasm as a JS module for browser import
const wasmBase64 = Buffer.from(wasmBytes).toString("base64");
const jsModule = `// Auto-generated from shader.ts
export const wasmBytes = Uint8Array.from(atob("${wasmBase64}"), c => c.charCodeAt(0));
export const wgslCode = ${JSON.stringify(wgslCode)};
`;
const jsPath = join(__dirname, "..", "build", "shader.js");
writeFileSync(jsPath, jsModule);

console.log("✅ Build complete!");
console.log(`   - Wasm: build/shader.wasm`);
console.log(`   - WGSL: build/shader.wgsl`);
console.log(`   - JS module: build/shader.js`);