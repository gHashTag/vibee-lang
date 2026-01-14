// Advanced GPU Particle System with Physics
// Supports millions of particles via transform feedback

export interface Particle {
  x: number; y: number; z: number;
  vx: number; vy: number; vz: number;
  life: number;
  size: number;
  color: [number, number, number];
}

export class ParticleSystem {
  private gl: WebGL2RenderingContext;
  private maxParticles: number;
  private particleCount = 0;
  
  // Double-buffered VAOs for transform feedback
  private vaos: [WebGLVertexArrayObject, WebGLVertexArrayObject];
  private buffers: [WebGLBuffer, WebGLBuffer];
  private currentBuffer = 0;
  
  private updateProgram: WebGLProgram;
  private renderProgram: WebGLProgram;
  private transformFeedback: WebGLTransformFeedback;
  
  // Emitters
  private emitters: ParticleEmitter[] = [];
  
  // Forces
  private gravity = [0, -9.8, 0];
  private wind = [0, 0, 0];
  private attractors: Attractor[] = [];
  
  constructor(gl: WebGL2RenderingContext, maxParticles = 100000) {
    this.gl = gl;
    this.maxParticles = maxParticles;
    
    this.updateProgram = this.createUpdateProgram();
    this.renderProgram = this.createRenderProgram();
    this.transformFeedback = gl.createTransformFeedback()!;
    
    this.vaos = [gl.createVertexArray()!, gl.createVertexArray()!];
    this.buffers = [gl.createBuffer()!, gl.createBuffer()!];
    
    this.initBuffers();
  }
  
  private createUpdateProgram(): WebGLProgram {
    const gl = this.gl;
    
    const vertSrc = `#version 300 es
    layout(location=0) in vec3 aPos;
    layout(location=1) in vec3 aVel;
    layout(location=2) in float aLife;
    layout(location=3) in float aSize;
    layout(location=4) in vec3 aColor;
    
    out vec3 vPos;
    out vec3 vVel;
    out float vLife;
    out float vSize;
    out vec3 vColor;
    
    uniform float uDt;
    uniform vec3 uGravity;
    uniform vec3 uWind;
    uniform vec4 uAttractors[8]; // xyz = pos, w = strength
    uniform int uAttractorCount;
    uniform float uTime;
    
    // Noise function for turbulence
    float hash(vec3 p) {
      p = fract(p * 0.3183099 + 0.1);
      p *= 17.0;
      return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
    }
    
    vec3 noise3D(vec3 p) {
      vec3 i = floor(p);
      vec3 f = fract(p);
      f = f * f * (3.0 - 2.0 * f);
      
      return vec3(
        mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x),
            mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
        mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
            mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y),
        hash(i + f)
      ) * 2.0 - 1.0;
    }
    
    void main() {
      if(aLife <= 0.0) {
        // Dead particle - pass through
        vPos = aPos;
        vVel = vec3(0.0);
        vLife = 0.0;
        vSize = 0.0;
        vColor = aColor;
        return;
      }
      
      vec3 force = uGravity + uWind;
      
      // Attractors
      for(int i = 0; i < uAttractorCount; i++) {
        vec3 toAttractor = uAttractors[i].xyz - aPos;
        float dist = length(toAttractor);
        if(dist > 0.1) {
          force += normalize(toAttractor) * uAttractors[i].w / (dist * dist);
        }
      }
      
      // Turbulence
      vec3 turb = noise3D(aPos * 2.0 + uTime) * 5.0;
      force += turb;
      
      // Curl noise for swirling motion
      float eps = 0.01;
      vec3 curl;
      curl.x = noise3D(aPos + vec3(0, eps, 0)).z - noise3D(aPos - vec3(0, eps, 0)).z
             - noise3D(aPos + vec3(0, 0, eps)).y + noise3D(aPos - vec3(0, 0, eps)).y;
      curl.y = noise3D(aPos + vec3(0, 0, eps)).x - noise3D(aPos - vec3(0, 0, eps)).x
             - noise3D(aPos + vec3(eps, 0, 0)).z + noise3D(aPos - vec3(eps, 0, 0)).z;
      curl.z = noise3D(aPos + vec3(eps, 0, 0)).y - noise3D(aPos - vec3(eps, 0, 0)).y
             - noise3D(aPos + vec3(0, eps, 0)).x + noise3D(aPos - vec3(0, eps, 0)).x;
      force += curl * 3.0;
      
      // Integration (Verlet-like)
      vec3 newVel = aVel + force * uDt;
      newVel *= 0.99; // Drag
      vec3 newPos = aPos + newVel * uDt;
      
      // Bounce off ground
      if(newPos.y < 0.0) {
        newPos.y = 0.0;
        newVel.y *= -0.5;
        newVel.xz *= 0.8;
      }
      
      vPos = newPos;
      vVel = newVel;
      vLife = aLife - uDt * 0.5;
      vSize = aSize * (0.5 + 0.5 * vLife);
      vColor = aColor;
    }`;
    
    const fragSrc = `#version 300 es
    precision highp float;
    void main() { discard; }`;
    
    const prog = this.compileProgram(vertSrc, fragSrc, ['vPos', 'vVel', 'vLife', 'vSize', 'vColor']);
    return prog;
  }
  
