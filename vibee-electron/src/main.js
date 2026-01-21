/**
 * VIBEE Browser - Electron Main Process
 * Real Chromium Browser + Monaco Editor + AI Chat
 * φ² + 1/φ² = 3 | PHOENIX = 999
 */

const { app, BrowserWindow, BrowserView, ipcMain, session, Menu } = require('electron');
const path = require('path');

// ═══════════════════════════════════════════════════════════════════════════
// GOLDEN RATIO CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════

const PHI = 1.6180339887498949;
const PHI_SQUARED = PHI * PHI;           // 2.618...
const PHI_INV_SQUARED = 1 / PHI_SQUARED; // 0.382...
const TRINITY = PHI_SQUARED + PHI_INV_SQUARED; // 3.0 exactly!

// Layout ratios based on φ
const BROWSER_RATIO = 0.618;  // 61.8% - Browser (φ/(φ+1))
const CHAT_RATIO = 0.146;     // 14.6% - Chat
const EDITOR_RATIO = 0.236;   // 23.6% - Editor

// ═══════════════════════════════════════════════════════════════════════════
// GLOBAL STATE
// ═══════════════════════════════════════════════════════════════════════════

let mainWindow = null;
let browserView = null;
let chatView = null;
let editorView = null;

const TOOLBAR_HEIGHT = 52;
const STATUSBAR_HEIGHT = 24;

// ═══════════════════════════════════════════════════════════════════════════
// WINDOW CREATION
// ═══════════════════════════════════════════════════════════════════════════

function createWindow() {
    // Create main window
    mainWindow = new BrowserWindow({
        width: 1600,
        height: 1000,
        minWidth: 1200,
        minHeight: 700,
        backgroundColor: '#0d0d0d',
        titleBarStyle: process.platform === 'darwin' ? 'hiddenInset' : 'default',
        trafficLightPosition: { x: 12, y: 18 },
        webPreferences: {
            preload: path.join(__dirname, 'preload.js'),
            nodeIntegration: false,
            contextIsolation: true,
            webviewTag: false
        }
    });

    // Load main UI (toolbar)
    mainWindow.loadFile(path.join(__dirname, 'ui', 'index.html'));

    // Create Browser View (REAL CHROMIUM WEBVIEW)
    browserView = new BrowserView({
        webPreferences: {
            nodeIntegration: false,
            contextIsolation: true,
            sandbox: true,
            webSecurity: true
        }
    });
    mainWindow.addBrowserView(browserView);
    
    // Load default page
    browserView.webContents.loadURL('https://www.google.com');

    // Create Chat View
    chatView = new BrowserView({
        webPreferences: {
            preload: path.join(__dirname, 'preload.js'),
            nodeIntegration: false,
            contextIsolation: true
        }
    });
    mainWindow.addBrowserView(chatView);
    chatView.webContents.loadFile(path.join(__dirname, 'ui', 'chat.html'));

    // Create Editor View (Monaco)
    editorView = new BrowserView({
        webPreferences: {
            preload: path.join(__dirname, 'preload.js'),
            nodeIntegration: false,
            contextIsolation: true
        }
    });
    mainWindow.addBrowserView(editorView);
    editorView.webContents.loadFile(path.join(__dirname, 'ui', 'editor.html'));

    // Apply golden ratio layout
    updateLayout();

    // Handle resize
    mainWindow.on('resize', updateLayout);

    // Setup browser events
    setupBrowserEvents();

    // DevTools in dev mode
    if (process.argv.includes('--dev')) {
        mainWindow.webContents.openDevTools({ mode: 'detach' });
    }

    // Log startup
    console.log('╔═══════════════════════════════════════════════════════════════╗');
    console.log('║           VIBEE Browser v1.0.0 - PRODUCTION READY             ║');
    console.log('║                                                               ║');
    console.log('║   φ = ' + PHI.toFixed(15) + '                          ║');
    console.log('║   φ² + 1/φ² = ' + TRINITY.toFixed(1) + ' (TRINITY)                            ║');
    console.log('║                                                               ║');
    console.log('║   Layout: Browser 61.8% | Chat 14.6% | Editor 23.6%          ║');
    console.log('║   PHOENIX = 999                                               ║');
    console.log('╚═══════════════════════════════════════════════════════════════╝');
}

// ═══════════════════════════════════════════════════════════════════════════
// GOLDEN RATIO LAYOUT
// ═══════════════════════════════════════════════════════════════════════════

