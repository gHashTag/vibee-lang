// GPU-Accelerated Fluid Simulation
// Based on Jos Stam's "Stable Fluids" and Navier-Stokes equations
// ∂u/∂t + (u·∇)u = -∇p + ν∇²u + f

export class FluidSimulation {
  private gl: WebGL2RenderingContext;
  private width: number;
  private height: number;
  
  // Simulation parameters
  private viscosity = 0.0001;
  private diffusion = 0.0001;
  private pressureIterations = 40;
  private curlStrength = 30;
  private dyeDecay = 0.99;
  
  // Framebuffers (double-buffered)
  private velocityFBO: DoubleFBO;
  private pressureFBO: DoubleFBO;
  private divergenceFBO: FBO;
  private dyeFBO: DoubleFBO;
  private curlFBO: FBO;
  
  // Shaders
  private programs: Map<string, WebGLProgram> = new Map();
  private quadVAO: WebGLVertexArrayObject;
  
  constructor(gl: WebGL2RenderingContext, width = 512, height = 512) {
    this.gl = gl;
    this.width = width;
    this.height = height;
    
    this.quadVAO = this.createQuad();
    this.initShaders();
    this.initFramebuffers();
  }
  
  private createQuad(): WebGLVertexArrayObject {
    const gl = this.gl;
    const vao = gl.createVertexArray()!;
    gl.bindVertexArray(vao);
    
    const vbo = gl.createBuffer()!;
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([
      -1, -1, 1, -1, -1, 1, 1, 1
    ]), gl.STATIC_DRAW);
    
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
    
