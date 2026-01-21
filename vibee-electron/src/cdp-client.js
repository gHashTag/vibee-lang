/**
 * VIBEE Browser - CDP Client
 * Chrome DevTools Protocol WebSocket client
 * φ² + 1/φ² = 3 | PHOENIX = 999
 */

const WebSocket = require('ws');

class CDPClient {
    constructor() {
        this.ws = null;
        this.messageId = 0;
        this.callbacks = new Map();
        this.eventHandlers = new Map();
    }

    /**
     * Connect to CDP WebSocket
     */
    async connect(wsUrl) {
        return new Promise((resolve, reject) => {
            this.ws = new WebSocket(wsUrl);

            this.ws.on('open', () => {
                console.log('[CDP] Connected to', wsUrl);
                resolve();
            });

            this.ws.on('message', (data) => {
                const message = JSON.parse(data.toString());
                
                if (message.id !== undefined) {
                    // Response to a command
                    const callback = this.callbacks.get(message.id);
                    if (callback) {
                        this.callbacks.delete(message.id);
                        if (message.error) {
                            callback.reject(new Error(message.error.message));
                        } else {
                            callback.resolve(message.result);
                        }
                    }
                } else if (message.method) {
                    // Event
                    const handlers = this.eventHandlers.get(message.method) || [];
                    handlers.forEach(handler => handler(message.params));
                }
            });

            this.ws.on('error', (error) => {
                console.error('[CDP] Error:', error);
                reject(error);
            });

            this.ws.on('close', () => {
                console.log('[CDP] Disconnected');
            });
        });
    }

    /**
     * Send CDP command
     */
    async send(method, params = {}) {
        return new Promise((resolve, reject) => {
            const id = ++this.messageId;
            
            this.callbacks.set(id, { resolve, reject });
            
            const message = JSON.stringify({ id, method, params });
            this.ws.send(message);
        });
    }

    /**
     * Subscribe to CDP event
     */
    on(event, handler) {
        if (!this.eventHandlers.has(event)) {
            this.eventHandlers.set(event, []);
        }
        this.eventHandlers.get(event).push(handler);
    }

    /**
     * Enable CDP domain
     */
    async enableDomain(domain) {
        return this.send(`${domain}.enable`);
    }

    /**
     * Disconnect
     */
    disconnect() {
        if (this.ws) {
            this.ws.close();
            this.ws = null;
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // PAGE DOMAIN
    // ═══════════════════════════════════════════════════════════════════════

    async navigate(url) {
        return this.send('Page.navigate', { url });
    }

    async reload(ignoreCache = false) {
        return this.send('Page.reload', { ignoreCache });
    }

    async getNavigationHistory() {
        return this.send('Page.getNavigationHistory');
    }

    async captureScreenshot(format = 'png', quality = 80) {
        return this.send('Page.captureScreenshot', { format, quality });
    }

    // ═══════════════════════════════════════════════════════════════════════
    // DOM DOMAIN
    // ═══════════════════════════════════════════════════════════════════════

    async getDocument() {
        return this.send('DOM.getDocument');
    }

    async querySelector(nodeId, selector) {
        return this.send('DOM.querySelector', { nodeId, selector });
    }

    async querySelectorAll(nodeId, selector) {
        return this.send('DOM.querySelectorAll', { nodeId, selector });
    }

    async getBoxModel(nodeId) {
        return this.send('DOM.getBoxModel', { nodeId });
    }

    async getOuterHTML(nodeId) {
        return this.send('DOM.getOuterHTML', { nodeId });
    }

    // ═══════════════════════════════════════════════════════════════════════
    // INPUT DOMAIN
    // ═══════════════════════════════════════════════════════════════════════

    async dispatchMouseEvent(type, x, y, button = 'left', clickCount = 1) {
        return this.send('Input.dispatchMouseEvent', {
            type,
            x,
            y,
            button,
            clickCount
        });
    }

    async click(x, y) {
        await this.dispatchMouseEvent('mousePressed', x, y, 'left', 1);
        await this.dispatchMouseEvent('mouseReleased', x, y, 'left', 1);
    }

    async dispatchKeyEvent(type, key, code, text) {
        return this.send('Input.dispatchKeyEvent', {
            type,
            key,
            code,
            text
        });
    }

    async type(text) {
        for (const char of text) {
            await this.send('Input.insertText', { text: char });
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // RUNTIME DOMAIN
    // ═══════════════════════════════════════════════════════════════════════

    async evaluate(expression, returnByValue = true) {
        return this.send('Runtime.evaluate', {
            expression,
            returnByValue
        });
    }

    // ═══════════════════════════════════════════════════════════════════════
    // NETWORK DOMAIN
    // ═══════════════════════════════════════════════════════════════════════

    async setRequestInterception(patterns) {
        return this.send('Fetch.enable', { patterns });
    }

    async continueRequest(requestId) {
        return this.send('Fetch.continueRequest', { requestId });
    }

    async failRequest(requestId, errorReason) {
        return this.send('Fetch.failRequest', { requestId, errorReason });
    }
}

module.exports = { CDPClient };
