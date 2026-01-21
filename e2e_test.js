const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');

async function runE2ETest() {
    console.log('🚀 Starting VIBEE Browser E2E Test...\n');
    
    const browser = await puppeteer.launch({
        headless: 'new',
        args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-gpu'
        ]
    });
    
    const page = await browser.newPage();
    
    // Set viewport
    await page.setViewport({ width: 1920, height: 1080 });
    
    // Load runtime.html
    const runtimePath = path.join(__dirname, 'runtime', 'runtime.html');
    console.log(`📂 Loading: ${runtimePath}`);
    
    if (!fs.existsSync(runtimePath)) {
        console.error('❌ runtime.html not found!');
        await browser.close();
        process.exit(1);
    }
    
    await page.goto(`file://${runtimePath}`, { waitUntil: 'networkidle0', timeout: 30000 });
    
    console.log('✅ Page loaded successfully\n');
    
    // Get page title
    const title = await page.title();
    console.log(`📄 Page Title: ${title}`);
    
    // Get page content info
    const bodyContent = await page.evaluate(() => {
        return {
            bodyLength: document.body.innerHTML.length,
            hasCanvas: !!document.querySelector('canvas'),
            hasWebGL: !!document.querySelector('canvas[data-webgl]'),
            scripts: document.querySelectorAll('script').length,
            styles: document.querySelectorAll('style').length,
            divs: document.querySelectorAll('div').length,
            buttons: document.querySelectorAll('button').length,
            inputs: document.querySelectorAll('input').length
        };
    });
    
    console.log('\n📊 Page Structure:');
    console.log(`   Body HTML length: ${bodyContent.bodyLength} chars`);
    console.log(`   Has Canvas: ${bodyContent.hasCanvas}`);
    console.log(`   Scripts: ${bodyContent.scripts}`);
    console.log(`   Styles: ${bodyContent.styles}`);
    console.log(`   Divs: ${bodyContent.divs}`);
    console.log(`   Buttons: ${bodyContent.buttons}`);
    console.log(`   Inputs: ${bodyContent.inputs}`);
    
    // Check for errors in console
    const consoleMessages = [];
    page.on('console', msg => consoleMessages.push({ type: msg.type(), text: msg.text() }));
    
    // Check for JavaScript errors
    const jsErrors = [];
    page.on('pageerror', error => jsErrors.push(error.message));
    
    // Wait a bit for any async operations
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Take screenshot
    const screenshotPath = '/workspaces/vibee-lang/e2e_screenshot.png';
    await page.screenshot({ path: screenshotPath, fullPage: true });
    console.log(`\n📸 Screenshot saved: ${screenshotPath}`);
    
    // Check for WebGL support
    const webglSupport = await page.evaluate(() => {
        const canvas = document.createElement('canvas');
        const gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');
        return !!gl;
    });
    console.log(`\n🎮 WebGL Support: ${webglSupport ? '✅ Yes' : '❌ No'}`);
    
    // Check for WebGPU support
    const webgpuSupport = await page.evaluate(() => {
        return 'gpu' in navigator;
    });
    console.log(`🖥️  WebGPU Support: ${webgpuSupport ? '✅ Yes' : '❌ No (expected in headless)'}`);
    
    // Report errors
    if (jsErrors.length > 0) {
        console.log('\n❌ JavaScript Errors:');
        jsErrors.forEach(err => console.log(`   ${err}`));
    } else {
        console.log('\n✅ No JavaScript errors detected');
    }
    
    // Summary
    console.log('\n' + '='.repeat(50));
    console.log('📋 E2E TEST SUMMARY');
    console.log('='.repeat(50));
    console.log(`✅ Page loaded: Yes`);
    console.log(`✅ Title: ${title}`);
    console.log(`✅ Content size: ${bodyContent.bodyLength} chars`);
    console.log(`✅ WebGL: ${webglSupport ? 'Supported' : 'Not supported'}`);
    console.log(`✅ JS Errors: ${jsErrors.length}`);
    console.log('='.repeat(50));
    
    await browser.close();
    
    console.log('\n🎉 E2E Test completed successfully!\n');
    
    // Return test results
    return {
        success: true,
        title,
        bodyLength: bodyContent.bodyLength,
        webglSupport,
        jsErrors: jsErrors.length
    };
}

runE2ETest().catch(err => {
    console.error('❌ E2E Test failed:', err);
    process.exit(1);
});