    return vao;
  }
  
  private initShaders() {
    const baseVert = `#version 300 es
    layout(location=0) in vec2 aPos;
    out vec2 vUV;
    void main() {
      vUV = aPos * 0.5 + 0.5;
      gl_Position = vec4(aPos, 0.0, 1.0);
    }`;
    
    // Advection - move quantities along velocity field
    this.createProgram('advect', baseVert, `#version 300 es
    precision highp float;
    in vec2 vUV;
    out vec4 fragColor;
    uniform sampler2D uVelocity;
    uniform sampler2D uSource;
    uniform vec2 uTexelSize;
    uniform float uDt;
    uniform float uDissipation;
    
    void main() {
      vec2 vel = texture(uVelocity, vUV).xy;
      vec2 pos = vUV - vel * uDt * uTexelSize;
      fragColor = texture(uSource, pos) * uDissipation;
    }`);
    
    // Divergence - ∇·u
    this.createProgram('divergence', baseVert, `#version 300 es
    precision highp float;
    in vec2 vUV;
    out vec4 fragColor;
    uniform sampler2D uVelocity;
    uniform vec2 uTexelSize;
    
    void main() {
      float L = texture(uVelocity, vUV - vec2(uTexelSize.x, 0.0)).x;
      float R = texture(uVelocity, vUV + vec2(uTexelSize.x, 0.0)).x;
      float B = texture(uVelocity, vUV - vec2(0.0, uTexelSize.y)).y;
      float T = texture(uVelocity, vUV + vec2(0.0, uTexelSize.y)).y;
      float div = 0.5 * (R - L + T - B);
      fragColor = vec4(div, 0.0, 0.0, 1.0);
    }`);
    
    // Pressure solve (Jacobi iteration)
    this.createProgram('pressure', baseVert, `#version 300 es
    precision highp float;
    in vec2 vUV;
    out vec4 fragColor;
    uniform sampler2D uPressure;
    uniform sampler2D uDivergence;
    uniform vec2 uTexelSize;
    
    void main() {
      float L = texture(uPressure, vUV - vec2(uTexelSize.x, 0.0)).x;
      float R = texture(uPressure, vUV + vec2(uTexelSize.x, 0.0)).x;
      float B = texture(uPressure, vUV - vec2(0.0, uTexelSize.y)).x;
      float T = texture(uPressure, vUV + vec2(0.0, uTexelSize.y)).x;
      float div = texture(uDivergence, vUV).x;
      float p = (L + R + B + T - div) * 0.25;
      fragColor = vec4(p, 0.0, 0.0, 1.0);
    }`);
    
    // Gradient subtraction - make velocity divergence-free
    this.createProgram('gradient', baseVert, `#version 300 es
    precision highp float;
    in vec2 vUV;
    out vec4 fragColor;
    uniform sampler2D uPressure;
    uniform sampler2D uVelocity;
    uniform vec2 uTexelSize;
    
    void main() {
      float L = texture(uPressure, vUV - vec2(uTexelSize.x, 0.0)).x;
      float R = texture(uPressure, vUV + vec2(uTexelSize.x, 0.0)).x;
      float B = texture(uPressure, vUV - vec2(0.0, uTexelSize.y)).x;
      float T = texture(uPressure, vUV + vec2(0.0, uTexelSize.y)).x;
      vec2 vel = texture(uVelocity, vUV).xy;
      vel -= vec2(R - L, T - B) * 0.5;
      fragColor = vec4(vel, 0.0, 1.0);
    }`);
    
    // Curl (vorticity)
    this.createProgram('curl', baseVert, `#version 300 es
    precision highp float;
    in vec2 vUV;
    out vec4 fragColor;
    uniform sampler2D uVelocity;
    uniform vec2 uTexelSize;
    
    void main() {
      float L = texture(uVelocity, vUV - vec2(uTexelSize.x, 0.0)).y;
      float R = texture(uVelocity, vUV + vec2(uTexelSize.x, 0.0)).y;
      float B = texture(uVelocity, vUV - vec2(0.0, uTexelSize.y)).x;
      float T = texture(uVelocity, vUV + vec2(0.0, uTexelSize.y)).x;
      float curl = (R - L) - (T - B);
      fragColor = vec4(curl * 0.5, 0.0, 0.0, 1.0);
    }`);
    
    // Vorticity confinement - add swirl back
    this.createProgram('vorticity', baseVert, `#version 300 es
    precision highp float;
    in vec2 vUV;
    out vec4 fragColor;
    uniform sampler2D uVelocity;
    uniform sampler2D uCurl;
    uniform vec2 uTexelSize;
    uniform float uCurlStrength;
    uniform float uDt;
    
    void main() {
      float L = texture(uCurl, vUV - vec2(uTexelSize.x, 0.0)).x;
      float R = texture(uCurl, vUV + vec2(uTexelSize.x, 0.0)).x;
      float B = texture(uCurl, vUV - vec2(0.0, uTexelSize.y)).x;
      float T = texture(uCurl, vUV + vec2(0.0, uTexelSize.y)).x;
      float C = texture(uCurl, vUV).x;
      
      vec2 force = vec2(abs(T) - abs(B), abs(R) - abs(L));
      float len = length(force) + 0.0001;
      force = force / len * C;
      
      vec2 vel = texture(uVelocity, vUV).xy;
      vel += force * uCurlStrength * uDt;
      fragColor = vec4(vel, 0.0, 1.0);
    }`);
    
    // Splat - add force/dye
    this.createProgram('splat', baseVert, `#version 300 es
    precision highp float;
    in vec2 vUV;
    out vec4 fragColor;
    uniform sampler2D uTarget;
    uniform vec2 uPoint;
    uniform vec3 uColor;
    uniform float uRadius;
    uniform float uAspect;
    
    void main() {
      vec2 p = vUV - uPoint;
      p.x *= uAspect;
      float d = exp(-dot(p, p) / uRadius);
      vec3 base = texture(uTarget, vUV).xyz;
      fragColor = vec4(base + uColor * d, 1.0);
    }`);
    
    // Display with color mapping
    this.createProgram('display', baseVert, `#version 300 es
    precision highp float;
    in vec2 vUV;
    out vec4 fragColor;
    uniform sampler2D uDye;
    uniform sampler2D uVelocity;
    uniform int uMode; // 0=dye, 1=velocity, 2=pressure
    
    vec3 hsv2rgb(vec3 c) {
      vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
      vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
      return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
    }
    
    void main() {
      if(uMode == 0) {
        vec3 dye = texture(uDye, vUV).rgb;
        fragColor = vec4(dye, 1.0);
      } else if(uMode == 1) {
        vec2 vel = texture(uVelocity, vUV).xy;
        float speed = length(vel);
        float angle = atan(vel.y, vel.x) / 6.28318 + 0.5;
        vec3 col = hsv2rgb(vec3(angle, 1.0, min(speed * 0.1, 1.0)));
        fragColor = vec4(col, 1.0);
      }
    }`);
    
    // Viscous diffusion
    this.createProgram('diffuse', baseVert, `#version 300 es
    precision highp float;
    in vec2 vUV;
    out vec4 fragColor;
    uniform sampler2D uSource;
    uniform vec2 uTexelSize;
    uniform float uAlpha;
    uniform float uBeta;
    
    void main() {
      vec4 L = texture(uSource, vUV - vec2(uTexelSize.x, 0.0));
      vec4 R = texture(uSource, vUV + vec2(uTexelSize.x, 0.0));
      vec4 B = texture(uSource, vUV - vec2(0.0, uTexelSize.y));
      vec4 T = texture(uSource, vUV + vec2(0.0, uTexelSize.y));
      vec4 C = texture(uSource, vUV);
      fragColor = (L + R + B + T + uAlpha * C) / uBeta;
    }`);
  }
  
  private createProgram(name: string, vertSrc: string, fragSrc: string) {
    const gl = this.gl;
    
    const vert = gl.createShader(gl.VERTEX_SHADER)!;
    gl.shaderSource(vert, vertSrc);
    gl.compileShader(vert);
    
    const frag = gl.createShader(gl.FRAGMENT_SHADER)!;
    gl.shaderSource(frag, fragSrc);
    gl.compileShader(frag);
    
    if (!gl.getShaderParameter(frag, gl.COMPILE_STATUS)) {
      console.error(`${name}:`, gl.getShaderInfoLog(frag));
    }
    
    const prog = gl.createProgram()!;
    gl.attachShader(prog, vert);
    gl.attachShader(prog, frag);
    gl.linkProgram(prog);
    
    this.programs.set(name, prog);
  }
  
  private initFramebuffers() {
    const gl = this.gl;
    const w = this.width, h = this.height;
    
    // Velocity (RG for x,y)
    this.velocityFBO = this.createDoubleFBO(w, h, gl.RG16F, gl.RG, gl.HALF_FLOAT);
    
    // Pressure (R only)
    this.pressureFBO = this.createDoubleFBO(w, h, gl.R16F, gl.RED, gl.HALF_FLOAT);
    
    // Divergence
    this.divergenceFBO = this.createFBO(w, h, gl.R16F, gl.RED, gl.HALF_FLOAT);
    
    // Curl
    this.curlFBO = this.createFBO(w, h, gl.R16F, gl.RED, gl.HALF_FLOAT);
    
    // Dye (RGB color)
    this.dyeFBO = this.createDoubleFBO(w, h, gl.RGBA16F, gl.RGBA, gl.HALF_FLOAT);
  }
  
  private createFBO(w: number, h: number, internalFormat: number, format: number, type: number): FBO {
    const gl = this.gl;
    
    const tex = gl.createTexture()!;
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.texImage2D(gl.TEXTURE_2D, 0, internalFormat, w, h, 0, format, type, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    
    const fbo = gl.createFramebuffer()!;
    gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, tex, 0);
    
    return { fbo, tex, width: w, height: h };
  }
  
  private createDoubleFBO(w: number, h: number, internalFormat: number, format: number, type: number): DoubleFBO {
    return {
      read: this.createFBO(w, h, internalFormat, format, type),
      write: this.createFBO(w, h, internalFormat, format, type),
      swap() { [this.read, this.write] = [this.write, this.read]; }
    };
  }
  
  private blit(target: FBO | null) {
    const gl = this.gl;
    if (target) {
      gl.bindFramebuffer(gl.FRAMEBUFFER, target.fbo);
      gl.viewport(0, 0, target.width, target.height);
    } else {
      gl.bindFramebuffer(gl.FRAMEBUFFER, null);
      gl.viewport(0, 0, gl.canvas.width, gl.canvas.height);
    }
    gl.bindVertexArray(this.quadVAO);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
  }
  
  // Add force/velocity at point
  splat(x: number, y: number, dx: number, dy: number, color: [number, number, number]) {
    const gl = this.gl;
    const prog = this.programs.get('splat')!;
    gl.useProgram(prog);
    
    const texelSize = [1 / this.width, 1 / this.height];
    const aspect = this.width / this.height;
    
    // Splat velocity
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this.velocityFBO.read.tex);
    gl.uniform1i(gl.getUniformLocation(prog, 'uTarget'), 0);
    gl.uniform2f(gl.getUniformLocation(prog, 'uPoint'), x, y);
    gl.uniform3f(gl.getUniformLocation(prog, 'uColor'), dx * 10, dy * 10, 0);
    gl.uniform1f(gl.getUniformLocation(prog, 'uRadius'), 0.0005);
    gl.uniform1f(gl.getUniformLocation(prog, 'uAspect'), aspect);
    this.blit(this.velocityFBO.write);
    this.velocityFBO.swap();
    
    // Splat dye
    gl.bindTexture(gl.TEXTURE_2D, this.dyeFBO.read.tex);
    gl.uniform3fv(gl.getUniformLocation(prog, 'uColor'), color);
    gl.uniform1f(gl.getUniformLocation(prog, 'uRadius'), 0.001);
    this.blit(this.dyeFBO.write);
    this.dyeFBO.swap();
  }
  
  step(dt: number) {
    const gl = this.gl;
    const texelSize = [1 / this.width, 1 / this.height];
    
    // 1. Curl
    let prog = this.programs.get('curl')!;
    gl.useProgram(prog);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this.velocityFBO.read.tex);
    gl.uniform1i(gl.getUniformLocation(prog, 'uVelocity'), 0);
    gl.uniform2fv(gl.getUniformLocation(prog, 'uTexelSize'), texelSize);
    this.blit(this.curlFBO);
    
    // 2. Vorticity confinement
    prog = this.programs.get('vorticity')!;
    gl.useProgram(prog);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this.velocityFBO.read.tex);
    gl.uniform1i(gl.getUniformLocation(prog, 'uVelocity'), 0);
    gl.activeTexture(gl.TEXTURE1);
    gl.bindTexture(gl.TEXTURE_2D, this.curlFBO.tex);
    gl.uniform1i(gl.getUniformLocation(prog, 'uCurl'), 1);
    gl.uniform2fv(gl.getUniformLocation(prog, 'uTexelSize'), texelSize);
    gl.uniform1f(gl.getUniformLocation(prog, 'uCurlStrength'), this.curlStrength);
    gl.uniform1f(gl.getUniformLocation(prog, 'uDt'), dt);
    this.blit(this.velocityFBO.write);
    this.velocityFBO.swap();
    
    // 3. Divergence
    prog = this.programs.get('divergence')!;
    gl.useProgram(prog);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this.velocityFBO.read.tex);
    gl.uniform1i(gl.getUniformLocation(prog, 'uVelocity'), 0);
    gl.uniform2fv(gl.getUniformLocation(prog, 'uTexelSize'), texelSize);
    this.blit(this.divergenceFBO);
    
    // 4. Clear pressure
    gl.bindFramebuffer(gl.FRAMEBUFFER, this.pressureFBO.read.fbo);
    gl.clearColor(0, 0, 0, 1);
    gl.clear(gl.COLOR_BUFFER_BIT);
    
    // 5. Pressure solve (Jacobi iterations)
    prog = this.programs.get('pressure')!;
    gl.useProgram(prog);
    gl.uniform2fv(gl.getUniformLocation(prog, 'uTexelSize'), texelSize);
    gl.activeTexture(gl.TEXTURE1);
    gl.bindTexture(gl.TEXTURE_2D, this.divergenceFBO.tex);
    gl.uniform1i(gl.getUniformLocation(prog, 'uDivergence'), 1);
    
    for (let i = 0; i < this.pressureIterations; i++) {
      gl.activeTexture(gl.TEXTURE0);
      gl.bindTexture(gl.TEXTURE_2D, this.pressureFBO.read.tex);
      gl.uniform1i(gl.getUniformLocation(prog, 'uPressure'), 0);
      this.blit(this.pressureFBO.write);
      this.pressureFBO.swap();
    }
    
    // 6. Gradient subtraction
    prog = this.programs.get('gradient')!;
    gl.useProgram(prog);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this.pressureFBO.read.tex);
    gl.uniform1i(gl.getUniformLocation(prog, 'uPressure'), 0);
    gl.activeTexture(gl.TEXTURE1);
    gl.bindTexture(gl.TEXTURE_2D, this.velocityFBO.read.tex);
    gl.uniform1i(gl.getUniformLocation(prog, 'uVelocity'), 1);
    gl.uniform2fv(gl.getUniformLocation(prog, 'uTexelSize'), texelSize);
    this.blit(this.velocityFBO.write);
    this.velocityFBO.swap();
    
    // 7. Advect velocity
    prog = this.programs.get('advect')!;
    gl.useProgram(prog);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this.velocityFBO.read.tex);
    gl.uniform1i(gl.getUniformLocation(prog, 'uVelocity'), 0);
    gl.activeTexture(gl.TEXTURE1);
    gl.bindTexture(gl.TEXTURE_2D, this.velocityFBO.read.tex);
    gl.uniform1i(gl.getUniformLocation(prog, 'uSource'), 1);
    gl.uniform2fv(gl.getUniformLocation(prog, 'uTexelSize'), texelSize);
    gl.uniform1f(gl.getUniformLocation(prog, 'uDt'), dt);
    gl.uniform1f(gl.getUniformLocation(prog, 'uDissipation'), 0.99);
    this.blit(this.velocityFBO.write);
    this.velocityFBO.swap();
    
    // 8. Advect dye
    gl.activeTexture(gl.TEXTURE1);
    gl.bindTexture(gl.TEXTURE_2D, this.dyeFBO.read.tex);
    gl.uniform1f(gl.getUniformLocation(prog, 'uDissipation'), this.dyeDecay);
    this.blit(this.dyeFBO.write);
    this.dyeFBO.swap();
  }
  
  render(mode = 0) {
    const gl = this.gl;
    const prog = this.programs.get('display')!;
    gl.useProgram(prog);
    
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this.dyeFBO.read.tex);
    gl.uniform1i(gl.getUniformLocation(prog, 'uDye'), 0);
    
    gl.activeTexture(gl.TEXTURE1);
    gl.bindTexture(gl.TEXTURE_2D, this.velocityFBO.read.tex);
    gl.uniform1i(gl.getUniformLocation(prog, 'uVelocity'), 1);
    
    gl.uniform1i(gl.getUniformLocation(prog, 'uMode'), mode);
    
    this.blit(null);
  }
  
  // Get dye texture for compositing
  getDyeTexture(): WebGLTexture {
    return this.dyeFBO.read.tex;
  }
  
  getVelocityTexture(): WebGLTexture {
    return this.velocityFBO.read.tex;
  }
}

