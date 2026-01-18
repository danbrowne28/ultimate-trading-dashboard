/**
 * PM2 Ecosystem Configuration for Autonomous Agent Ensemble
 * 
 * Usage:
 *   pm2 start ecosystem.config.js
 *   pm2 logs autonomous-agent
 *   pm2 monit
 *   pm2 restart autonomous-agent
 * 
 * Documentation: https://pm2.keymetrics.io/docs/usage/application-declaration/
 */

const path = require('path');
const os = require('os');

// Dynamic paths (works for any user)
const HOME_DIR = process.env.HOME || os.homedir();
const REPO_DIR = path.join(HOME_DIR, 'ultimate-trading-dashboard');

module.exports = {
  apps: [
    {
      name: 'autonomous-agent',
      script: './.github/agents/autonomous-agent-ensemble.sh',
      interpreter: '/bin/bash',
      cwd: REPO_DIR,
      
      // Execution mode
      instances: 1,
      exec_mode: 'fork',
      
      // Auto-restart configuration
      autorestart: true,
      watch: false,
      max_restarts: 10,
      min_uptime: '60s',
      restart_delay: 5000,
      
      // Environment variables
      env: {
        NODE_ENV: 'production',
        OLLAMA_NUM_THREADS: '4',
        OLLAMA_NUM_PARALLEL: '3',
        OLLAMA_MAX_LOADED_MODELS: '3',
        OLLAMA_CONTEXT_SIZE: '1024',
        OLLAMA_NUM_GPU: '0',
        OLLAMA_KV_CACHE_TYPE: 'q8_0',
        OLLAMA_KEEP_ALIVE: '10m',
      },
      
      // Logging
      error_file: './.agent/logs/pm2-error.log',
      out_file: './.agent/logs/pm2-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true,
      
      // Resource limits (optional, adjust for your A1 instance)
      max_memory_restart: '2G',
      
      // Graceful shutdown
      kill_timeout: 10000,
      wait_ready: false,
      listen_timeout: 3000,
    },
    
    // Alternative: Cron-based execution (run every 2 hours instead of continuous loop)
    {
      name: 'autonomous-agent-cron',
      script: './.github/agents/autonomous-agent-ensemble.sh',
      interpreter: '/bin/bash',
      cwd: REPO_DIR,
      
      // Cron execution
      instances: 1,
      exec_mode: 'fork',
      cron_restart: '0 */2 * * *',  // Every 2 hours
      autorestart: false,  // Don't auto-restart, let cron handle it
      
      // Environment variables
      env: {
        NODE_ENV: 'production',
        OLLAMA_NUM_THREADS: '4',
        OLLAMA_NUM_PARALLEL: '3',
        OLLAMA_MAX_LOADED_MODELS: '3',
        OLLAMA_CONTEXT_SIZE: '1024',
        OLLAMA_NUM_GPU: '0',
        OLLAMA_KV_CACHE_TYPE: 'q8_0',
        OLLAMA_KEEP_ALIVE: '10m',
      },
      
      // Logging
      error_file: './.agent/logs/pm2-cron-error.log',
      out_file: './.agent/logs/pm2-cron-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true,
    },
  ],
};
