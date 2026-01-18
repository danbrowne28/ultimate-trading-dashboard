# Deployment Guide - Autonomous Agent Ensemble

**Platform**: Oracle Cloud Ampere A1 (ARM64)  
**Process Manager**: PM2 (recommended) or Systemd  
**Containerization**: Docker (optional)

---

## 🎯 Deployment Options

| Method | Pros | Cons | Best For |
|--------|------|------|----------|
| **PM2 Native** | Fast, low overhead, easy monitoring | Requires Node.js | **Recommended** for production |
| **Docker + PM2** | Isolated, portable, reproducible | Higher memory (~500MB overhead) | Multi-tenant or isolation needed |
| **Systemd** | Native Linux, no dependencies | Limited monitoring tools | Minimal setups |

---

## 🚀 Method 1: PM2 Native (Recommended)

### Prerequisites

```bash
# Install Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PM2 globally
sudo npm install -g pm2

# Verify
node --version  # Should be v20.x
pm2 --version   # Should be 5.x
```

### Step 1: Install Ollama

```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Verify
ollama --version
```

### Step 2: Pull Models

```bash
# Pull all 3 models (~7GB download, takes 5-10 min)
ollama pull phi4-mini-reasoning
ollama pull qwen3:4b
ollama pull deepseek-r1:1.5b

# Verify
ollama list
# Should show all 3 models
```

### Step 3: Clone Repository

```bash
cd ~
git clone https://github.com/danbrowne28/ultimate-trading-dashboard.git
cd ultimate-trading-dashboard

# Make agent executable
chmod +x .github/agents/autonomous-agent-ensemble.sh
```

### Step 4: Configure GitHub Authentication

```bash
# Install GitHub CLI if not present
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
    sudo tee /etc/apt/sources.list.d/github-cli.list
sudo apt-get update
sudo apt-get install -y gh

# Authenticate
gh auth login
# Choose: GitHub.com > HTTPS > Authenticate with browser/token

# Verify
gh auth status
```

### Step 5: Start with PM2

```bash
# Start the agent
pm2 start .github/agents/ecosystem.config.js

# Expected output:
# [PM2] Spawning PM2 daemon with pm2_home=/home/ubuntu/.pm2
# [PM2] PM2 Successfully daemonized
# [PM2][DONE] Process autonomous-agent launched
```

### Step 6: Verify Running

```bash
# Check status
pm2 status
# Should show:
# ┌────────────────────────────────────────────────────────────┐
# │ id  │ name              │ status │ ↑ restart │ uptime │ cpu  │ mem    │
# ├────────────────────────────────────────────────────────────┤
# │ 0   │ autonomous-agent  │ online │ 0        │ 30s    │ 0%   │ 25.3mb │
# └────────────────────────────────────────────────────────────┘

# View logs in real-time
pm2 logs autonomous-agent

# View monitoring dashboard
pm2 monit
```

### Step 7: Configure Auto-Startup (Survives Reboots)

```bash
# Save PM2 process list
pm2 save

# Generate startup script
pm2 startup
# This will output a command like:
# sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u ubuntu --hp /home/ubuntu

# Copy and run that command (with sudo)
# Example:
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u ubuntu --hp /home/ubuntu

# Verify
sudo systemctl status pm2-ubuntu
# Should show: active (running)
```

---

## 📦 Method 2: Docker + PM2

### Prerequisites

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Re-login to apply group membership
exit
# SSH back in

# Verify
docker --version
```

### Step 1: Clone Repository

```bash
cd ~
git clone https://github.com/danbrowne28/ultimate-trading-dashboard.git
cd ultimate-trading-dashboard
```

### Step 2: Build Docker Image

```bash
# Build image (takes 10-15 min on first build)
cd .github/agents
docker build -t autonomous-agent:latest .

# Expected output:
# [+] Building 450.2s (18/18) FINISHED
# Successfully tagged autonomous-agent:latest

