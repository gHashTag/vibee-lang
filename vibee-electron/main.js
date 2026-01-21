/**
 * VIBEE Browser - Electron Main Process
 * Full Chromium with Golden Ratio Split View
 * φ² + 1/φ² = 3 | PHOENIX = 999
 */

const { app, BrowserWindow, BrowserView, ipcMain, session } = require('electron');
const path = require('path');

// Golden Ratio Constants
const PHI = 1.618033988749895;
const PHI_SQ = PHI * PHI;           // 2.618...
const PHI_INV_SQ = 1 / PHI_SQ;      // 0.382...
const TRINITY = PHI_SQ + PHI_INV_SQ; // 3.0

// Layout ratios (φ-based)
const BROWSER_RATIO = 0.618;  // 61.8% - Browser
const CHAT_RATIO = 0.146;     // 14.6% - Chat  
const EDITOR_RATIO = 0.236;   // 23.6% - Editor

let mainWindow;
let browserView;
let chatView;
let editorView;

function createWindow() {
    // Main window
    mainWindow = new BrowserWindow({
        width: 1600,
        height: 1000,
        minWidth: 1200,
        minHeight: 700,
        titleBarStyle: 'hiddenInset',
        trafficLightPosition: { x: 12, y: 12 },
        backgroundColor: '#0d0d0d',
        webPreferences: {
            preload: path.join(__dirname, 'preload.js'),
            nodeIntegration: false,
            contextIsolation: true
        }
    });

    // Load main UI (toolbar + status)
    mainWindow.loadFile('renderer/index.html');

    // Create Browser View (61.8% width)
    browserView = new BrowserView({
        webPreferences: {
            nodeIntegration: false,
            contextIsolation: true,
            sandbox: true
        }
    });
    mainWindow.addBrowserView(browserView);
    browserView.webContents.loadURL('https://google.com');

    // Create Chat View (14.6% width)
    chatView = new BrowserView({
        webPreferences: {
            preload: path.join(__dirname, 'preload.js'),
            nodeIntegration: false,
            contextIsolation: true
        }
    });
    mainWindow.addBrowserView(chatView);
    chatView.webContents.loadFile('renderer/chat.html');

    // Create Editor View (23.6% width)
    editorView = new BrowserView({
        webPreferences: {
            preload: path.join(__dirname, 'preload.js'),
            nodeIntegration: false,
            contextIsolation: true
        }
    });
    mainWindow.addBrowserView(editorView);
    editorView.webContents.loadFile('renderer/editor.html');

    // Layout views
    updateLayout();

    // Handle resize
    mainWindow.on('resize', updateLayout);

    // DevTools for debugging
    if (process.argv.includes('--dev')) {
        mainWindow.webContents.openDevTools({ mode: 'detach' });
    }

    console.log('╔═══════════════════════════════════════════════════════════════╗');
    console.log('║  VIBEE Browser v0.0.1 - Full Chromium                         ║');
    console.log('║  φ² + 1/φ² = 3 | PHOENIX = 999                                ║');
    console.log('║  Layout: Browser 61.8% | Chat 14.6% | Editor 23.6%            ║');
    console.log('╚═══════════════════════════════════════════════════════════════╝');
}

function updateLayout() {
    const bounds = mainWindow.getContentBounds();
    const toolbarHeight = 90; // Toolbar + URL bar
    const statusHeight = 24;  // Status bar
    const contentHeight = bounds.height - toolbarHeight - statusHeight;
    
    const browserWidth = Math.floor(bounds.width * BROWSER_RATIO);
    const chatWidth = Math.floor(bounds.width * CHAT_RATIO);
    const editorWidth = bounds.width - browserWidth - chatWidth;

    // Browser View (left)
    browserView.setBounds({
        x: 0,
        y: toolbarHeight,
        width: browserWidth,
        height: contentHeight
    });

    // Chat View (middle)
    chatView.setBounds({
        x: browserWidth,
        y: toolbarHeight,
        width: chatWidth,
        height: contentHeight
    });

    // Editor View (right)
    editorView.setBounds({
        x: browserWidth + chatWidth,
        y: toolbarHeight,
        width: editorWidth,
        height: contentHeight
    });
}

// IPC Handlers
ipcMain.handle('navigate', async (event, url) => {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
        if (url.includes('.') && !url.includes(' ')) {
            url = 'https://' + url;
        } else {
            url = 'https://www.google.com/search?q=' + encodeURIComponent(url);
        }
    }
    browserView.webContents.loadURL(url);
    return url;
});

ipcMain.handle('go-back', () => {
    if (browserView.webContents.canGoBack()) {
        browserView.webContents.goBack();
    }
});

ipcMain.handle('go-forward', () => {
    if (browserView.webContents.canGoForward()) {
        browserView.webContents.goForward();
    }
});

ipcMain.handle('reload', () => {
    browserView.webContents.reload();
});

ipcMain.handle('get-url', () => {
    return browserView.webContents.getURL();
});

ipcMain.handle('get-title', () => {
    return browserView.webContents.getTitle();
});

ipcMain.handle('get-phi', () => {
    return {
        phi: PHI,
        phi_squared: PHI_SQ,
        phi_inv_squared: PHI_INV_SQ,
        trinity: TRINITY,
        phoenix: 999
    };
});

// CDP Access for AI agents
ipcMain.handle('cdp-send', async (event, method, params) => {
    const debugger_ = browserView.webContents.debugger;
    try {
        debugger_.attach('1.3');
        const result = await debugger_.sendCommand(method, params || {});
        debugger_.detach();
        return result;
    } catch (e) {
        return { error: e.message };
    }
});

// Execute JS in browser
ipcMain.handle('execute-js', async (event, code) => {
    return browserView.webContents.executeJavaScript(code);
});

// Screenshot
ipcMain.handle('screenshot', async () => {
    const image = await browserView.webContents.capturePage();
    return image.toDataURL();
});

// URL change events
function setupBrowserEvents() {
    browserView.webContents.on('did-navigate', (event, url) => {
        mainWindow.webContents.send('url-changed', url);
    });
    
    browserView.webContents.on('did-navigate-in-page', (event, url) => {
        mainWindow.webContents.send('url-changed', url);
    });
    
    browserView.webContents.on('page-title-updated', (event, title) => {
        mainWindow.webContents.send('title-changed', title);
    });
    
    browserView.webContents.on('did-start-loading', () => {
        mainWindow.webContents.send('loading-started');
    });
    
    browserView.webContents.on('did-stop-loading', () => {
        mainWindow.webContents.send('loading-stopped');
    });
}

app.whenReady().then(() => {
    createWindow();
    setupBrowserEvents();
    
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
