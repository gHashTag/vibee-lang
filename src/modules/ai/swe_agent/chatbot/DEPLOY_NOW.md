# 🚀 Deploy to Production NOW

## Quick Deploy Options

### Option 1: Vercel (Recommended - 2 minutes)

1. **Install Vercel CLI** (if not installed):
   ```bash
   npm install -g vercel
   ```

2. **Deploy**:
   ```bash
   cd swe_agent/chatbot
   vercel --prod
   ```

3. **Set Environment Variable**:
   ```bash
   vercel env add VITE_API_URL production
   # Enter: https://vibee-mcp.fly.dev
   ```

4. **Redeploy with env**:
   ```bash
   vercel --prod
   ```

### Option 2: Netlify (Alternative - 2 minutes)

1. **Install Netlify CLI**:
   ```bash
   npm install -g netlify-cli
   ```

2. **Deploy**:
   ```bash
   cd swe_agent/chatbot
   netlify deploy --prod
   ```

3. **Set Environment Variable** in Netlify dashboard:
   - Go to Site settings → Environment variables
   - Add: `VITE_API_URL` = `https://vibee-mcp.fly.dev`

### Option 3: GitHub Actions (Automated)

Already configured! Just push to `main` branch:

```bash
git push origin main
```

Vercel will auto-deploy from GitHub.

### Option 4: Vercel Dashboard (No CLI)

1. Go to [vercel.com](https://vercel.com)
2. Click "Add New Project"
3. Import from GitHub: `gHashTag/vibee-lang`
4. Set Root Directory: `swe_agent/chatbot`
5. Add Environment Variable:
   - `VITE_API_URL` = `https://vibee-mcp.fly.dev`
6. Click "Deploy"

## Verify Deployment

After deployment, check:

1. **Frontend URL**: Should show chatbot UI
2. **Backend Status**: Should show "● Online" (green) in header
3. **Test Agent Mode**: Try "Create a todo app with React"
4. **Test Chat Mode**: Try "Explain VIBEE DSL"

## Current Status

✅ Code committed and pushed to GitHub
✅ API integration complete
✅ Backend health check working
✅ Mock mode fallback ready

⏳ Waiting for production deployment

## Production URLs

- **Frontend**: Will be `https://swe-agent-chatbot.vercel.app` (or custom domain)
- **Backend**: `https://vibee-mcp.fly.dev`

## Troubleshooting

**If backend shows "Mock Mode":**
- Check `VITE_API_URL` environment variable is set
- Verify backend is running: `curl https://vibee-mcp.fly.dev/health`
- Check browser console for CORS errors

**If deployment fails:**
- Verify `package.json` has correct build script
- Check Node.js version compatibility (18+)
- Review build logs in Vercel/Netlify dashboard
