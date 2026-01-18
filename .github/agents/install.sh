#!/bin/bash
set -e

################################################################################
#                                                                              #
#  ONE-COMMAND INSTALL SCRIPT - AUTONOMOUS AGENT ENSEMBLE                     #
#  ==============================================================              #
#                                                                              #
#  This script fully automates deployment of the 3-model ensemble agent:      #
#  - Installs Node.js, PM2, Ollama, GitHub CLI                                #
#  - Pulls Phi-4-Mini-Reasoning, Qwen3-4B, DeepSeek-R1-1.5B                  #
#  - Configures environment for ARM CPU optimization                           #
#  - Authenticates GitHub CLI                                                  #
#  - Starts agent with PM2                                                     #
#  - Configures auto-startup on reboot                                         #
#                                                                              #
#  Usage: curl -fsSL <raw-github-url>/install.sh | bash                       #
#  Or:    bash install.sh                                                      #
#                                                                              #
#  Platform: Oracle Cloud Ampere A1 (ARM64, Ubuntu 22.04)                     #
#  Time: ~10 minutes (depends on network speed for 7GB model downloads)       #
#                                                                              #
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${RESET} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${RESET} ✓ $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${RESET} ⚠  $*"
}

log_error() {
    echo -e "${RED}[ERROR]${RESET} ✗ $*"
    exit 1
}

log_header() {
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${PURPLE}  $*${RESET}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}

# Check if running on ARM64
check_architecture() {
    log_header "CHECKING SYSTEM ARCHITECTURE"
    
    ARCH=$(uname -m)
    if [[ "$ARCH" != "aarch64" && "$ARCH" != "arm64" ]]; then
        log_error "This script is designed for ARM64 architecture. Detected: $ARCH"
    fi
    
    log_success "Architecture: $ARCH (ARM64) ✓"
    
    # Check Ubuntu version
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        log_info "OS: $NAME $VERSION"
        if [[ "$ID" != "ubuntu" ]]; then
            log_warn "This script is optimized for Ubuntu. Detected: $ID"
            log_warn "Continuing anyway, but some commands may fail..."
        fi
    fi
}

# Update system packages
update_system() {
    log_header "UPDATING SYSTEM PACKAGES"
    
    log_info "Running apt-get update..."
    sudo apt-get update -qq
    
    log_info "Installing base dependencies..."
    sudo apt-get install -y -qq curl git jq ca-certificates build-essential > /dev/null 2>&1
    
    log_success "System packages updated"
}

# Install Node.js
install_nodejs() {
    log_header "INSTALLING NODE.JS"
    
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        log_info "Node.js already installed: $NODE_VERSION"
        
        # Check if version is 18.x or higher
        MAJOR_VERSION=$(echo "$NODE_VERSION" | sed 's/v\([0-9]*\).*/\1/')
        if [ "$MAJOR_VERSION" -ge 18 ]; then
            log_success "Node.js version is sufficient"
            return 0
        else
            log_warn "Node.js version is old, upgrading to v20.x..."
        fi
    fi
    
    log_info "Installing Node.js 20.x from NodeSource..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - > /dev/null 2>&1
    sudo apt-get install -y nodejs > /dev/null 2>&1
    
    NODE_VERSION=$(node --version)
    NPM_VERSION=$(npm --version)
    log_success "Node.js installed: $NODE_VERSION"
    log_success "npm installed: $NPM_VERSION"
}

# Install PM2
install_pm2() {
    log_header "INSTALLING PM2"
    
    if command -v pm2 &> /dev/null; then
        PM2_VERSION=$(pm2 --version)
        log_success "PM2 already installed: v$PM2_VERSION"
        return 0
    fi
    
    log_info "Installing PM2 globally..."
    sudo npm install -g pm2 > /dev/null 2>&1
    
    PM2_VERSION=$(pm2 --version)
    log_success "PM2 installed: v$PM2_VERSION"
}

# Install Ollama
install_ollama() {
    log_header "INSTALLING OLLAMA"
    
    if command -v ollama &> /dev/null; then
        OLLAMA_VERSION=$(ollama --version 2>&1 | head -1)
        log_success "Ollama already installed: $OLLAMA_VERSION"
        return 0
    fi
    
    log_info "Installing Ollama with ARM optimizations..."
    curl -fsSL https://ollama.com/install.sh | sh > /dev/null 2>&1
    
    OLLAMA_VERSION=$(ollama --version 2>&1 | head -1)
    log_success "Ollama installed: $OLLAMA_VERSION"
    
    # Start Ollama service
    log_info "Starting Ollama service..."
    sudo systemctl enable ollama > /dev/null 2>&1 || true
    sudo systemctl start ollama > /dev/null 2>&1 || true
    
    # Wait for Ollama to be ready
    log_info "Waiting for Ollama to be ready..."
    for i in {1..30}; do
        if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
            log_success "Ollama is ready!"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "Ollama failed to start after 30 seconds"
        fi
        sleep 1
    done
}

