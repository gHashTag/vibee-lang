/**
 * VIBEE Advanced Browser Control v2310
 * Comprehensive Headless Browser Management
 * φ² + 1/φ² = 3 | PHOENIX = 999
 */

const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

class VIBEEBrowserController {
    constructor(config = {}) {
        this.config = {
            headless: config.headless ?? 'new',
            slowMo: config.slowMo ?? 0,
            devtools: config.devtools ?? false,
            viewport: config.viewport ?? { width: 1920, height: 1080 },
            screenshotsDir: config.screenshotsDir ?? './screenshots',
            timeout: config.timeout ?? 30000,
            ...config
        };
        this.browser = null;
        this.page = null;
        this.cdpSession = null;
        this.networkRequests = [];
        this.consoleMessages = [];
        this.performanceMetrics = {};
    }

    async launch() {
        console.log('🚀 Launching VIBEE Browser Controller...');
        this.browser = await puppeteer.launch({
            headless: this.config.headless,
            slowMo: this.config.slowMo,
            devtools: this.config.devtools,
            args: [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-gpu',
                '--disable-dev-shm-usage'
            ]
        });
        
        this.page = await this.browser.newPage();
        await this.page.setViewport(this.config.viewport);
        
        // Create CDP session for advanced features
        this.cdpSession = await this.page.target().createCDPSession();
        
        // Enable CDP domains
        await this.cdpSession.send('Performance.enable');
        await this.cdpSession.send('Network.enable');
        await this.cdpSession.send('Console.enable');
        await this.cdpSession.send('DOM.enable');
        
        // Setup event listeners
        this._setupEventListeners();
        
        console.log('✅ Browser launched successfully');
        return this;
    }

    _setupEventListeners() {
        // Console messages
        this.page.on('console', msg => {
            this.consoleMessages.push({
                type: msg.type(),
                text: msg.text(),
                timestamp: Date.now()
            });
        });

        // Network requests
        this.page.on('request', req => {
            this.networkRequests.push({
                url: req.url(),
                method: req.method(),
                resourceType: req.resourceType(),
                timestamp: Date.now()
            });
        });

        // Page errors
        this.page.on('pageerror', error => {
            this.consoleMessages.push({
                type: 'error',
                text: error.message,
                timestamp: Date.now()
            });
        });
    }

    async navigate(url) {
        console.log(`📍 Navigating to: ${url}`);
        await this.page.goto(url, {
            waitUntil: 'networkidle0',
            timeout: this.config.timeout
        });
        return this;
    }

    async screenshot(name, options = {}) {
        const filename = `${name}.png`;
        const filepath = path.join(this.config.screenshotsDir, filename);
        
        if (!fs.existsSync(this.config.screenshotsDir)) {
            fs.mkdirSync(this.config.screenshotsDir, { recursive: true });
        }
        
        await this.page.screenshot({
            path: filepath,
            fullPage: options.fullPage ?? true,
            ...options
        });
        
        console.log(`📸 Screenshot saved: ${filepath}`);
        return filepath;
    }

    async getPerformanceMetrics() {
        const metrics = await this.cdpSession.send('Performance.getMetrics');
        this.performanceMetrics = metrics.metrics.reduce((acc, m) => {
            acc[m.name] = m.value;
            return acc;
        }, {});
        
        // Get timing metrics
        const timing = await this.page.evaluate(() => {
            const perf = performance.timing;
            return {
                loadTime: perf.loadEventEnd - perf.navigationStart,
                domReady: perf.domContentLoadedEventEnd - perf.navigationStart,
                firstPaint: performance.getEntriesByType('paint')[0]?.startTime || 0
            };
        });
        
        return { ...this.performanceMetrics, ...timing };
    }

    async runAccessibilityAudit() {
        // Inject axe-core
        await this.page.addScriptTag({
            url: 'https://cdnjs.cloudflare.com/ajax/libs/axe-core/4.7.0/axe.min.js'
        });
        
        const results = await this.page.evaluate(async () => {
            return await axe.run();
        });
        
        return {
            violations: results.violations.length,
            passes: results.passes.length,
            incomplete: results.incomplete.length,
            details: results.violations.map(v => ({
                id: v.id,
                impact: v.impact,
                description: v.description,
                nodes: v.nodes.length
            }))
        };
    }

    async testNavigation(sections) {
        const results = {};
        
        for (const section of sections) {
            try {
                const clicked = await this.page.evaluate((s) => {
                    const selectors = [
                        `[data-section="${s}"]`,
                        `[onclick*="${s}"]`,
                        `a[href*="${s}"]`,
                        `button:contains("${s}")`
                    ];
                    
                    for (const selector of selectors) {
                        try {
                            const el = document.querySelector(selector);
                            if (el) {
                                el.click();
                                return true;
                            }
                        } catch (e) {}
                    }
                    
                    // Try by text content
                    const els = document.querySelectorAll('button, a, [role="button"]');
                    for (const el of els) {
                        if (el.textContent.toLowerCase().includes(s.toLowerCase())) {
                            el.click();
                            return true;
                        }
                    }
                    return false;
                }, section);
                
                await new Promise(r => setTimeout(r, 300));
                results[section] = clicked ? '✅' : '⚠️';
            } catch (e) {
                results[section] = '❌';
            }
        }
        
        return results;
    }

    async testInteractiveElements() {
        return await this.page.evaluate(() => ({
            buttons: document.querySelectorAll('button').length,
            inputs: document.querySelectorAll('input, textarea, select').length,
            links: document.querySelectorAll('a[href]').length,
            clickable: document.querySelectorAll('[onclick], [role="button"]').length,
            forms: document.querySelectorAll('form').length
        }));
    }

