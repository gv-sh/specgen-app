#!/bin/bash

# Diagnose and fix CSS issues
set -e

echo "🔍 Diagnosing CSS issues..."

# Check admin app
echo "=== Admin App ==="
if [ -d "admin/src" ]; then
    echo "CSS files found:"
    find admin/src -name "*.css" -o -name "*.scss" 2>/dev/null || echo "No CSS files found"
    
    echo "Tailwind config:"
    if [ -f "admin/tailwind.config.js" ]; then
        echo "✓ tailwind.config.js exists"
    else
        echo "❌ No tailwind.config.js"
    fi
    
    echo "Package.json for CSS dependencies:"
    if [ -f "admin/package.json" ]; then
        grep -E "(tailwind|css)" admin/package.json || echo "No CSS dependencies found"
    fi
fi

echo ""
echo "=== User App ==="
if [ -d "user/src" ]; then
    echo "CSS files found:"
    find user/src -name "*.css" -o -name "*.scss" 2>/dev/null || echo "No CSS files found"
    
    echo "Tailwind config:"
    if [ -f "user/tailwind.config.js" ]; then
        echo "✓ tailwind.config.js exists"
    else
        echo "❌ No tailwind.config.js"
    fi
    
    echo "Package.json for CSS dependencies:"
    if [ -f "user/package.json" ]; then
        grep -E "(tailwind|css)" user/package.json || echo "No CSS dependencies found"
    fi
fi

# Try to fix missing CSS imports
echo ""
echo "🔧 Attempting CSS fixes..."

# Check and fix main CSS imports
if [ -f "admin/src/index.js" ]; then
    if ! grep -q "index.css" admin/src/index.js; then
        echo "Adding CSS import to admin/src/index.js..."
        sed -i.bak '1i\
import '\''./index.css'\'';
' admin/src/index.js
    fi
fi

if [ -f "user/src/index.js" ]; then
    if ! grep -q "index.css" user/src/index.js; then
        echo "Adding CSS import to user/src/index.js..."
        sed -i.bak '1i\
import '\''./index.css'\'';
' user/src/index.js
    fi
fi

# Check for App.css imports
if [ -f "admin/src/App.js" ] && [ -f "admin/src/App.css" ]; then
    if ! grep -q "App.css" admin/src/App.js; then
        echo "Adding App.css import to admin..."
        sed -i.bak '2i\
import '\''./App.css'\'';
' admin/src/App.js
    fi
fi

if [ -f "user/src/App.js" ] && [ -f "user/src/App.css" ]; then
    if ! grep -q "App.css" user/src/App.js; then
        echo "Adding App.css import to user..."
        sed -i.bak '2i\
import '\''./App.css'\'';
' user/src/App.js
    fi
fi

echo "✅ CSS diagnosis complete!"
