#!/usr/bin/env bash
# VIBEE Dogfooding System Setup Script
# Installs git hooks and verifies configuration

set -e

echo "🐕 VIBEE Dogfooding System Setup"
echo "================================"
echo ""

# Check if we're in a git repository
if [ ! -d ".git" ]; then
  echo "❌ Error: Not a git repository"
  echo "   Run this script from the repository root"
  exit 1
fi

echo "✅ Git repository detected"
echo ""

# Check if Gleam is installed
if ! command -v gleam &> /dev/null; then
  echo "❌ Error: Gleam not found"
  echo "   Install Gleam: https://gleam.run/getting-started/installing/"
  exit 1
fi

echo "✅ Gleam found: $(gleam --version)"
echo ""

# Build the project
echo "🔨 Building VIBEE..."
gleam build
echo "✅ Build successful"
echo ""

# Install git hooks
echo "🪝 Installing git hooks..."
gleam run -m honeycomb/dogfooding/cli -- install-hooks

if [ $? -eq 0 ]; then
  echo "✅ Git hooks installed"
else
  echo "❌ Failed to install git hooks"
  exit 1
fi

echo ""

# Verify hooks are executable
echo "🔍 Verifying hooks..."
if [ -x ".git/hooks/pre-commit" ]; then
  echo "✅ pre-commit hook is executable"
else
  echo "⚠️  pre-commit hook is not executable, fixing..."
  chmod +x .git/hooks/pre-commit
fi

if [ -x ".git/hooks/pre-push" ]; then
  echo "✅ pre-push hook is executable"
else
  echo "⚠️  pre-push hook is not executable, fixing..."
  chmod +x .git/hooks/pre-push
fi

echo ""

# Run initial scan
echo "🔍 Running initial scan..."
gleam run -m honeycomb/dogfooding/cli -- scan honeycomb/

if [ $? -eq 0 ]; then
  echo "✅ No violations found"
else
  echo "⚠️  Violations found - run 'gleam run -m honeycomb/dogfooding/cli -- fix honeycomb/' to auto-fix"
fi

echo ""
echo "================================"
echo "✅ Setup complete!"
echo ""
echo "Usage:"
echo "  Scan:      gleam run -m honeycomb/dogfooding/cli -- scan honeycomb/"
echo "  Fix:       gleam run -m honeycomb/dogfooding/cli -- fix honeycomb/"
echo "  Status:    gleam run -m honeycomb/dogfooding/cli -- status"
echo "  Uninstall: gleam run -m honeycomb/dogfooding/cli -- uninstall-hooks"
echo ""
echo "Bypass hooks (emergency only):"
echo "  git commit --no-verify"
echo "  git push --no-verify"
echo ""