function updateLayout() {
    if (!mainWindow || !browserView || !chatView || !editorView) return;

    const bounds = mainWindow.getContentBounds();
    const contentHeight = bounds.height - TOOLBAR_HEIGHT - STATUSBAR_HEIGHT;
    
    // Calculate widths using golden ratio
    const browserWidth = Math.floor(bounds.width * BROWSER_RATIO);
    const chatWidth = Math.floor(bounds.width * CHAT_RATIO);
    const editorWidth = bounds.width - browserWidth - chatWidth;

    // Browser View (left - 61.8%)
    browserView.setBounds({
        x: 0,
        y: TOOLBAR_HEIGHT,
        width: browserWidth,
        height: contentHeight
    });

    // Chat View (middle - 14.6%)
    chatView.setBounds({
        x: browserWidth,
        y: TOOLBAR_HEIGHT,
        width: chatWidth,
        height: contentHeight
    });

    // Editor View (right - 23.6%)
    editorView.setBounds({
        x: browserWidth + chatWidth,
        y: TOOLBAR_HEIGHT,
        width: editorWidth,
        height: contentHeight
    });
}

// ═══════════════════════════════════════════════════════════════════════════
// BROWSER EVENTS
// ═══════════════════════════════════════════════════════════════════════════

function setupBrowserEvents() {
    // URL changed
    browserView.webContents.on('did-navigate', (event, url) => {
        mainWindow.webContents.send('url-changed', url);
    });

    browserView.webContents.on('did-navigate-in-page', (event, url) => {
        mainWindow.webContents.send('url-changed', url);
    });

    // Title changed
    browserView.webContents.on('page-title-updated', (event, title) => {
        mainWindow.webContents.send('title-changed', title);
        mainWindow.setTitle(`${title} - VIBEE Browser`);
    });

    // Loading state
    browserView.webContents.on('did-start-loading', () => {
        mainWindow.webContents.send('loading', true);
    });

    browserView.webContents.on('did-stop-loading', () => {
        mainWindow.webContents.send('loading', false);
    });

    // New window (open in same view)
    browserView.webContents.setWindowOpenHandler(({ url }) => {
        browserView.webContents.loadURL(url);
        return { action: 'deny' };
    });
}

// ═══════════════════════════════════════════════════════════════════════════
// IPC HANDLERS - NAVIGATION
// ═══════════════════════════════════════════════════════════════════════════

ipcMain.handle('navigate', async (event, url) => {
    if (!url) return null;
    
    // Smart URL handling
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
        if (url.includes('.') && !url.includes(' ')) {
            url = 'https://' + url;
        } else {
            url = 'https://www.google.com/search?q=' + encodeURIComponent(url);
        }
    }
    
    await browserView.webContents.loadURL(url);
    return url;
});

ipcMain.handle('go-back', () => {
    if (browserView.webContents.canGoBack()) {
        browserView.webContents.goBack();
        return true;
    }
    return false;
});

ipcMain.handle('go-forward', () => {
    if (browserView.webContents.canGoForward()) {
        browserView.webContents.goForward();
        return true;
    }
    return false;
});

ipcMain.handle('reload', () => {
    browserView.webContents.reload();
    return true;
});

ipcMain.handle('stop', () => {
    browserView.webContents.stop();
    return true;
});

ipcMain.handle('get-url', () => {
    return browserView.webContents.getURL();
});

ipcMain.handle('get-title', () => {
    return browserView.webContents.getTitle();
});

ipcMain.handle('can-go-back', () => {
    return browserView.webContents.canGoBack();
});

ipcMain.handle('can-go-forward', () => {
    return browserView.webContents.canGoForward();
});

// ═══════════════════════════════════════════════════════════════════════════
// IPC HANDLERS - CDP / AUTOMATION
// ═══════════════════════════════════════════════════════════════════════════

ipcMain.handle('cdp-send', async (event, method, params = {}) => {
    try {
        const debugger_ = browserView.webContents.debugger;
        if (!debugger_.isAttached()) {
            debugger_.attach('1.3');
        }
        const result = await debugger_.sendCommand(method, params);
        return { success: true, result };
    } catch (error) {
        return { success: false, error: error.message };
    }
});

ipcMain.handle('execute-js', async (event, code) => {
    try {
        const result = await browserView.webContents.executeJavaScript(code);
        return { success: true, result };
    } catch (error) {
        return { success: false, error: error.message };
    }
});

