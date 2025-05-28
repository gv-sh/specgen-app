module.exports = {
  apps: [{
    name: 'specgen',
    script: './server/index.js',
    cwd: process.env.PWD || '/home/ubuntu/specgen-app',
    env: {
      NODE_ENV: 'production',
      PORT: 80,
      HOST: '0.0.0.0',
      OPENAI_API_KEY: process.env.OPENAI_API_KEY || 'sk-test1234'
    },
    instances: 1,
    exec_mode: 'fork',
    max_memory_restart: '500M',
    time: true,
    watch: false,
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log'
  }]
}