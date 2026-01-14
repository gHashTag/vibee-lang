// Advanced WebGL2 Graphics Engine
// GPU-accelerated rendering with modern techniques

export class WebGLEngine {
  private gl: WebGL2RenderingContext;
  private programs: Map<string, WebGLProgram> = new Map();
  private framebuffers: Map<string, WebGLFramebuffer> = new Map();
  private textures: Map<string, WebGLTexture> = new Map();
  private quadVAO: WebGLVertexArrayObject;
  private time = 0;
  
  constructor(canvas: HTMLCanvasElement) {
    const gl = canvas.getContext('webgl2', {
      antialias: true,
      alpha: false,
      preserveDrawingBuffer: true,
      powerPreference: 'high-performance'
    });
    if (!gl) throw new Error('WebGL2 not supported');
    this.gl = gl;
    
    // Enable extensions
    gl.getExtension('EXT_color_buffer_float');
    gl.getExtension('OES_texture_float_linear');
    
    this.quadVAO = this.createQuad();
    this.initShaders();
    this.initFramebuffers();
  }
  
  private createQuad(): WebGLVertexArrayObject {
    const gl = this.gl;
    const vao = gl.createVertexArray()!;
    gl.bindVertexArray(vao);
    
    const vertices = new Float32Array([
      -1, -1, 0, 0,
       1, -1, 1, 0,
      -1,  1, 0, 1,
       1,  1, 1, 1
    ]);
    
    const vbo = gl.createBuffer()!;
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.STATIC_DRAW);
    
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 16, 0);
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 2, gl.FLOAT, false, 16, 8);
    
    return vao;
  }
  
  private initShaders() {
    // Ray Marching shader for 3D scenes
    this.createProgram('raymarching', VERTEX_SHADER, RAYMARCHING_FRAG);
    
    // Fluid simulation
    this.createProgram('fluid_advect', VERTEX_SHADER, FLUID_ADVECT_FRAG);
    this.createProgram('fluid_divergence', VERTEX_SHADER, FLUID_DIVERGENCE_FRAG);
    this.createProgram('fluid_pressure', VERTEX_SHADER, FLUID_PRESSURE_FRAG);
    this.createProgram('fluid_gradient', VERTEX_SHADER, FLUID_GRADIENT_FRAG);
    
    // Post-processing
    this.createProgram('bloom_extract', VERTEX_SHADER, BLOOM_EXTRACT_FRAG);
    this.createProgram('blur', VERTEX_SHADER, BLUR_FRAG);
    this.createProgram('tonemap', VERTEX_SHADER, TONEMAP_FRAG);
    
    // Particles
    this.createProgram('particles', PARTICLE_VERT, PARTICLE_FRAG);
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
      console.error(`${name} frag:`, gl.getShaderInfoLog(frag));
    }
    
    const prog = gl.createProgram()!;
    gl.attachShader(prog, vert);
    gl.attachShader(prog, frag);
    gl.linkProgram(prog);
    
    this.programs.set(name, prog);
  }
  
  private initFramebuffers() {
    const gl = this.gl;
    const w = gl.canvas.width, h = gl.canvas.height;
    
    // HDR framebuffer
    this.createFramebuffer('hdr', w, h, gl.RGBA16F);
    this.createFramebuffer('bloom1', w/2, h/2, gl.RGBA16F);
    this.createFramebuffer('bloom2', w/4, h/4, gl.RGBA16F);
    
    // Fluid simulation buffers
    this.createFramebuffer('velocity', w, h, gl.RG16F);
    this.createFramebuffer('velocity_temp', w, h, gl.RG16F);
    this.createFramebuffer('pressure', w, h, gl.R16F);
    this.createFramebuffer('divergence', w, h, gl.R16F);
  }
  
  private createFramebuffer(name: string, w: number, h: number, format: number) {
    const gl = this.gl;
    const fb = gl.createFramebuffer()!;
    const tex = gl.createTexture()!;
    
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.texImage2D(gl.TEXTURE_2D, 0, format, w, h, 0, 
      format === gl.RG16F ? gl.RG : format === gl.R16F ? gl.RED : gl.RGBA,
      gl.FLOAT, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    
    gl.bindFramebuffer(gl.FRAMEBUFFER, fb);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, tex, 0);
    
    this.framebuffers.set(name, fb);
    this.textures.set(name, tex);
  }
  
  render(dt: number) {
    this.time += dt;
    const gl = this.gl;
    
    // 1. Render scene to HDR buffer
    gl.bindFramebuffer(gl.FRAMEBUFFER, this.framebuffers.get('hdr')!);
    gl.viewport(0, 0, gl.canvas.width, gl.canvas.height);
    this.renderRaymarching();
    
    // 2. Extract bright areas for bloom
    gl.bindFramebuffer(gl.FRAMEBUFFER, this.framebuffers.get('bloom1')!);
    gl.viewport(0, 0, gl.canvas.width/2, gl.canvas.height/2);
    this.renderBloomExtract();
    
    // 3. Blur bloom
    this.renderBlur('bloom1', 'bloom2', true);
    this.renderBlur('bloom2', 'bloom1', false);
    
    // 4. Final composite with tone mapping
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    gl.viewport(0, 0, gl.canvas.width, gl.canvas.height);
    this.renderTonemap();
  }
  
  private renderRaymarching() {
    const gl = this.gl;
    const prog = this.programs.get('raymarching')!;
    gl.useProgram(prog);
    
    gl.uniform1f(gl.getUniformLocation(prog, 'uTime'), this.time);
    gl.uniform2f(gl.getUniformLocation(prog, 'uResolution'), 
      gl.canvas.width, gl.canvas.height);
    
    gl.bindVertexArray(this.quadVAO);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
  }
  
  private renderBloomExtract() {
    const gl = this.gl;
    const prog = this.programs.get('bloom_extract')!;
    gl.useProgram(prog);
    
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this.textures.get('hdr')!);
    gl.uniform1i(gl.getUniformLocation(prog, 'uTexture'), 0);
    gl.uniform1f(gl.getUniformLocation(prog, 'uThreshold'), 1.0);
    
    gl.bindVertexArray(this.quadVAO);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
  }
  
  private renderBlur(src: string, dst: string, horizontal: boolean) {
    const gl = this.gl;
    const prog = this.programs.get('blur')!;
    gl.useProgram(prog);
    
    gl.bindFramebuffer(gl.FRAMEBUFFER, this.framebuffers.get(dst)!);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this.textures.get(src)!);
    gl.uniform1i(gl.getUniformLocation(prog, 'uTexture'), 0);
    gl.uniform1i(gl.getUniformLocation(prog, 'uHorizontal'), horizontal ? 1 : 0);
    
    gl.bindVertexArray(this.quadVAO);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
  }
  
  private renderTonemap() {
    const gl = this.gl;
    const prog = this.programs.get('tonemap')!;
    gl.useProgram(prog);
    
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this.textures.get('hdr')!);
    gl.uniform1i(gl.getUniformLocation(prog, 'uScene'), 0);
    
    gl.activeTexture(gl.TEXTURE1);
    gl.bindTexture(gl.TEXTURE_2D, this.textures.get('bloom1')!);
    gl.uniform1i(gl.getUniformLocation(prog, 'uBloom'), 1);
    
    gl.uniform1f(gl.getUniformLocation(prog, 'uExposure'), 1.2);
    gl.uniform1f(gl.getUniformLocation(prog, 'uBloomStrength'), 0.3);
    
    gl.bindVertexArray(this.quadVAO);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
  }
}

