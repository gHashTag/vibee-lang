// ═══════════════════════════════════════════════════════════════
// GEN UI LIVING DATA — СВЯЩЕННАЯ ФОРМУЛА: V = n × 3^k × π^m
// ═══════════════════════════════════════════════════════════════
// 27 источников данных (3³) | Реальные криптовалюты | Глобальные метрики
// arXiv: 2507.11599, 2403.18183, 2312.17642, 2201.02441
// ═══════════════════════════════════════════════════════════════

const V = {n: 999, k: 9, m: 3};
const PHI = 1.618033988749895;
const PI = Math.PI;
const TAU = PI * 2;

// Данные криптовалют
const CRYPTO_DATA = {
  BTC: {price: 0, change: 0, volume: 0, color: '#F7931A', name: 'Bitcoin'},
  ETH: {price: 0, change: 0, volume: 0, color: '#627EEA', name: 'Ethereum'},
  SOL: {price: 0, change: 0, volume: 0, color: '#00FFA3', name: 'Solana'},
  BNB: {price: 0, change: 0, volume: 0, color: '#F3BA2F', name: 'BNB'},
  XRP: {price: 0, change: 0, volume: 0, color: '#23292F', name: 'XRP'},
  ADA: {price: 0, change: 0, volume: 0, color: '#0033AD', name: 'Cardano'},
  DOGE: {price: 0, change: 0, volume: 0, color: '#C2A633', name: 'Dogecoin'},
  MATIC: {price: 0, change: 0, volume: 0, color: '#8247E5', name: 'Polygon'},
  LTC: {price: 0, change: 0, volume: 0, color: '#345D9D', name: 'Litecoin'}
};

// Глобальные метрики (симулированные)
const GLOBAL_DATA = {
  population: 8100000000,
  internetUsers: 5300000000,
  sp500: 5200,
  gold: 2650,
  vix: 15,
  co2: 424,
  tweets: 6000,
  energy: 580
};

class LivingDataScreen {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.dpr = Math.min(window.devicePixelRatio || 1, 3);
    this.resize();
    this.time = 0;
    this.particles = [];
    this.transactions = [];
    this.priceHistory = [];
    this.audioData = new Float32Array(27);
    this.dataStreams = new Float32Array(27);
    this.wsConnections = [];
    
    this.initParticles(999);
    this.initAudio();
    this.initWebSockets();
    this.initSimulatedData();
    this.setupEvents();
    
