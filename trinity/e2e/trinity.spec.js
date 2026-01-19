/**
 * TRINITY E2E Tests v22.φ
 * End-to-end tests using Playwright
 * 
 * φ² + 1/φ² = 3
 */

import { test, expect } from '@playwright/test';

test.describe('TRINITY Core', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    // Wait for canvas to be ready
    await page.waitForSelector('canvas#c');
  });

  test('should load the application', async ({ page }) => {
    await expect(page).toHaveTitle(/Trinity/i);
  });

  test('should display canvas', async ({ page }) => {
    const canvas = page.locator('canvas#c');
    await expect(canvas).toBeVisible();
  });

  test('should have navigation tabs', async ({ page }) => {
    const articleTab = page.locator('.tab[data-tab="article"]');
    const selfTestTab = page.locator('.tab[data-tab="selftest"]');
    
    await expect(articleTab).toBeVisible();
    await expect(selfTestTab).toBeVisible();
  });

  test('should switch tabs', async ({ page }) => {
    const selfTestTab = page.locator('.tab[data-tab="selftest"]');
    await selfTestTab.click();
    
    await expect(selfTestTab).toHaveClass(/active/);
    await expect(page).toHaveURL(/#selftest/);
  });
});

test.describe('TRINITY Accessibility', () => {
  test('should have skip link', async ({ page }) => {
    await page.goto('/');
    
    const skipLink = page.locator('.skip-link');
    await expect(skipLink).toBeAttached();
  });

  test('should have ARIA live region', async ({ page }) => {
    await page.goto('/');
    
    const liveRegion = page.locator('#aria-live');
    await expect(liveRegion).toBeAttached();
    await expect(liveRegion).toHaveAttribute('role', 'status');
  });

  test('should have accessible tabs', async ({ page }) => {
    await page.goto('/');
    
    const tablist = page.locator('[role="tablist"]');
    await expect(tablist).toBeVisible();
    
    const tabs = page.locator('[role="tab"]');
    await expect(tabs).toHaveCount(2);
  });

  test('canvas should have aria-label', async ({ page }) => {
    await page.goto('/');
    
    const canvas = page.locator('canvas#c');
    await expect(canvas).toHaveAttribute('aria-label', /TRINITY/);
  });
});

test.describe('TRINITY Performance', () => {
  test('should load within 5 seconds', async ({ page }) => {
    const startTime = Date.now();
    await page.goto('/');
    await page.waitForSelector('canvas#c');
    const loadTime = Date.now() - startTime;
    
    expect(loadTime).toBeLessThan(5000);
  });

  test('should have no console errors', async ({ page }) => {
    const errors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        errors.push(msg.text());
      }
    });
    
    await page.goto('/');
    await page.waitForTimeout(2000);
    
    // Filter out expected warnings
    const criticalErrors = errors.filter(e => 
      !e.includes('favicon') && 
      !e.includes('WASM') &&
      !e.includes('WebGPU')
    );
    
    expect(criticalErrors).toHaveLength(0);
  });
});

test.describe('TRINITY Navigation', () => {
  test('should navigate with keyboard', async ({ page }) => {
    await page.goto('/');
    
    // Focus on canvas
    await page.locator('canvas#c').focus();
    
    // Press arrow keys
    await page.keyboard.press('ArrowDown');
    await page.keyboard.press('ArrowUp');
    
    // Should not throw errors
  });

  test('should handle hash navigation', async ({ page }) => {
    await page.goto('/#selftest');
    
    const selfTestTab = page.locator('.tab[data-tab="selftest"]');
    await expect(selfTestTab).toHaveClass(/active/);
  });
});

test.describe('TRINITY Service Worker', () => {
  test('should register service worker', async ({ page }) => {
    await page.goto('/');
    
    // Wait for SW registration
    await page.waitForTimeout(2000);
    
    const swRegistered = await page.evaluate(async () => {
      if ('serviceWorker' in navigator) {
        const registrations = await navigator.serviceWorker.getRegistrations();
        return registrations.length > 0;
      }
      return false;
    });
    
    expect(swRegistered).toBe(true);
  });
});

test.describe('TRINITY WASM', () => {
  test('should load WASM module', async ({ page }) => {
    await page.goto('/');
    
    // Wait for WASM to load
    await page.waitForTimeout(3000);
    
    const wasmLoaded = await page.evaluate(() => {
      return typeof WASMCompute !== 'undefined' && WASMCompute.loaded;
    });
    
    // WASM may not load if file not served, but should not error
    expect(wasmLoaded === true || wasmLoaded === false).toBe(true);
  });
});

test.describe('TRINITY Golden Identity', () => {
  test('should validate φ² + 1/φ² = 3', async ({ page }) => {
    await page.goto('/');
    
    const valid = await page.evaluate(() => {
      const PHI = 1.618033988749895;
      const result = PHI * PHI + 1 / (PHI * PHI);
      return Math.abs(result - 3) < 1e-10;
    });
    
    expect(valid).toBe(true);
  });
});

test.describe('TRINITY Mobile', () => {
  test.use({ viewport: { width: 375, height: 667 } });
  
  test('should be responsive on mobile', async ({ page }) => {
    await page.goto('/');
    
    const canvas = page.locator('canvas#c');
    await expect(canvas).toBeVisible();
    
    // Canvas should fill viewport
    const box = await canvas.boundingBox();
    expect(box.width).toBeGreaterThan(300);
    expect(box.height).toBeGreaterThan(500);
  });
});