interface FBO {
  fbo: WebGLFramebuffer;
  tex: WebGLTexture;
  width: number;
  height: number;
}

interface DoubleFBO {
  read: FBO;
  write: FBO;
  swap(): void;
}

// Interactive fluid with mouse
export function createInteractiveFluid(canvas: HTMLCanvasElement): {
  fluid: FluidSimulation;
  start: () => void;
  stop: () => void;
} {
  const gl = canvas.getContext('webgl2', {
    alpha: false,
    preserveDrawingBuffer: false,
    powerPreference: 'high-performance'
  })!;
  
  gl.getExtension('EXT_color_buffer_float');
  
  const fluid = new FluidSimulation(gl, canvas.width, canvas.height);
  
  let lastX = 0, lastY = 0;
  let animationId: number;
  let lastTime = performance.now();
  
  const getColor = (t: number): [number, number, number] => {
    return [
      Math.sin(t * 0.3) * 0.5 + 0.5,
      Math.sin(t * 0.3 + 2) * 0.5 + 0.5,
      Math.sin(t * 0.3 + 4) * 0.5 + 0.5
    ];
  };
  
  const onMove = (e: MouseEvent | TouchEvent) => {
    const rect = canvas.getBoundingClientRect();
    let x: number, y: number;
    
    if ('touches' in e) {
      x = e.touches[0].clientX;
      y = e.touches[0].clientY;
    } else {
      x = e.clientX;
      y = e.clientY;
    }
    
    const nx = (x - rect.left) / rect.width;
    const ny = 1 - (y - rect.top) / rect.height;
    
    const dx = nx - lastX;
    const dy = ny - lastY;
    
    if (Math.abs(dx) > 0 || Math.abs(dy) > 0) {
      fluid.splat(nx, ny, dx, dy, getColor(performance.now() * 0.001));
    }
    
    lastX = nx;
    lastY = ny;
  };
  
  const loop = () => {
    const now = performance.now();
    const dt = Math.min((now - lastTime) / 1000, 0.016);
    lastTime = now;
    
    // Auto-splat for demo
    const t = now * 0.001;
    fluid.splat(
      0.5 + Math.sin(t) * 0.3,
      0.5 + Math.cos(t * 1.3) * 0.3,
      Math.cos(t) * 0.01,
      Math.sin(t * 1.3) * 0.01,
      getColor(t)
    );
    
    fluid.step(dt);
    fluid.render(0);
    
    animationId = requestAnimationFrame(loop);
  };
  
  canvas.addEventListener('mousemove', onMove);
  canvas.addEventListener('touchmove', onMove);
  
  return {
    fluid,
    start: () => { lastTime = performance.now(); loop(); },
    stop: () => cancelAnimationFrame(animationId)
  };
}
