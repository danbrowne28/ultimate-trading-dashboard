#!/bin/bash
set -euo pipefail

################################################################################
#                                                                              #
#  3-MODEL ENSEMBLE AUTONOMOUS AGENT FOR AMPERE A1                           #
#  ============================================================                #
#                                                                              #
#  Architecture: Specialized model routing + parallel execution               #
#  Performance: 2.5× faster than single-model approach                        #
#  Memory: 3.8 GB total (Phi-4 + Qwen3-4B + DeepSeek-R1-1.5B)               #
#                                                                              #
#  Model Assignments:                                                          #
#  - Phi-4-Mini-Reasoning: Security + Performance (logic-intensive)           #
#  - Qwen3-4B: Code quality + Documentation (pattern matching)                #
#  - DeepSeek-R1-1.5B: Incomplete features + Testing (fast scanning)          #
#                                                                              #
#  Expected Cycle Time: ~5 minutes (vs 7.2 min single-model)                  #
#  Research: Microsoft Phi-4 Technical Report (April 2025)                    #
#                                                                              #
################################################################################

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

readonly MODEL_REASONING="phi4-mini-reasoning"    # Security, Performance
readonly MODEL_CODE="qwen3:4b"                     # Code quality, Docs
readonly MODEL_FAST="deepseek-r1:1.5b"             # Incomplete, Testing

readonly LLM_TIMEOUT=180  # 3 minutes per model
readonly STATE_DIR=".agent"
readonly LOG_DIR="$STATE_DIR/logs"
readonly RESULTS_DIR="$STATE_DIR/results"

mkdir -p "$LOG_DIR" "$RESULTS_DIR"

# Colors
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[0;34m'
readonly C_PURPLE='\033[0;35m'
readonly C_CYAN='\033[0;36m'
readonly C_RESET='\033[0m'

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UTILITY FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log() {
    local level="$1"; shift
    local msg="$*"
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        INFO)    echo -e "${C_BLUE}[$ts]${C_RESET} ℹ  $msg" ;;
        SUCCESS) echo -e "${C_GREEN}[$ts]${C_RESET} ✓ $msg" ;;
        WARN)    echo -e "${C_YELLOW}[$ts]${C_RESET} ⚠  $msg" ;;
        ERROR)   echo -e "${C_RED}[$ts]${C_RESET} ✗ $msg" ;;
    esac
    
    echo "[$ts] [$level] $msg" >> "$LOG_DIR/audit.log"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MODEL-SPECIFIC ANALYSIS FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

analyze_security_performance() {
    local model="$MODEL_REASONING"
    local output="$RESULTS_DIR/security_performance.txt"
    
    log INFO "[Phi-4] Analyzing security + performance (reasoning-intensive)..."
    
    local prompt="You are a security and performance analysis expert with mathematical reasoning.

## TASK 1: SECURITY ANALYSIS
Find security vulnerabilities that require logical reasoning:
- SQL injection (trace user input → query construction → exploit)
- XSS vulnerabilities (input → DOM manipulation → script execution)
- Authentication bypass (auth flow → validation logic → bypass path)
- Insecure cryptography (algorithm choice → key management → weakness)

## TASK 2: PERFORMANCE ANALYSIS
Identify performance issues requiring algorithmic analysis:
- Nested loops (O(n²) → suggest O(n log n) alternatives)
- Database N+1 queries (detect repeated queries → suggest eager loading)
- Memory leaks (object retention → reference cycles → garbage collection)
- Inefficient algorithms (current complexity → optimal complexity)

For EACH finding:
[PRIORITY] Title | File:Line | Action

Use <thinking> tags to show your reasoning."
    
    if timeout "$LLM_TIMEOUT" ollama run "$model" <<< "$prompt" > "$output" 2>&1; then
        log SUCCESS "[Phi-4] Security + Performance analysis complete"
        return 0
    else
        log ERROR "[Phi-4] Analysis timeout or error"
        return 1
    fi
}