  private createRenderProgram(): WebGLProgram {
    const gl = this.gl;
    
    const vertSrc = `#version 300 es
    layout(location=0) in vec3 aPos;
    layout(location=1) in vec3 aVel;
    layout(location=2) in float aLife;
    layout(location=3) in float aSize;
    layout(location=4) in vec3 aColor;
    
    uniform mat4 uMVP;
    uniform vec2 uScreenSize;
    
    out vec3 vColor;
    out float vLife;
    out float vSpeed;
    
    void main() {
      if(aLife <= 0.0) {
        gl_Position = vec4(2.0, 2.0, 2.0, 1.0); // Off screen
        gl_PointSize = 0.0;
        return;
      }
      
      vec4 clipPos = uMVP * vec4(aPos, 1.0);
      gl_Position = clipPos;
      
      // Size attenuation
      float dist = clipPos.w;
      gl_PointSize = aSize * uScreenSize.y / dist;
      gl_PointSize = clamp(gl_PointSize, 1.0, 64.0);
      
      vColor = aColor;
      vLife = aLife;
      vSpeed = length(aVel);
    }`;
    
    const fragSrc = `#version 300 es
    precision highp float;
    
    in vec3 vColor;
    in float vLife;
    in float vSpeed;
    
    out vec4 fragColor;
    
    void main() {
      vec2 cxy = 2.0 * gl_PointCoord - 1.0;
      float r2 = dot(cxy, cxy);
      
      if(r2 > 1.0) discard;
      
      // Soft circle with glow
      float alpha = exp(-r2 * 2.0) * vLife;
      
      // Color based on speed and life
      vec3 col = vColor;
      col = mix(col, vec3(1.0, 0.8, 0.4), vSpeed * 0.05);
      col += vec3(1.0, 0.9, 0.7) * exp(-r2 * 8.0) * 0.5; // Hot core
      
      // HDR output
      fragColor = vec4(col * 2.0, alpha);
    }`;
    
    return this.compileProgram(vertSrc, fragSrc);
  }
  
  private compileProgram(vertSrc: string, fragSrc: string, varyings?: string[]): WebGLProgram {
    const gl = this.gl;
    
    const vert = gl.createShader(gl.VERTEX_SHADER)!;
    gl.shaderSource(vert, vertSrc);
    gl.compileShader(vert);
    if (!gl.getShaderParameter(vert, gl.COMPILE_STATUS)) {
      console.error('Vertex:', gl.getShaderInfoLog(vert));
    }
    
    const frag = gl.createShader(gl.FRAGMENT_SHADER)!;
    gl.shaderSource(frag, fragSrc);
    gl.compileShader(frag);
    if (!gl.getShaderParameter(frag, gl.COMPILE_STATUS)) {
      console.error('Fragment:', gl.getShaderInfoLog(frag));
    }
    
    const prog = gl.createProgram()!;
    gl.attachShader(prog, vert);
    gl.attachShader(prog, frag);
    
    if (varyings) {
      gl.transformFeedbackVaryings(prog, varyings, gl.INTERLEAVED_ATTRIBS);
    }
    
    gl.linkProgram(prog);
    return prog;
  }
  
  private initBuffers() {
    const gl = this.gl;
    const stride = (3 + 3 + 1 + 1 + 3) * 4; // pos, vel, life, size, color
    
    for (let i = 0; i < 2; i++) {
      gl.bindVertexArray(this.vaos[i]);
      gl.bindBuffer(gl.ARRAY_BUFFER, this.buffers[i]);
      gl.bufferData(gl.ARRAY_BUFFER, this.maxParticles * stride, gl.DYNAMIC_DRAW);
      
      // Position
      gl.enableVertexAttribArray(0);
      gl.vertexAttribPointer(0, 3, gl.FLOAT, false, stride, 0);
      // Velocity
      gl.enableVertexAttribArray(1);
      gl.vertexAttribPointer(1, 3, gl.FLOAT, false, stride, 12);
      // Life
      gl.enableVertexAttribArray(2);
      gl.vertexAttribPointer(2, 1, gl.FLOAT, false, stride, 24);
      // Size
      gl.enableVertexAttribArray(3);
      gl.vertexAttribPointer(3, 1, gl.FLOAT, false, stride, 28);
      // Color
      gl.enableVertexAttribArray(4);
      gl.vertexAttribPointer(4, 3, gl.FLOAT, false, stride, 32);
    }
  }
  
