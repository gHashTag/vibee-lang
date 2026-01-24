const react = require('@vitejs/plugin-react')

module.exports = {
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 5173
  }
}
