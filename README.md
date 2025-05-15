# SpecGen App - Complete Platform

A unified deployment package for the SpecGen speculative fiction generator platform.

## Components

- **Server**: Node.js API with OpenAI integration
- **Admin**: React admin interface for content management
- **User**: React user interface for story generation

## Local Development

### Option 1: From Source Repositories (Recommended for Development)
```bash
# Setup from actual source code (includes Tailwind configs)
npm run setup:source

# Add your OpenAI API key to server/.env

# Start development servers
npm run dev:source
```

### Option 2: From NPM Packages (For Testing Packages)
```bash
# Setup from published npm packages
npm run setup:mac

# Add your OpenAI API key to server/.env

# Start development servers (CSS might be limited)
npm run dev:mac
```

Access:
- User Interface: http://localhost:3002
- Admin Interface: http://localhost:3001
- API: http://localhost:3000

## Production Build

```bash
npm run build
npm start
```

## AWS Deployment

1. Launch Ubuntu 22.04 instance with SSH access
2. Run deployment script:

```bash
# On AWS instance
wget https://github.com/gv-sh/specgen-app/raw/main/scripts/deploy.sh
chmod +x deploy.sh
sudo ./deploy.sh
```

## Maintenance Commands

```bash
# Stop services
sudo ./scripts/stop.sh

# Restart services
sudo ./scripts/restart.sh

# Update to latest
sudo ./scripts/update.sh

# Check status
sudo ./scripts/status.sh

# Create backup
sudo ./scripts/backup.sh
```

## Environment Variables

Required environment files will be created during setup.

## Mac Development Setup

1. **Initial Setup**:
   ```bash
   npm run setup:mac
   ```

2. **Add OpenAI API Key** to `server/.env`

3. **Start Development**:
   ```bash
   npm run dev:mac
   ```

4. **Troubleshooting**:
   ```bash
   npm run troubleshoot
   ```

## Port Configuration

- Server: http://localhost:3000
- Admin: http://localhost:3001
- User: http://localhost:3002

The Mac scripts automatically handle port conflicts.
