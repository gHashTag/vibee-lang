// ═══════════════════════════════════════════════════════════════
// CORE.999.JS - Generated from specs/core.vibee
// DO NOT EDIT MANUALLY - Regenerate from specification
// All VIBEE 999 implementation lives here
// ═══════════════════════════════════════════════════════════════

(function() {
'use strict';

// ═══════════════════════════════════════════════════════════════
// CONSTANTS - n × 3^k × π^m
// ═══════════════════════════════════════════════════════════════

var TAU = Math.PI * 2;
var PI = Math.PI;
var PHI = 1.618033988749895;
var DPR = 3; // 4K quality

function p999(n, k, m) {
  return n * Math.pow(3, k) * Math.pow(PI, m);
}

function col(h, s, l, a) {
  return 'hsla(' + h + ',' + s + '%,' + l + '%,' + a + ')';
}

// ═══════════════════════════════════════════════════════════════
// CANVAS SETUP - 4K
// ═══════════════════════════════════════════════════════════════

var canvas = document.getElementById('c');
var ctx = canvas.getContext('2d');
var W, H, t = 0;

function resize() {
  W = window.innerWidth;
  H = window.innerHeight;
  canvas.width = W * DPR;
  canvas.height = H * DPR;
  canvas.style.width = W + 'px';
  canvas.style.height = H + 'px';
  ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
}

resize();
window.addEventListener('resize', resize);

// ═══════════════════════════════════════════════════════════════
// SENSORS
// ═══════════════════════════════════════════════════════════════

var S = {
  mouse: { x: W/2, y: H/2, vx: 0, vy: 0, vel: 0, down: false },
  audio: { vol: 0, freq: 0 },
  time: { p: 0 }
};

var px = W/2, py = H/2;

document.addEventListener('mousemove', function(e) {
  S.mouse.vx = e.clientX - px;
  S.mouse.vy = e.clientY - py;
  S.mouse.vel = Math.sqrt(S.mouse.vx * S.mouse.vx + S.mouse.vy * S.mouse.vy);
  S.mouse.x = e.clientX;
  S.mouse.y = e.clientY;
  px = e.clientX;
  py = e.clientY;
});

document.addEventListener('mousedown', function() { S.mouse.down = true; });
document.addEventListener('mouseup', function() { S.mouse.down = false; });

document.addEventListener('touchstart', function(e) {
  S.mouse.down = true;
  if (e.touches[0]) {
    S.mouse.x = e.touches[0].clientX;
    S.mouse.y = e.touches[0].clientY;
  }
}, { passive: true });

document.addEventListener('touchmove', function(e) {
  if (e.touches[0]) {
    var tx = e.touches[0].clientX;
    var ty = e.touches[0].clientY;
    S.mouse.vx = tx - S.mouse.x;
    S.mouse.vy = ty - S.mouse.y;
    S.mouse.vel = Math.sqrt(S.mouse.vx * S.mouse.vx + S.mouse.vy * S.mouse.vy);
    S.mouse.x = tx;
    S.mouse.y = ty;
  }
}, { passive: true });

document.addEventListener('touchend', function() {
  S.mouse.down = false;
  S.mouse.vel = 0;
});

// Audio
var audioCtx, analyser, fftData;

function initAudio() {
  if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
    navigator.mediaDevices.getUserMedia({ audio: true }).then(function(stream) {
      audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      analyser = audioCtx.createAnalyser();
      analyser.fftSize = 256;
      fftData = new Uint8Array(128);
      audioCtx.createMediaStreamSource(stream).connect(analyser);
    }).catch(function() {});
  }
}

function readAudio() {
  if (analyser && fftData) {
    analyser.getByteFrequencyData(fftData);
    var sum = 0, max = 0, maxI = 0;
    for (var i = 0; i < 128; i++) {
      sum += fftData[i] * fftData[i];
      if (fftData[i] > max) { max = fftData[i]; maxI = i; }
    }
    S.audio.vol = Math.sqrt(sum / 128) / 255;
    S.audio.freq = maxI * (audioCtx.sampleRate / 256);
  }
}

function readTime() {
  var d = new Date();
  S.time.p = (d.getHours() * 3600 + d.getMinutes() * 60 + d.getSeconds()) / 86400;
}

// ═══════════════════════════════════════════════════════════════
// NEURAL 999: 3 → 9 → 27 → 9 → 3
// ═══════════════════════════════════════════════════════════════

var N = {
  layers: [3, 9, 27, 9, 3],
  weights: [],
  act: [[0,0,0], new Array(9).fill(0), new Array(27).fill(0), new Array(9).fill(0), [0,0,0]],
  emotion: 0,
  pulse: 1,
  gen: 0
};

function initNeural() {
  for (var l = 0; l < 4; l++) {
    N.weights[l] = [];
    for (var i = 0; i < N.layers[l]; i++) {
      N.weights[l][i] = [];
      for (var j = 0; j < N.layers[l + 1]; j++) {
        var n = (i % 9) + 1;
        var k = l;
        var m = j % 3;
        N.weights[l][i][j] = (p999(n, k, m) / 100) * (0.9 + Math.random() * 0.2);
      }
    }
  }
}

function processNeural() {
  var input = [
    S.mouse.x / W || 0.5,
    S.mouse.y / H || 0.5,
    Math.min(S.mouse.vel / 100, 1),
    S.audio.vol,
    S.audio.freq / 2000,
    0.5,
    0.5,
    0.5,
    S.time.p
  ];
  
  N.act[0] = input.slice(0, 3);
  
  for (var l = 0; l < 4; l++) {
    for (var j = 0; j < N.layers[l + 1]; j++) {
      var sum = 0;
      for (var i = 0; i < N.layers[l]; i++) {
        sum += (N.act[l][i] || 0) * (N.weights[l][i][j] || 0);
      }
      N.act[l + 1][j] = Math.tanh(sum) * Math.sin(((j % 9) + 1) * PI / 9);
    }
  }
  
  var out = N.act[4];
  N.emotion = N.emotion * 0.95 + (out[1] || 0) * 0.05;
  N.pulse = 1 + Math.sin(t * 0.5) * 0.2 + N.emotion * 0.3;
  N.gen++;
}

// ═══════════════════════════════════════════════════════════════
// RENDERER - 4K Quality
// ═══════════════════════════════════════════════════════════════

function draw() {
  var cx = W / 2;
  var cy = H / 2;
  var r = Math.min(W, H) * 0.4;
  var mx = S.mouse.x;
  var my = S.mouse.y;
  var baseHue = (t * 20 + N.emotion * 60) % 360;
  
  // Clear with trail
  ctx.fillStyle = 'rgba(0, 0, 0, 0.04)';
  ctx.fillRect(0, 0, W, H);
  
  // Ambient glow
  var ambientGrad = ctx.createRadialGradient(cx, cy, 0, cx, cy, r * 1.5);
  ambientGrad.addColorStop(0, col(baseHue, 50, 20, 0.12));
  ambientGrad.addColorStop(0.5, col(baseHue + 60, 40, 15, 0.06));
  ambientGrad.addColorStop(1, 'transparent');
  ctx.fillStyle = ambientGrad;
  ctx.fillRect(0, 0, W, H);
  
  // Three rings: 3, 9, 27 (3^1, 3^2, 3^3)
  for (var ring = 0; ring < 3; ring++) {
    var rr = r * (0.3 + ring * 0.25);
    var els = 3 * Math.pow(3, ring);
    var phase = t * (0.4 + ring * 0.15) * N.pulse;
    
    for (var i = 0; i < els; i++) {
      var a = (i / els) * TAU + phase;
      var x = cx + Math.cos(a) * rr;
      var y = cy + Math.sin(a) * rr;
      var n = (i % 9) + 1;
      var k = ring;
      var m = Math.floor(i / 9) % 3;
      var sz = 4 + (p999(n, k, m) % 18);
      var hue = (i * 40 + ring * 120 + t * 25 + N.emotion * 50) % 360;
      
      // Glow effect
      var glowGrad = ctx.createRadialGradient(x, y, 0, x, y, sz * 3);
      glowGrad.addColorStop(0, col(hue, 80, 60, 0.5));
      glowGrad.addColorStop(1, 'transparent');
      ctx.fillStyle = glowGrad;
      ctx.fillRect(x - sz * 3, y - sz * 3, sz * 6, sz * 6);
      
      // Shape
      ctx.beginPath();
      if (ring === 0) {
        // Circles
        ctx.arc(x, y, sz, 0, TAU);
      } else if (ring === 1) {
        // Triangles
        for (var p = 0; p < 3; p++) {
          var pa = p * TAU / 3 - TAU / 4 + a;
          if (p === 0) ctx.moveTo(x + Math.cos(pa) * sz, y + Math.sin(pa) * sz);
          else ctx.lineTo(x + Math.cos(pa) * sz, y + Math.sin(pa) * sz);
        }
        ctx.closePath();
      } else {
        // Nonagons (9-sided)
        for (var p = 0; p < 9; p++) {
          var pa = p * TAU / 9 + a;
          if (p === 0) ctx.moveTo(x + Math.cos(pa) * sz * 0.7, y + Math.sin(pa) * sz * 0.7);
          else ctx.lineTo(x + Math.cos(pa) * sz * 0.7, y + Math.sin(pa) * sz * 0.7);
        }
        ctx.closePath();
      }
      
      ctx.strokeStyle = col(hue, 80, 60, 0.8);
      ctx.lineWidth = 2;
      ctx.stroke();
      ctx.fillStyle = col(hue, 80, 55, 0.25);
      ctx.fill();
    }
  }
  
  // Core 999
  var cp = 1 + Math.sin(t * 3) * 0.25;
  
  // Core glow
  var coreGlow = ctx.createRadialGradient(cx, cy, 0, cx, cy, 60 * cp);
  coreGlow.addColorStop(0, col(baseHue, 80, 60, 0.5));
  coreGlow.addColorStop(0.5, col(baseHue + 30, 70, 50, 0.2));
  coreGlow.addColorStop(1, 'transparent');
  ctx.fillStyle = coreGlow;
  ctx.fillRect(cx - 80, cy - 80, 160, 160);
  
  // Three 9s
  ctx.font = 'bold ' + (32 * cp) + 'px Georgia, serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  for (var i = 0; i < 3; i++) {
    var a = i * TAU / 3 + t * 2;
    ctx.fillStyle = col(i * 120 + N.emotion * 30, 85, 65, 0.9);
    ctx.fillText('9', cx + Math.cos(a) * 20 * cp, cy + Math.sin(a) * 20 * cp);
  }
  
  // π spiral (999 points)
  ctx.beginPath();
  for (var i = 0; i < 999; i++) {
    var a = i * 0.1 + t * 0.8;
    var m = Math.floor(i / 333);
    var sr = Math.pow(PI, m) * i * 0.12;
    if (sr > r * 1.2) break;
    if (i === 0) ctx.moveTo(cx + Math.cos(a) * sr, cy + Math.sin(a) * sr);
    else ctx.lineTo(cx + Math.cos(a) * sr, cy + Math.sin(a) * sr);
  }
  ctx.strokeStyle = col(270, 60, 55, 0.4);
  ctx.lineWidth = 1.5;
  ctx.stroke();
  
  // Cursor interaction
  if (S.mouse.vel > 1 || S.mouse.down) {
    // 3^k ripples
    for (var k = 0; k < 3; k++) {
      var rippleR = Math.pow(3, k) * 12 * (1 + Math.sin(t * 6) * 0.3);
      ctx.beginPath();
      ctx.arc(mx, my, rippleR, 0, TAU);
      ctx.strokeStyle = col((t * 60) % 360, 85, 60, 0.5 - k * 0.15);
      ctx.lineWidth = 3 - k;
      ctx.stroke();
    }
    
    // 9 rays
    for (var i = 0; i < 9; i++) {
      var a = i * TAU / 9 + t;
      ctx.beginPath();
      ctx.moveTo(mx, my);
      ctx.lineTo(cx + Math.cos(a) * r * 0.5, cy + Math.sin(a) * r * 0.5);
      ctx.strokeStyle = col(i * 40, 70, 55, 0.25);
      ctx.lineWidth = 2;
      ctx.stroke();
    }
  }
  
  // Audio reactive
  if (S.audio.vol > 0.08) {
    var audioR = r * 0.18 + S.audio.vol * 60;
    var audioGrad = ctx.createRadialGradient(cx, cy, audioR * 0.5, cx, cy, audioR);
    audioGrad.addColorStop(0, col((S.audio.freq / 8) % 360, 85, 60, S.audio.vol * 0.6));
    audioGrad.addColorStop(1, 'transparent');
    ctx.beginPath();
    ctx.arc(cx, cy, audioR, 0, TAU);
    ctx.fillStyle = audioGrad;
    ctx.fill();
  }
}

// ═══════════════════════════════════════════════════════════════
// MAIN LOOP
// ═══════════════════════════════════════════════════════════════

var lastFrame = performance.now();

function loop() {
  var now = performance.now();
  var dt = Math.min((now - lastFrame) / 1000, 0.1);
  lastFrame = now;
  t += dt;
  
  readTime();
  readAudio();
  processNeural();
  draw();
  
  requestAnimationFrame(loop);
}

// ═══════════════════════════════════════════════════════════════
// INIT
// ═══════════════════════════════════════════════════════════════

initNeural();
initAudio();
loop();

console.log('VIBEE 999 | DPR: ' + DPR + ' | Pattern: n × 3^k × π^m');

})();