# Install GitHub CLI
install_gh_cli() {
    log_header "INSTALLING GITHUB CLI"
    
    if command -v gh &> /dev/null; then
        GH_VERSION=$(gh --version | head -1)
        log_success "GitHub CLI already installed: $GH_VERSION"
        return 0
    fi
    
    log_info "Installing GitHub CLI..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
        sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg > /dev/null 2>&1
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
        sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null 2>&1
    sudo apt-get update -qq
    sudo apt-get install -y gh > /dev/null 2>&1
    
    GH_VERSION=$(gh --version | head -1)
    log_success "GitHub CLI installed: $GH_VERSION"
}

# Pull Ollama models
pull_models() {
    log_header "DOWNLOADING LLM MODELS (~7GB)"
    
    MODELS=("phi4-mini-reasoning" "qwen3:4b" "deepseek-r1:1.5b")
    
    log_info "This will download 3 models:"
    log_info "  1. Phi-4-Mini-Reasoning (3.2GB) - Security & Performance"
    log_info "  2. Qwen3-4B (2.8GB) - Code Quality & Documentation"
    log_info "  3. DeepSeek-R1-1.5B (1.1GB) - Incomplete Features & Testing"
    log_info ""
    log_warn "Total download: ~7GB (this may take 5-10 minutes depending on your connection)"
    echo ""
    
    for model in "${MODELS[@]}"; do
        if ollama list | grep -q "$model"; then
            log_success "$model already present, skipping"
        else
            log_info "Pulling $model..."
            ollama pull "$model" || log_error "Failed to pull $model"
            log_success "$model downloaded"
        fi
    done
    
    log_success "All models ready!"
}

# Clone repository
clone_repository() {
    log_header "CLONING REPOSITORY"
    
    REPO_DIR="$HOME/ultimate-trading-dashboard"
    
    if [ -d "$REPO_DIR" ]; then
        log_info "Repository already exists at $REPO_DIR"
        log_info "Pulling latest changes..."
        cd "$REPO_DIR"
        git pull origin main > /dev/null 2>&1 || log_warn "Failed to pull latest changes"
        log_success "Repository updated"
    else
        log_info "Cloning repository to $REPO_DIR..."
        git clone https://github.com/danbrowne28/ultimate-trading-dashboard.git "$REPO_DIR" > /dev/null 2>&1
        log_success "Repository cloned"
    fi
    
    cd "$REPO_DIR"
    
    # Make agent executable
    chmod +x .github/agents/autonomous-agent-ensemble.sh
    log_success "Agent script is executable"
}

# Configure GitHub authentication
configure_github_auth() {
    log_header "CONFIGURING GITHUB AUTHENTICATION"
    
    if gh auth status &> /dev/null; then
        log_success "GitHub CLI already authenticated"
        GITHUB_USER=$(gh api user -q .login)
        log_info "Authenticated as: $GITHUB_USER"
        return 0
    fi
    
    log_info "GitHub CLI is not authenticated"
    log_info ""
    log_warn "To enable automatic GitHub issue creation, you need to authenticate."
    log_info "You can do this now or later."
    echo ""
    
    read -p "$(echo -e "${CYAN}Authenticate GitHub CLI now? (y/n): ${RESET}")" -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Starting GitHub CLI authentication..."
        log_info "Follow the prompts to authenticate."
        echo ""
        gh auth login || {
            log_warn "GitHub authentication failed or skipped"
            log_warn "You can authenticate later by running: gh auth login"
            return 1
        }
        
        GITHUB_USER=$(gh api user -q .login)
        log_success "Authenticated as: $GITHUB_USER"
    else
        log_warn "Skipping GitHub authentication"
        log_info "To authenticate later, run: gh auth login"
        log_info "The agent will still run but cannot create GitHub issues"
    fi
}

# Configure Ollama environment
configure_ollama() {
    log_header "CONFIGURING OLLAMA ENVIRONMENT"
    
    log_info "Setting ARM CPU optimizations..."
    
    mkdir -p ~/.ollama
    cat > ~/.ollama/env << 'EOF'
# ARM CPU Optimizations for Ampere A1
export OLLAMA_NUM_THREADS=4
export OLLAMA_NUM_PARALLEL=3
export OLLAMA_MAX_LOADED_MODELS=3
export OLLAMA_CONTEXT_SIZE=1024
export OLLAMA_NUM_GPU=0
export OLLAMA_KV_CACHE_TYPE=q8_0
export OLLAMA_KEEP_ALIVE=10m
EOF
    
    source ~/.ollama/env
    
    # Restart Ollama to apply changes
    sudo systemctl restart ollama > /dev/null 2>&1 || true
    sleep 2
    
    log_success "Ollama environment configured for ARM CPU"
}

# Start agent with PM2
start_agent() {
    log_header "STARTING AUTONOMOUS AGENT"
    
    REPO_DIR="$HOME/ultimate-trading-dashboard"
    cd "$REPO_DIR"
    
    # Stop existing instance if running
    if pm2 list | grep -q "autonomous-agent"; then
        log_info "Stopping existing agent instance..."
        pm2 stop autonomous-agent > /dev/null 2>&1 || true
        pm2 delete autonomous-agent > /dev/null 2>&1 || true
    fi
    
    log_info "Starting agent with PM2..."
    pm2 start .github/agents/ecosystem.config.js > /dev/null 2>&1
    
    # Wait a moment for startup
    sleep 3
    
    # Check if running
    if pm2 list | grep -q "online.*autonomous-agent"; then
        log_success "Agent started successfully!"
    else
        log_error "Agent failed to start. Check logs with: pm2 logs autonomous-agent"
    fi
}

