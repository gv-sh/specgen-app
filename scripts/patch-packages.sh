#!/bin/bash

# Fix package scripts after extraction with proper CSS handling
set -e

echo "Patching package.json files..."

# Fix user package start script
if [ -f "user/package.json" ]; then
    echo "Fixing user package start script..."
    # Use SKIP_PREFLIGHT_CHECK=true to avoid version conflicts
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed 's/node scripts\/start.js/SKIP_PREFLIGHT_CHECK=true react-scripts start/g' user/package.json > user/package.json.tmp
    else
        sed 's/node scripts\/start.js/SKIP_PREFLIGHT_CHECK=true react-scripts start/g' user/package.json > user/package.json.tmp
    fi
    mv user/package.json.tmp user/package.json
fi

# Fix admin package start script if needed  
if [ -f "admin/package.json" ]; then
    echo "Fixing admin package start script..."
    # Also add SKIP_PREFLIGHT_CHECK for admin
    if grep -q "node scripts/start.js" admin/package.json; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed 's/node scripts\/start.js/SKIP_PREFLIGHT_CHECK=true react-scripts start/g' admin/package.json > admin/package.json.tmp
        else
            sed 's/node scripts\/start.js/SKIP_PREFLIGHT_CHECK=true react-scripts start/g' admin/package.json > admin/package.json.tmp
        fi
        mv admin/package.json.tmp admin/package.json
    fi
fi

# Ensure proper scripts are in place
echo "Adding development environment handling..."

# Create a simple start override for user
cat > user/start-dev.js << 'EOF'
// Development server starter with proper env handling
process.env.NODE_ENV = 'development';
process.env.SKIP_PREFLIGHT_CHECK = 'true';
require('react-scripts/scripts/start');
EOF

echo "Package patching complete!"