// ============ SHADERS ============

const VERTEX_SHADER = `#version 300 es
layout(location=0) in vec2 aPos;
layout(location=1) in vec2 aUV;
out vec2 vUV;
void main() {
  vUV = aUV;
  gl_Position = vec4(aPos, 0.0, 1.0);
}`;

const RAYMARCHING_FRAG = `#version 300 es
precision highp float;
in vec2 vUV;
out vec4 fragColor;

uniform float uTime;
uniform vec2 uResolution;

// Signed Distance Functions
float sdSphere(vec3 p, float r) { return length(p) - r; }
float sdBox(vec3 p, vec3 b) {
  vec3 q = abs(p) - b;
  return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}
float sdTorus(vec3 p, vec2 t) {
  vec2 q = vec2(length(p.xz) - t.x, p.y);
  return length(q) - t.y;
}

// Smooth operations
float opSmoothUnion(float d1, float d2, float k) {
  float h = clamp(0.5 + 0.5*(d2-d1)/k, 0.0, 1.0);
  return mix(d2, d1, h) - k*h*(1.0-h);
}

// Rotation matrix
mat2 rot2D(float a) {
  float c = cos(a), s = sin(a);
  return mat2(c, -s, s, c);
}

// Scene SDF
float map(vec3 p) {
  // Animated morphing shapes
  float t = uTime * 0.5;
  
  // Rotating torus
  vec3 p1 = p;
  p1.xz *= rot2D(t);
  p1.xy *= rot2D(t * 0.7);
  float torus = sdTorus(p1, vec2(1.0, 0.3));
  
  // Pulsing sphere
  float sphere = sdSphere(p - vec3(sin(t)*0.5, cos(t*1.3)*0.3, 0.0), 
                          0.5 + 0.1*sin(t*3.0));
  
  // Morphing box
  vec3 p2 = p;
  p2.xy *= rot2D(-t * 0.5);
  float box = sdBox(p2 - vec3(0.0, 0.0, sin(t)*0.5), 
                    vec3(0.3 + 0.1*sin(t*2.0)));
  
  // Combine with smooth union
  float d = opSmoothUnion(torus, sphere, 0.5);
  d = opSmoothUnion(d, box, 0.3);
  
  return d;
}

// Calculate normal
vec3 calcNormal(vec3 p) {
  const float h = 0.001;
  const vec2 k = vec2(1, -1);
  return normalize(
    k.xyy * map(p + k.xyy*h) +
    k.yyx * map(p + k.yyx*h) +
    k.yxy * map(p + k.yxy*h) +
    k.xxx * map(p + k.xxx*h)
  );
}

// Soft shadows
float softShadow(vec3 ro, vec3 rd, float mint, float maxt, float k) {
  float res = 1.0;
  float t = mint;
  for(int i = 0; i < 32; i++) {
    float h = map(ro + rd*t);
    res = min(res, k*h/t);
    t += clamp(h, 0.02, 0.1);
    if(h < 0.001 || t > maxt) break;
  }
  return clamp(res, 0.0, 1.0);
}

// Ambient occlusion
float calcAO(vec3 p, vec3 n) {
  float occ = 0.0;
  float sca = 1.0;
  for(int i = 0; i < 5; i++) {
    float h = 0.01 + 0.12 * float(i);
    float d = map(p + h*n);
    occ += (h - d) * sca;
    sca *= 0.95;
  }
  return clamp(1.0 - 3.0*occ, 0.0, 1.0);
}

void main() {
  vec2 uv = (gl_FragCoord.xy - 0.5*uResolution) / uResolution.y;
  
  // Camera
  float camDist = 4.0;
  float camAngle = uTime * 0.2;
  vec3 ro = vec3(sin(camAngle)*camDist, 1.5 + sin(uTime*0.3)*0.5, cos(camAngle)*camDist);
  vec3 ta = vec3(0.0, 0.0, 0.0);
  
  vec3 ww = normalize(ta - ro);
  vec3 uu = normalize(cross(ww, vec3(0.0, 1.0, 0.0)));
  vec3 vv = cross(uu, ww);
  vec3 rd = normalize(uv.x*uu + uv.y*vv + 1.5*ww);
  
  // Ray march
  float t = 0.0;
  vec3 col = vec3(0.0);
  
  for(int i = 0; i < 100; i++) {
    vec3 p = ro + rd*t;
    float d = map(p);
    
    if(d < 0.001) {
      // Hit - calculate lighting
      vec3 n = calcNormal(p);
      
      // Multiple lights
      vec3 light1 = normalize(vec3(1.0, 2.0, 1.0));
      vec3 light2 = normalize(vec3(-1.0, 1.0, -1.0));
      
      // Diffuse
      float diff1 = max(dot(n, light1), 0.0);
      float diff2 = max(dot(n, light2), 0.0);
      
      // Specular (Blinn-Phong)
      vec3 h1 = normalize(light1 - rd);
      vec3 h2 = normalize(light2 - rd);
      float spec1 = pow(max(dot(n, h1), 0.0), 32.0);
      float spec2 = pow(max(dot(n, h2), 0.0), 32.0);
      
      // Shadows
      float sha1 = softShadow(p + n*0.01, light1, 0.01, 3.0, 16.0);
      float sha2 = softShadow(p + n*0.01, light2, 0.01, 3.0, 16.0);
      
      // AO
      float ao = calcAO(p, n);
      
      // Fresnel
      float fresnel = pow(1.0 - max(dot(n, -rd), 0.0), 3.0);
      
      // Material color based on position
      vec3 matCol = 0.5 + 0.5*cos(uTime + p.xyz + vec3(0, 2, 4));
      
      // Combine lighting
      col = matCol * (
        vec3(1.0, 0.9, 0.8) * diff1 * sha1 +
        vec3(0.4, 0.5, 0.8) * diff2 * sha2 +
        vec3(0.1, 0.1, 0.15) * ao
      );
      col += vec3(1.0, 0.95, 0.9) * spec1 * sha1 * 0.5;
      col += vec3(0.5, 0.6, 1.0) * spec2 * sha2 * 0.3;
      col += fresnel * vec3(0.2, 0.3, 0.5) * 0.5;
      
      // HDR - allow values > 1
      col *= 1.5;
      break;
    }
    
    t += d;
    if(t > 20.0) {
      // Sky gradient
      col = vec3(0.1, 0.15, 0.3) - rd.y * 0.2;
      col += 0.5 * pow(max(dot(rd, normalize(vec3(1.0, 0.5, 0.0))), 0.0), 32.0);
      break;
    }
  }
  
  fragColor = vec4(col, 1.0);
}`;

