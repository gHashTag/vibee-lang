/**
 * VIBEE Browser Control System
 * Комплексное управление headless браузером
 * 
 * φ² + 1/φ² = 3 | PHOENIX = 999
 */

const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');

class VIBEEBrowserController {
    constructor() {
        this.browser = null;
        this.page = null;
        this.screenshots = [];
        this.testResults = [];
        this.startTime = Date.now();
    }

    async init() {
        console.log('🚀 Initializing VIBEE Browser Controller...\n');
        
        this.browser = await puppeteer.launch({
            headless: 'new',
            args: [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage',
                '--disable-gpu',
                '--window-size=1920,1080'
            ]
        });
        
        this.page = await this.browser.newPage();
        await this.page.setViewport({ width: 1920, height: 1080 });
        
        // Capture console logs
        this.consoleLogs = [];
        this.page.on('console', msg => {
            this.consoleLogs.push({ type: msg.type(), text: msg.text() });
        });
        
        // Capture errors
        this.errors = [];
        this.page.on('pageerror', error => {
            this.errors.push(error.message);
        });
        
        console.log('✅ Browser initialized\n');
        return this;
    }

    async loadRuntime() {
        const runtimePath = path.join(__dirname, 'runtime', 'runtime.html');
        console.log(`📂 Loading: ${runtimePath}`);
        await this.page.goto(`file://${runtimePath}`, { waitUntil: 'networkidle0', timeout: 30000 });
        await this.wait(1000);
        console.log('✅ Runtime loaded\n');
    }

    async wait(ms) {
        await new Promise(resolve => setTimeout(resolve, ms));
    }

    async screenshot(name) {
        const filename = `/workspaces/vibee-lang/screenshots/${name}.png`;
        await fs.promises.mkdir('/workspaces/vibee-lang/screenshots', { recursive: true });
        await this.page.screenshot({ path: filename, fullPage: false });
        this.screenshots.push(filename);
        return filename;
    }

    async click(selector) {
        try {
            await this.page.click(selector);
            await this.wait(300);
            return true;
        } catch (e) {
            return false;
        }
    }

    async clickByText(text) {
        const clicked = await this.page.evaluate((searchText) => {
            const elements = document.querySelectorAll('*');
            for (const el of elements) {
                if (el.textContent.trim() === searchText && 
                    el.children.length === 0 &&
                    (el.tagName === 'BUTTON' || el.tagName === 'A' || 
                     el.tagName === 'SPAN' || el.tagName === 'DIV' ||
                     el.onclick || el.style.cursor === 'pointer')) {
                    el.click();
                    return true;
                }
            }
            // Try partial match
            for (const el of elements) {
                if (el.textContent.includes(searchText) && 
                    el.children.length === 0) {
                    el.click();
                    return true;
                }
            }
            return false;
        }, text);
        await this.wait(300);
        return clicked;
    }

    async getPageInfo() {
        return await this.page.evaluate(() => {
            return {
                title: document.title,
                url: window.location.href,
                bodyLength: document.body.innerHTML.length,
                canvases: document.querySelectorAll('canvas').length,
                buttons: document.querySelectorAll('button').length,
                inputs: document.querySelectorAll('input').length,
                divs: document.querySelectorAll('div').length,
                visibleText: document.body.innerText.substring(0, 500)
            };
        });
    }

    async getModuleInfo() {
        return await this.page.evaluate(() => {
            const text = document.body.innerText;
            const moduleMatch = text.match(/(\d+)\s*Modules/i);
            const categories = text.match(/(CORE|PAS|EVO|AGENT|VIZ|QUANTUM|BLOCK|INT)\s*\(\d+\)/gi) || [];
            return {
                totalModules: moduleMatch ? parseInt(moduleMatch[1]) : 0,
                categories: categories
            };
        });
    }

    async testNavigation() {
        console.log('\n' + '='.repeat(60));
        console.log('🧭 TEST: Navigation System');
        console.log('='.repeat(60));
        
        const tabs = ['Home', 'Modules', 'PAS', 'Neuro', 'Mind', 'Core', 'Agents', 'LLM', 'Languages'];
        const results = {};
        
        for (const tab of tabs) {
            const clicked = await this.clickByText(tab);
            results[tab] = clicked;
            console.log(`   ${tab}: ${clicked ? '✅' : '⚠️'}`);
            if (clicked) {
                await this.screenshot(`nav_${tab.toLowerCase()}`);
            }
        }
        
        this.testResults.push({ name: 'Navigation', results });
        return results;
    }