ipcMain.handle('screenshot', async (event, options = {}) => {
    try {
        const image = await browserView.webContents.capturePage();
        const format = options.format || 'png';
        if (format === 'dataurl') {
            return { success: true, data: image.toDataURL() };
        }
        return { success: true, data: image.toPNG().toString('base64') };
    } catch (error) {
        return { success: false, error: error.message };
    }
});

// ═══════════════════════════════════════════════════════════════════════════
// IPC HANDLERS - PAGE CONTENT
// ═══════════════════════════════════════════════════════════════════════════

ipcMain.handle('get-page-content', async () => {
    try {
        const content = await browserView.webContents.executeJavaScript(`
            document.body.innerText
        `);
        return { success: true, content };
    } catch (error) {
        return { success: false, error: error.message };
    }
});

ipcMain.handle('get-page-html', async () => {
    try {
        const html = await browserView.webContents.executeJavaScript(`
            document.documentElement.outerHTML
        `);
        return { success: true, html };
    } catch (error) {
        return { success: false, error: error.message };
    }
});

// ═══════════════════════════════════════════════════════════════════════════
// IPC HANDLERS - AUTOMATION ACTIONS
// ═══════════════════════════════════════════════════════════════════════════

ipcMain.handle('click', async (event, selector) => {
    try {
        await browserView.webContents.executeJavaScript(`
            const el = document.querySelector('${selector}');
            if (el) el.click();
        `);
        return { success: true };
    } catch (error) {
        return { success: false, error: error.message };
    }
});

ipcMain.handle('type', async (event, selector, text) => {
    try {
        await browserView.webContents.executeJavaScript(`
            const el = document.querySelector('${selector}');
            if (el) {
                el.focus();
                el.value = '${text.replace(/'/g, "\\'")}';
                el.dispatchEvent(new Event('input', { bubbles: true }));
            }
        `);
        return { success: true };
    } catch (error) {
        return { success: false, error: error.message };
    }
});

ipcMain.handle('scroll', async (event, x, y) => {
    try {
        await browserView.webContents.executeJavaScript(`
            window.scrollBy(${x}, ${y});
        `);
        return { success: true };
    } catch (error) {
        return { success: false, error: error.message };
    }
});

// ═══════════════════════════════════════════════════════════════════════════
// IPC HANDLERS - GOLDEN RATIO
// ═══════════════════════════════════════════════════════════════════════════

ipcMain.handle('get-phi', () => {
    return {
        phi: PHI,
        phi_squared: PHI_SQUARED,
        phi_inv_squared: PHI_INV_SQUARED,
        trinity: TRINITY,
        phoenix: 999,
        layout: {
            browser: BROWSER_RATIO,
            chat: CHAT_RATIO,
            editor: EDITOR_RATIO
        }
    };
});

// ═══════════════════════════════════════════════════════════════════════════
// IPC HANDLERS - EDITOR
// ═══════════════════════════════════════════════════════════════════════════

ipcMain.handle('editor-set-content', async (event, content, language) => {
    editorView.webContents.send('set-content', { content, language });
    return { success: true };
});

ipcMain.handle('editor-get-content', async () => {
    return new Promise((resolve) => {
        const handler = (event, content) => {
            ipcMain.removeListener('editor-content-response', handler);
            resolve({ success: true, content });
        };
        ipcMain.on('editor-content-response', handler);
        editorView.webContents.send('get-content');
        
        // Timeout
        setTimeout(() => {
            ipcMain.removeListener('editor-content-response', handler);
            resolve({ success: false, error: 'Timeout' });
        }, 5000);
    });
});

// ═══════════════════════════════════════════════════════════════════════════
// IPC HANDLERS - CHAT / LLM
// ═══════════════════════════════════════════════════════════════════════════

ipcMain.handle('chat-send', async (event, message, context) => {
    chatView.webContents.send('user-message', { message, context });
    return { success: true };
});

// ═══════════════════════════════════════════════════════════════════════════
// APP LIFECYCLE
// ═══════════════════════════════════════════════════════════════════════════

app.whenReady().then(() => {
    createWindow();

    app.on('activate', () => {
        if (BrowserWindow.getAllWindows().length === 0) {
            createWindow();
        }
    });
});

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') {
        app.quit();
    }
});

// Security
app.on('web-contents-created', (event, contents) => {
    contents.on('will-navigate', (event, navigationUrl) => {
        // Allow navigation in browser view only
    });
});