  addEmitter(emitter: ParticleEmitter) {
    this.emitters.push(emitter);
  }
  
  addAttractor(x: number, y: number, z: number, strength: number) {
    this.attractors.push({ x, y, z, strength });
  }
  
  setGravity(x: number, y: number, z: number) {
    this.gravity = [x, y, z];
  }
  
  setWind(x: number, y: number, z: number) {
    this.wind = [x, y, z];
  }
  
  emit(count: number, emitter: ParticleEmitter) {
    const gl = this.gl;
    const stride = (3 + 3 + 1 + 1 + 3);
    const data = new Float32Array(count * stride);
    
    for (let i = 0; i < count; i++) {
      const offset = i * stride;
      const particle = emitter.emit();
      
      data[offset + 0] = particle.x;
      data[offset + 1] = particle.y;
      data[offset + 2] = particle.z;
      data[offset + 3] = particle.vx;
      data[offset + 4] = particle.vy;
      data[offset + 5] = particle.vz;
      data[offset + 6] = particle.life;
      data[offset + 7] = particle.size;
      data[offset + 8] = particle.color[0];
      data[offset + 9] = particle.color[1];
      data[offset + 10] = particle.color[2];
    }
    
    gl.bindBuffer(gl.ARRAY_BUFFER, this.buffers[this.currentBuffer]);
    gl.bufferSubData(gl.ARRAY_BUFFER, this.particleCount * stride * 4, data);
    this.particleCount = Math.min(this.particleCount + count, this.maxParticles);
  }
  
  update(dt: number, time: number) {
    const gl = this.gl;
    
    // Emit from all emitters
    for (const emitter of this.emitters) {
      const count = Math.floor(emitter.rate * dt);
      if (count > 0) {
        this.emit(count, emitter);
      }
    }
    
    // Transform feedback update
    gl.useProgram(this.updateProgram);
    
    gl.uniform1f(gl.getUniformLocation(this.updateProgram, 'uDt'), dt);
    gl.uniform1f(gl.getUniformLocation(this.updateProgram, 'uTime'), time);
    gl.uniform3fv(gl.getUniformLocation(this.updateProgram, 'uGravity'), this.gravity);
    gl.uniform3fv(gl.getUniformLocation(this.updateProgram, 'uWind'), this.wind);
    
    // Set attractors
    const attractorData = new Float32Array(32);
    for (let i = 0; i < Math.min(this.attractors.length, 8); i++) {
      const a = this.attractors[i];
      attractorData[i * 4 + 0] = a.x;
      attractorData[i * 4 + 1] = a.y;
      attractorData[i * 4 + 2] = a.z;
      attractorData[i * 4 + 3] = a.strength;
    }
    gl.uniform4fv(gl.getUniformLocation(this.updateProgram, 'uAttractors'), attractorData);
    gl.uniform1i(gl.getUniformLocation(this.updateProgram, 'uAttractorCount'), this.attractors.length);
    
    // Bind source VAO
    gl.bindVertexArray(this.vaos[this.currentBuffer]);
    
    // Bind destination buffer for transform feedback
    const nextBuffer = 1 - this.currentBuffer;
    gl.bindTransformFeedback(gl.TRANSFORM_FEEDBACK, this.transformFeedback);
    gl.bindBufferBase(gl.TRANSFORM_FEEDBACK_BUFFER, 0, this.buffers[nextBuffer]);
    
    // Disable rasterization
    gl.enable(gl.RASTERIZER_DISCARD);
    
    // Run update
    gl.beginTransformFeedback(gl.POINTS);
    gl.drawArrays(gl.POINTS, 0, this.particleCount);
    gl.endTransformFeedback();
    
    gl.disable(gl.RASTERIZER_DISCARD);
    gl.bindTransformFeedback(gl.TRANSFORM_FEEDBACK, null);
    
    // Swap buffers
    this.currentBuffer = nextBuffer;
  }
  
  render(mvp: Float32Array, screenWidth: number, screenHeight: number) {
    const gl = this.gl;
    
    gl.useProgram(this.renderProgram);
    gl.uniformMatrix4fv(gl.getUniformLocation(this.renderProgram, 'uMVP'), false, mvp);
    gl.uniform2f(gl.getUniformLocation(this.renderProgram, 'uScreenSize'), screenWidth, screenHeight);
    
    gl.enable(gl.BLEND);
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE); // Additive blending
    gl.depthMask(false);
    
