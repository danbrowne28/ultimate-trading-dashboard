# ============================================================================
# Autonomous Agent Ensemble - Docker Container
# ============================================================================
# 
# Build: docker build -t autonomous-agent:latest .
# Run:   docker run -d --name agent -v $(pwd)/.agent:/app/.agent autonomous-agent:latest
#
# Size: ~12GB (base + Ollama + 3 models)
# Platform: linux/arm64 (Ampere A1 compatible)
# ============================================================================

FROM ubuntu:22.04

# Metadata
LABEL maintainer="danbrowne28"
LABEL description="3-Model Ensemble Autonomous Development Agent"
LABEL version="2.0"

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    jq \
    ca-certificates \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama
RUN curl -fsSL https://ollama.com/install.sh | sh

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
    tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && \
    apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# Install Node.js and PM2 (for process management)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g pm2 && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy repository files
COPY . /app/

# Make agent executable
RUN chmod +x /app/.github/agents/autonomous-agent-ensemble.sh

# Create directories
RUN mkdir -p /app/.agent/logs /app/.agent/results

# Ollama environment configuration
ENV OLLAMA_NUM_THREADS=4
ENV OLLAMA_NUM_PARALLEL=3
ENV OLLAMA_MAX_LOADED_MODELS=3
ENV OLLAMA_CONTEXT_SIZE=1024
ENV OLLAMA_NUM_GPU=0
ENV OLLAMA_KV_CACHE_TYPE=q8_0
ENV OLLAMA_KEEP_ALIVE=10m
ENV OLLAMA_HOST=0.0.0.0:11434

# ============================================================================
# OPTIONAL: Pre-download models (increases image size by ~7GB)
# Uncomment if you want models baked into the image
# ============================================================================
# RUN ollama serve & \
#     sleep 5 && \
#     ollama pull phi4-mini-reasoning && \
#     ollama pull qwen3:4b && \
#     ollama pull deepseek-r1:1.5b && \
#     pkill ollama

# Expose Ollama port (optional, for external access)
EXPOSE 11434

# Health check
HEALTHCHECK --interval=5m --timeout=30s --start-period=30s --retries=3 \
    CMD pgrep -f "ollama" || exit 1

# Entrypoint script
COPY .github/agents/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["pm2-runtime", "start", ".github/agents/ecosystem.config.js", "--only", "autonomous-agent"]
