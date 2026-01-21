/**
 * VIBEE Browser - Preload Script
 * Secure IPC bridge between renderer and main process
 * φ² + 1/φ² = 3 | PHOENIX = 999
 */

const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('vibee', {
    // ═══════════════════════════════════════════════════════════════════════
    // NAVIGATION
    // ═══════════════════════════════════════════════════════════════════════
    navigate: (url) => ipcRenderer.invoke('navigate', url),
    goBack: () => ipcRenderer.invoke('go-back'),
    goForward: () => ipcRenderer.invoke('go-forward'),
    reload: () => ipcRenderer.invoke('reload'),
    stop: () => ipcRenderer.invoke('stop'),
    getUrl: () => ipcRenderer.invoke('get-url'),
    getTitle: () => ipcRenderer.invoke('get-title'),
    canGoBack: () => ipcRenderer.invoke('can-go-back'),
    canGoForward: () => ipcRenderer.invoke('can-go-forward'),

    // ═══════════════════════════════════════════════════════════════════════
    // CDP / AUTOMATION
    // ═══════════════════════════════════════════════════════════════════════
    cdpSend: (method, params) => ipcRenderer.invoke('cdp-send', method, params),
    executeJs: (code) => ipcRenderer.invoke('execute-js', code),
    screenshot: (options) => ipcRenderer.invoke('screenshot', options),
    
    // ═══════════════════════════════════════════════════════════════════════
    // PAGE CONTENT
    // ═══════════════════════════════════════════════════════════════════════
    getPageContent: () => ipcRenderer.invoke('get-page-content'),
    getPageHtml: () => ipcRenderer.invoke('get-page-html'),

    // ═══════════════════════════════════════════════════════════════════════
    // AUTOMATION ACTIONS
    // ═══════════════════════════════════════════════════════════════════════
    click: (selector) => ipcRenderer.invoke('click', selector),
    type: (selector, text) => ipcRenderer.invoke('type', selector, text),
    scroll: (x, y) => ipcRenderer.invoke('scroll', x, y),

    // ═══════════════════════════════════════════════════════════════════════
    // GOLDEN RATIO
    // ═══════════════════════════════════════════════════════════════════════
    getPhi: () => ipcRenderer.invoke('get-phi'),

    // ═══════════════════════════════════════════════════════════════════════
    // EDITOR
    // ═══════════════════════════════════════════════════════════════════════
    editorSetContent: (content, language) => ipcRenderer.invoke('editor-set-content', content, language),
    editorGetContent: () => ipcRenderer.invoke('editor-get-content'),

    // ═══════════════════════════════════════════════════════════════════════
    // CHAT
    // ═══════════════════════════════════════════════════════════════════════
    chatSend: (message, context) => ipcRenderer.invoke('chat-send', message, context),

    // ═══════════════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════════════
    onUrlChanged: (callback) => ipcRenderer.on('url-changed', (_, url) => callback(url)),
    onTitleChanged: (callback) => ipcRenderer.on('title-changed', (_, title) => callback(title)),
    onLoading: (callback) => ipcRenderer.on('loading', (_, loading) => callback(loading)),
    onSetContent: (callback) => ipcRenderer.on('set-content', (_, data) => callback(data)),
    onGetContent: (callback) => ipcRenderer.on('get-content', () => callback()),
    onUserMessage: (callback) => ipcRenderer.on('user-message', (_, data) => callback(data)),
    
    // Send content back to main
    sendEditorContent: (content) => ipcRenderer.send('editor-content-response', content)
});
