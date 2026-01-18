#!/bin/bash
set -e

################################################################################
# Docker Entrypoint for Autonomous Agent Ensemble
################################################################################

echo "[Entrypoint] Starting Ollama server..."
ollama serve > /dev/null 2>&1 &
OLLAMA_PID=$!

# Wait for Ollama to be ready
echo "[Entrypoint] Waiting for Ollama to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo "[Entrypoint] Ollama is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "[Entrypoint] ERROR: Ollama failed to start after 30s"
        exit 1
    fi
    sleep 1
done

# Check if models are already downloaded
echo "[Entrypoint] Checking for models..."
MODELS_NEEDED=("phi4-mini-reasoning" "qwen3:4b" "deepseek-r1:1.5b")
MODELS_MISSING=0

for model in "${MODELS_NEEDED[@]}"; do
    if ! ollama list | grep -q "$model"; then
        echo "[Entrypoint] Model $model not found, will pull..."
        MODELS_MISSING=1
    else
        echo "[Entrypoint] Model $model already present"
    fi
done

# Pull missing models
if [ $MODELS_MISSING -eq 1 ]; then
    echo "[Entrypoint] Pulling missing models (this may take 5-10 minutes)..."
    
    for model in "${MODELS_NEEDED[@]}"; do
        if ! ollama list | grep -q "$model"; then
            echo "[Entrypoint] Pulling $model..."
            ollama pull "$model" || {
                echo "[Entrypoint] WARNING: Failed to pull $model"
            }
        fi
    done
    
    echo "[Entrypoint] All models ready!"
else
    echo "[Entrypoint] All models already present, skipping pull"
fi

# Verify GitHub CLI authentication (if token provided)
if [ -n "$GITHUB_TOKEN" ]; then
    echo "[Entrypoint] Configuring GitHub CLI..."
    echo "$GITHUB_TOKEN" | gh auth login --with-token || {
        echo "[Entrypoint] WARNING: GitHub authentication failed"
        echo "[Entrypoint] Agent will run but cannot create issues"
    }
else
    echo "[Entrypoint] No GITHUB_TOKEN provided, skipping GitHub auth"
    echo "[Entrypoint] Set GITHUB_TOKEN environment variable to enable issue creation"
fi

# Execute the main command
echo "[Entrypoint] Starting autonomous agent..."
echo "[Entrypoint] Logs will be in /app/.agent/logs/"
echo "═══════════════════════════════════════════════════════════════════════════════"

exec "$@"
