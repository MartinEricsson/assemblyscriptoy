/**
 * Drive the live Vite app and scrape Compiler Results for each demo.
 * Requires: dev server on http://localhost:3001, `pnpm exec playwright install chromium` once.
 *
 * Run: node scripts/collect-browser-demos.mjs
 */
import { chromium } from "playwright";

const BASE = process.env.PLAYGROUND_URL ?? "http://localhost:3001/";
const DEMOS = [
  "starter",
  "xorTextureZoo",
  "plasma",
  "metaballs",
  "voxelRaycaster",
  "persistentLife",
  "persistentHeat",
  "persistentCyclic",
  "flagshipSdfScene",
  "flagshipMandelbrot",
  "flagshipClouds",
  "flagshipFire",
  "cornellBoxGi",
];

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();

await page.goto(BASE, { waitUntil: "networkidle" });

const report = [];

for (const demo of DEMOS) {
  await page.evaluate((id) => {
    window.loadDemo(id);
  }, demo);

  await page.waitForTimeout(100);
  await page.click("#compileRunBtn");
  await page.waitForFunction(
    () => {
      const chip = document.querySelector(".status-chip");
      const text = chip?.textContent ?? "";
      return text.includes("RUNNING") || text.includes("ERROR") || text.includes("IDLE");
    },
    { timeout: 120000 },
  );

  await page.click("#btn-results");
  await page.waitForTimeout(200);

  const data = await page.evaluate(() => {
    const status = document.querySelector(".status-chip")?.textContent?.trim() ?? "";
    const resultsHtml = document.getElementById("results")?.innerHTML ?? "";
    const resultsText = document.getElementById("results")?.innerText ?? "";
    const statusDetail = document.getElementById("status")?.innerText ?? "";
    return { status, resultsHtml, resultsText, statusDetail };
  });

  report.push({ demo, ...data });
  console.log(`[${demo}] status=${data.status}`);
  if (data.resultsText.includes("Compilation failed") || data.resultsText.includes("●")) {
    console.log(data.resultsText.slice(0, 500));
  }
}

await browser.close();

import { writeFileSync } from "node:fs";
writeFileSync(
  "docs/demo-browser-compiler-output-0.3.txt",
  report
    .map(
      (r) =>
        `\n${"=".repeat(72)}\nDEMO: ${r.demo}\nSTATUS: ${r.status}\n${"=".repeat(72)}\n${r.resultsText}\n`,
    )
    .join("\n"),
);

console.log("\nWrote docs/demo-browser-compiler-output-0.3.txt");
