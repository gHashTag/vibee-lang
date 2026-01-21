/**
 * VIBEE Browser - Preload Script
 * Secure bridge between renderer and main process
 */

const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('vibee', {
    // Navigation
    navigate: (url) => ipcRenderer.invoke('navigate', url),
    goBack: () => ipcRenderer.invoke('go-back'),
    goForward: () => ipcRenderer.invoke('go-forward'),
    reload: () => ipcRenderer.invoke('reload'),
    getUrl: () => ipcRenderer.invoke('get-url'),
    getTitle: () => ipcRenderer.invoke('get-title'),
    
    // Sacred constants
    getPhi: () => ipcRenderer.invoke('get-phi'),
    
    // CDP for AI agents
    cdpSend: (method, params) => ipcRenderer.invoke('cdp-send', method, params),
    
    // Execute JS in browser
    executeJs: (code) => ipcRenderer.invoke('execute-js', code),
    
    // Screenshot
    screenshot: () => ipcRenderer.invoke('screenshot'),
    
    // Events
    onUrlChanged: (callback) => ipcRenderer.on('url-changed', (_, url) => callback(url)),
    onTitleChanged: (callback) => ipcRenderer.on('title-changed', (_, title) => callback(title)),
    onLoadingStarted: (callback) => ipcRenderer.on('loading-started', () => callback()),
    onLoadingStopped: (callback) => ipcRenderer.on('loading-stopped', () => callback())
});
