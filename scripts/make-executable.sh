#!/bin/bash

# SpecGen Package Deployment Script
echo "📦 Making files executable..."

# Make all shell scripts executable
find scripts -name "*.sh" -exec chmod +x {} \;

# Make CLI executable
chmod +x bin/cli.js

echo "✅ All scripts are now executable"