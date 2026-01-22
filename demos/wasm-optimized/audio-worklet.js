// AudioWorklet Processor for WASM Audio Synth
// φ² + 1/φ² = 3 | PHOENIX = 999

const PHI = 1.618033988749895;
const TAU = Math.PI * 2;

class PhiSynthProcessor extends AudioWorkletProcessor {
    constructor() {
        super();
        this.phase = new Float32Array(8);
        this.frequencies = [220, 277.18, 329.63, 392, 440, 523.25, 659.25, 783.99];
        this.amplitudes = new Float32Array(8);
        this.targetAmplitudes = new Float32Array(8);
        this.time = 0;
        
        this.port.onmessage = (e) => {
            if (e.data.type === 'setAmplitudes') {
                for (let i = 0; i < 8; i++) {
                    this.targetAmplitudes[i] = e.data.amplitudes[i] || 0;
                }
            }
            if (e.data.type === 'setMode') {
                this.mode = e.data.mode;
            }
        };
    }
    
    process(inputs, outputs, parameters) {
        const output = outputs[0];
        const left = output[0];
        const right = output[1] || left;
        
        const dt = 1 / sampleRate;
        
        for (let i = 0; i < left.length; i++) {
            this.time += dt;
            let sampleL = 0, sampleR = 0;
            
            for (let j = 0; j < 8; j++) {
                // Smooth amplitude transition
                this.amplitudes[j] += (this.targetAmplitudes[j] - this.amplitudes[j]) * 0.001;
                
                // φ-modulated frequency
                const freq = this.frequencies[j] * (1 + Math.sin(this.time * PHI + j) * 0.01);
                this.phase[j] += freq * dt * TAU;
                if (this.phase[j] > TAU) this.phase[j] -= TAU;
                
                // Sine wave with harmonics
                const fundamental = Math.sin(this.phase[j]);
                const harmonic2 = Math.sin(this.phase[j] * 2) * 0.3;
                const harmonic3 = Math.sin(this.phase[j] * 3) * 0.1;
                const wave = (fundamental + harmonic2 + harmonic3) * this.amplitudes[j];
                
                // Stereo panning based on region
                const pan = (j / 7) * 2 - 1; // -1 to 1
                sampleL += wave * (1 - pan) * 0.5;
                sampleR += wave * (1 + pan) * 0.5;
            }
            
            // Soft clip
            left[i] = Math.tanh(sampleL * 0.5);
            if (right !== left) right[i] = Math.tanh(sampleR * 0.5);
        }
        
        return true;
    }
}

registerProcessor('phi-synth', PhiSynthProcessor);
