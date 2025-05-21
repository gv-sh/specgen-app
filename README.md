# SpecGen App - Complete Platform

[![Version](https://img.shields.io/badge/version-0.1.6-blue.svg)](https://github.com/gv-sh/specgen-app)

A unified deployment package for the SpecGen speculative fiction generator platform.

## Components

- **Server**: Node.js API with OpenAI integration
- **Admin**: React admin interface for content management
- **User**: React user interface for story generation

## Quick Start

1. **Setup**:
   ```bash
   npm run setup
   ```

2. **Add OpenAI API Key** to `server/.env`

3. **Start Development**:
   ```bash
   npm run dev
   ```

## Access URLs

- User Interface: http://localhost:3002
- Admin Interface: http://localhost:3001
- API: http://localhost:3000

## Production Deployment

### Build
```bash
npm run build
npm start
```

### AWS Deployment

1. Launch Ubuntu 22.04 instance with SSH access
2. Run deployment script:

```bash
# On AWS instance
wget https://github.com/gv-sh/specgen-app/raw/main/scripts/deploy.sh
chmod +x deploy.sh
sudo ./deploy.sh
```

## Management Commands

```bash
# Stop services
npm run deploy:stop

# Restart services
npm run deploy:restart

# Update to latest
npm run deploy:update

# Check status
npm run deploy:status

# Create backup
npm run deploy:backup
```

## Troubleshooting

If you encounter issues:

```bash
npm run troubleshoot
```

This will check your setup and identify common problems.

## Environment Variables

The setup script creates necessary environment files automatically. You only need to add your OpenAI API key to `server/.env`.