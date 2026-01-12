// VIBEE UI Server - Serves Canvas UI Kit with Component API
// Run: node vibee-ui-server.js

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 8080;

// Load components from JSON file
const components = require('./components.json');

// Request handler
const server = http.createServer((req, res) => {
  const url = req.url;
  
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  
  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }
  
  // Routes
  if (url === '/' || url === '/index.html') {
    // Serve main HTML
    fs.readFile(path.join(__dirname, 'vibee-ui-fullscreen.html'), (err, data) => {
      if (err) {
        res.writeHead(500, { 'Content-Type': 'text/plain' });
        res.end('Error loading page');
        return;
      }
      res.writeHead(200, { 'Content-Type': 'text/html' });
      res.end(data);
    });
  }
  else if (url === '/components') {
    // Serve components JSON
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(components));
  }
  else if (url === '/api/health') {
    // Health check
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'ok',
      version: '1.0.0',
      agent_api: true
    }));
  }
  else if (url === '/api/viewport' && req.method === 'POST') {
    // Viewport tracking
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      console.log('Viewport:', body);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: true, message: 'Viewport updated' }));
    });
  }
  else if (url === '/api/hover' && req.method === 'POST') {
    // Hover tracking
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      console.log('Hover:', body);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: true, message: 'Hover tracked' }));
    });
  }
  else if (url === '/api/click' && req.method === 'POST') {
    // Click tracking
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      console.log('Click:', body);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: true, message: 'Click simulated' }));
    });
  }
  else {
    // 404
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not Found');
  }
});

server.listen(PORT, () => {
  console.log(`🚀 VIBEE UI Server running at http://localhost:${PORT}/`);
  console.log(`📊 Components: ${components.length}`);
  console.log(`🎨 Canvas UI Kit with BEAM-style API`);
});