# Verify
docker images | grep autonomous-agent
# Should show ~5-6GB image (without models baked in)
```

### Step 3: Run Container

#### Option A: With Host Ollama (Recommended)

```bash
# Start Ollama on host
sudo systemctl start ollama

# Run container with host network (shares Ollama)
docker run -d \
  --name autonomous-agent \
  --network host \
  --restart unless-stopped \
  -v $(pwd)/.agent:/app/.agent \
  -e GITHUB_TOKEN="$(gh auth token)" \
  autonomous-agent:latest

# Check logs
docker logs -f autonomous-agent
```

#### Option B: Isolated Container (Models Inside)

```bash
# Edit Dockerfile, uncomment lines 73-79 to bake models in
# Then rebuild:
docker build -t autonomous-agent:latest .

# Run isolated
docker run -d \
  --name autonomous-agent \
  --restart unless-stopped \
  -v $(pwd)/.agent:/app/.agent \
  -e GITHUB_TOKEN="$(gh auth token)" \
  autonomous-agent:latest
```

### Step 4: Manage Container

```bash
# View logs
docker logs -f autonomous-agent

# Check status
docker ps | grep autonomous-agent

# Restart
docker restart autonomous-agent

# Stop
docker stop autonomous-agent

# Remove
docker rm -f autonomous-agent
```

### Step 5: Docker Compose (Optional)

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  autonomous-agent:
    build:
      context: ../..
      dockerfile: .github/agents/Dockerfile
    container_name: autonomous-agent
    restart: unless-stopped
    network_mode: host
    volumes:
      - ../../.agent:/app/.agent
    environment:
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - OLLAMA_NUM_THREADS=4
      - OLLAMA_NUM_PARALLEL=3
    healthcheck:
      test: ["CMD", "pgrep", "-f", "ollama"]
      interval: 5m
      timeout: 30s
      retries: 3
```

Then:

```bash
# Start
GITHUB_TOKEN=$(gh auth token) docker-compose up -d

# View logs
docker-compose logs -f

# Stop
docker-compose down
```

---

## 🛠️ PM2 Management Commands

### Daily Operations

```bash
# View status
pm2 status

# View logs (real-time)
pm2 logs autonomous-agent

# View logs (last 100 lines)
pm2 logs autonomous-agent --lines 100

# View error logs only
pm2 logs autonomous-agent --err

# Monitoring dashboard
pm2 monit

# Restart
pm2 restart autonomous-agent

# Stop
pm2 stop autonomous-agent

# Delete
pm2 delete autonomous-agent

# Reload (zero-downtime restart)
pm2 reload autonomous-agent
```

### Log Management

```bash
# Flush logs (clear old logs)
pm2 flush

# Rotate logs (archive old, start fresh)
pm2 install pm2-logrotate
pm2 set pm2-logrotate:max_size 10M
pm2 set pm2-logrotate:retain 7

# View log locations
pm2 info autonomous-agent
# Look for:
# error log path: /home/ubuntu/ultimate-trading-dashboard/.agent/logs/pm2-error.log
# out log path:   /home/ubuntu/ultimate-trading-dashboard/.agent/logs/pm2-out.log
```

### Performance Monitoring

```bash
# CPU and memory usage
pm2 monit

# Or with top-like interface
pm2 list

# Detailed metrics
pm2 show autonomous-agent

# Export metrics (JSON)
pm2 jlist
```

---

## 📊 Monitoring & Alerts

### PM2 Plus (Optional Cloud Monitoring)

```bash
# Sign up at https://pm2.io
# Then link:
pm2 link <secret> <public>

# Features:
# - Real-time monitoring
# - Alerting (email, Slack, etc.)
# - Exception tracking
# - Transaction tracing
```

### Custom Health Checks

Add to `ecosystem.config.js`:

```javascript
module.exports = {
  apps: [{
    name: 'autonomous-agent',
    // ...
    
    // Health check every 5 minutes
    cron_restart: '*/5 * * * *',  // Restart if hung
    
    // Resource limits
    max_memory_restart: '2G',  // Restart if >2GB
    
    // Exponential backoff
    exp_backoff_restart_delay: 100,
  }]
};
```