    this.mouse = {x: 0, y: 0, active: false};
  }

  resize() {
    const w = window.innerWidth;
    const h = window.innerHeight;
    this.canvas.width = w * this.dpr;
    this.canvas.height = h * this.dpr;
    this.canvas.style.width = w + 'px';
    this.canvas.style.height = h + 'px';
    this.ctx.scale(this.dpr, this.dpr);
    this.w = w;
    this.h = h;
    this.cx = w / 2;
    this.cy = h / 2;
  }

  initParticles(count) {
    for (let i = 0; i < count; i++) {
      const angle = (i / count) * TAU * PHI;
      const r = Math.sqrt(i / count) * Math.min(this.w, this.h) * 0.35;
      this.particles.push({
        x: this.cx + Math.cos(angle) * r,
        y: this.cy + Math.sin(angle) * r,
        vx: 0, vy: 0,
        size: 1 + Math.random() * 2,
        hue: (i / count) * 360,
        crypto: Object.keys(CRYPTO_DATA)[i % 9]
      });
    }
  }

  async initAudio() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({audio: true});
      this.audioCtx = new AudioContext();
      const source = this.audioCtx.createMediaStreamSource(stream);
      this.analyser = this.audioCtx.createAnalyser();
      this.analyser.fftSize = 2048;
      this.analyser.smoothingTimeConstant = 0.8;
      source.connect(this.analyser);
      this.freqData = new Uint8Array(this.analyser.frequencyBinCount);
    } catch (e) {
      console.log('Audio not available');
    }
  }

  initWebSockets() {
    const symbols = ['btcusdt', 'ethusdt', 'solusdt', 'bnbusdt', 'xrpusdt', 'adausdt', 'dogeusdt', 'maticusdt', 'ltcusdt'];
    const cryptoKeys = Object.keys(CRYPTO_DATA);
    
    symbols.forEach((symbol, i) => {
      try {
        const ws = new WebSocket(`wss://stream.binance.com:9443/ws/${symbol}@trade`);
        ws.onmessage = (event) => {
          const data = JSON.parse(event.data);
          const key = cryptoKeys[i];
          const oldPrice = CRYPTO_DATA[key].price;
          CRYPTO_DATA[key].price = parseFloat(data.p);
          CRYPTO_DATA[key].volume += parseFloat(data.q);
          if (oldPrice > 0) {
            CRYPTO_DATA[key].change = ((CRYPTO_DATA[key].price - oldPrice) / oldPrice) * 100;
          }
          
          // Добавляем транзакцию как частицу
          if (parseFloat(data.q) > 0.01) {
            this.addTransaction(key, parseFloat(data.q), parseFloat(data.p));
          }
          
          // Обновляем историю цен для BTC
          if (key === 'BTC') {
            this.priceHistory.push(CRYPTO_DATA[key].price);
            if (this.priceHistory.length > 999) this.priceHistory.shift();
          }
        };
        ws.onerror = () => console.log(`WS error: ${symbol}`);
        this.wsConnections.push(ws);
      } catch (e) {
        console.log(`Failed to connect: ${symbol}`);
      }
    });
  }

  initSimulatedData() {
    // Симуляция глобальных данных
    setInterval(() => {
      GLOBAL_DATA.population += Math.floor(Math.random() * 5);
      GLOBAL_DATA.internetUsers += Math.floor(Math.random() * 1000 - 500);
      GLOBAL_DATA.sp500 += (Math.random() - 0.5) * 2;
      GLOBAL_DATA.gold += (Math.random() - 0.5) * 5;
      GLOBAL_DATA.vix += (Math.random() - 0.5) * 0.5;
      GLOBAL_DATA.tweets = 5000 + Math.random() * 2000;
    }, 1000);
  }

  addTransaction(crypto, amount, price) {
    const angle = Math.random() * TAU;
    const r = Math.min(this.w, this.h) * 0.3;
    this.transactions.push({
      x: this.cx + Math.cos(angle) * r,
      y: this.cy + Math.sin(angle) * r,
      vx: (Math.random() - 0.5) * 2,
      vy: (Math.random() - 0.5) * 2,
      size: Math.min(10, Math.log(amount + 1) * 3),
      color: CRYPTO_DATA[crypto].color,
      life: 1,
      crypto: crypto
    });
    if (this.transactions.length > 100) this.transactions.shift();
  }

  setupEvents() {
    window.addEventListener('resize', () => this.resize());
    window.addEventListener('mousemove', e => {
      this.mouse.x = e.clientX;
      this.mouse.y = e.clientY;
      this.mouse.active = true;
    });
    window.addEventListener('touchmove', e => {
      this.mouse.x = e.touches[0].clientX;
      this.mouse.y = e.touches[0].clientY;
      this.mouse.active = true;
    });
  }

  getAudioBands() {
    if (!this.analyser) return;
    this.analyser.getByteFrequencyData(this.freqData);
    const bands = 27;
    const binSize = Math.floor(this.freqData.length / bands);
    for (let i = 0; i < bands; i++) {
      let sum = 0;
      for (let j = 0; j < binSize; j++) {
        sum += this.freqData[i * binSize + j];
      }
      this.audioData[i] = this.audioData[i] * 0.7 + (sum / binSize / 255) * 0.3;
    }
  }

  updateDataStreams() {
    // Маппинг данных на 27 потоков
    const cryptoKeys = Object.keys(CRYPTO_DATA);
    cryptoKeys.forEach((key, i) => {
      const change = Math.abs(CRYPTO_DATA[key].change) || 0;
      this.dataStreams[i] = Math.min(1, change / 5);
    });
    // Глобальные данные
    this.dataStreams[9] = (GLOBAL_DATA.sp500 % 100) / 100;
    this.dataStreams[10] = (GLOBAL_DATA.gold % 100) / 100;
    this.dataStreams[11] = GLOBAL_DATA.vix / 50;
    this.dataStreams[12] = (GLOBAL_DATA.tweets / 10000);
    // Остальные
    for (let i = 13; i < 27; i++) {
      this.dataStreams[i] = Math.sin(this.time + i) * 0.5 + 0.5;
    }
  }

  drawBackground() {
    const vix = GLOBAL_DATA.vix;
    const fear = Math.min(1, vix / 30);
    const g = this.ctx.createRadialGradient(this.cx, this.cy, 0, this.cx, this.cy, this.w * 0.7);
    g.addColorStop(0, `rgba(${10 + fear * 20}, 0, ${20 - fear * 10}, 1)`);
    g.addColorStop(0.5, `rgba(${5 + fear * 10}, 0, ${10 - fear * 5}, 1)`);
    g.addColorStop(1, '#000000');
    this.ctx.fillStyle = g;
    this.ctx.fillRect(0, 0, this.w, this.h);
  }

  drawSacredFormula() {
    this.ctx.font = 'bold 28px monospace';
    this.ctx.textAlign = 'center';
    const btcChange = CRYPTO_DATA.BTC.change || 0;
    const hue = btcChange > 0 ? 120 : (btcChange < 0 ? 0 : 60);
    this.ctx.fillStyle = `hsla(${hue}, 80%, 60%, 0.9)`;
    this.ctx.shadowColor = this.ctx.fillStyle;
    this.ctx.shadowBlur = 20;
    this.ctx.fillText('V = n × 3^k × π^m', this.cx, 35);
    this.ctx.shadowBlur = 0;
    
    this.ctx.font = '12px monospace';
    this.ctx.fillStyle = '#666';
    const Vval = V.n * Math.pow(3, V.k) * Math.pow(PI, V.m);
    this.ctx.fillText(`V = ${V.n} × 3^${V.k} × π^${V.m} ≈ ${Vval.toExponential(2)}`, this.cx, 55);
  }

  drawTrinityCore() {
    const btc = CRYPTO_DATA.BTC;
    const priceNorm = btc.price > 0 ? Math.log10(btc.price) / 5 : 0.5;
    const change = btc.change || 0;
    const pulse = 1 + Math.sin(this.time * 3) * 0.1 + Math.abs(change) * 0.05;
    const size = 25 * pulse * (0.5 + priceNorm);
    
    // Цвет по изменению цены
    const hue = change > 0 ? 120 : (change < 0 ? 0 : 45);
    
    const g = this.ctx.createRadialGradient(this.cx, this.cy, 0, this.cx, this.cy, size * 3);
    g.addColorStop(0, `hsla(${hue}, 100%, 70%, 1)`);
    g.addColorStop(0.3, `hsla(${hue}, 90%, 50%, 0.6)`);
    g.addColorStop(0.6, `hsla(${hue + 30}, 80%, 30%, 0.3)`);
    g.addColorStop(1, 'transparent');
    
    this.ctx.fillStyle = g;
    this.ctx.beginPath();
    this.ctx.arc(this.cx, this.cy, size * 3, 0, TAU);
    this.ctx.fill();
    
    // BTC символ
    this.ctx.fillStyle = '#FFF';
    this.ctx.font = 'bold 16px monospace';
    this.ctx.textAlign = 'center';
    this.ctx.fillText('₿', this.cx, this.cy + 6);
  }

  drawTrinityRings() {
    const rings = [
      {count: 3, cryptos: ['ETH', 'SOL', 'BNB'], k: 1},
      {count: 9, cryptos: Object.keys(CRYPTO_DATA), k: 2},
      {count: 27, cryptos: null, k: 3}
    ];
    
    const baseRadius = Math.min(this.w, this.h) * 0.1;
    
    rings.forEach((ring, ringIdx) => {
      const radius = baseRadius * (ringIdx + 1.5);
      const rotation = this.time * (ringIdx % 2 ? 0.3 : -0.3);
      
      for (let i = 0; i < ring.count; i++) {
        const angle = (i / ring.count) * TAU + rotation;
        const x = this.cx + Math.cos(angle) * radius;
        const y = this.cy + Math.sin(angle) * radius;
        
        let color, size, data;
        if (ring.cryptos && i < ring.cryptos.length) {
          const key = ring.cryptos[i % ring.cryptos.length];
          const crypto = CRYPTO_DATA[key];
          color = crypto.color;
          const change = Math.abs(crypto.change || 0);
          size = 6 - ringIdx + change * 2;
          data = crypto;
        } else {
          const streamIdx = i % 27;
          const hue = (streamIdx / 27) * 360;
          color = `hsl(${hue}, 70%, 50%)`;
          size = 4 + this.dataStreams[streamIdx] * 4;
        }
        
        // Свечение
        const g = this.ctx.createRadialGradient(x, y, 0, x, y, size * 2);
        g.addColorStop(0, color);
        g.addColorStop(0.5, color + '44');
        g.addColorStop(1, 'transparent');
        this.ctx.fillStyle = g;
        this.ctx.beginPath();
        this.ctx.arc(x, y, size * 2, 0, TAU);
        this.ctx.fill();
        
        // Ядро
        this.ctx.fillStyle = color;
        this.ctx.beginPath();
        this.ctx.arc(x, y, size, 0, TAU);
        this.ctx.fill();
      }
    });
  }

  drawPriceSpiral() {
    if (this.priceHistory.length < 10) return;
    
    const points = Math.min(999, this.priceHistory.length);
    const maxR = Math.min(this.w, this.h) * 0.32;
    const minPrice = Math.min(...this.priceHistory);
    const maxPrice = Math.max(...this.priceHistory);
    const priceRange = maxPrice - minPrice || 1;
    
    this.ctx.beginPath();
    for (let i = 0; i < points; i++) {
      const t = i / points;
      const angle = t * TAU * PI + this.time * 0.5;
      const r = t * maxR;
      const priceNorm = (this.priceHistory[i] - minPrice) / priceRange;
      const x = this.cx + Math.cos(angle) * r * (0.8 + priceNorm * 0.4);
      const y = this.cy + Math.sin(angle) * r * (0.8 + priceNorm * 0.4);
      
      if (i === 0) this.ctx.moveTo(x, y);
      else this.ctx.lineTo(x, y);
    }
    
    const gradient = this.ctx.createLinearGradient(0, 0, this.w, this.h);
    gradient.addColorStop(0, '#F7931A44');
    gradient.addColorStop(1, '#627EEA44');
    this.ctx.strokeStyle = gradient;
    this.ctx.lineWidth = 1.5;
    this.ctx.stroke();
  }

  drawTransactions() {
    this.transactions.forEach((tx, i) => {
      tx.x += tx.vx;
      tx.y += tx.vy;
      tx.vx *= 0.98;
      tx.vy *= 0.98;
      tx.life -= 0.01;
      
      if (tx.life > 0) {
        this.ctx.globalAlpha = tx.life;
        this.ctx.fillStyle = tx.color;
        this.ctx.beginPath();
        this.ctx.arc(tx.x, tx.y, tx.size * tx.life, 0, TAU);
        this.ctx.fill();
        this.ctx.globalAlpha = 1;
      }
    });
    
    this.transactions = this.transactions.filter(tx => tx.life > 0);
  }

  drawParticles() {
    this.particles.forEach(p => {
      const crypto = CRYPTO_DATA[p.crypto];
      const change = crypto ? Math.abs(crypto.change || 0) : 0;
      const force = 0.1 + change * 0.1;
      
      const dx = this.cx - p.x;
      const dy = this.cy - p.y;
      const dist = Math.sqrt(dx * dx + dy * dy) || 1;
      
      p.vx += dx / dist * force;
      p.vy += dy / dist * force;
      
      if (this.mouse.active) {
        const mdx = this.mouse.x - p.x;
        const mdy = this.mouse.y - p.y;
        const mdist = Math.sqrt(mdx * mdx + mdy * mdy) || 1;
        if (mdist < 120) {
          p.vx -= mdx / mdist * 2;
          p.vy -= mdy / mdist * 2;
        }
      }
      
      p.vx *= 0.96;
      p.vy *= 0.96;
      p.x += p.vx;
      p.y += p.vy;
      
      const color = crypto ? crypto.color : `hsl(${p.hue}, 70%, 50%)`;
      this.ctx.fillStyle = color + '88';
      this.ctx.beginPath();
      this.ctx.arc(p.x, p.y, p.size, 0, TAU);
      this.ctx.fill();
    });
  }

  drawDataBars() {
    const barWidth = 6;
    const maxHeight = 50;
    const startX = 15;
    const startY = this.h - 70;
    
    for (let i = 0; i < 27; i++) {
      const height = (this.dataStreams[i] + this.audioData[i]) * maxHeight;
      const hue = (i / 27) * 360;
      
      this.ctx.fillStyle = `hsla(${hue}, 80%, 50%, 0.8)`;
      this.ctx.fillRect(startX + i * (barWidth + 1), startY - height, barWidth, height);
    }
    
    this.ctx.font = '9px monospace';
    this.ctx.fillStyle = '#555';
    this.ctx.textAlign = 'left';
    this.ctx.fillText('27 DATA STREAMS (3³)', startX, startY + 12);
  }

  drawCryptoPanel() {
    const x = 15;
    let y = 80;
    
    this.ctx.font = 'bold 11px monospace';
    this.ctx.fillStyle = '#F7931A';
    this.ctx.textAlign = 'left';
    this.ctx.fillText('═══ CRYPTO LIVE ═══', x, y);
    
    y += 18;
    this.ctx.font = '10px monospace';
    
    Object.entries(CRYPTO_DATA).slice(0, 6).forEach(([key, data]) => {
      const price = data.price > 0 ? data.price.toFixed(2) : '---';
      const change = data.change ? data.change.toFixed(2) : '0.00';
      const changeColor = data.change > 0 ? '#00FF00' : (data.change < 0 ? '#FF4444' : '#888');
      
      this.ctx.fillStyle = data.color;
      this.ctx.fillText(`${key}:`, x, y);
      this.ctx.fillStyle = '#FFF';
      this.ctx.fillText(`$${price}`, x + 45, y);
      this.ctx.fillStyle = changeColor;
      this.ctx.fillText(`${change > 0 ? '+' : ''}${change}%`, x + 110, y);
      y += 14;
    });
  }

  drawGlobalPanel() {
    const x = this.w - 160;
    let y = 80;
    
    this.ctx.font = 'bold 11px monospace';
    this.ctx.fillStyle = '#00BFFF';
    this.ctx.textAlign = 'left';
    this.ctx.fillText('═══ GLOBAL ═══', x, y);
    
    y += 18;
    this.ctx.font = '10px monospace';
    
    const metrics = [
      {name: 'Population', value: GLOBAL_DATA.population.toLocaleString(), color: '#00FF00'},
      {name: 'S&P 500', value: GLOBAL_DATA.sp500.toFixed(2), color: '#00C805'},
      {name: 'Gold', value: '$' + GLOBAL_DATA.gold.toFixed(2), color: '#FFD700'},
      {name: 'VIX', value: GLOBAL_DATA.vix.toFixed(2), color: GLOBAL_DATA.vix > 20 ? '#FF4444' : '#00FF00'},
      {name: 'Tweets/s', value: Math.floor(GLOBAL_DATA.tweets).toLocaleString(), color: '#1DA1F2'}
    ];
    
    metrics.forEach(m => {
      this.ctx.fillStyle = '#888';
      this.ctx.fillText(m.name + ':', x, y);
      this.ctx.fillStyle = m.color;
      this.ctx.fillText(m.value, x + 70, y);
      y += 14;
    });
  }

  drawStats() {
    this.ctx.font = '10px monospace';
    this.ctx.textAlign = 'right';
    this.ctx.fillStyle = '#444';
    this.ctx.fillText(`Particles: ${this.particles.length}`, this.w - 15, this.h - 30);
    this.ctx.fillText(`Transactions: ${this.transactions.length}`, this.w - 15, this.h - 18);
    this.ctx.fillText(`WS: ${this.wsConnections.filter(ws => ws.readyState === 1).length}/9`, this.w - 15, this.h - 6);
  }

  render() {
    this.time += 0.016;
    this.getAudioBands();
    this.updateDataStreams();
    
    this.drawBackground();
    this.drawPriceSpiral();
    this.drawTrinityRings();
    this.drawParticles();
    this.drawTransactions();
    this.drawTrinityCore();
    this.drawSacredFormula();
    this.drawDataBars();
    this.drawCryptoPanel();
    this.drawGlobalPanel();
    this.drawStats();
    
    requestAnimationFrame(() => this.render());
  }

  start() {
    this.render();
  }
}

window.addEventListener('load', () => {
  const canvas = document.getElementById('c');
  if (canvas) {
    const screen = new LivingDataScreen(canvas);
    screen.start();
  }
});
