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
  case 'dev':
    runScript('dev');
    break;
  case 'build':
    runScript('build');
    break;
  case 'start':
    runScript('start');
    break;
  case 'deploy':
    runScript('deploy');
    break;
  case 'deploy:ec2':
    runScript('deploy:ec2');
    break;
  case 'backup':
    runScript('backup:database');
    break;
  case 'restore':
    runScript('restore:database');
    break;
  default:
    console.log('Usage: specgen-app <command>');
    console.log('\nAvailable commands:');
    console.log('  setup      - Set up the SpecGen application');
    console.log('  dev        - Run the application in development mode');
    console.log('  build      - Build the admin and user applications');
    console.log('  start      - Start the server');
    console.log('  deploy     - Deploy the application locally');
    console.log('  deploy:ec2 - Deploy the application to EC2');
    console.log('  backup     - Create a backup of the database');
    console.log('  restore    - Restore the database from backup');
}
