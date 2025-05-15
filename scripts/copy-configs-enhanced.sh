#!/bin/bash

# Enhanced config copying with CSS handling
set -e

echo "🎨 Copying enhanced configs and CSS from source repositories..."

# Function to download a file from GitHub
download_file() {
    local repo=$1
    local file_path=$2
    local dest_path=$3
    local url="https://raw.githubusercontent.com/gv-sh/${repo}/main/${file_path}"
    
    echo "Downloading ${file_path} from ${repo}..."
    curl -s "$url" -o "$dest_path" || echo "Warning: Failed to download $file_path"
}

# Copy files for admin
if [ -d "admin" ]; then
    echo "=== Copying admin configs ==="
    
    # Essential config files
    download_file "specgen-admin" "tailwind.config.js" "admin/tailwind.config.js"
    download_file "specgen-admin" "postcss.config.js" "admin/postcss.config.js"
    
    # Create src directory if it doesn't exist
    mkdir -p admin/src
    
    # CSS files
    download_file "specgen-admin" "src/index.css" "admin/src/index.css"
    download_file "specgen-admin" "src/App.css" "admin/src/App.css"
    
    # Get the actual index.js to ensure proper imports
    if [ -f "admin/src/index.js" ]; then
        # Backup current file
        cp admin/src/index.js admin/src/index.js.bak
        # Download the source version
        download_file "specgen-admin" "src/index.js" "admin/src/index.js.source"
        
        # Extract just the imports from source and prepend to current file
        if [ -f "admin/src/index.js.source" ]; then
            # Get CSS imports from source
            grep "import.*css" admin/src/index.js.source > admin/src/css-imports.tmp || true
            # Combine with existing file
            cat admin/src/css-imports.tmp admin/src/index.js.bak > admin/src/index.js || cp admin/src/index.js.bak admin/src/index.js
            rm -f admin/src/index.js.source admin/src/css-imports.tmp
        fi
    fi
fi

# Copy files for user
if [ -d "user" ]; then
    echo "=== Copying user configs ==="
    
    # Essential config files
    download_file "specgen-user" "tailwind.config.js" "user/tailwind.config.js"
    download_file "specgen-user" "postcss.config.js" "user/postcss.config.js"
    
    # Create src directory if it doesn't exist
    mkdir -p user/src
    
    # CSS files
    download_file "specgen-user" "src/index.css" "user/src/index.css"
    download_file "specgen-user" "src/App.css" "user/src/App.css"
    
    # Get the actual index.js to ensure proper imports
    if [ -f "user/src/index.js" ]; then
        # Backup current file
        cp user/src/index.js user/src/index.js.bak
        # Download the source version
        download_file "specgen-user" "src/index.js" "user/src/index.js.source"
        
        # Extract just the imports from source and prepend to current file
        if [ -f "user/src/index.js.source" ]; then
            # Get CSS imports from source
            grep "import.*css" user/src/index.js.source > user/src/css-imports.tmp || true
            # Combine with existing file
            cat user/src/css-imports.tmp user/src/index.js.bak > user/src/index.js || cp user/src/index.js.bak user/src/index.js
            rm -f user/src/index.js.source user/src/css-imports.tmp
        fi
    fi
fi

# Verify Tailwind configs are properly set up
echo "Verifying Tailwind configurations..."
for app in admin user; do
    if [ -f "$app/tailwind.config.js" ]; then
        echo "✓ $app/tailwind.config.js exists"
    else
        echo "❌ $app/tailwind.config.js missing"
    fi
    
    if [ -f "$app/src/index.css" ]; then
        if grep -q "@tailwind" "$app/src/index.css"; then
            echo "✓ $app/src/index.css has Tailwind directives"
        else
            echo "Adding Tailwind directives to $app/src/index.css..."
            cat > "$app/src/index.css" << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;
EOF
        fi
    fi
done

echo "✅ Enhanced config copying complete!"