const BLOOM_EXTRACT_FRAG = `#version 300 es
precision highp float;
in vec2 vUV;
out vec4 fragColor;
uniform sampler2D uTexture;
uniform float uThreshold;

void main() {
  vec3 col = texture(uTexture, vUV).rgb;
  float brightness = dot(col, vec3(0.2126, 0.7152, 0.0722));
  if(brightness > uThreshold) {
    fragColor = vec4(col * (brightness - uThreshold), 1.0);
  } else {
    fragColor = vec4(0.0);
  }
}`;

const BLUR_FRAG = `#version 300 es
precision highp float;
in vec2 vUV;
out vec4 fragColor;
uniform sampler2D uTexture;
uniform int uHorizontal;

const float weights[5] = float[](0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216);

void main() {
  vec2 texSize = vec2(textureSize(uTexture, 0));
  vec2 texOffset = 1.0 / texSize;
  
  vec3 result = texture(uTexture, vUV).rgb * weights[0];
  
  if(uHorizontal == 1) {
    for(int i = 1; i < 5; i++) {
      result += texture(uTexture, vUV + vec2(texOffset.x * float(i), 0.0)).rgb * weights[i];
      result += texture(uTexture, vUV - vec2(texOffset.x * float(i), 0.0)).rgb * weights[i];
    }
  } else {
    for(int i = 1; i < 5; i++) {
      result += texture(uTexture, vUV + vec2(0.0, texOffset.y * float(i))).rgb * weights[i];
      result += texture(uTexture, vUV - vec2(0.0, texOffset.y * float(i))).rgb * weights[i];
    }
  }
  
  fragColor = vec4(result, 1.0);
}`;