# Configure PM2 auto-startup
configure_autostart() {
    log_header "CONFIGURING AUTO-STARTUP"
    
    log_info "Saving PM2 process list..."
    pm2 save > /dev/null 2>&1
    
    log_info "Configuring PM2 to start on boot..."
    
    # Generate startup script
    STARTUP_CMD=$(pm2 startup systemd -u "$USER" --hp "$HOME" 2>&1 | grep 'sudo')
    
    if [ -n "$STARTUP_CMD" ]; then
        log_info "Running: $STARTUP_CMD"
        eval "$STARTUP_CMD" > /dev/null 2>&1
        log_success "Auto-startup configured"
        log_info "Agent will automatically start after system reboot"
    else
        log_warn "Could not configure auto-startup"
        log_info "You can manually configure it later with: pm2 startup"
    fi
}

# Display final status
show_status() {
    log_header "INSTALLATION COMPLETE!"
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║                                                                    ║${RESET}"
    echo -e "${GREEN}║  ✓ Autonomous Agent Ensemble Successfully Installed!               ║${RESET}"
    echo -e "${GREEN}║                                                                    ║${RESET}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    
    log_info "System Status:"
    echo ""
    
    # PM2 status
    echo -e "${CYAN}PM2 Process:${RESET}"
    pm2 list
    echo ""
    
    # Models status
    echo -e "${CYAN}Ollama Models:${RESET}"
    ollama list
    echo ""
    
    log_info "Useful Commands:"
    echo ""
    echo -e "  ${YELLOW}View logs:${RESET}        pm2 logs autonomous-agent"
    echo -e "  ${YELLOW}Monitor:${RESET}          pm2 monit"
    echo -e "  ${YELLOW}Restart:${RESET}          pm2 restart autonomous-agent"
    echo -e "  ${YELLOW}Stop:${RESET}             pm2 stop autonomous-agent"
    echo -e "  ${YELLOW}Check issues:${RESET}     gh issue list --label autonomous-agent"
    echo ""
    
    log_info "Documentation:"
    echo ""
    echo -e "  ${YELLOW}Full README:${RESET}      $HOME/ultimate-trading-dashboard/.github/agents/README.md"
    echo -e "  ${YELLOW}Deployment:${RESET}       $HOME/ultimate-trading-dashboard/.github/agents/DEPLOYMENT.md"
    echo -e "  ${YELLOW}Quick Start:${RESET}      $HOME/ultimate-trading-dashboard/.github/agents/QUICKSTART.md"
    echo ""
    
    log_success "The agent is now running and will:"
    echo -e "  ${GREEN}•${RESET} Analyze your codebase every hour"
    echo -e "  ${GREEN}•${RESET} Create GitHub issues with detailed findings"
    echo -e "  ${GREEN}•${RESET} Use 3 specialized models in parallel (5-min cycles)"
    echo -e "  ${GREEN}•${RESET} Automatically restart on failure"
    echo -e "  ${GREEN}•${RESET} Survive system reboots"
    echo ""
    
    log_info "First cycle will start within 1 minute..."
    log_info "Check logs with: pm2 logs autonomous-agent"
    echo ""
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
    clear
    
    echo ""
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${PURPLE}║                                                                      ║${RESET}"
    echo -e "${PURPLE}║        AUTONOMOUS AGENT ENSEMBLE - ONE-COMMAND INSTALLER             ║${RESET}"
    echo -e "${PURPLE}║                                                                      ║${RESET}"
    echo -e "${PURPLE}║  3-Model System: Phi-4 + Qwen3-4B + DeepSeek-R1-1.5B               ║${RESET}"
    echo -e "${PURPLE}║  Platform: Oracle Cloud Ampere A1 (ARM64)                           ║${RESET}"
    echo -e "${PURPLE}║  Expected Time: ~10 minutes                                          ║${RESET}"
    echo -e "${PURPLE}║                                                                      ║${RESET}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    
    log_warn "This script will install:"
    echo "  • Node.js 20.x"
    echo "  • PM2 (process manager)"
    echo "  • Ollama (LLM runtime)"
    echo "  • GitHub CLI"
    echo "  • 3 AI models (~7GB download)"
    echo ""
    
    read -p "$(echo -e "${CYAN}Continue with installation? (y/n): ${RESET}")" -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi
    
    echo ""
    log_info "Starting installation..."
    sleep 1
    
    # Run installation steps
    check_architecture
    update_system
    install_nodejs
    install_pm2
    install_ollama
    install_gh_cli
    pull_models
    clone_repository
    configure_github_auth
    configure_ollama
    start_agent
    configure_autostart
    
    # Show final status
    show_status
}

# Run main function
main "$@"
