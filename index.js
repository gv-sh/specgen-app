// This file makes the package importable
// The main functionality is provided through the CLI

module.exports = {
  version: require('./package.json').version,
  description: 'SpecGen Application Package',
  
  // Export script paths for programmatic access
  scripts: {
    setup: require.resolve('./scripts/setup.sh'),
    dev: require.resolve('./scripts/dev.sh'),
    production: require.resolve('./scripts/production.sh')
  }
};
