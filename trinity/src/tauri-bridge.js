/**
 * TRINITY v24.φ - Tauri Bridge
 * JavaScript interface for native Rust φ-computations
 * 
 * @version 24.φ
 */

const PHI = 1.618033988749895;
const PHI_INV = 0.618033988749895;
const PHI_SQ = 2.618033988749895;
const TRINITY = 3.0;

const isTauri = () => typeof window !== 'undefined' && window.__TAURI__ !== undefined;

class TauriBridge {
    constructor() {
        this.isNative = isTauri();
        this.invoke = this.isNative ? window.__TAURI__.invoke : null;
        this.cache = new Map();
        
        console.log(this.isNative ? '🦀 TRINITY: Native Tauri mode' : '🌐 TRINITY: Web mode');
    }
    
    async getPhiConstants() {
        if (this.isNative) {
            try { return await this.invoke('get_phi_constants'); }
            catch (e) { console.warn('Native call failed:', e); }
        }
        return { PHI, PHI_INV, PHI_SQ, TRINITY, PHI_CUBED: PHI ** 3 };
    }
    
    async phiPower(n) {
        if (this.isNative) {
            try { return await this.invoke('phi_power', { n }); }
            catch (e) { console.warn('Native call failed:', e); }
        }
        const cacheKey = `phi_${n}`;
        if (this.cache.has(cacheKey)) {
            return { value: this.cache.get(cacheKey), cached: true };
        }
        const value = PHI ** n;
        this.cache.set(cacheKey, value);
        return { value, cached: false };
    }
    
    async fibonacci(n) {
        if (this.isNative) {
            try { return await this.invoke('fibonacci_phi', { n }); }
            catch (e) { console.warn('Native call failed:', e); }
        }
        const sqrt5 = Math.sqrt(5);
        const psi = -PHI_INV;
        return Math.round((PHI ** n - psi ** n) / sqrt5);
    }
    
    async lucas(n) {
        if (this.isNative) {
            try { return await this.invoke('lucas_phi', { n }); }
            catch (e) { console.warn('Native call failed:', e); }
        }
        const psi = -PHI_INV;
        return Math.round(PHI ** n + psi ** n);
    }
    
    async phiSpiral(n, scale = 1) {
        if (this.isNative) {
            try { return await this.invoke('phi_spiral', { n, scale }); }
            catch (e) { console.warn('Native call failed:', e); }
        }
        const points = [];
        for (let i = 0; i < n; i++) {
            const angle = i * Math.PI * 2 * PHI_INV;
            const radius = scale * PHI ** (i * 0.1);
            points.push([radius * Math.cos(angle), radius * Math.sin(angle)]);
        }
        return points;
    }
    
    async verifyTrinity() {
        if (this.isNative) {
            try { return await this.invoke('verify_trinity'); }
            catch (e) { console.warn('Native call failed:', e); }
        }
        const phiSq = PHI * PHI;
        const phiInvSq = 1 / (PHI * PHI);
        const sum = phiSq + phiInvSq;
        return { phi_squared: phiSq, phi_inv_squared: phiInvSq, sum, expected: TRINITY, verified: Math.abs(sum - TRINITY) < 1e-10 };
    }
    
    async benchmark(iterations = 100000) {
        if (this.isNative) {
            try { return await this.invoke('benchmark_phi', { iterations }); }
            catch (e) { console.warn('Native benchmark failed:', e); }
        }
        
        let start = performance.now();
        let sum = 0;
        for (let i = 0; i < iterations; i++) sum += PHI ** (i % 100);
        const phiTime = (performance.now() - start) * 1e6 / iterations;
        
        return {
            iterations,
            phi_power_ns: phiTime,
            phi_power_ops_sec: 1e9 / phiTime,
            mode: 'javascript'
        };
    }
    
    async getSystemInfo() {
        if (this.isNative) {
            try { return await this.invoke('get_system_info'); }
            catch (e) { console.warn('Native call failed:', e); }
        }
        return { os: navigator.platform, trinity_version: '24.φ', phi_optimized: true };
    }
    
    async saveDocument(document) {
        if (this.isNative) {
            const { save } = window.__TAURI__.dialog;
            const path = await save({ filters: [{ name: 'TRINITY', extensions: ['trinity'] }] });
            if (path) {
                await this.invoke('save_document', { path, document: { version: '24.φ', phi_constant: PHI, ...document } });
                return { success: true, path };
            }
        }
        const blob = new Blob([JSON.stringify({ version: '24.φ', phi_constant: PHI, ...document }, null, 2)]);
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url; a.download = 'document.trinity'; a.click();
        URL.revokeObjectURL(url);
        return { success: true };
    }
    
    async loadDocument() {
        if (this.isNative) {
            const { open } = window.__TAURI__.dialog;
            const path = await open({ filters: [{ name: 'TRINITY', extensions: ['trinity', 'json'] }] });
            if (path) return { success: true, document: await this.invoke('load_document', { path }) };
        }
        return new Promise(resolve => {
            const input = document.createElement('input');
            input.type = 'file'; input.accept = '.trinity,.json';
            input.onchange = async e => {
                const file = e.target.files[0];
                if (file) resolve({ success: true, document: JSON.parse(await file.text()) });
                else resolve({ success: false });
            };
            input.click();
        });
    }
}

const tauriBridge = new TauriBridge();

if (typeof window !== 'undefined') {
    window.TrinityTauri = { bridge: tauriBridge, isTauri, PHI, PHI_INV, PHI_SQ, TRINITY };
}

export { TauriBridge, tauriBridge, isTauri, PHI, PHI_INV, PHI_SQ, TRINITY };
