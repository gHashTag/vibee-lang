// PhotoReal Diffusion Engine - Based on DDPM/DiT research
// Forward: x_t = √ᾱ_t·x_0 + √(1-ᾱ_t)·ε
// Reverse: x_{t-1} = (1/√α_t)(x_t - (1-α_t)/√(1-ᾱ_t)·ε_θ) + σ_t·z

export class DiffusionEngine {
  private steps: number;
  private betas: Float32Array;
  private alphas: Float32Array;
  private alphasCumprod: Float32Array;
  
  constructor(steps = 50) {
    this.steps = steps;
    this.betas = this.cosineSchedule(steps);
    this.alphas = new Float32Array(steps);
    this.alphasCumprod = new Float32Array(steps);
    
    let cumprod = 1;
    for (let i = 0; i < steps; i++) {
      this.alphas[i] = 1 - this.betas[i];
      cumprod *= this.alphas[i];
      this.alphasCumprod[i] = cumprod;
    }
  }
  
  // Cosine schedule (improved over linear)
  private cosineSchedule(steps: number): Float32Array {
    const betas = new Float32Array(steps);
    const s = 0.008;
    for (let i = 0; i < steps; i++) {
      const t1 = i / steps;
      const t2 = (i + 1) / steps;
      const a1 = Math.cos((t1 + s) / (1 + s) * Math.PI / 2) ** 2;
      const a2 = Math.cos((t2 + s) / (1 + s) * Math.PI / 2) ** 2;
      betas[i] = Math.min(1 - a2 / a1, 0.999);
    }
    return betas;
  }
  
  // Forward diffusion q(x_t|x_0)
  forward(x0: Float32Array, t: number, noise?: Float32Array): Float32Array {
    const n = x0.length;
    noise = noise || this.randn(n);
    const sqrtAlpha = Math.sqrt(this.alphasCumprod[t]);
    const sqrtOneMinusAlpha = Math.sqrt(1 - this.alphasCumprod[t]);
    
    const xt = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      xt[i] = sqrtAlpha * x0[i] + sqrtOneMinusAlpha * noise[i];
    }
    return xt;
  }
  
  // Single reverse step
  reverseStep(xt: Float32Array, t: number, predictedNoise: Float32Array): Float32Array {
    const n = xt.length;
    const alpha = this.alphas[t];
    const alphaCumprod = this.alphasCumprod[t];
    const beta = this.betas[t];
    
    const coef1 = 1 / Math.sqrt(alpha);
    const coef2 = (1 - alpha) / Math.sqrt(1 - alphaCumprod);
    
    const mean = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      mean[i] = coef1 * (xt[i] - coef2 * predictedNoise[i]);
    }
    
    if (t > 0) {
      const sigma = Math.sqrt(beta);
      const z = this.randn(n);
      for (let i = 0; i < n; i++) {
        mean[i] += sigma * z[i];
      }
    }
    return mean;
  }
  
  private randn(n: number): Float32Array {
    const arr = new Float32Array(n);
    for (let i = 0; i < n; i += 2) {
      const u1 = Math.random(), u2 = Math.random();
      const r = Math.sqrt(-2 * Math.log(u1));
      arr[i] = r * Math.cos(2 * Math.PI * u2);
      if (i + 1 < n) arr[i + 1] = r * Math.sin(2 * Math.PI * u2);
    }
    return arr;
  }
}

// Simple U-Net style noise predictor
export class NoisePredictor {
  private weights: Float32Array[];
  
  constructor(dim: number) {
    this.weights = [
      this.initWeights(dim, dim * 2),
      this.initWeights(dim * 2, dim * 2),
      this.initWeights(dim * 2, dim)
    ];
  }
  
  private initWeights(inDim: number, outDim: number): Float32Array {
    const w = new Float32Array(inDim * outDim);
    const scale = Math.sqrt(2 / inDim);
    for (let i = 0; i < w.length; i++) {
      w[i] = (Math.random() - 0.5) * scale;
    }
    return w;
  }
  
  predict(x: Float32Array, t: number, steps: number): Float32Array {
    // Time embedding
    const tEmbed = Math.sin(t / steps * Math.PI);
    
    // Simple forward pass with time conditioning
    let h = new Float32Array(x.length * 2);
    for (let i = 0; i < x.length; i++) {
      h[i] = Math.tanh(x[i] + tEmbed);
      h[i + x.length] = Math.tanh(x[i] * tEmbed);
    }
    
    // Output layer
    const out = new Float32Array(x.length);
    for (let i = 0; i < x.length; i++) {
      out[i] = h[i] - h[i + x.length];
    }
    return out;
  }
}

// Visual diffusion demo for canvas
export function createDiffusionDemo(width: number, height: number) {
  const engine = new DiffusionEngine(30);
  const predictor = new NoisePredictor(width * height * 4);
  
  return {
    // Generate noise -> image animation
    async *generate(targetImage: ImageData): AsyncGenerator<ImageData> {
      const n = width * height * 4;
      let x = new Float32Array(n);
      
      // Start from noise
      for (let i = 0; i < n; i++) {
        x[i] = (Math.random() - 0.5) * 2;
      }
      
      // Reverse diffusion
      for (let t = 29; t >= 0; t--) {
        const noise = predictor.predict(x, t, 30);
        x = engine.reverseStep(x, t, noise);
        
        // Blend with target for guided generation
        const alpha = 1 - t / 30;
        for (let i = 0; i < n; i++) {
          x[i] = x[i] * (1 - alpha * 0.1) + (targetImage.data[i] / 255 - 0.5) * alpha * 0.1;
        }
        
        // Convert to ImageData
        const img = new ImageData(width, height);
        for (let i = 0; i < n; i++) {
          img.data[i] = Math.max(0, Math.min(255, (x[i] + 0.5) * 255));
        }
        yield img;
      }
    }
  };
}
