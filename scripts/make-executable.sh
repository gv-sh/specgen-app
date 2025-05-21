#!/bin/bash

# SpecGen Package Deployment Script
echo "📦 Making files executable..."

# Make all shell scripts executable
find scripts -name "*.sh" -exec chmod +x {} \;

# Make CLI executable
chmod +x bin/cli.js

# Make sure the low memory scripts are executable
chmod +x scripts/setup-low-memory.sh
chmod +x scripts/production-low-memory.sh

echo "✅ All scripts are now executable"
