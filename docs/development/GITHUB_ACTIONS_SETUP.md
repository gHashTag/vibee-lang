# GitHub Actions Setup

**Дата**: 2026-01-11  
**Цель**: Настроить автоматический деплой через GitHub Actions

---

## 🚀 Overview

GitHub Actions автоматически деплоит autoposting service на Fly.io при изменениях в коде.

**Triggers**:
- Push to `main` branch
- Changes in autoposting files
- Manual trigger (workflow_dispatch)

**Actions**:
1. Build Docker image
2. Deploy to Fly.io
3. Check deployment status
4. Show logs

---

## 📋 Setup

### 1. Add Fly.io API Token to GitHub Secrets

**Get Token**:
```bash
# Login to Fly.io
fly auth login

# Get token
fly auth token
```

**Add to GitHub**:
1. Go to repository: https://github.com/gHashTag/vibee-lang
2. Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Name: `FLY_API_TOKEN`
5. Value: (paste your token)
6. Click "Add secret"

### 2. Verify Workflow File

**File**: `.github/workflows/deploy-autoposting.yml`

**Check**:
```bash
# View workflow
cat .github/workflows/deploy-autoposting.yml

# Should contain:
# - Checkout code
# - Setup Fly.io CLI
# - Deploy to Fly.io
# - Check status
# - Show logs
```

### 3. Test Workflow

**Option A: Push to main**:
```bash
# Make a change
echo "# Test" >> README.md

# Commit and push
git add README.md
git commit -m "test: trigger GitHub Actions"
git push origin main
```

**Option B: Manual trigger**:
1. Go to Actions tab
2. Select "Deploy Autoposting to Fly.io"
3. Click "Run workflow"
4. Select branch: `main`
5. Click "Run workflow"

### 4. Monitor Deployment

**GitHub UI**:
1. Go to Actions tab
2. Click on latest workflow run
3. Watch logs in real-time

**Expected output**:
```
✓ Checkout code
✓ Setup Fly.io CLI
✓ Deploy to Fly.io
  → Building image...
  → Pushing image...
  → Deploying...
  → Health checks passing
✓ Check deployment status
  → Status: running
  → Health: healthy
✓ Show recent logs
  → 🐝 VIBEE Autoposting Service
  → ✅ Configuration loaded
  → 🚀 Starting scheduler...
```

---

## 🔧 Workflow Configuration

### Triggers

**On Push**:
```yaml
on:
  push:
    branches:
      - main
    paths:
      - 'honeycomb/social/**'
      - 'honeycomb/autoposting/**'
      - 'gleam/src/vibee_autoposting.gleam'
      - 'config/autoposting.json'
      - 'Dockerfile.autoposting'
      - 'fly.autoposting.toml'
```

**Only triggers when autoposting files change**

**Manual Trigger**:
```yaml
on:
  workflow_dispatch:
```

**Allows manual deployment from GitHub UI**

### Steps

**1. Checkout**:
```yaml
- uses: actions/checkout@v4
```

**2. Setup Fly.io**:
```yaml
- uses: superfly/flyctl-actions/setup-flyctl@master
```

**3. Deploy**:
```yaml
- run: flyctl deploy -a vibee-autoposting
  env:
    FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

**4. Check Status**:
```yaml
- run: flyctl status -a vibee-autoposting
```

**5. Show Logs**:
```yaml
- run: flyctl logs -a vibee-autoposting --limit 50
  if: always()  # Run even if previous steps fail
```

---

## 🐛 Troubleshooting

### "FLY_API_TOKEN not found"

**Причина**: Secret не установлен

**Решение**:
1. Get token: `fly auth token`
2. Add to GitHub Secrets (see Setup step 1)
3. Re-run workflow

### "App not found: vibee-autoposting"

**Причина**: App не создан на Fly.io

**Решение**:
```bash
# Create app
fly apps create vibee-autoposting

# Set secrets
fly secrets set TELEGRAM_BOT_TOKEN="..." -a vibee-autoposting
fly secrets set TELEGRAM_CHAT_ID="@vibee_dev" -a vibee-autoposting

