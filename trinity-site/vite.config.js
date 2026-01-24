import react from '@vitejs/plugin-react'
export default {
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 5173
  }
}
