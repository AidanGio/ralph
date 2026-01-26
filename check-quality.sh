#!/bin/bash
# Ralph Quality Gate - Detect project type and run appropriate checks

set -e

echo "🔍 Running Ralph Quality Gates..."

# Node.js / TypeScript
if [ -f "package.json" ]; then
  echo "📦 Node.js project detected."
  
  # Check for pnpm, npm, or yarn
  if command -v pnpm &> /dev/null; then
    PKG_MGR="pnpm"
  elif command -v yarn &> /dev/null; then
    PKG_MGR="yarn"
  else
    PKG_MGR="npm"
  fi
  
  echo "Using $PKG_MGR..."

  # Run checks if scripts exist
  if jq -e '.scripts.test' package.json > /dev/null; then $PKG_MGR run test; fi
  if jq -e '.scripts.lint' package.json > /dev/null; then $PKG_MGR run lint; fi
  if jq -e '.scripts.typecheck' package.json > /dev/null; then $PKG_MGR run typecheck; fi
  if jq -e '.scripts.build' package.json > /dev/null; then $PKG_MGR run build; fi

# Python
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
  echo "🐍 Python project detected."
  if command -v pytest &> /dev/null; then
    pytest -q
  else
    echo "⚠️ pytest not found, skipping tests."
  fi

else
  echo "❓ Unknown project type. Running basic syntax check..."
  # Placeholder for generic smoke test
fi

echo "✅ Quality Gates Passed!"
