#!/usr/bin/env node

const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

// Find the root directory of the package
const findPackageRoot = () => {
  // When installed as a dependency, the package will be in node_modules/@gv-sh/specgen-app
  // When running directly from the package, we're already at the root
  const packageJsonPath = path.resolve(__dirname, '../package.json');
  
  if (fs.existsSync(packageJsonPath)) {
    return path.dirname(packageJsonPath);
  }
  
  throw new Error('Could not locate package root directory');
};

const runScript = (scriptName) => {
  try {
    const packageRoot = findPackageRoot();
    process.chdir(packageRoot);
    
    console.log(`📦 Running ${scriptName} script...`);
    execSync(`npm run ${scriptName}`, { stdio: 'inherit' });
    
    console.log(`✅ ${scriptName} completed successfully`);
  } catch (error) {
    console.error(`❌ Error during ${scriptName}:`, error.message);
    process.exit(1);
  }
};

const command = process.argv[2];

switch (command) {
  case 'setup':
    runScript('setup');
    break;
  case 'setup-low-memory':
    runScript('setup-low-memory');
    break;
  case 'production':
    runScript('production');
    break;
  case 'production-low-memory':
    runScript('production-low-memory');
    break;
  case 'dev':
    runScript('dev');
    break;
  case 'deploy':
    runScript('deploy');
    break;
  case 'deploy:stop':
    runScript('deploy:stop');
    break;
  case 'deploy:restart':
    runScript('deploy:restart');
    break;
  case 'deploy:update':
    runScript('deploy:update');
    break;
  case 'deploy:status':
    runScript('deploy:status');
    break;
  case 'deploy:backup':
    runScript('deploy:backup');
    break;
  case 'troubleshoot':
    runScript('troubleshoot');
    break;
  default:
    console.log('Usage: specgen-app <command>');
    console.log('\nAvailable commands:');
    console.log('  setup           - Set up the SpecGen application');
  console.log('  setup-low-memory - Set up the SpecGen application with memory optimizations');
    console.log('  production      - Run the application in production mode');
  console.log('  production-low-memory - Run the application in production mode with memory optimizations');
    console.log('  dev             - Run the application in development mode');
    console.log('  deploy          - Deploy the application');
    console.log('  deploy:stop     - Stop the deployed application');
    console.log('  deploy:restart  - Restart the deployed application');
    console.log('  deploy:update   - Update the deployed application');
    console.log('  deploy:status   - Check the status of the deployed application');
    console.log('  deploy:backup   - Create a backup of the deployed application');
    console.log('  troubleshoot    - Run troubleshooting checks');
}