    async testGlassUI() {
        return await this.page.evaluate(() => {
            const elements = Array.from(document.querySelectorAll('*'));
            let blur = 0, transparent = 0, gradient = 0;
            
            elements.forEach(el => {
                const style = getComputedStyle(el);
                if (style.backdropFilter?.includes('blur')) blur++;
                if (parseFloat(style.opacity) < 1 || style.backgroundColor?.includes('rgba')) transparent++;
                if (style.background?.includes('gradient')) gradient++;
            });
            
            return { blurElements: blur, transparentElements: transparent, gradientElements: gradient };
        });
    }

    async testResponsive(viewports) {
        const results = {};
        
        for (const vp of viewports) {
            await this.page.setViewport(vp);
            await new Promise(r => setTimeout(r, 200));
            
            const layout = await this.page.evaluate(() => ({
                scrollWidth: document.body.scrollWidth,
                clientWidth: document.body.clientWidth,
                hasHorizontalScroll: document.body.scrollWidth > document.body.clientWidth
            }));
            
            results[vp.name || `${vp.width}x${vp.height}`] = !layout.hasHorizontalScroll ? '✅' : '⚠️';
        }
        
        // Reset viewport
        await this.page.setViewport(this.config.viewport);
        return results;
    }

    async runComprehensiveTest(url) {
        console.log('\n🔥 VIBEE COMPREHENSIVE TEST SUITE');
        console.log('═'.repeat(60));
        
        await this.navigate(url);
        
        const results = {
            timestamp: new Date().toISOString(),
            url: url,
            tests: {}
        };
        
        // 1. Navigation Test
        console.log('\n🧭 Testing Navigation...');
        results.tests.navigation = await this.testNavigation([
            'home', 'modules', 'pas', 'neuro', 'mind', 'core', 'agents', 'llm', 'languages'
        ]);
        
        // 2. Interactive Elements
        console.log('🖱️ Testing Interactive Elements...');
        results.tests.interactive = await this.testInteractiveElements();
        
        // 3. Glass UI
        console.log('🔮 Testing Glass UI...');
        results.tests.glassUI = await this.testGlassUI();
        
        // 4. Performance
        console.log('⚡ Testing Performance...');
        results.tests.performance = await this.getPerformanceMetrics();
        
        // 5. Responsive
        console.log('📱 Testing Responsive...');
        results.tests.responsive = await this.testResponsive([
            { width: 375, height: 667, name: 'mobile' },
            { width: 768, height: 1024, name: 'tablet' },
            { width: 1920, height: 1080, name: 'desktop' }
        ]);
        
        // 6. Console Errors
        console.log('🐛 Checking Errors...');
        const errors = this.consoleMessages.filter(m => m.type === 'error');
        results.tests.errors = {
            count: errors.length,
            messages: errors.slice(0, 5).map(e => e.text.substring(0, 100))
        };
        
        // 7. Network
        console.log('🌐 Analyzing Network...');
        results.tests.network = {
            totalRequests: this.networkRequests.length,
            byType: this.networkRequests.reduce((acc, r) => {
                acc[r.resourceType] = (acc[r.resourceType] || 0) + 1;
                return acc;
            }, {})
        };
        
        // Take screenshot
        await this.screenshot('comprehensive_test');
        
        // Summary
        console.log('\n' + '═'.repeat(60));
        console.log('📊 TEST SUMMARY');
        console.log('═'.repeat(60));
        
        const navPassed = Object.values(results.tests.navigation).filter(v => v === '✅').length;
        console.log(`Navigation: ${navPassed}/9`);
        console.log(`Interactive: ${results.tests.interactive.buttons} buttons, ${results.tests.interactive.inputs} inputs`);
        console.log(`Glass UI: ${results.tests.glassUI.blurElements} blur, ${results.tests.glassUI.transparentElements} transparent`);
        console.log(`Performance: ${results.tests.performance.loadTime}ms load time`);
        console.log(`Responsive: ${Object.values(results.tests.responsive).filter(v => v === '✅').length}/3`);
        console.log(`Errors: ${results.tests.errors.count}`);
        console.log(`Network: ${results.tests.network.totalRequests} requests`);
        
        return results;
    }

    async close() {
        if (this.browser) {
            await this.browser.close();
            console.log('🔒 Browser closed');
        }
    }

    getConsoleMessages() {
        return this.consoleMessages;
    }

    getNetworkRequests() {
        return this.networkRequests;
    }
}

// Main execution
(async () => {
    const controller = new VIBEEBrowserController({
        headless: 'new',
        viewport: { width: 1920, height: 1080 },
        screenshotsDir: './screenshots'
    });
    
    try {
        await controller.launch();
        
        const runtimePath = path.resolve(__dirname, 'runtime/runtime.html');
        const results = await controller.runComprehensiveTest(`file://${runtimePath}`);
        
        // Save results
        fs.writeFileSync('yolo20_comprehensive_results.json', JSON.stringify(results, null, 2));
        console.log('\n✅ Results saved to yolo20_comprehensive_results.json');
        
    } catch (error) {
        console.error('❌ Test error:', error.message);
    } finally {
        await controller.close();
    }
    
    console.log('\n🔥 YOLO XX BROWSER CONTROL COMPLETE');
    console.log('φ² + 1/φ² = 3 | PHOENIX = 999');
})();

module.exports = VIBEEBrowserController;
