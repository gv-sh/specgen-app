#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Read main package.json
const mainPackage = JSON.parse(fs.readFileSync('package.json', 'utf8'));
const dependencies = mainPackage.dependencies;

// Component mappings
const components = {
  server: dependencies['@gv-sh/specgen-server'],
  admin: dependencies['@gv-sh/specgen-admin'],
  user: dependencies['@gv-sh/specgen-user']
};

console.log('🔄 Syncing versions from main package.json...');

Object.entries(components).forEach(([dir, expectedVersion]) => {
  const packagePath = path.join(dir, 'package.json');
  
  if (fs.existsSync(packagePath)) {
    const localPackage = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
    const currentVersion = localPackage.version;
    
    if (currentVersion !== expectedVersion) {
      console.log(`📦 ${dir}: ${currentVersion} → ${expectedVersion}`);
      localPackage.version = expectedVersion;
      fs.writeFileSync(packagePath, JSON.stringify(localPackage, null, 2) + '\n');
    } else {
      console.log(`✅ ${dir}: ${currentVersion} (already synced)`);
    }
  } else {
    console.log(`❌ ${dir}: package.json not found`);
  }
});

console.log('✨ Version sync complete!');