# Re-run workflow
```

### "Deployment failed"

**Причина**: Build error или health check failed

**Решение**:
1. Check logs in GitHub Actions
2. Test locally: `docker build -f Dockerfile.autoposting .`
3. Fix errors
4. Push again

### "Workflow not triggering"

**Причина**: Changes not in watched paths

**Решение**:
1. Check `paths:` in workflow file
2. Make sure your changes match
3. Or use manual trigger

---

## 📊 Monitoring

### GitHub Actions

**View runs**:
1. Go to Actions tab
2. See all workflow runs
3. Click on run to see details

**Metrics**:
- Success rate
- Duration
- Logs

### Fly.io

**Check status**:
```bash
fly status -a vibee-autoposting
```

**View logs**:
```bash
fly logs -a vibee-autoposting --follow
```

**Check health**:
```bash
fly checks list -a vibee-autoposting
```

---

## 🔄 Deployment Flow

```
1. Developer pushes to main
   ↓
2. GitHub Actions triggered
   ↓
3. Checkout code
   ↓
4. Setup Fly.io CLI
   ↓
5. Build Docker image
   ↓
6. Push to Fly.io registry
   ↓
7. Deploy to Fly.io
   ↓
8. Health checks
   ↓
9. Deployment complete
   ↓
10. Show logs
```

**Time**: ~2-3 minutes

---

## 🎯 Best Practices

### Secrets Management

**DO** ✅:
- Use GitHub Secrets for tokens
- Rotate tokens regularly (every 90 days)
- Use different tokens for dev/prod

**DON'T** ❌:
- Commit tokens to git
- Share tokens in chat
- Use same token everywhere

### Workflow Optimization

**DO** ✅:
- Only trigger on relevant file changes
- Cache dependencies
- Run tests before deploy
- Show logs on failure

**DON'T** ❌:
- Deploy on every commit
- Skip tests
- Ignore errors

### Monitoring

**DO** ✅:
- Check deployment status
- Monitor logs
- Set up alerts (email/Slack)

**DON'T** ❌:
- Assume deployment succeeded
- Ignore errors
- Skip monitoring

---

## 📝 Workflow Files

### Current Workflows

**1. deploy-autoposting.yml**:
- Deploys autoposting service
- Triggers on push to main
- Manual trigger available

**2. test.yml**:
- Runs tests
- Triggers on push/PR
- Checks formatting

### Adding New Workflows

**Create file**:
```bash
touch .github/workflows/my-workflow.yml
```

**Template**:
```yaml
name: My Workflow

on:
  push:
    branches:
      - main

jobs:
  my-job:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "Hello World"
```

---

## 🚀 Advanced Features

### Matrix Builds

**Test on multiple OS/versions**:
```yaml
strategy:
  matrix:
    os: [ubuntu-latest, macos-latest]
    gleam-version: ['1.0.0', '1.1.0']
```

### Conditional Steps

**Run only on success**:
```yaml
- name: Deploy
  if: success()
  run: flyctl deploy
```

**Run always**:
```yaml
- name: Show logs
  if: always()
  run: flyctl logs
```

### Caching

**Cache dependencies**:
```yaml
- uses: actions/cache@v3
  with:
    path: gleam/build
    key: ${{ runner.os }}-gleam-${{ hashFiles('gleam/gleam.toml') }}
```

### Notifications

**Slack notification**:
```yaml
- name: Notify Slack
  if: failure()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

---

## ✅ Checklist

### Setup
- [ ] Get Fly.io API token
- [ ] Add token to GitHub Secrets
- [ ] Verify workflow file exists
- [ ] Test manual trigger

### First Deployment
- [ ] Push to main
- [ ] Watch GitHub Actions
- [ ] Check deployment status
- [ ] Verify logs

### Monitoring
- [ ] Check workflow runs daily
- [ ] Monitor Fly.io status
- [ ] Review logs for errors
- [ ] Set up alerts (optional)

---

## 📚 Resources

**GitHub Actions**:
- [Documentation](https://docs.github.com/en/actions)
- [Workflow syntax](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions)
- [Marketplace](https://github.com/marketplace?type=actions)

**Fly.io**:
- [Documentation](https://fly.io/docs)
- [GitHub Actions](https://fly.io/docs/app-guides/continuous-deployment-with-github-actions/)
- [CLI reference](https://fly.io/docs/flyctl/)

---

**Status**: ✅ Ready to use  
**Next**: Add FLY_API_TOKEN to GitHub Secrets

**Created BY AI, FOR AI developers** 🤖🐝