const TONEMAP_FRAG = `#version 300 es
precision highp float;
in vec2 vUV;
out vec4 fragColor;
uniform sampler2D uScene;
uniform sampler2D uBloom;
uniform float uExposure;
uniform float uBloomStrength;

// ACES Filmic Tone Mapping
vec3 ACESFilm(vec3 x) {
  float a = 2.51;
  float b = 0.03;
  float c = 2.43;
  float d = 0.59;
  float e = 0.14;
  return clamp((x*(a*x+b))/(x*(c*x+d)+e), 0.0, 1.0);
}

void main() {
  vec3 hdrColor = texture(uScene, vUV).rgb;
  vec3 bloomColor = texture(uBloom, vUV).rgb;
  
  // Add bloom
  hdrColor += bloomColor * uBloomStrength;
  
  // Exposure
  hdrColor *= uExposure;
  
  // Tone mapping
  vec3 mapped = ACESFilm(hdrColor);
  
  // Gamma correction
  mapped = pow(mapped, vec3(1.0/2.2));
  
  // Vignette
  vec2 uv = vUV * 2.0 - 1.0;
  float vignette = 1.0 - dot(uv, uv) * 0.2;
  mapped *= vignette;
  
  fragColor = vec4(mapped, 1.0);
}`;

// Fluid simulation shaders
const FLUID_ADVECT_FRAG = `#version 300 es
precision highp float;
in vec2 vUV;
out vec4 fragColor;
uniform sampler2D uVelocity;
uniform sampler2D uSource;
uniform float uDt;
uniform float uDissipation;

void main() {
  vec2 vel = texture(uVelocity, vUV).xy;
  vec2 pos = vUV - vel * uDt;
  fragColor = vec4(texture(uSource, pos).rgb * uDissipation, 1.0);
}`;

const FLUID_DIVERGENCE_FRAG = `#version 300 es
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
}`;

const FLUID_PRESSURE_FRAG = `#version 300 es
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
  fragColor = vec4((L + R + B + T - div) * 0.25, 0.0, 0.0, 1.0);
}`;

const FLUID_GRADIENT_FRAG = `#version 300 es
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
}`;

// Particle shaders
const PARTICLE_VERT = `#version 300 es
layout(location=0) in vec3 aPos;
layout(location=1) in vec3 aVel;
layout(location=2) in float aLife;
uniform mat4 uMVP;
uniform float uTime;
out float vLife;
out vec3 vVel;

void main() {
  vLife = aLife;
  vVel = aVel;
  float size = mix(5.0, 1.0, aLife);
  gl_PointSize = size;
  gl_Position = uMVP * vec4(aPos, 1.0);
}`;

const PARTICLE_FRAG = `#version 300 es
precision highp float;
in float vLife;
in vec3 vVel;
out vec4 fragColor;

void main() {
  vec2 cxy = 2.0 * gl_PointCoord - 1.0;
  float r = dot(cxy, cxy);
  if(r > 1.0) discard;
  
  float alpha = (1.0 - r) * (1.0 - vLife);
  vec3 col = mix(vec3(1.0, 0.5, 0.1), vec3(0.1, 0.3, 1.0), vLife);
  col += vec3(1.0) * pow(1.0 - r, 4.0);
  
  fragColor = vec4(col * 2.0, alpha);
}`;

export { VERTEX_SHADER, RAYMARCHING_FRAG };
