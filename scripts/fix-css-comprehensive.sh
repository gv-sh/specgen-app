#!/bin/bash

# Comprehensive CSS and development fix
set -e

echo "🎨 Fixing CSS and styling issues comprehensively..."

# Function to fix a React app
fix_react_app() {
    local app_dir=$1
    echo "Fixing $app_dir..."
    
    cd "$app_dir"
    
    # Ensure proper CSS imports in index.js/App.js
    if [ -f "src/index.js" ]; then
        # Check if index.css import exists
        if ! grep -q "index.css" src/index.js; then
            echo "Adding CSS import to index.js..."
            sed -i.bak '1i\
import '\''./index.css'\'';
' src/index.js
        fi
    fi
    
    # Check for Tailwind config
    if [ -f "tailwind.config.js" ]; then
        echo "Tailwind config found, rebuilding CSS..."
        # Ensure Tailwind imports in main CSS file
        if [ -f "src/index.css" ]; then
            if ! grep -q "@tailwind" src/index.css; then
                echo "Adding Tailwind directives..."
                cat > src/index.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;
EOF
            fi
        fi
    fi
    
    # Clear all caches
    rm -rf node_modules/.cache build .eslintcache || true
    
    # Reinstall dependencies
    npm install
    
    cd ..
}

# Fix both apps
fix_react_app "admin"
fix_react_app "user"

# Create a development env file to force proper CSS loading
cat > .env.development << 'EOF'
GENERATE_SOURCEMAP=true
SKIP_PREFLIGHT_CHECK=true
EOF

echo "✅ CSS fix complete! Restart dev servers now."