    async testModuleVisualization() {
        console.log('\n' + '='.repeat(60));
        console.log('📊 TEST: Module Visualization');
        console.log('='.repeat(60));
        
        await this.clickByText('Modules');
        await this.wait(500);
        
        const moduleInfo = await this.getModuleInfo();
        console.log(`   Total Modules: ${moduleInfo.totalModules}`);
        console.log(`   Categories: ${moduleInfo.categories.length}`);
        moduleInfo.categories.forEach(cat => console.log(`     - ${cat}`));
        
        // Check canvas
        const canvasInfo = await this.page.evaluate(() => {
            const canvas = document.querySelector('canvas');
            if (!canvas) return null;
            return {
                width: canvas.width,
                height: canvas.height,
                context: canvas.getContext('2d') ? '2d' : (canvas.getContext('webgl') ? 'webgl' : 'none')
            };
        });
        
        if (canvasInfo) {
            console.log(`   Canvas: ${canvasInfo.width}x${canvasInfo.height} (${canvasInfo.context})`);
        }
        
        await this.screenshot('modules_visualization');
        
        this.testResults.push({ name: 'Module Visualization', results: { moduleInfo, canvasInfo } });
        return { moduleInfo, canvasInfo };
    }

    async testInteractiveElements() {
        console.log('\n' + '='.repeat(60));
        console.log('🖱️ TEST: Interactive Elements');
        console.log('='.repeat(60));
        
        const elements = await this.page.evaluate(() => {
            const buttons = Array.from(document.querySelectorAll('button')).map(b => b.textContent.trim().substring(0, 30));
            const inputs = Array.from(document.querySelectorAll('input')).map(i => ({ type: i.type, placeholder: i.placeholder }));
            const clickable = document.querySelectorAll('[onclick]').length;
            
            return { buttons: buttons.slice(0, 20), inputs, clickable };
        });
        
        console.log(`   Buttons (${elements.buttons.length}): ${elements.buttons.slice(0, 5).join(', ')}...`);
        console.log(`   Inputs: ${elements.inputs.length}`);
        console.log(`   Clickable elements: ${elements.clickable}`);
        
        // Try clicking some buttons
        if (elements.buttons.length > 0) {
            console.log('\n   Testing button clicks:');
            for (let i = 0; i < Math.min(3, elements.buttons.length); i++) {
                const btn = elements.buttons[i];
                if (btn && btn.length > 0) {
                    const clicked = await this.clickByText(btn);
                    console.log(`     "${btn.substring(0, 20)}": ${clicked ? '✅' : '⚠️'}`);
                }
            }
        }
        
        this.testResults.push({ name: 'Interactive Elements', results: elements });
        return elements;
    }

    async testPerformance() {
        console.log('\n' + '='.repeat(60));
        console.log('⚡ TEST: Performance Metrics');
        console.log('='.repeat(60));
        
        const metrics = await this.page.metrics();
        const performance = await this.page.evaluate(() => {
            const perf = window.performance;
            const timing = perf.timing;
            return {
                loadTime: timing.loadEventEnd - timing.navigationStart,
                domReady: timing.domContentLoadedEventEnd - timing.navigationStart,
                firstPaint: perf.getEntriesByType('paint')[0]?.startTime || 0
            };
        });
        
        console.log(`   JS Heap Used: ${(metrics.JSHeapUsedSize / 1024 / 1024).toFixed(2)} MB`);
        console.log(`   JS Heap Total: ${(metrics.JSHeapTotalSize / 1024 / 1024).toFixed(2)} MB`);
        console.log(`   DOM Nodes: ${metrics.Nodes}`);
        console.log(`   Documents: ${metrics.Documents}`);
        console.log(`   Frames: ${metrics.Frames}`);
        console.log(`   Load Time: ${performance.loadTime}ms`);
        console.log(`   DOM Ready: ${performance.domReady}ms`);
        
        this.testResults.push({ name: 'Performance', results: { metrics, performance } });
        return { metrics, performance };
    }

    async testAIAgentsSection() {
        console.log('\n' + '='.repeat(60));
        console.log('🤖 TEST: AI Agents Section');
        console.log('='.repeat(60));
        
        await this.clickByText('Agents');
        await this.wait(500);
        
        const agentInfo = await this.page.evaluate(() => {
            const text = document.body.innerText;
            const hasAgents = text.includes('Agent') || text.includes('AGENT');
            const agentKeywords = ['orchestrat', 'memory', 'tool', 'plan', 'reflect'].filter(k => 
                text.toLowerCase().includes(k)
            );
            return { hasAgents, agentKeywords };
        });
        
        console.log(`   Agents section found: ${agentInfo.hasAgents ? '✅' : '❌'}`);
        console.log(`   Agent features: ${agentInfo.agentKeywords.join(', ') || 'none detected'}`);
        
        await this.screenshot('agents_section');
        
        this.testResults.push({ name: 'AI Agents', results: agentInfo });
        return agentInfo;
    }

