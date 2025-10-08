#!/bin/bash

REPO_URL="https://github.com/lorenzotomasdiez/ccpm-gitlab.git"
TARGET_DIR=".claude"

echo "📦 Installing Claude Code PM - GitLab Edition"
echo "=============================================="
echo ""
echo "Cloning from $REPO_URL..."

git clone --depth 1 "$REPO_URL" "$TARGET_DIR"

if [ $? -eq 0 ]; then
    echo "✅ Clone successful"
    echo "🧹 Cleaning up..."
    rm -rf "$TARGET_DIR/.git" "$TARGET_DIR/.gitignore" "$TARGET_DIR/install"
    echo ""
    echo "✅ Installation complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Run: /pm:init"
    echo "  2. Run: /init"
    echo "  3. Start with: /pm:prd-new your-feature"
else
    echo "❌ Error: Failed to clone repository."
    exit 1
fi