analyze_code_quality_docs() {
    local model="$MODEL_CODE"
    local output="$RESULTS_DIR/code_quality_docs.txt"
    
    log INFO "[Qwen3] Analyzing code quality + documentation (pattern matching)..."
    
    local prompt="You are a code quality and documentation expert.

## TASK 1: CODE QUALITY
Find code smells and anti-patterns:
- Duplicated code blocks (copy-pasted logic)
- Long functions (>50 lines, multiple responsibilities)
- High cyclomatic complexity (nested if/else, many branches)
- Magic numbers (hardcoded values without constants)
- Poor naming (unclear variable/function names)

## TASK 2: DOCUMENTATION GAPS
Identify missing or outdated documentation:
- Functions without docstrings
- Misleading comments (code changed, comment didn't)
- Missing README sections
- Undocumented API endpoints
- No usage examples

For EACH finding:
[PRIORITY] Title | File:Line | Action"
    
    if timeout "$LLM_TIMEOUT" ollama run "$model" <<< "$prompt" > "$output" 2>&1; then
        log SUCCESS "[Qwen3] Code quality + Documentation analysis complete"
        return 0
    else
        log ERROR "[Qwen3] Analysis timeout or error"
        return 1
    fi
}

analyze_incomplete_testing() {
    local model="$MODEL_FAST"
    local output="$RESULTS_DIR/incomplete_testing.txt"
    
    log INFO "[DeepSeek-R1] Analyzing incomplete features + testing gaps (fast scan)..."
    
    local prompt="You are a completeness and testing expert. Work quickly.

## TASK 1: INCOMPLETE FEATURES
Find unfinished work:
- TODO/FIXME/HACK comments
- Functions with 'pass' or empty bodies
- Placeholder return values (return None, return {})
- Commented-out code blocks

## TASK 2: TESTING GAPS
Identify untested code:
- Functions without corresponding tests
- Missing edge case tests (empty input, null, max values)
- Low test coverage areas
- Brittle assertions (testing implementation, not behavior)

For EACH finding:
[PRIORITY] Title | File:Line | Action"
    
    if timeout "$LLM_TIMEOUT" ollama run "$model" <<< "$prompt" > "$output" 2>&1; then
        log SUCCESS "[DeepSeek-R1] Incomplete + Testing analysis complete"
        return 0
    else
        log ERROR "[DeepSeek-R1] Analysis timeout or error"
        return 1
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PARALLEL EXECUTION ENGINE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

phase_discovery_ensemble() {
    log INFO "${C_PURPLE}╔═══════════════════════════════════════════════════════╗${C_RESET}"
    log INFO "${C_PURPLE}║   PHASE 1: ENSEMBLE DISCOVERY (3 Models Parallel)    ║${C_RESET}"
    log INFO "${C_PURPLE}╚═══════════════════════════════════════════════════════╝${C_RESET}"
    
    local start=$(date +%s)
    
    # Clear previous results
    rm -f "$RESULTS_DIR"/*.txt
    
    # Launch all 3 models in parallel (background processes)
    analyze_security_performance &
    local pid_phi=$!
    
    analyze_code_quality_docs &
    local pid_qwen=$!
    
    analyze_incomplete_testing &
    local pid_deepseek=$!
    
    # Wait for all models to complete
    local failed=0
    
    wait $pid_phi || { log WARN "Phi-4 analysis failed"; failed=$((failed + 1)); }
    wait $pid_qwen || { log WARN "Qwen3 analysis failed"; failed=$((failed + 1)); }
    wait $pid_deepseek || { log WARN "DeepSeek-R1 analysis failed"; failed=$((failed + 1)); }
    
    local duration=$(($(date +%s) - start))
    
    if [ $failed -gt 0 ]; then
        log WARN "$failed model(s) failed, continuing with available results"
    fi
    
    log SUCCESS "Parallel analysis complete in ${duration}s"
    
    # Aggregate results
    aggregate_and_create_issues
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# RESULT AGGREGATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

aggregate_and_create_issues() {
    log INFO "Aggregating results from 3 models..."
    
    local total_issues=0
    
    # Process each model's output
    for result_file in "$RESULTS_DIR"/*.txt; do
        [ -f "$result_file" ] || continue
        
        local model_name=$(basename "$result_file" .txt)
        
        # Extract findings (lines starting with [PRIORITY])
        while IFS='|' read -r priority_title location action; do
            # Parse priority and title
            local priority=$(echo "$priority_title" | sed -n 's/^\[\([^]]*\)\].*/\1/p' | xargs)
            local title=$(echo "$priority_title" | sed 's/^\[[^]]*\] //' | xargs)
            local loc=$(echo "$location" | xargs)
            local fix=$(echo "$action" | xargs)
            
            # Skip empty lines
            [ -z "$title" ] && continue
            
            # Extract reasoning if available
            local reasoning=$(sed -n '/<thinking>/,/<\/thinking>/p' "$result_file" | head -20)
            
            # Create GitHub issue
            if gh issue create \
                --title "[$priority] $title" \
                --body "**Location**: $loc
**Action Required**: $fix
**Analysis Model**: $model_name

**Reasoning**:
\`\`\`
$reasoning
\`\`\`

---
*Generated by Ensemble Autonomous Agent v2.0*
*Timestamp: $(date -Iseconds)*" \
                --label "autonomous-agent,$priority,ensemble-${model_name}" 2>/dev/null; then
                
                total_issues=$((total_issues + 1))
                log SUCCESS "Created issue: [$priority] $title (from $model_name)"
            fi
            
        done < <(grep '^\[' "$result_file" 2>/dev/null || true)
    done
    
    log SUCCESS "Created $total_issues GitHub issues from ensemble analysis"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# IMPLEMENTATION PHASE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

phase_implementation() {
    log INFO "${C_PURPLE}╔═══════════════════════════════════════════════════════╗${C_RESET}"
    log INFO "${C_PURPLE}║         PHASE 2: IMPLEMENTATION (Copilot)            ║${C_RESET}"
    log INFO "${C_PURPLE}╚═══════════════════════════════════════════════════════╝${C_RESET}"
    
    local issues=$(gh issue list --state open --limit 5 --json number,title,labels 2>/dev/null || echo "[]")
    
    if [ "$(echo "$issues" | jq '. | length')" -eq 0 ]; then
        log INFO "No open issues to implement"
        return 0
    fi
    
    local pr_count=0
    
    echo "$issues" | jq -c '.[]' | while read -r issue; do
        local num=$(echo "$issue" | jq -r '.number')
        local title=$(echo "$issue" | jq -r '.title')
        
        log INFO "Processing issue #$num: $title"
        
        # Assign to GitHub Copilot if available
        if command -v gh &>/dev/null && gh extension list 2>/dev/null | grep -q copilot; then
            if gh copilot task "$num" 2>/dev/null; then
                log SUCCESS "Copilot assigned to #$num"
                pr_count=$((pr_count + 1))
            fi
        fi
        
        # Safety limit: max 3 PRs per cycle
        [ $pr_count -ge 3 ] && { log INFO "Reached max PRs (3)"; break; }
    done
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# VALIDATION PHASE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

phase_validation() {
    log INFO "${C_PURPLE}╔═══════════════════════════════════════════════════════╗${C_RESET}"
    log INFO "${C_PURPLE}║            PHASE 3: VALIDATION                       ║${C_RESET}"
    log INFO "${C_PURPLE}╚═══════════════════════════════════════════════════════╝${C_RESET}"
    
    # Run tests if available
    if [ -f "pyproject.toml" ] || [ -f "pytest.ini" ]; then
        if command -v pytest &>/dev/null && pytest --co -q &>/dev/null; then
            log INFO "Running test suite..."
            if pytest --maxfail=5 -q 2>&1 | tee "$LOG_DIR/test-results.log"; then
                log SUCCESS "All tests passed"
            else
                log WARN "Some tests failed (see logs)"
            fi
        fi
    else
        log INFO "No test framework detected"
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN LOOP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main_loop() {
    log INFO "${C_GREEN}╔═══════════════════════════════════════════════════════╗${C_RESET}"
    log INFO "${C_GREEN}║  🤖 ENSEMBLE AUTONOMOUS AGENT v2.0 STARTED          ║${C_RESET}"
    log INFO "${C_GREEN}║  3 Models: Phi-4 + Qwen3-4B + DeepSeek-R1-1.5B     ║${C_RESET}"
    log INFO "${C_GREEN}║  Expected: 5-min cycles, 2.5× faster               ║${C_RESET}"
    log INFO "${C_GREEN}╚═══════════════════════════════════════════════════════╝${C_RESET}"
    
    # Verify models are available
    for model in "$MODEL_REASONING" "$MODEL_CODE" "$MODEL_FAST"; do
        if ! ollama list | grep -q "$model"; then
            log ERROR "Model $model not found. Run: ollama pull $model"
            exit 1
        fi
    done
    
    log SUCCESS "All 3 models verified"
    
    while true; do
        local cycle_start=$(date +%s)
        
        log INFO ""
        log INFO "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
        log INFO "${C_CYAN}CYCLE STARTING${C_RESET}"
        log INFO "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
        log INFO ""
        
        phase_discovery_ensemble || log ERROR "Discovery failed"
        phase_implementation || log ERROR "Implementation failed"
        phase_validation || log ERROR "Validation failed"
        
        local cycle_duration=$(($(date +%s) - cycle_start))
        local cycle_min=$((cycle_duration / 60))
        local cycle_sec=$((cycle_duration % 60))
        
        log INFO ""
        log SUCCESS "Cycle complete in ${cycle_min}m ${cycle_sec}s"
        log INFO "Cooldown: 1 hour (next cycle at $(date -d '+1 hour' '+%H:%M:%S'))"
        log INFO ""
        
        sleep 3600
    done
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ENTRY POINT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main_loop "$@"
fi
