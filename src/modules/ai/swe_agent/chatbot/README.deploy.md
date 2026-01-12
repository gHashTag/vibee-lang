# 🚀 Deployment Guide

## Deploy to Vercel

### Option 1: Vercel CLI

```bash
# Install Vercel CLI
npm i -g vercel

# Login
vercel login

# Deploy
cd swe_agent/chatbot
vercel
```

### Option 2: Vercel Dashboard

1. Go to [vercel.com](https://vercel.com)
2. Click "New Project"
3. Import from GitHub: `gHashTag/vibee-lang`
4. Set root directory: `swe_agent/chatbot`
5. Framework: Vite
6. Click "Deploy"

### Environment Variables

No environment variables needed for basic deployment.

For backend integration:
- `VITE_API_URL` - Backend API URL
- `VITE_WS_URL` - WebSocket URL

## Deploy to Netlify

### Option 1: Netlify CLI

```bash
# Install Netlify CLI
npm i -g netlify-cli

# Login
netlify login

# Deploy
cd swe_agent/chatbot
netlify deploy --prod
```

### Option 2: Netlify Dashboard

1. Go to [netlify.com](https://netlify.com)
2. Click "Add new site"
3. Import from GitHub: `gHashTag/vibee-lang`
4. Base directory: `swe_agent/chatbot`
5. Build command: `npm run build`
6. Publish directory: `dist`
7. Click "Deploy"

## Deploy to GitHub Pages

```bash
cd swe_agent/chatbot

# Build
npm run build

# Deploy
npx gh-pages -d dist
```

## Custom Domain

### Vercel
1. Go to project settings
2. Click "Domains"
3. Add your domain
4. Update DNS records

### Netlify
1. Go to site settings
2. Click "Domain management"
3. Add custom domain
4. Update DNS records

## URLs

After deployment, your chatbot will be available at:
- Vercel: `https://vibee-swe-agent.vercel.app`
- Netlify: `https://vibee-swe-agent.netlify.app`
- GitHub Pages: `https://ghashtag.github.io/vibee-lang`

## Troubleshooting

### Build fails
- Check Node.js version (need 18+)
- Clear cache: `rm -rf node_modules && npm install`
- Check build logs

### 404 on routes
- Add `_redirects` file for Netlify
- Configure `vercel.json` for Vercel

### Environment variables not working
- Prefix with `VITE_` for Vite
- Restart dev server after changes