    async testLLMSection() {
        console.log('\n' + '='.repeat(60));
        console.log('🧠 TEST: LLM Integration Section');
        console.log('='.repeat(60));
        
        await this.clickByText('LLM');
        await this.wait(500);
        
        const llmInfo = await this.page.evaluate(() => {
            const text = document.body.innerText.toLowerCase();
            return {
                hasOpenAI: text.includes('openai') || text.includes('gpt'),
                hasAnthropic: text.includes('anthropic') || text.includes('claude'),
                hasEmbeddings: text.includes('embedding'),
                hasStreaming: text.includes('stream')
            };
        });
        
        console.log(`   OpenAI integration: ${llmInfo.hasOpenAI ? '✅' : '⚠️'}`);
        console.log(`   Anthropic integration: ${llmInfo.hasAnthropic ? '✅' : '⚠️'}`);
        console.log(`   Embeddings: ${llmInfo.hasEmbeddings ? '✅' : '⚠️'}`);
        console.log(`   Streaming: ${llmInfo.hasStreaming ? '✅' : '⚠️'}`);
        
        await this.screenshot('llm_section');
        
        this.testResults.push({ name: 'LLM Integration', results: llmInfo });
        return llmInfo;
    }

    async testGlassUI() {
        console.log('\n' + '='.repeat(60));
        console.log('✨ TEST: Glass UI / Glassmorphism');
        console.log('='.repeat(60));
        
        const glassInfo = await this.page.evaluate(() => {
            const styles = Array.from(document.querySelectorAll('*')).map(el => {
                const style = window.getComputedStyle(el);
                return {
                    hasBlur: style.backdropFilter?.includes('blur') || style.filter?.includes('blur'),
                    hasTransparency: parseFloat(style.opacity) < 1 || style.backgroundColor?.includes('rgba'),
                    hasShadow: style.boxShadow !== 'none',
                    hasGradient: style.background?.includes('gradient')
                };
            });
            
            return {
                blurElements: styles.filter(s => s.hasBlur).length,
                transparentElements: styles.filter(s => s.hasTransparency).length,
                shadowElements: styles.filter(s => s.hasShadow).length,
                gradientElements: styles.filter(s => s.hasGradient).length
            };
        });
        
        console.log(`   Blur effects: ${glassInfo.blurElements}`);
        console.log(`   Transparent elements: ${glassInfo.transparentElements}`);
        console.log(`   Shadow elements: ${glassInfo.shadowElements}`);
        console.log(`   Gradient elements: ${glassInfo.gradientElements}`);
        
        const hasGlassmorphism = glassInfo.blurElements > 0 || glassInfo.transparentElements > 10;
        console.log(`   Glassmorphism detected: ${hasGlassmorphism ? '✅' : '⚠️'}`);
        
        this.testResults.push({ name: 'Glass UI', results: glassInfo });
        return glassInfo;
    }

    async testCollaboration() {
        console.log('\n' + '='.repeat(60));
        console.log('👥 TEST: Real-Time Collaboration');
        console.log('='.repeat(60));
        
        const collabInfo = await this.page.evaluate(() => {
            const text = document.body.innerText.toLowerCase();
            return {
                hasCRDT: text.includes('crdt') || text.includes('yjs') || text.includes('automerge'),
                hasWebRTC: text.includes('webrtc') || text.includes('peer'),
                hasPresence: text.includes('presence') || text.includes('cursor'),
                hasSync: text.includes('sync') || text.includes('collab')
            };
        });
        
        console.log(`   CRDT support: ${collabInfo.hasCRDT ? '✅' : '⚠️'}`);
        console.log(`   WebRTC support: ${collabInfo.hasWebRTC ? '✅' : '⚠️'}`);
        console.log(`   Presence system: ${collabInfo.hasPresence ? '✅' : '⚠️'}`);
        console.log(`   Sync system: ${collabInfo.hasSync ? '✅' : '⚠️'}`);
        
        this.testResults.push({ name: 'Collaboration', results: collabInfo });
        return collabInfo;
    }