    gl.bindVertexArray(this.vaos[this.currentBuffer]);
    gl.drawArrays(gl.POINTS, 0, this.particleCount);
    
    gl.depthMask(true);
    gl.disable(gl.BLEND);
  }
}

interface Attractor {
  x: number; y: number; z: number;
  strength: number;
}

export class ParticleEmitter {
  x: number; y: number; z: number;
  rate: number; // particles per second
  spread: number;
  speed: number;
  speedVariance: number;
  life: number;
  lifeVariance: number;
  size: number;
  sizeVariance: number;
  color: [number, number, number];
  colorVariance: number;
  direction: [number, number, number];
  
  constructor(options: Partial<ParticleEmitter> = {}) {
    this.x = options.x ?? 0;
    this.y = options.y ?? 0;
    this.z = options.z ?? 0;
    this.rate = options.rate ?? 1000;
    this.spread = options.spread ?? 0.5;
    this.speed = options.speed ?? 5;
    this.speedVariance = options.speedVariance ?? 2;
    this.life = options.life ?? 2;
    this.lifeVariance = options.lifeVariance ?? 0.5;
    this.size = options.size ?? 10;
    this.sizeVariance = options.sizeVariance ?? 5;
    this.color = options.color ?? [1, 0.5, 0.2];
    this.colorVariance = options.colorVariance ?? 0.2;
    this.direction = options.direction ?? [0, 1, 0];
  }
  
  emit(): Particle {
    const rand = () => Math.random() * 2 - 1;
    const randPos = () => Math.random();
    
    // Random direction within cone
    const theta = randPos() * Math.PI * 2;
    const phi = randPos() * this.spread;
    const sinPhi = Math.sin(phi);
    
    let dx = sinPhi * Math.cos(theta);
    let dy = Math.cos(phi);
    let dz = sinPhi * Math.sin(theta);
    
    // Rotate to match emitter direction
    // (simplified - assumes direction is normalized)
    const [dirX, dirY, dirZ] = this.direction;
    if (Math.abs(dirY) < 0.99) {
      // Rotate around cross product
      const len = Math.sqrt(dirX*dirX + dirZ*dirZ);
      const nx = dirX / len, nz = dirZ / len;
      const temp = dx;
      dx = dx * dirY + dy * nx * (1 - dirY);
      dy = dy * dirY - temp * len;
    }
    
    const speed = this.speed + rand() * this.speedVariance;
    
    return {
      x: this.x + rand() * 0.1,
      y: this.y + rand() * 0.1,
      z: this.z + rand() * 0.1,
      vx: dx * speed,
      vy: dy * speed,
      vz: dz * speed,
      life: this.life + rand() * this.lifeVariance,
      size: this.size + rand() * this.sizeVariance,
      color: [
        Math.max(0, Math.min(1, this.color[0] + rand() * this.colorVariance)),
        Math.max(0, Math.min(1, this.color[1] + rand() * this.colorVariance)),
        Math.max(0, Math.min(1, this.color[2] + rand() * this.colorVariance))
      ]
    };
  }
}

// Preset emitters
export const FireEmitter = (x: number, y: number, z: number) => new ParticleEmitter({
  x, y, z,
  rate: 500,
  spread: 0.3,
  speed: 3,
  speedVariance: 1,
  life: 1.5,
  lifeVariance: 0.5,
  size: 15,
  sizeVariance: 8,
  color: [1, 0.3, 0.05],
  colorVariance: 0.15,
  direction: [0, 1, 0]
});

export const SmokeEmitter = (x: number, y: number, z: number) => new ParticleEmitter({
  x, y, z,
  rate: 100,
  spread: 0.5,
  speed: 1,
  speedVariance: 0.5,
  life: 4,
  lifeVariance: 1,
  size: 30,
  sizeVariance: 15,
  color: [0.3, 0.3, 0.35],
  colorVariance: 0.1,
  direction: [0, 1, 0]
});

export const SparkEmitter = (x: number, y: number, z: number) => new ParticleEmitter({
  x, y, z,
  rate: 200,
  spread: 1.0,
  speed: 8,
  speedVariance: 4,
  life: 0.8,
  lifeVariance: 0.3,
  size: 3,
  sizeVariance: 2,
  color: [1, 0.8, 0.3],
  colorVariance: 0.2,
  direction: [0, 1, 0]
});

export const MagicEmitter = (x: number, y: number, z: number) => new ParticleEmitter({
  x, y, z,
  rate: 300,
  spread: Math.PI,
  speed: 2,
  speedVariance: 1,
  life: 2,
  lifeVariance: 0.5,
  size: 8,
  sizeVariance: 4,
  color: [0.3, 0.5, 1],
  colorVariance: 0.3,
  direction: [0, 0, 0]
});
