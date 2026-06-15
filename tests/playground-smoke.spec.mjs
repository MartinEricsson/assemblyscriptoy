import { expect, test } from '@playwright/test';

test('loads and runs the initial demo in CPU mode', async ({ page }) => {
    const pageErrors = [];
    page.on('pageerror', error => pageErrors.push(error));

    await page.goto('/');
    await page.locator('#renderMode').selectOption('cpu');

    const editor = page.locator('#asSourceEditor');
    await expect(editor).toHaveValue(/export function main/);
    await expect(editor).toHaveValue(/sceneSDF/);
    await expect(page.locator('#statusChip')).toHaveText('RUNNING', { timeout: 120_000 });
    await expect(page.locator('#canvasMeta')).toContainText('CPU');

    await page.getByRole('tab', { name: 'RESULTS' }).click();
    await expect(page.locator('#results')).toContainText('Compiled successfully');
    await expect(page.locator('#results')).toContainText('Running directly via WebAssembly');
    expect(pageErrors).toEqual([]);
});

test('rapid demo switching keeps only the latest session active', async ({ page }) => {
    const pageErrors = [];
    const consoleErrors = [];
    page.on('pageerror', error => pageErrors.push(error));
    page.on('console', message => {
        if (message.type() === 'error') consoleErrors.push(message.text());
    });

    await page.goto('/');
    await page.locator('#renderMode').selectOption('cpu');
    await expect(page.locator('#asSourceEditor')).toHaveValue(/sceneSDF/);

    await page.evaluate(() => {
        void window.loadDemo('cornellBoxGi');
        void window.loadDemo('starter');
    });

    await expect(page.locator('#statusChip')).toHaveText('RUNNING', { timeout: 120_000 });
    await expect(page.locator('.demo-item.active')).toHaveAttribute('data-demo', 'starter');
    await expect(page.locator('#demoSelect')).toHaveValue('starter');
    await expect(page.locator('#asSourceEditor')).toHaveValue(/triWave/);
    await expect(page.locator('#asSourceEditor')).not.toHaveValue(/tracePath/);

    await page.getByRole('tab', { name: 'RESULTS' }).click();
    await expect(page.locator('#results')).toContainText('Compiled successfully');
    await expect(page.locator('#results')).toContainText('Running directly via WebAssembly');

    expect(pageErrors).toEqual([]);
    expect(
        consoleErrors.filter(message =>
            /createBuffer|destroyed|device lost|TypeError/i.test(message),
        ),
    ).toEqual([]);
});

test('CPU runtime trap stops once and allows recovery', async ({ page }) => {
    const pageErrors = [];
    const runtimeErrors = [];
    page.on('pageerror', error => pageErrors.push(error));
    page.on('console', message => {
        if (message.type() === 'error' && /memory access out of bounds/i.test(message.text())) {
            runtimeErrors.push(message.text());
        }
    });

    await page.goto('/');
    await page.locator('#renderMode').selectOption('cpu');
    await expect(page.locator('#asSourceEditor')).toHaveValue(/sceneSDF/);
    await page.evaluate(() => window.loadDemo('starter'));
    await expect(page.locator('#statusChip')).toHaveText('RUNNING', { timeout: 120_000 });

    await page.locator('#asSourceEditor').fill(`export function main(): void {
  store<i32>(2000000, 1);
}`);
    await page.getByRole('button', { name: /compile & run/i }).click();

    await expect(page.locator('#statusChip')).toHaveText('ERROR', { timeout: 120_000 });
    await expect(page.locator('#stopBtn')).toBeHidden();
    await expect(page.locator('#results')).toContainText(/memory access out of bounds/i);
    await page.waitForTimeout(400);
    await expect(page.locator('#statusChip')).toHaveText('ERROR');
    expect(runtimeErrors).toHaveLength(1);
    expect(pageErrors).toEqual([]);

    await page.evaluate(() => window.loadDemo('starter'));
    await expect(page.locator('#statusChip')).toHaveText('RUNNING', { timeout: 120_000 });
    await expect(page.locator('#asSourceEditor')).toHaveValue(/triWave/);
});

test('local Prism highlights source and compiler output without cdnjs', async ({ page }) => {
    const requests = [];
    const pageErrors = [];
    page.on('request', request => requests.push(request.url()));
    page.on('pageerror', error => pageErrors.push(error));

    await page.goto('/');
    await page.locator('#renderMode').selectOption('cpu');
    await expect(page.locator('#asSourceEditor')).toHaveValue(/sceneSDF/);
    await expect(page.locator('#statusChip')).toHaveText('RUNNING', { timeout: 120_000 });
    await expect(page.locator('#asSourceEditorCode .token').first()).toBeVisible();

    await page.getByRole('tab', { name: 'WAT' }).click();
    await expect(page.locator('#watCodeElement .token').first()).toBeVisible();

    const hasWebGPU = await page.evaluate(async () => {
        if (!navigator.gpu) return false;
        return Boolean(await navigator.gpu.requestAdapter());
    });
    if (hasWebGPU) {
        await page.locator('#renderMode').selectOption('gpu');
        await page.evaluate(() => window.loadDemo('starter'));
        await expect(page.locator('#statusChip')).toHaveText('RUNNING', { timeout: 120_000 });
        await page.getByRole('tab', { name: 'WGSL' }).click();
        await expect(page.locator('#wgslCodeElement .token').first()).toBeVisible();
    }

    expect(requests.some(url => url.includes('cdnjs.cloudflare.com/ajax/libs/prism'))).toBe(false);
    expect(
        pageErrors.filter(error => /Prism is not defined|language grammar/i.test(error.message)),
    ).toEqual([]);
});

test('WGSL output panel exposes minify and copies the source', async ({ context, page }) => {
    await context.grantPermissions(['clipboard-read', 'clipboard-write']);
    await page.goto('/');
    await page.locator('#renderMode').selectOption('cpu');
    await page.getByRole('tab', { name: 'WGSL' }).click();

    await expect(page.getByLabel('MINIFY OUTPUT')).toBeVisible();
    await page.getByRole('button', { name: 'COPY WGSL' }).click();
    await expect(page.locator('#copyWGSLBtn')).toHaveText('COPIED');
    await expect.poll(() => page.evaluate(() => navigator.clipboard.readText())).toContain(
        'Click Compile & Run to generate WGSL',
    );
});