    async testVibecoding() {
        console.log('\n' + '='.repeat(60));
        console.log('💻 TEST: Vibecoding Features');
        console.log('='.repeat(60));
        
        const vibeInfo = await this.page.evaluate(() => {
            const text = document.body.innerText.toLowerCase();
            return {
                hasIntent: text.includes('intent'),
                hasAutocomplete: text.includes('autocomplete') || text.includes('complete'),
                hasRefactor: text.includes('refactor'),
                hasExplain: text.includes('explain'),
                hasTestGen: text.includes('test') && text.includes('gen'),
                hasDocGen: text.includes('doc') && text.includes('gen')
            };
        });
        
        console.log(`   Intent recognition: ${vibeInfo.hasIntent ? '✅' : '⚠️'}`);
        console.log(`   Autocomplete: ${vibeInfo.hasAutocomplete ? '✅' : '⚠️'}`);
        console.log(`   Refactoring: ${vibeInfo.hasRefactor ? '✅' : '⚠️'}`);
        console.log(`   Code explanation: ${vibeInfo.hasExplain ? '✅' : '⚠️'}`);
        console.log(`   Test generation: ${vibeInfo.hasTestGen ? '✅' : '⚠️'}`);
        console.log(`   Doc generation: ${vibeInfo.hasDocGen ? '✅' : '⚠️'}`);
        
        this.testResults.push({ name: 'Vibecoding', results: vibeInfo });
        return vibeInfo;
    }

    async testErrorHandling() {
        console.log('\n' + '='.repeat(60));
        console.log('🛡️ TEST: Error Handling');
        console.log('='.repeat(60));
        
        console.log(`   JavaScript errors: ${this.errors.length}`);
        if (this.errors.length > 0) {
            this.errors.forEach(err => console.log(`     ❌ ${err}`));
        } else {
            console.log('   ✅ No JavaScript errors detected');
        }
        
        console.log(`   Console warnings: ${this.consoleLogs.filter(l => l.type === 'warning').length}`);
        console.log(`   Console errors: ${this.consoleLogs.filter(l => l.type === 'error').length}`);
        
        this.testResults.push({ name: 'Error Handling', results: { errors: this.errors, consoleLogs: this.consoleLogs } });
        return { errors: this.errors.length, warnings: this.consoleLogs.filter(l => l.type === 'warning').length };
    }

    async generateReport() {
        console.log('\n' + '='.repeat(60));
        console.log('📋 COMPREHENSIVE TEST REPORT');
        console.log('='.repeat(60));
        
        const duration = ((Date.now() - this.startTime) / 1000).toFixed(2);
        
        console.log(`\n⏱️  Test Duration: ${duration}s`);
        console.log(`📸 Screenshots taken: ${this.screenshots.length}`);
        console.log(`🧪 Tests executed: ${this.testResults.length}`);
        
        console.log('\n📊 Test Summary:');
        console.log('-'.repeat(40));
        
        let passed = 0;
        let warnings = 0;
        
        this.testResults.forEach(test => {
            const hasIssues = JSON.stringify(test.results).includes('false') || 
                             JSON.stringify(test.results).includes('"0"');
            if (hasIssues) {
                warnings++;
                console.log(`   ⚠️  ${test.name}`);
            } else {
                passed++;
                console.log(`   ✅ ${test.name}`);
            }
        });
        
        console.log('-'.repeat(40));
        console.log(`   Passed: ${passed}/${this.testResults.length}`);
        console.log(`   Warnings: ${warnings}/${this.testResults.length}`);
        
        // Save report to file
        const report = {
            timestamp: new Date().toISOString(),
            duration: `${duration}s`,
            screenshots: this.screenshots,
            testResults: this.testResults,
            errors: this.errors,
            consoleLogs: this.consoleLogs.slice(0, 50)
        };
        
        await fs.promises.writeFile(
            '/workspaces/vibee-lang/e2e_report.json',
            JSON.stringify(report, null, 2)
        );
        console.log('\n📄 Full report saved: e2e_report.json');
        
        return report;
    }

    async close() {
        if (this.browser) {
            await this.browser.close();
            console.log('\n🔒 Browser closed');
        }
    }

    async runAllTests() {
        try {
            await this.init();
            await this.loadRuntime();
            
            // Run all tests
            await this.testNavigation();
            await this.testModuleVisualization();
            await this.testInteractiveElements();
            await this.testPerformance();
            await this.testAIAgentsSection();
            await this.testLLMSection();
            await this.testGlassUI();
            await this.testCollaboration();
            await this.testVibecoding();
            await this.testErrorHandling();
            
            // Generate report
            await this.generateReport();
            
        } catch (error) {
            console.error('❌ Test suite failed:', error);
        } finally {
            await this.close();
        }
    }
}

// Run tests
const controller = new VIBEEBrowserController();
controller.runAllTests();