---

## 🔥 Troubleshooting

### Issue: PM2 process shows "errored"

```bash
# Check logs
pm2 logs autonomous-agent --err --lines 50

# Common causes:
# 1. Models not pulled
ollama list
ollama pull phi4-mini-reasoning
ollama pull qwen3:4b
ollama pull deepseek-r1:1.5b

# 2. GitHub auth failed
gh auth status
gh auth login

# 3. Permissions issue
chmod +x .github/agents/autonomous-agent-ensemble.sh

# Restart
pm2 restart autonomous-agent
```

### Issue: High memory usage

```bash
# Check current usage
pm2 monit

# If >6GB total (PM2 + Ollama):
# Edit ecosystem.config.js, reduce parallel models:
export OLLAMA_NUM_PARALLEL=1
export OLLAMA_MAX_LOADED_MODELS=1

# Restart
pm2 restart autonomous-agent
```

### Issue: Ollama not responding

```bash
# Check Ollama service
sudo systemctl status ollama

# Restart Ollama
sudo systemctl restart ollama

# Then restart agent
pm2 restart autonomous-agent
```

### Issue: No GitHub issues created

```bash
# Check GitHub auth
gh auth status

# Re-authenticate
gh auth login

# Check repo permissions
gh repo view danbrowne28/ultimate-trading-dashboard

# Test issue creation manually
gh issue create --title "Test" --body "Test issue"

# If manual works, restart agent
pm2 restart autonomous-agent
```

---

## ⚙️ Configuration Tuning

### For Faster Cycles (Reduce Quality)

Edit `ecosystem.config.js`:

```javascript
env: {
  OLLAMA_CONTEXT_SIZE: '512',  // Down from 1024 (2× faster)
  OLLAMA_NUM_PARALLEL: '3',    // Keep parallel
}
```

Edit `.github/agents/autonomous-agent-ensemble.sh` line 18:

```bash
readonly LLM_TIMEOUT=120  # Down from 180s
```

### For Better Quality (Slower Cycles)

Edit `ecosystem.config.js`:

```javascript
env: {
  OLLAMA_CONTEXT_SIZE: '2048',  // Up from 1024 (more context)
  OLLAMA_NUM_PARALLEL: '1',     // Sequential for better reasoning
}
```

### For Memory-Constrained Environments

Edit `ecosystem.config.js`:

```javascript
env: {
  OLLAMA_NUM_PARALLEL: '1',        // One at a time
  OLLAMA_MAX_LOADED_MODELS: '1',   // Unload after use
  OLLAMA_KEEP_ALIVE: '2m',         // Shorter cache
}
```

---

## 📝 Production Checklist

- [ ] Ollama installed and running
- [ ] All 3 models pulled
- [ ] GitHub CLI authenticated
- [ ] Repository cloned
- [ ] PM2 installed
- [ ] Agent started with PM2
- [ ] PM2 startup configured (survives reboots)
- [ ] First cycle completed successfully
- [ ] GitHub issues created
- [ ] Logs rotating (pm2-logrotate installed)
- [ ] Monitoring set up (pm2 monit or PM2 Plus)

---

## 🔗 Quick Reference

### PM2 Commands
```bash
pm2 start ecosystem.config.js       # Start agent
pm2 logs autonomous-agent           # View logs
pm2 monit                            # Monitor
pm2 restart autonomous-agent        # Restart
pm2 save                             # Save process list
pm2 startup                          # Configure auto-start
```

### Docker Commands
```bash
docker build -t autonomous-agent .  # Build
docker run -d autonomous-agent      # Run
docker logs -f autonomous-agent     # Logs
docker restart autonomous-agent     # Restart
```

### Ollama Commands
```bash
ollama list                          # List models
ollama pull <model>                  # Download model
sudo systemctl restart ollama        # Restart service
```

---

**Deployment Status**: Production-ready ✅  
**Last Updated**: January 18, 2026  
**Recommended**: PM2 Native for best performance
