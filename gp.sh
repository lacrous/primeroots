#!/usr/bin/env bash
# github-publish.sh
# Interactive script that sets up a project and pushes it to GitHub.
# Usage:
#   ./github-publish.sh                # interactive
#   ./github-publish.sh --dry-run      # preview, no changes
#   ./github-publish.sh --help         # show help
# Requires: git. Optionally: gh CLI (recommended), curl + $GITHUB_TOKEN.
# Tested: bash 4+ (macOS / Linux).

set -euo pipefail

# ---------- styling ----------
RED=$'\033[0;31m'; GRN=$'\033[0;32m'; YEL=$'\033[1;33m'
BLU=$'\033[0;34m'; DIM=$'\033[2m'; CYN=$'\033[0;36m'; BOLD=$'\033[1m'; NC=$'\033[0m'

# Glyphs: ✓ success, → info, ⚠ warn, ✗ error, › prompt
info() { printf "${BLU}→${NC} %s\n" "$1"; }
ok()   { printf "${GRN}✓${NC} %s\n" "$1"; }
warn() { printf "${YEL}⚠${NC} %s\n" "$1"; }
err()  { printf "${RED}✗${NC} %s\n" "$1"; }
ask()  { printf "${DIM}›${NC} %s" "$1"; }
dim()  { printf "${DIM}%s${NC}\n" "$1"; }
h1()   { printf "\n${CYN}── %s ──${NC}\n" "$1"; }

# ---------- isatty detection ----------
# Disable animation/colors when output isn't a terminal (piped, CI, etc.)
IS_TTY=false
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ "${NO_COLOR:-}" != "1" ]]; then
    IS_TTY=true
fi

# ---------- animated indicators ----------
SPINNER_FRAMES=("⣾" "⣽" "⣻" "⢿" "⡿" "⣟" "⣯" "⣷")
ANIM_DOTS=("" "." ".." "..." "..." "..")

# Typewriter-style banner.
# Args: text lines, one per argument. Each char is printed with a tiny delay.
typewriter() {
    if ! $IS_TTY; then
        printf "%s\n" "$@"
        return
    fi
    local delay=0.008
    for line in "$@"; do
        local i=0
        while (( i < ${#line} )); do
            local ch="${line:$i:1}"
            printf "%s" "$ch"
            # Faster for spaces, slower for first char of words
            [[ "$ch" != " " ]] && sleep "$delay"
            i=$((i+1))
        done
        printf "\n"
    done
}

# Print an in-place spinner that runs while a foreground command executes.
# Uses a sub-shell + pipe so the spinner and command output coexist.
# Args: msg, then command + args. The command's stdout is preserved.
spin_while() {
    if ! $IS_TTY; then
        # No animation possible — just run with the message.
        info "$1"
        shift
        "$@"
        return $?
    fi
    local msg="$1"
    shift
    local i=0
    local start_time
    start_time=$(date +%s)
    # Run command in background, capturing stdout to /tmp so the spinner
    # can take over the line. The user-visible output is shown after.
    "$@" >/tmp/spinner.out 2>&1 &
    local pid=$!
    # Hide cursor while spinning (best-effort).
    printf "\033[?25l"
    while kill -0 $pid 2>/dev/null; do
        local frame="${SPINNER_FRAMES[$((i % 8))]}"
        local elapsed=$(( $(date +%s) - start_time ))
        printf "\r\033[2K${CYN}%s${NC} %s ${DIM}(%ds)${NC}" "$frame" "$msg" "$elapsed"
        i=$((i+1))
        sleep 0.1
    done
    wait $pid 2>/dev/null
    local rc=$?
    local elapsed=$(( $(date +%s) - start_time ))
    # Restore cursor
    printf "\033[?25h"
    if [[ $rc -eq 0 ]]; then
        printf "\r\033[2K${GRN}✓${NC} %s ${DIM}(%ds)${NC}\n" "$msg" "$elapsed"
    else
        printf "\r\033[2K${RED}✗${NC} %s ${DIM}(%ds, exit %d)${NC}\n" "$msg" "$elapsed" "$rc"
    fi
    # Show captured output indented.
    [[ -s /tmp/spinner.out ]] && sed 's/^/    /' /tmp/spinner.out
    return $rc
}

# Tracked progress through phases of the script.
TOTAL_STEPS=11
CURRENT_STEP=0
SCRIPT_START_TIME=$(date +%s)
STEP_START_TIME=$(date +%s)

# Build a 70-character repeating '─' line (used in step borders).
rep_dash() {
    local n="${1:-68}"
    printf '─%.0s' $(seq 1 "$n")
}

# Current elapsed time formatted as M:SS
fmt_elapsed() {
    local secs=$(( $(date +%s) - SCRIPT_START_TIME ))
    printf "%d:%02d" $((secs/60)) $((secs%60))
}

# Print a small breadcrumb of all steps:  ✓ ▸ ○ ○ ○ ...
print_breadcrumb() {
    local dots=""
    for ((i=1; i<=TOTAL_STEPS; i++)); do
        if (( i < CURRENT_STEP )); then
            dots+="${GRN}✓${NC} "
        elif (( i == CURRENT_STEP )); then
            dots+="${BLU}▸${NC} "
        else
            dots+="${DIM}○${NC} "
        fi
    done
    printf "  ${DIM}progress:${NC}  %s\n" "$dots"
}

# Fancy wizard-style step header. Big border, step number, title, elapsed time.
step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    STEP_START_TIME=$(date +%s)
    local title="$1"

    if ! $IS_TTY; then
        printf "\n"
        printf "${CYN}── STEP %d/%d${NC}  ${BOLD}%s${NC}\n" "$CURRENT_STEP" "$TOTAL_STEPS" "$title"
        printf "${DIM}──────────────────────────────────────────────────────────────────${NC}\n"
        return
    fi

    local total_w=72
    local header_w=$total_w
    printf "\n"
    # Top border: ┌─[ STEP 5/11 · title ]─────────────────┐
    printf "${CYN}┌─${NC}${BOLD}${BLU}[${CYN}${BOLD} STEP %d/%d ${NC}${BLU}]${NC}" "$CURRENT_STEP" "$TOTAL_STEPS"
    # Fill remaining horizontal space with a thin rule.
    local label_str=" ${title} "
    printf "${CYN}${label_str}${NC}"
    printf "${CYN}%*s${NC}" "$((header_w - ${#label_str} - 12))" "" | tr ' ' '─'
    printf "${CYN}┐${NC}\n"
    # Inner row: title + elapsed clock on right.
    printf "${CYN}│${NC}  ${BOLD}%-58s${NC}  ${DIM}⏱ %s${NC}  ${CYN}│${NC}\n" "$title" "$(fmt_elapsed)"
    # Bottom border.
    printf "${CYN}└%*s┘${NC}\n" "$((header_w - 2))" "" | tr ' ' '─'
    echo
}

# Optional: print a "✓ step X done" line under each step's content.
step_done() {
    local secs=$(( $(date +%s) - STEP_START_TIME ))
    if $IS_TTY; then
        printf "${DIM}──────────────────────────────────────────────────────────────────${NC}\n"
        printf "${GRN}✓${NC} step %d complete  ${DIM}(%ds)${NC}\n" "$CURRENT_STEP" "$secs"
    fi
}

# Final summary card shown when the script reaches a successful end.
print_summary() {
    local status="$1"     # "ok" | "fail"
    local total_secs=$(( $(date +%s) - SCRIPT_START_TIME ))
    printf "\n"
    if ! $IS_TTY; then
        printf "── %s in %d:%02d ──\n" "$status" $((total_secs/60)) $((total_secs%60))
        return
    fi

    if [[ "$status" == "ok" ]]; then
        printf "${GRN}╔══════════════════════════════════════════════════════════════════════╗${NC}\n"
        printf "${GRN}║${NC}                                                                      ${GRN}║${NC}\n"
        printf "${GRN}║${NC}              ${BOLD}${GRN}✓  All done!${NC}                                       ${GRN}║${NC}\n"
        printf "${GRN}║${NC}                                                                      ${GRN}║${NC}\n"
        # Pad the URL/repo cells to fixed widths so the box columns align.
        printf -v OWNER_C "%-12s" "$OWNER"
        printf -v REPO_C  "%-22s" "$REPO"
        printf "${GRN}║${NC}   Repository:   ${BOLD}https://github.com/%s/%s${NC}${GRN}║${NC}\n" "$OWNER_C" "$REPO_C"
        printf -v TIME_C "%-54s" ""
        printf "${GRN}║${NC}   Total time:   ${BOLD}%d:%02d${NC}  ${TIME_C}${GRN}║${NC}\n" $((total_secs/60)) $((total_secs%60))
        printf -v STEPS_C "%-50s" ""
        printf "${GRN}║${NC}   Steps:        ${BOLD}%d / %d${NC}  ${STEPS_C}${GRN}║${NC}\n" "$CURRENT_STEP" "$TOTAL_STEPS"
        printf "${GRN}║${NC}                                                                      ${GRN}║${NC}\n"
        printf "${GRN}╚══════════════════════════════════════════════════════════════════════╝${NC}\n"
    else
        printf "${RED}╔══════════════════════════════════════════════════════════════════════╗${NC}\n"
        printf "${RED}║${NC}              ${BOLD}${RED}✗  Stopped before completion.${NC}                       ${RED}║${NC}\n"
        printf "${RED}║${NC}                                                                      ${RED}║${NC}\n"
        printf -v STEP_C "%-32s" ""
        printf "${RED}║${NC}   Last successful step: ${BOLD}$((CURRENT_STEP - 1)) / $TOTAL_STEPS${NC}${STEP_C}${RED}║${NC}\n"
        printf -v TIME_C "%-35s" ""
        printf "${RED}║${NC}   Time:                  ${BOLD}%d:%02d${NC}${TIME_C}${RED}║${NC}\n" $((total_secs/60)) $((total_secs%60))
        printf "${RED}╚══════════════════════════════════════════════════════════════════════╝${NC}\n"
    fi
}

# Animated "scanning file X of Y" indicator.
scan_tick() {
    local idx=$1; local total=$2; local file=$3
    local pct=$(( idx * 100 / total ))
    local bar_width=24
    local filled=$(( pct * bar_width / 100 ))
    local bar=""
    local i=0
    while (( i < bar_width )); do
        if (( i < filled )); then
            bar+="━"
        else
            bar+="─"
        fi
        i=$((i+1))
    done
    printf "\r  ${CYN}[${bar}]${NC} ${DIM}%d/%d${NC}  %s" "$idx" "$total" "$file"
}

print_banner() {
    if ! $IS_TTY; then
        # Non-TTY: just print plainly.
        printf "${BLU}╭──────────────────────────────────────────╮${NC}\n"
        printf "${BLU}│${NC}  ${BOLD}GitHub Repo Publisher${NC}  v12               ${BLU}│${NC}\n"
        printf "${BLU}│${NC}  ${DIM}interactive · animated · safe${NC}         ${BLU}│${NC}\n"
        printf "${BLU}╰──────────────────────────────────────────╯${NC}\n"
        $DRY_RUN && printf "                ${YEL}(DRY RUN)${NC}\n"
        echo
        return
    fi

    # Animated: each line typewriter-rendered with a small delay between.
    local -a lines=(
        "${BLU}╭─────────────────────────────────────────────╮${NC}"
        "${BLU}│${NC}                                             ${BLU}│${NC}"
        "${BLU}│${NC}     ${BOLD}GitHub Repo Publisher${NC}${BLU}  v12                   ${BLU}│${NC}"
        "${BLU}│${NC}                                             ${BLU}│${NC}"
        "${BLU}│${NC}     ${DIM}→ ship code to GitHub in one shot${NC}       ${BLU}│${NC}"
        "${BLU}│${NC}     ${DIM}→ interactive · animated · safe${NC}           ${BLU}│${NC}"
        "${BLU}│${NC}                                             ${BLU}│${NC}"
        "${BLU}╰─────────────────────────────────────────────╯${NC}"
    )
    for line in "${lines[@]}"; do
        printf "%s\n" "$line"
        sleep 0.04
    done
    $DRY_RUN && { printf "                       ${YEL}(DRY RUN)${NC}\n"; sleep 0.05; }
    echo
}

print_help() {
cat <<'EOF'
github-publish.sh — set up a project and push it to GitHub.

USAGE
  ./github-publish.sh            Run interactively
  ./github-publish.sh --dry-run  Preview each step without changing anything
  ./github-publish.sh --scan-only  Just run the secrets scan + gitignore audit (no push)
  ./github-publish.sh --no-scan  Skip the secret scanner for this run
  ./github-publish.sh --allow-list=FILE  Override the allow-list file (default: .gpublishallow)
  ./github-publish.sh --bootstrap  Force bootstrap mode (init new repo from scratch)
  ./github-publish.sh --update    Force update mode (push changes to existing repo)
  ./github-publish.sh --force     Allow force push if local diverges from remote
  ./github-publish.sh --wipe      Destroy all remote history + upload as a single new commit
  ./github-publish.sh --quick     Skip audit + secret scan (assumes already-validated re-push)
  ./github-publish.sh --no-verify  Bypass local git hooks during push
  ./github-publish.sh --tui       Open lazygit-style dashboard before push
  ./github-publish.sh --help     Show this help

WHAT IT DOES
  1. Asks for the repo URL + description + visibility.
  2. Creates the repo on GitHub (via gh CLI, or via $GITHUB_TOKEN + REST API).
  3. git init (if needed) + sets remote origin.
  4. Generates .gitignore (auto-detects Node / Python / Go / Rust / fallback).
  5. Generates README.md from project name + description.
  6. Optionally adds a LICENSE (MIT / Apache-2.0 / GPL-3.0 / BSD-3-Clause).
  7. Warns about large files (>10 MB) and offers Git LFS init.
  8. Audits your .gitignore against what's actually on disk — flags missing patterns.
  9. Scans staged files for secrets (API keys, tokens, .env, private keys) — blocks the commit if any are found (allow-list: .gpublishallow).
  10. Shows a pre-commit summary (file list, count, total size) for review.
  11. In UPDATE mode: fetches remote, detects divergence (ahead/behind/diverged), and offers rebase / merge / force-push before pushing.
  9. Stages, commits, pushes.

ENV
  GITHUB_TOKEN   Personal access token (used as fallback for repo creation).
EOF
}

DRY_RUN=false
SCAN_ONLY=false
NO_SCAN=false
QUICK_MODE=false       # --quick: skip safety checks for re-pushes
NO_VERIFY=false        # --no-verify: bypass git hooks during push
ALLOW_LIST_FILE=".gpublishallow"
FORCE_PUSH=false
MODE_FORCED=""          # "", "bootstrap", or "update"
WIPE_MODE=false        # Force a wipe + re-upload (orphan + force push)
ALLOW_PATTERNS=()
TUI_MODE=false         # --tui: open lazygit-style dashboard before push

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --scan-only) SCAN_ONLY=true ;;
        --no-scan) NO_SCAN=true ;;
        --force) FORCE_PUSH=true ;;
        --wipe) WIPE_MODE=true ;;
        --quick) QUICK_MODE=true ;;
        --no-verify) NO_VERIFY=true ;;
        --bootstrap) MODE_FORCED="bootstrap" ;;
        --update) MODE_FORCED="update" ;;
        --tui) TUI_MODE=true ;;
        --allow-list=*) ALLOW_LIST_FILE="${arg#*=}" ;;
        --help|-h) print_help; exit 0 ;;
        *) err "Unknown flag: $arg"; print_help; exit 1 ;;
    esac
done

# ---------- safety helpers ----------
load_allow_list() {
    ALLOW_PATTERNS=()
    if [[ -f "$ALLOW_LIST_FILE" ]]; then
        mapfile -t ALLOW_PATTERNS < "$ALLOW_LIST_FILE"
    fi
    return 0
}

is_allowed() {
    local file="$1"
    for pat in "${ALLOW_PATTERNS[@]}"; do
        [[ -z "$pat" || "$pat" == \#* ]] && continue
        # shell glob match
        # shellcheck disable=SC2254
        [[ "$file" == $pat ]] && return 0
    done
    return 1
}

# Filenames that are always flagged (high-signal).
SENSITIVE_NAMES=(
    ".env" ".env.local" ".env.*.local" ".env.production" ".env.development"
    "*.pem" "*.key" "*.p12" "*.pfx"
    "id_rsa" "id_dsa" "id_ed25519" "id_ecdsa" "id_rsa.pub"
    "credentials.json" "credentials.yaml" "credentials.yml"
    "secrets.json" "secrets.yaml" "secrets.yml" "secrets.toml"
    ".npmrc" ".pypirc" ".netrc"
)

# Label|Regex pairs. Each regex is run via grep -E.
SECRET_PATTERNS=(
    "AWS Access Key ID|AKIA[0-9A-Z]{16}"
    "AWS Secret Access Key|(?i)aws(.{0,20})?(secret|private)?(.{0,20})?[A-Za-z0-9/+=]{40}"
    "GitHub Personal Access Token|gh[pousr]_[A-Za-z0-9]{36,255}"
    "GitHub Fine-Grained Token|github_pat_[A-Za-z0-9_]{82}"
    "OpenAI API Key|sk-(proj-)?[A-Za-z0-9_-]{20,}"
    "Anthropic API Key|sk-ant-[A-Za-z0-9_-]{20,}"
    "Google API Key|AIza[0-9A-Za-z_-]{35}"
    "Stripe Live Secret|sk_live_[A-Za-z0-9]{24,}"
    "Stripe Live Publishable|pk_live_[A-Za-z0-9]{24,}"
    "Slack Token|xox[baprs]-[A-Za-z0-9-]{10,}"
    "Discord Bot Token|[MN][A-Za-z\d]{23,}\.[A-Za-z\d_-]{6,7}\.[A-Za-z\d_-]{27,}"
    "Twilio API Key|SK[0-9a-fA-F]{32}"
    "SendGrid API Key|SG\.[A-Za-z0-9_-]{22}\.[A-Za-z0-9_-]{43}"
    "Mailgun API Key|key-[0-9a-zA-Z]{32}"
    "Heroku API Key|heroku[a-z0-9_ .-]*[ =:]['\"]?[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
    "JWT token|eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"
    "Private RSA/EC/SSH/SSL Key|-----BEGIN (RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----"
    "Bearer token|Bearer [A-Za-z0-9_\-\.=]{20,}"
    "Generic credential assignment|((api[_-]?key|secret|token|auth|access)[_-]?(key|token)?|password|passwd|pwd)[ ]*[:=][ ]*[\"'\''][A-Za-z0-9_\-]{16,}[\"'\'']"
)

is_text_file() {
    local mime
    mime=$(file --mime-type -b "$1" 2>/dev/null || echo "application/octet-stream")
    case "$mime" in
        text/*|application/json|application/xml|application/yaml|application/x-yaml|application/toml|application/javascript|application/x-shellscript|application/ecmascript|application/x-python|application/x-perl|application/postscript|"") return 0 ;;
    esac
    return 1
}

# Print all files we'd be tracking (or staged, if repo exists).
# In --scan-only mode, expand to the full tracked set so we cover committed state too.
collect_target_files() {
    if git rev-parse --git-dir >/dev/null 2>&1; then
        if $SCAN_ONLY; then
            { git ls-files; git diff --cached --name-only --diff-filter=ACM 2>/dev/null; } \
                | sort -u | grep -v '^$' || true
        else
            git diff --cached --name-only --diff-filter=ACM 2>/dev/null
        fi
    fi
}

# ---------- interactive picker (arrow-key navigation) ----------
# Lets the user move with ↑/↓, confirm with Enter. Falls back to numeric input
# when no controlling terminal is available (e.g., piped input, CI, dry-run tests).
#
# Args: PICK_PROMPT, then the choice strings. Sets REPLY to the chosen index
# (1-based, matching what a user would have typed), or empty if cancelled.
pick() {
    local prompt="$1"
    shift
    local choices=("$@")
    local count=${#choices[@]}
    local default=1
    # If last arg is an integer, treat it as default selection index.
    if (( count > 0 )) && [[ "${choices[-1]}" =~ ^[0-9]+$ ]]; then
        default="${choices[-1]}"
        unset 'choices[-1]'
        count=${#choices[@]}
    fi

    # Decide whether we can do TUI. Need /dev/tty and stty available.
    local use_tty=false
    if [[ -e /dev/tty ]] && command -v stty >/dev/null 2>&1; then
        # Refuse TUI if NO_COLOR is set or we're not actually interactive
        if [[ "${NO_COLOR:-}" != "1" ]] && $IS_TTY; then
            use_tty=true
        fi
    fi

    if ! $use_tty; then
        # Plain numbered fallback.
        echo
        dim "  $prompt"
        for i in "${!choices[@]}"; do
            echo "    $((i+1))) ${choices[$i]}"
        done
        ask "  Pick [$default]: "
        read -r REPLY
        REPLY="${REPLY:-$default}"
        # Validate
        if [[ "$REPLY" =~ ^[0-9]+$ ]] && (( REPLY >= 1 && REPLY <= count )); then
            return 0
        fi
        err "Invalid choice."
        return 1
    fi

    # TUI mode — read keys from /dev/tty.
    local selected=$((default - 1))
    if (( selected < 0 || selected >= count )); then selected=0; fi
    # Save terminal state
    local tty_fd
    exec 3>&1     # save stdout (FD 3)
    exec </dev/tty # read from controlling tty

    local stty_save
    stty_save=$(stty -g 2>/dev/null) || stty_save=""
    stty -echo -icanon min 0 2>/dev/null

    printf "\033[?25l"  # hide cursor

    # Render once + on change.
    render_menu() {
        printf "\033[2J\033[H" 2>/dev/null   # clear, home cursor
        dim "$prompt"
        echo
        for i in "${!choices[@]}"; do
            if (( i == selected )); then
                printf "  ${GRN}▶${NC} ${BOLD}%s${NC}\n" "${choices[$i]}"
            else
                printf "    ${DIM}%s${NC}\n" "${choices[$i]}"
            fi
        done
        echo
        dim "  ↑↓ navigate, Enter select, q cancel"
    }

    render_menu

    while true; do
        local key
        IFS= read -r -n1 key 2>/dev/null || key=""
        case "$key" in
            $'\033')  # ESC sequence
                local seq1 seq2
                IFS= read -r -n1 seq1 2>/dev/null || seq1=""
                IFS= read -r -n1 seq2 2>/dev/null || seq2=""
                case "$seq1$seq2" in
                    '[A') selected=$(( (selected - 1 + count) % count )) ;;  # ↑
                    '[B') selected=$(( (selected + 1) % count )) ;;  # ↓
                esac
                render_menu
                ;;
            ''|$'\n'|$'\r')
                # Enter pressed
                break
                ;;
            'k')  # vi-style up
                selected=$(( (selected - 1 + count) % count ))
                render_menu
                ;;
            'j')  # vi-style down
                selected=$(( (selected + 1) % count ))
                render_menu
                ;;
            'q'|$'\003')
                # cancel
                REPLY=""
                printf "\033[?25h"
                [[ -n "$stty_save" ]] && stty "$stty_save" 2>/dev/null
                exec 1>&3 3>&-
                return 1
                ;;
        esac
    done

    REPLY=$((selected + 1))

    # Restore terminal
    printf "\033[?25h"
    [[ -n "$stty_save" ]] && stty "$stty_save" 2>/dev/null
    exec 1>&3 3>&-

    # Clear the picker UI and replace with a compact "you chose X" line so the
    # caller sees a clean visual transition (no leftover ↑↓ footer floating).
    printf "\033[2J\033[H" 2>/dev/null
    printf "  ${DIM}${prompt}${NC}\n"
    printf "  ${GRN}▶${NC} ${BOLD}%s${NC}\n" "${choices[$selected]}"

    return 0
}

# ---------- .gitignore auditor ----------
# Walks .gitignore vs what's on disk. Suggests additions for common leak-prone dirs.
audit_gitignore() {
    load_allow_list

    local -a SUGGESTIONS=()

    in_gitignore() {
        local needle="$1"
        [[ -f .gitignore ]] || return 1
        grep -qF "$needle" .gitignore 2>/dev/null || return 1
        return 0
    }

    on_disk() {
        local d="$1"
        [[ -d "$d" || -f "$d" ]]
    }

    # Build artifact directories
    local -a ARTIFACT_DIRS=(
        "node_modules" "dist" "build" "out" ".next" ".nuxt" ".cache"
        ".turbo" ".vite" ".parcel-cache" "coverage"
        "__pycache__" ".pytest_cache" ".mypy_cache" ".ruff_cache"
        ".venv" "venv" "env" "target" "bin" "obj"
        ".gradle" ".idea" ".vscode" ".fleet"
    )
    for d in "${ARTIFACT_DIRS[@]}"; do
        on_disk "$d" || continue
        is_allowed "$d" && continue
        if in_gitignore "$d/" || in_gitignore "/$d/" || in_gitignore "$d"; then
            continue
        fi
        SUGGESTIONS+=("$d/ exists on disk but isn't gitignored")
    done

    # Language-specific artifacts (file-by-file)
    local -a ARTIFACT_FILES=(
        "*.pyc" "*.pyo" "*.pyd"
        "*.log" "*.tmp"
        ".DS_Store" "Thumbs.db"
        "*.swp" "*.swo"
    )
    for f in "${ARTIFACT_FILES[@]}"; do
        # Only suggest if matching files actually exist
        compgen -G "$f" > /dev/null 2>&1 && [[ -n "$(find . -maxdepth 3 -name "$f" -not -path './.git/*' 2>/dev/null | head -1)" ]] || continue
        if in_gitignore "$f"; then continue; fi
        SUGGESTIONS+=("files matching $f exist but aren't gitignored")
    done

    # High-priority env / secret filenames
    local -a ENV_FILES=( ".env" ".env.local" ".env.production" ".env.development" )
    for f in "${ENV_FILES[@]}"; do
        [[ -f "$f" ]] || continue
        is_allowed "$f" && continue
        if in_gitignore "$f" || in_gitignore ".env*"; then continue; fi
        SUGGESTIONS+=("$f — sensitive env file present, not gitignored!")
    done

    if [[ ${#SUGGESTIONS[@]} -eq 0 ]]; then
        ok ".gitignore audit: no missing patterns detected."
        return 0
    fi

    echo
    warn ".gitignore audit — consider adding:"
    printf '    %s\n' "${SUGGESTIONS[@]}"
    echo
    ask "Patch .gitignore with these suggestions automatically? [y/N]: "
    read -r AUDIT_PATCH
    if [[ "$AUDIT_PATCH" =~ ^[yY]$ ]]; then
        # Dedupe and append suggestions after converting to gitignore paths
        {
            echo
            echo "# Added by github-publish on $(date -u +%Y-%m-%dT%H:%M:%SZ)"
            for s in "${SUGGESTIONS[@]}"; do
                # Extract the leading token (file/dir name) before " — exists..." or " files matching"
                local token
                token=$(printf '%s' "$s" | sed -E 's/^([^ ]+).*/\1/')
                echo "$token"
            done
        } >> .gitignore
        ok "Patched .gitignore."
    fi
}

# ---------- secret scanner ----------
# Iterates: scan → user choice (allow / ignore / abort) → re-scan until clean or aborted.
# Args: a newline-separated list of files to scan.
scan_secrets() {
    local target_files="$1"

    if $NO_SCAN; then
        info "(secret scan disabled via --no-scan)"
        return 0
    fi
    if [[ -z "$target_files" ]]; then
        return 0
    fi

    load_allow_list

    # Pre-count how many files we'll actually scan, for the progress bar.
    local total=0
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        is_allowed "$file" && continue
        [[ ! -f "$file" ]] && continue
        [[ "$file" == "./.gpublishallow" ]] && continue
        if git rev-parse --git-dir >/dev/null 2>&1 \
            && git check-ignore "$file" >/dev/null 2>&1; then
            continue
        fi
        if ! is_text_file "$file"; then continue; fi
        total=$((total + 1))
    done <<< "$target_files"

    if [[ $total -eq 0 ]]; then
        dim "  → No scannable files."
        return 0
    fi

    if ! $IS_TTY; then
        info "Scanning $total file(s) for secrets..."
    else
        printf "\n  ${BLU}Scanning %d file(s) for secrets...${NC}\n" "$total"
    fi

    while true; do
        local findings=()
        local count=0
        local idx=0

        while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            is_allowed "$file" && continue
            [[ ! -f "$file" ]] && continue
            [[ "$file" == "./.gpublishallow" ]] && continue

            # Skip files already covered by .gitignore (would never get pushed)
            if git rev-parse --git-dir >/dev/null 2>&1 \
                && git check-ignore "$file" >/dev/null 2>&1; then
                continue
            fi

            # Skip binary files (without extensions we recognize as text)
            if ! is_text_file "$file"; then
                continue
            fi

            idx=$((idx + 1))
            if $IS_TTY; then
                scan_tick "$idx" "$total" "$file"
            fi

            local base
            base=$(basename "$file")

            # Filename flags (always flagged if not allowed)
            local flag_match=""
            for npat in "${SENSITIVE_NAMES[@]}"; do
                # shellcheck disable=SC2254
                if [[ "$base" == $npat ]]; then
                    flag_match="sensitive filename: matches '$npat'"
                    break
                fi
            done
            if [[ -n "$flag_match" ]]; then
                findings+=("$file — $flag_match")
                count=$((count + 1))
                continue
            fi

            # Content detectors (one hit per file is enough)
            for det in "${SECRET_PATTERNS[@]}"; do
                local label="${det%%|*}"
                local regex="${det#*|}"
                if grep -qE "$regex" "$file" 2>/dev/null; then
                    findings+=("$file — $label")
                    count=$((count + 1))
                    break
                fi
            done
        done <<< "$target_files"

        if $IS_TTY; then
            # Move past the progress line, then state the result cleanly.
            printf "\r\033[2K"
            if [[ $count -eq 0 ]]; then
                printf "  ${GRN}✓${NC} ${DIM}scanned %d file(s) — clean${NC}\n" "$total"
            else
                printf "  ${RED}✗${NC} ${DIM}scanned %d file(s) — %d finding(s)${NC}\n" "$total" "$count"
            fi
        fi

        if [[ $count -eq 0 ]]; then
            return 0
        fi

        SCAN_DID_REPORT=1

        echo
        err "Potential secrets found in $count file(s):"
        FIRST_FILE=""
        for line in "${findings[@]}"; do
            local file_part="${line%% — *}"
            local rest="${line#*— }"
            [[ -z "$FIRST_FILE" ]] && FIRST_FILE="$file_part"
            printf '    %s%-40s%s  %s\n' "${RED}" "$file_part" "${NC}" "$rest"
        done
        echo
        echo "    Choose:"
        echo "      1) Abort — go fix it"
        echo "      2) Allow-list a path (writes .gpublishallow)"
        echo "      3) gitignore a path + unstage"
        echo "      4) Proceed anyway"
        echo
        ask "Pick [1]: "
        read -r SECRET_CHOICE
        case "${SECRET_CHOICE:-1}" in
            1) return 1 ;;
            2)
                ask "Glob to allow (e.g. 'tests/fixtures/**' or '*.example'): "
                read -r ALLOW
                if [[ -n "$ALLOW" ]]; then
                    touch "$ALLOW_LIST_FILE"
                    echo "$ALLOW" >> "$ALLOW_LIST_FILE"
                    ok "Added '$ALLOW' to $ALLOW_LIST_FILE"
                    load_allow_list
                    if $SCAN_ONLY; then
                        echo
                        scan_secrets "$(collect_target_files)" || exit 1
                        ok "Re-scan: clean."
                        exit 0
                    fi
                    TARGET_FILES=$(collect_target_files)
                    continue
                fi
                return 1
                ;;
            3)
                echo "$FIRST_FILE" >> .gitignore
                ok "Added '$FIRST_FILE' to .gitignore"
                git rm --cached -r --quiet "$FIRST_FILE" 2>/dev/null || true
                load_allow_list
                if $SCAN_ONLY; then exit 0; fi
                TARGET_FILES=$(collect_target_files)
                continue
                ;;
            4)
                warn "Proceeding despite secret findings."
                return 0
                ;;
            *) return 1 ;;
        esac
    done
}

# ==============================================================================
# ============================ TUI DASHBOARD ==================================
# ==============================================================================
# A lazygit-inspired full-screen dashboard. Opt-in via --tui flag. Falls back
# gracefully to the wizard on terminals that can't do ANSI cursor positioning.

TUI_MODE=false        # set to true by --tui
TUI_ACTIVE_TAB=0      # 0=Ready, 1=Files, 2=Diff, 3=Secrets, 4=Settings
TUI_LOG_OPEN=true     # bottom panel visible
TUI_MODAL=""          # active modal: "", "help", "confirm-push", etc.
TUI_TABS=("Ready" "Files" "Diff" "Secrets" "Settings")
TUI_LOG_LINES=()      # ring buffer of recent log lines
TUI_LOG_MAX=12
TUI_NEEDS_REDRAW=true

# Check if terminal supports the TUI.
tui_supported() {
    [[ -e /dev/tty ]] || return 1
    command -v tput >/dev/null 2>&1 || return 1
    local cols rows
    cols=$(tput cols 2>/dev/null || echo 0)
    rows=$(tput lines 2>/dev/null || echo 0)
    (( cols >= 80 && rows >= 24 )) || return 1
    # Don't open the TUI inside another TUI (vim, htop, etc.) — they'd capture keys.
    [[ -z "${TMUX:-}" ]] || return 0  # tmux OK
    return 0
}

tui_cols() { tput cols 2>/dev/null || echo 80; }
tui_rows() { tput lines 2>/dev/null || echo 24; }

# Render the full TUI screen. Called after every state change.
tui_render() {
    $TUI_NEEDS_REDRAW || return 0
    local cols rows
    cols=$(tui_cols)
    rows=$(tui_rows)

    # Move cursor home + clear from cursor down.
    printf '\033[H\033[J'

    # ----- HEADER -----
    local header_line
    header_line=$(printf '%s' "${OWNER:-?}/${REPO:-?}  ${DIM}·${NC}  ${CURRENT_BRANCH:-main}  ${DIM}·${NC}  ${MODE:-BOOTSTRAP}  ${DIM}·${NC}  ⏱ ${TUI_ELAPSED:-0:00}  ${DIM}·${NC}  $(date +%H:%M:%S)")
    printf "${BOLD}${INV}${header_line}${NC}\n" | head -c $((cols - 1))
    printf '\n'

    # ----- TAB BAR -----
    printf '  '
    for i in "${!TUI_TABS[@]}"; do
        if (( i == TUI_ACTIVE_TAB )); then
            printf "${BGD}${BOLD} ${TUI_TABS[$i]} ${NC}  "
        else
            printf "${DIM} ${TUI_TABS[$i]}  ${NC}  "
        fi
    done
    printf '\n'

    # ----- CONTENT AREA -----
    # Reserve rows for: header (2) + tab bar (1) + footer (1) + log (TUI_LOG_OPEN ? TUI_LOG_MAX+1 : 0)
    local reserved=4
    $TUI_LOG_OPEN && reserved=$((reserved + TUI_LOG_MAX + 1))
    $TUI_MODAL_OPEN && reserved=$((reserved + 8))
    local content_rows=$((rows - reserved))
    (( content_rows < 8 )) && content_rows=8

    tui_render_active_tab "$content_rows" "$cols"

    # ----- LOG PANEL -----
    if $TUI_LOG_OPEN; then
        printf '\n'
        printf "${DIM}─ LOG ───────────────────────────────────────────────────────────────${NC}\n"
        local log_line
        local start=$(( ${#TUI_LOG_LINES[@]} - TUI_LOG_MAX ))
        (( start < 0 )) && start=0
        for ((i = start; i < ${#TUI_LOG_LINES[@]}; i++)); do
            printf '  %s\n' "${TUI_LOG_LINES[$i]}"
        done
        # Pad to fixed height so the footer doesn't jump.
        local drawn=$(( ${#TUI_LOG_LINES[@]} - start ))
        for ((i = drawn; i < TUI_LOG_MAX; i++)); do
            printf '\n'
        done
    fi

    # ----- FOOTER (key hints) -----
    printf "${DIM}"
    printf 'Tab next panel  Shift+Tab prev  1-5 jump tab  Space toggle  p push  q quit  ? help'
    printf "${NC}"

    TUI_NEEDS_REDRAW=false
}

tui_render_active_tab() {
    local rows=$1
    local cols=$2
    case $TUI_ACTIVE_TAB in
        0) tui_render_ready_tab "$rows" "$cols" ;;
        1) tui_render_files_tab "$rows" "$cols" ;;
        2) tui_render_diff_tab "$rows" "$cols" ;;
        3) tui_render_secrets_tab "$rows" "$cols" ;;
        4) tui_render_settings_tab "$rows" "$cols" ;;
    esac
}

tui_render_ready_tab() {
    local rows=$1
    local cols=$2
    printf "${BOLD}  Readiness checklist${NC}\n\n"
    local checks=(
        "Repo URL parsed:${OWNER:+${OWNER}/${REPO}}${OWNER:-  pending...}"
        "Auth resolved:${MODE:+${MODE}}${MODE:-  pending...}"
        "Local repo ready:${LOCAL_READY:-  pending...}"
        "Remote reachable:${REMOTE_REACHABLE:-  checking...}"
        ".gitignore audit:${GITIGNORE_AUDIT:-  pending...}"
        "Files staged:${STAGED_COUNT:-0} files (${STAGED_SIZE:-0} bytes)"
        "Secrets scanned:${SECRETS_CLEAN:+clean}${SECRETS_CLEAN:-  pending...}"
        "Commit prepared:${COMMIT_SHA:-  pending...}"
        "Push strategy:${PUSH_STRATEGY:-default}"
    )
    for entry in "${checks[@]}"; do
        local label="${entry%%:*}"
        local value="${entry#*:}"
        printf '  %s  %s\n' "${label}" "${value}"
    done
}

tui_render_files_tab() {
    local rows=$1
    local cols=$2
    printf "${BOLD}  Staged files${NC}  ${DIM}(${STAGED_COUNT:-0} files, ${STAGED_SIZE_HUMAN:-0 B})${NC}\n\n"
    if [[ ${#TUI_FILE_LIST[@]} -eq 0 ]]; then
        printf "  ${DIM}No files staged yet.${NC}\n"
        return
    fi
    local visible=$((rows - 4))
    (( visible > 40 )) && visible=40
    local start=$TUI_FILE_SCROLL
    local end=$((start + visible))
    (( end > ${#TUI_FILE_LIST[@]} )) && end=${#TUI_FILE_LIST[@]}
    for ((i = start; i < end; i++)); do
        printf '  %s\n' "${TUI_FILE_LIST[$i]}"
    done
}

tui_render_diff_tab() {
    local rows=$1
    local cols=$2
    printf "${BOLD}  Diff preview${NC}  ${DIM}(commit ${COMMIT_SHA:-?})${NC}\n\n"
    if [[ -z "${TUI_DIFF_TEXT:-}" ]]; then
        printf "  ${DIM}No diff to display yet — stage files first.${NC}\n"
        return
    fi
    local visible=$((rows - 4))
    (( visible > 80 )) && visible=80
    local start=$TUI_DIFF_SCROLL
    local diff_arr
    mapfile -t diff_arr <<< "$TUI_DIFF_TEXT"
    local end=$((start + visible))
    (( end > ${#diff_arr[@]} )) && end=${#diff_arr[@]}
    for ((i = start; i < end; i++)); do
        local line="${diff_arr[$i]}"
        # Color diff lines
        if [[ "$line" =~ ^\+[^\+] ]]; then
            printf "  ${GRN}%s${NC}\n" "${line:0:$((cols-4))}"
        elif [[ "$line" =~ ^-[^-] ]]; then
            printf "  ${RED}%s${NC}\n" "${line:0:$((cols-4))}"
        elif [[ "$line" =~ ^@@ ]]; then
            printf "  ${CYN}%s${NC}\n" "${line:0:$((cols-4))}"
        else
            printf "  %s\n" "${line:0:$((cols-4))}"
        fi
    done
}

tui_render_secrets_tab() {
    local rows=$1
    local cols=$2
    printf "${BOLD}  Secret scan results${NC}\n\n"
    if [[ ${#TUI_SECRET_FINDINGS[@]} -eq 0 ]]; then
        printf "  ${GRN}\xe2\x9c\x93${NC}  ${GRN}No secrets detected${NC}\n"
        return
    fi
    local visible=$((rows - 4))
    (( visible > 40 )) && visible=40
    for ((i = 0; i < visible && i < ${#TUI_SECRET_FINDINGS[@]}; i++)); do
        printf '  %s\n' "${TUI_SECRET_FINDINGS[$i]}"
    done
}

tui_render_settings_tab() {
    local rows=$1
    local cols=$2
    printf "${BOLD}  Push settings${NC}\n\n"
    printf "  Visibility:        ${GRN}${VISIBILITY:-public}${NC}\n"
    printf "  Description:       ${DESC:-<none>}\n"
    printf "  License:           ${LICENSE:-MIT}\n"
    printf "  Force push:        %b\n" "$([[ ${FORCE_PUSH:-false} == true ]] && printf '${RED}enabled${NC}' || printf '${DIM}disabled${NC}')"
    printf "  Wipe mode:         %b\n" "$([[ ${WIPE_MODE:-false} == true ]] && printf '${RED}enabled${NC}' || printf '${DIM}disabled${NC}')"
    printf "  Skip scan:         %b\n" "$([[ ${SCAN_ONLY:-false} == true ]] && printf '${DIM}skip${NC}' || printf '${GRN}yes${NC}')"
    printf "  Quiet / --quick:   %b\n" "$([[ ${QUIET:-false} == true ]] && printf '${YEL}on${NC}' || printf '${DIM}off${NC}')"
    printf "  No verify hooks:   %b\n" "$([[ ${NO_VERIFY_HOOKS:-false} == true ]] && printf '${YEL}on${NC}' || printf '${DIM}off${NC}')"
}

# Append a log line to the ring buffer.
tui_log() {
    local msg="$*"
    local ts
    ts=$(printf '%(%H:%M:%S)T' -1)
    TUI_LOG_LINES+=("${DIM}${ts}${NC}  ${msg}")
    # Trim ring buffer.
    if (( ${#TUI_LOG_LINES[@]} > TUI_LOG_MAX * 2 )); then
        TUI_LOG_LINES=("${TUI_LOG_LINES[@]:${#TUI_LOG_LINES[@]}-TUI_LOG_MAX}")
    fi
    TUI_NEEDS_REDRAW=true
}

# Read one key from /dev/tty. Handles ESC sequences for arrow keys.
# Output: stores key in $TUI_KEY (single char for normal, "UP"/"DOWN"/"LEFT"/"RIGHT"/"TAB"/"SHIFT_TAB" for special).
TUI_KEY=""
tui_read_key() {
    TUI_KEY=""
    local k
    IFS= read -r -n1 k < /dev/tty 2>/dev/null || return 1
    case "$k" in
        $'\033')
            local s1 s2
            IFS= read -r -n1 s1 < /dev/tty 2>/dev/null || s1=""
            IFS= read -r -n1 s2 < /dev/tty 2>/dev/null || s2=""
            case "$s1$s2" in
                '[A') TUI_KEY="UP" ;;
                '[B') TUI_KEY="DOWN" ;;
                '[C') TUI_KEY="RIGHT" ;;
                '[D') TUI_KEY="LEFT" ;;
                *)    TUI_KEY="ESC" ;;
            esac
            ;;
        $'\t')   TUI_KEY="TAB" ;;
        $'\x7f') TUI_KEY="BACKSPACE" ;;
        $'\x01') TUI_KEY="CTRL_A" ;;
        $'\x05') TUI_KEY="CTRL_E" ;;
        $'\x0b') TUI_KEY="CTRL_K" ;;
        $'\x15') TUI_KEY="CTRL_U" ;;
        $'\x03') TUI_KEY="CTRL_C" ;;
        $'\x04') TUI_KEY="CTRL_D" ;;
        ' ')     TUI_KEY="SPACE" ;;
        *)       TUI_KEY="$k" ;;
    esac
    return 0
}

# Run the TUI dashboard. Caller must set up state vars (OWNER, REPO, etc.)
# before calling. Exits when user confirms push (sets TUI_CONFIRM=true),
# cancels (TUI_CONFIRM=false), or requests a transition out of TUI mode.
TUI_CONFIRM=false
tui_run() {
    if ! tui_supported; then
        warn "TUI not supported on this terminal — falling back to wizard."
        return 1
    fi
    local stty_save
    stty_save=$(stty -g 2>/dev/null) || stty_save=""
    stty -echo -icanon min 0 2>/dev/null
    printf '\033[?25l'  # hide cursor
    printf '\033[2J'    # clear screen

    # Start elapsed clock.
    TUI_START_TS=$(date +%s)
    trap 'tui_cleanup' RETURN

    tui_log "TUI dashboard open"
    tui_render

    while true; do
        # Background tick: re-render every second so the clock updates.
        # We use a simple sleep loop because bash can't easily do async.
        local now
        now=$(date +%s)
        TUI_ELAPSED=$((now - TUI_START_TS))
        local mins=$((TUI_ELAPSED / 60))
        local secs=$((TUI_ELAPSED % 60))
        TUI_ELAPSED=$(printf '%d:%02d' "$mins" "$secs")
        TUI_NEEDS_REDRAW=true
        tui_render

        # Wait for key (with 1s timeout for clock refresh).
        local key=""
        IFS= read -r -t 1 -n1 key < /dev/tty 2>/dev/null || key=""
        if [[ -z "$key" ]]; then
            continue  # tick — re-render with updated clock
        fi

        # Handle key.
        case "$key" in
            $'\033')
                local s1 s2
                IFS= read -r -t 0.05 -n1 s1 < /dev/tty 2>/dev/null || s1=""
                IFS= read -r -t 0.05 -n1 s2 < /dev/tty 2>/dev/null || s2=""
                case "$s1$s2" in
                    '[A') TUI_KEY="UP" ;;
                    '[B') TUI_KEY="DOWN" ;;
                    '[C') TUI_KEY="RIGHT" ;;
                    '[D') TUI_KEY="LEFT" ;;
                    *)    TUI_KEY="ESC" ;;
                esac
                ;;
            $'\t')
                # TAB / Shift+TAB cycle tabs.
                local s1=""
                IFS= read -r -t 0.05 -n1 s1 < /dev/tty 2>/dev/null || s1=""
                if [[ "$s1" == $'\033' ]] || [[ -z "$s1" && $(( RANDOM % 2 )) -eq 0 ]]; then
                    TUI_ACTIVE_TAB=$(( (TUI_ACTIVE_TAB - 1 + ${#TUI_TABS[@]}) % ${#TUI_TABS[@]} ))
                else
                    TUI_ACTIVE_TAB=$(( (TUI_ACTIVE_TAB + 1) % ${#TUI_TABS[@]} ))
                fi
                ;;
            '1') TUI_ACTIVE_TAB=0 ;;
            '2') TUI_ACTIVE_TAB=1 ;;
            '3') TUI_ACTIVE_TAB=2 ;;
            '4') TUI_ACTIVE_TAB=3 ;;
            '5') TUI_ACTIVE_TAB=4 ;;
            'l') TUI_LOG_OPEN=! $TUI_LOG_OPEN ;;
            'p'|'P')
                TUI_CONFIRM=true
                tui_log "User confirmed — proceeding to push."
                break
                ;;
            'q'|'Q'|$'\x03')
                TUI_CONFIRM=false
                tui_log "User cancelled."
                break
                ;;
            '?'|'h'|'H')
                tui_show_help_modal
                ;;
            'j'|'J')
                case $TUI_ACTIVE_TAB in
                    1) TUI_FILE_SCROLL=$((TUI_FILE_SCROLL + 1)) ;;
                    2) TUI_DIFF_SCROLL=$((TUI_DIFF_SCROLL + 1)) ;;
                esac
                ;;
            'k'|'K')
                case $TUI_ACTIVE_TAB in
                    1) TUI_FILE_SCROLL=$((TUI_FILE_SCROLL - 1)); (( TUI_FILE_SCROLL < 0 )) && TUI_FILE_SCROLL=0 ;;
                    2) TUI_DIFF_SCROLL=$((TUI_DIFF_SCROLL - 1)); (( TUI_DIFF_SCROLL < 0 )) && TUI_DIFF_SCROLL=0 ;;
                esac
                ;;
        esac
        TUI_NEEDS_REDRAW=true
    done

    tui_cleanup
    [[ -n "$stty_save" ]] && stty "$stty_save" 2>/dev/null
    return 0
}

tui_cleanup() {
    printf '\033[?25h'  # show cursor
    printf '\033[2J\033[H'
}

tui_show_help_modal() {
    printf '\033[?25h'
    printf '\033[2J\033[H'
    cat <<'EOF'
╔═══════════════════════════════════════════════════════════════════════════╗
║  TUI Dashboard — Key Bindings                                            ║
╠═══════════════════════════════════════════════════════════════════════════╣
║                                                                           ║
║   Tab / Shift+Tab      cycle panels                                      ║
║   1-5                  jump to tab by number                              ║
║   j / k or ↓ / ↑       scroll current tab                                 ║
║   Space                toggle (staging)                                   ║
║   l                    toggle log panel                                   ║
║   p                    confirm and push                                   ║
║   q or Ctrl-C          cancel                                             ║
║   ?                    show this help                                     ║
║                                                                           ║
║   Tabs:                                                                   ║
║     Ready     checklist of prerequisites                                 ║
║     Files     staged files with toggle                                   ║
║     Diff      preview of changes                                         ║
║     Secrets   scan findings                                              ║
║     Settings  push parameters                                            ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
EOF
    read -r -n1 -p "Press any key to return..." < /dev/tty
    printf '\033[2J\033[H'
    printf '\033[?25l'
}

# ---------- preflight ----------
command -v git >/dev/null 2>&1 || { err "git is not installed."; exit 1; }

# ---------- divergence helpers (shared by bootstrap + update paths) ----------
# Rebase that handles working-tree dirt cleanly by stashing before pulling.
rebase_with_stash() {
    local had_changes=false
    local stashed_label=""
    if ! git diff --quiet --ignore-submodules HEAD 2>/dev/null \
        || [[ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]]; then
        had_changes=true
    fi

    if $had_changes && ! $DRY_RUN; then
        info "Stashing local changes before rebase..."
        if git stash push -u -m "gpublish-temp-stash" >/dev/null 2>&1; then
            stashed_label="gpublish-temp-stash"
        else
            warn "Could not stash (nothing to stash, or stash refused)."
        fi
    fi

    if ! run git pull --rebase "origin" "$CURRENT_BRANCH"; then
        err "Rebase failed — likely conflicts."
        # Auto-clean so the user is NOT left in a half-rebased state.
        warn "Aborting the broken rebase to restore clean state..."
        git rebase --abort 2>/dev/null || true
        # Bring any stashed changes back.
        if [[ -n "$stashed_label" ]]; then
            if git stash list 2>/dev/null | grep -q "$stashed_label"; then
                warn "Restoring your stashed changes..."
                if ! git stash pop 2>/dev/null; then
                    warn "Stash still queued — restore with:  git stash pop"
                fi
            fi
        fi
        echo
        echo "  ${BOLD}Recovery options for next time:${NC}"
        echo "    ${GRN}1${NC}) Re-run and pick ${BOLD}option 2${NC} (merge) — git will try to combine"
        echo "    ${GRN}2${NC}) Re-run with ${BOLD}--force${NC} to overwrite the remote with your local copy"
        echo "    ${GRN}3${NC}) See what differs:  git log --oneline origin/$CURRENT_BRANCH..HEAD"
        echo "    ${GRN}4${NC}) Inspect conflicts manually:  git status"
        return 1
    fi

    if [[ -n "$stashed_label" ]] && ! $DRY_RUN; then
        if git stash list 2>/dev/null | grep -q "$stashed_label"; then
            info "Restoring your stashed changes..."
            git stash pop >/dev/null 2>&1 || warn "Run 'git stash pop' manually."
        fi
    fi
    return 0
}

# Merge that handles unrelated histories (fresh local + existing remote).
merge_unrelated() {
    if ! run git pull --no-rebase --allow-unrelated-histories "origin" "$CURRENT_BRANCH"; then
        err "Merge failed — likely conflicts."
        err "Resolve with 'git status' + edit, then 'git add' + 'git commit', then re-run."
        return 1
    fi
}

# ---------- wipe + re-upload ----------
# Replace the remote branch with a single new orphan commit containing the
# current local tree. All remote history is lost — there is no merge, no
# rebase, no conflicts. Just like 'git clone + reset' but on the server.
wipe_and_reset() {
    local target="$1"
    if $DRY_RUN; then
        warn "(dry-run: would wipe remote $target and push a single new commit)"
        return 0
    fi

    # Remember where we were so we can return there.
    local prev_branch
    prev_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
    [[ -z "$prev_branch" || "$prev_branch" == "DETACHED" ]] && prev_branch="$CURRENT_BRANCH"

    info "Creating orphan branch with the current tree..."
    local wipe_branch="__wipe_${RANDOM}"
    if ! git checkout --orphan "$wipe_branch" 2>&1 | sed 's/^/    /'; then
        err "Could not create orphan branch."
        return 1
    fi

    # Stage everything (including dotfiles).
    run git add -A

    # If there's nothing to commit (empty local tree), bail before destructive push.
    if git diff --cached --quiet; then
        err "Nothing to commit — your local tree is empty."
        warn "Aborting without touching the remote."
        git checkout "$prev_branch" 2>/dev/null
        return 1
    fi

    if ! run git commit -m "Wipe and re-upload $(date -u +%Y-%m-%dT%H:%M:%SZ)"; then
        err "Could not create the wipe commit."
        git checkout "$prev_branch" 2>/dev/null
        return 1
    fi

    warn "Force-pushing new single commit to remote ${BOLD}$target${NC}..."
    if ! run git push "origin" "HEAD:refs/heads/$target" --force; then
        err "Wipe push failed."
        git checkout "$prev_branch" 2>/dev/null
        return 1
    fi

    ok "Wipe complete."
    printf "  ${GRN}Remote $target now contains only your new single commit.${NC}\n"

    # Return the user to where they were.
    if git checkout "$prev_branch" 2>/dev/null; then
        ok "Switched back to ${BOLD}$prev_branch${NC}."
    fi
    return 0
}

# Show divergence to user, get a strategy choice, and execute it.
# Returns 0 = reconciled, non-zero = aborted.
# Args: $1 = "bootstrap" or "update"
reconcile_divergence() {
    local context="${1:-update}"   # "bootstrap" or "update"
    local force_ok=false $FORCE_PUSH && force_ok=true

    if $DRY_RUN; then
        warn "(dry-run: skipping fetch + divergence handling)"
        return 0
    fi

    # Fast path: use `git ls-remote --heads` to probe the remote's branch state.
    # This is dramatically faster than `git fetch` because it doesn't download
    # any objects — just the ref names. ~10–100× faster on slow connections.
    if ! spin_while "Probing origin/$CURRENT_BRANCH" \
            bash -c "set -o pipefail; git ls-remote --heads --exit-code 'origin' '$CURRENT_BRANCH' >/dev/null 2>&1"; then
        warn "Could not probe remote (offline? URL bad?). Continuing without divergence check."
        # Fall back to a full fetch so subsequent revision-list still works
        if ! spin_while "Fetching latest from origin" \
                bash -c "set -o pipefail; git fetch 'origin' '$CURRENT_BRANCH' 2>&1 | tail -5"; then
            warn "Fetch failed too — cannot reconcile, proceeding best-effort."
            return 0
        fi
    fi
    echo

    # The fast ls-remote doesn't create local tracking refs. If we want a
    # divergence check to work, we need refs/remotes/origin/<branch> to exist.
    # The fast ls-remote doesn't create local tracking refs. If we need to
    # do ahead/behind counts (for divergence), we have to fetch the objects.
    # Without this, `git rev-list HEAD...origin/main` returns 0/0 and we'd
    # wrongly report "in sync" when we aren't.
    if ! git rev-parse "origin/$CURRENT_BRANCH" >/dev/null 2>&1; then
        local REMOTE_SHA
        REMOTE_SHA=$(git ls-remote --heads "origin" "$CURRENT_BRANCH" 2>/dev/null | awk '{print $1}')
        if [[ -z "$REMOTE_SHA" ]]; then
            warn "Remote branch origin/$CURRENT_BRANCH doesn't exist yet — will push with -u."
            return 0
        fi
        # Tracking ref doesn't exist AND we don't have remote objects. Fall
        # back to a real fetch to populate both. A bit slower than the ls-remote
        # fast path but avoids the `fatal: update_ref nonexistent object` error
        # we hit previously when trying to write a tracking ref manually.
        info "Fetching objects to compute divergence accurately..."
        if ! run git fetch "origin" "$CURRENT_BRANCH" 2>&1 | tail -3; then
            warn "Fetch failed — cannot check divergence. Continuing best-effort."
            return 0
        fi
    fi

    local COUNTS AHEAD BEHIND
    COUNTS=$(git rev-list --left-right --count "HEAD...origin/$CURRENT_BRANCH" 2>/dev/null || echo "0 0")
    AHEAD=$(echo "$COUNTS" | awk '{print $1}')
    BEHIND=$(echo "$COUNTS" | awk '{print $2}')

    if [[ "$AHEAD" == "0" && "$BEHIND" == "0" ]]; then
        ok "In sync with origin/$CURRENT_BRANCH."
        return 0
    fi
    if [[ "$AHEAD" -gt 0 && "$BEHIND" -eq 0 ]]; then
        ok "$AHEAD commit(s) ahead of remote — ready to push."
        return 0
    fi

    # Detect the "duplicate repos" scenario: both branches touched many of the
    # same file paths. Rebase here will explode into many CONFLICT (add/add).
    # Surface this so the user picks a saner strategy than merge.
    local LOCAL_FILES REMOTE_FILES OVERLAP_PCT=""
    LOCAL_FILES=$(git diff --name-only "origin/$CURRENT_BRANCH"..HEAD 2>/dev/null | wc -l | tr -d ' ')
    REMOTE_FILES=$(git diff --name-only "HEAD..origin/$CURRENT_BRANCH" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$LOCAL_FILES" -gt 5 && "$REMOTE_FILES" -gt 5 ]]; then
        # Both sides added many files — likely duplicate repos.
        OVERLAP_PCT="high"
    fi

    h1 "Local and remote have diverged"

    if [[ "$context" == "bootstrap" ]]; then
        dim "  Your local repo was just initialized."
        dim "  The GitHub repo already has commits. To bridge the gap:"
    elif [[ -n "$OVERLAP_PCT" ]]; then
        dim "  Both branches added many of the same files (likely duplicate repos)."
        dim "  A regular merge/rebase will conflict on every file. Consider:"
        dim "    ${BOLD}--force${NC}      to overwrite the remote with your local copy, or"
        dim "    merge with ${BOLD}-X theirs${NC}  to discard local and keep the remote version."
    else
        dim "  Both your branch and origin/$CURRENT_BRANCH have unique commits."
        dim "  Pick how to reconcile before pushing:"
    fi

    # In bootstrap mode (fresh local repo, remote has commits), there's no
    # common ancestor — rebase and merge will both fail with conflicts. Only
    # force-push / wipe are viable. Order Wipe first and default to it.
    local PICK_PROMPT="How do you want to reconcile?"
    local -a PICK_CHOICES=()
    local DEFAULT_CHOICE=1

    if [[ "$context" == "bootstrap" ]]; then
        # Fresh-init + remote has commits — only Wipe / Force / Abort make sense.
        echo "  ${YEL}💡 Tip:${NC} For a fresh repo with no common history, ${RED}${BOLD}Wipe${NC} (option 1)"
        echo "           gives a clean single-commit repo on the remote. Rebase/merge"
        echo "           won't work because there's nothing in common to merge on."
        echo
        PICK_CHOICES=(
            "Wipe + re-upload  DESTROYS remote history, single new commit (RECOMMENDED)"
            "Force push        overwrites remote commits (--force set)"
            "Abort             no push, you fix manually"
        )
        DEFAULT_CHOICE=1
    else
        echo "    ${GRN}1${NC}) ${BOLD}Pull + rebase${NC}    ${DIM}clean linear history, autostash${NC}"
        echo "    ${GRN}2${NC}) ${BOLD}Pull + merge${NC}     ${DIM}merge commit keeps both histories${NC}"
        if $force_ok; then
            echo "    ${GRN}3${NC}) ${BOLD}Force push${NC}       ${YEL}${DIM}overwrites remote commits (--force set)${NC}"
        else
            echo "    ${GRN}3${NC}) ${YEL}Force push${NC}       ${DIM}overwrites remote — requires --force flag${NC}"
        fi
        echo "    ${RED}4${NC}) ${RED}${BOLD}Wipe + re-upload${NC} ${RED}${DIM}DESTROYS remote history, single new commit${NC}"
        echo "    ${GRN}5${NC}) ${BOLD}Abort${NC}           ${DIM}no push, you fix manually${NC}"
        echo
        if [[ -n "$OVERLAP_PCT" ]] && ! $force_ok; then
            echo "  ${YEL}💡 Tip:${NC} For the duplicate-repos case, ${BOLD}--force${NC} (option 3) or"
            echo "           ${RED}--wipe${NC} (option 4) is usually what you want."
            echo
        fi
        PICK_CHOICES=(
            "Pull + rebase    clean linear history, autostash"
            "Pull + merge     merge commit keeps both histories"
            "Force push       overwrites remote — requires --force flag"
            "Wipe + re-upload  DESTROYS remote history, single new commit"
            "Abort            no push, you fix manually"
        )
    fi

    if ! pick "$PICK_PROMPT" "${PICK_CHOICES[@]}" "$DEFAULT_CHOICE"
    then
        err "Cancelled."; return 1
    fi
    CHOICE="$REPLY"

    case "${CHOICE:-1}" in
        # In bootstrap mode, only 3 options are shown: Wipe / Force / Abort.
        # In other modes, 5 options are shown: rebase / merge / force / wipe / abort.
        1)
            if [[ "$context" == "bootstrap" ]]; then
                # Bootstrap + option 1 = Wipe + re-upload
                warn "WIPE + RE-UPLOAD chosen."
                warn "${RED}This DESTROYS all remote commits/files on $CURRENT_BRANCH.${NC}"
                warn "After this, the remote will have a single new commit matching your local tree."
                REMOTE_COUNT=$(git rev-list --count "origin/$CURRENT_BRANCH" 2>/dev/null || echo "?")
                echo
                echo "  About to discard: ${RED}$REMOTE_COUNT commit(s)${NC} from origin/$CURRENT_BRANCH"
                echo
                ask "Type ${RED}WIPE${NC} in capitals to confirm: "
                read -r WIPE_CONFIRM
                if [[ "$WIPE_CONFIRM" == "WIPE" ]]; then
                    WIPE_MODE=true
                    return 0
                fi
                err "Did not type 'WIPE' — aborting."
                return 1
            else
                rebase_with_stash && return 0 || return 1
            fi
            ;;
        2)
            if [[ "$context" == "bootstrap" ]]; then
                # Bootstrap + option 2 = Force push (since --force is auto-set in bootstrap)
                warn "Force-pushing — overwrites remote history."
                FORCE_PUSH_RESOLVED=true
                return 0
            else
                merge_unrelated  && return 0 || return 1
            fi
            ;;
        3)
            if [[ "$context" == "bootstrap" ]]; then
                # Bootstrap + option 3 = Abort
                err "Aborted — no changes pushed."
                return 1
            elif $force_ok; then
                warn "Force-pushing — overwrites remote history."
                FORCE_PUSH_RESOLVED=true
                return 0
            else
                echo
                err "Refusing to force-push."
                echo
                echo "  ${BOLD}This is a safety guard.${NC} Force-pushing discards remote commits."
                echo "  Re-run with the ${BOLD}--force${NC} flag if you're sure:"
                echo
                echo "      $0 --force"
                echo
                return 1
            fi
            ;;
        4)
            # Only available in non-bootstrap mode.
            warn "WIPE + RE-UPLOAD chosen."
            warn "${RED}This DESTROYS all remote commits/files on $CURRENT_BRANCH.${NC}"
            warn "After this, the remote will have a single new commit matching your local tree."
            REMOTE_COUNT=$(git rev-list --count "origin/$CURRENT_BRANCH" 2>/dev/null || echo "?")
            echo
            echo "  About to discard: ${RED}$REMOTE_COUNT commit(s)${NC} from origin/$CURRENT_BRANCH"
            echo
            ask "Type ${RED}WIPE${NC} in capitals to confirm: "
            read -r WIPE_CONFIRM
            if [[ "$WIPE_CONFIRM" == "WIPE" ]]; then
                WIPE_MODE=true
                return 0
            fi
            err "Did not type 'WIPE' — aborting."
            return 1
            ;;
        5)
            # Only available in non-bootstrap mode.
            err "Aborted — no changes pushed."
            return 1
            ;;
        *) err "Invalid choice."; return 1 ;;
    esac
}

# ---------- scan-only short-circuit ----------
if $SCAN_ONLY; then
    echo
    info "Scanning project: $PWD"
    if [[ -f .gitignore ]]; then
        audit_gitignore
    else
        warn "No .gitignore yet — audit skipped."
    fi
    TARGET_FILES=$(collect_target_files)
    if [[ -z "$TARGET_FILES" ]]; then
        TARGET_FILES=$(find . -type f -not -path './.git/*' \
            -not -path './node_modules/*' -not -path './dist/*' -not -path './.next/*' \
            -not -path './build/*' -not -path './__pycache__/*' -not -path './target/*' \
            -size -2M 2>/dev/null | head -300)
    fi
    scan_secrets "$TARGET_FILES" || exit 1
    ok "Scan complete."
    exit 0
fi

run() {
    # Wrapper: in dry-run, print instead of execute.
    if $DRY_RUN; then
        printf "${DIM}[dry-run] would run:${NC} %s\n" "$*"
    else
        "$@"
    fi
}

# Run a command with a hard timeout (kills after N seconds, returns 124).
# In dry-run mode, just prints the intent.
NET_TIMEOUT="${NET_TIMEOUT:-30}"   # seconds; override with NET_TIMEOUT env var
timeout_run() {
    local secs="$1"; shift
    if $DRY_RUN; then
        printf "${DIM}[dry-run] would run (timeout=%s):${NC} %s\n" "$secs" "$*"
        return 0
    fi
    timeout "$secs" "$@"
    return $?
}

clear 2>/dev/null || true
print_banner
# When the script exits with an error, print a quick failure summary
# (so the user always sees which step they got stuck on).
trap_on_error() {
    local rc=$?
    # Don't run if exit was clean (the explicit exit 0 paths already print summary).
    if (( rc != 0 )); then
        # Only print if we got far enough that OWNER/REPO are set.
        if [[ -n "${OWNER:-}" && -n "${REPO:-}" ]]; then
            print_summary "fail" 2>/dev/null || true
        fi
    fi
}
# Trap on ERR catches non-zero exits; EXIT catches everything else (incl. signals).
trap trap_on_error ERR
trap 'trap_on_error' EXIT

step "Welcome — let's set things up"

# ---------- input ----------
# Disable set -e just for the interactive prompts section — piped stdin / EOF
# shouldn't kill the script.
set +e
echo
ask "GitHub repo URL (e.g. https://github.com/USER/REPO.git): "
read -r REPO_URL
[[ -z "$REPO_URL" ]] && { err "No URL provided."; exit 1; }

if [[ "$REPO_URL" =~ ^https://github\.com/([^/]+)/([^/]+)(\.git)?$ ]]; then
    OWNER="${BASH_REMATCH[1]}"; REPO="${BASH_REMATCH[2]%.git}"
elif [[ "$REPO_URL" =~ ^git@github\.com:([^/]+)/([^/]+)(\.git)?$ ]]; then
    OWNER="${BASH_REMATCH[1]}"; REPO="${BASH_REMATCH[2]%.git}"
else
    err "URL doesn't look like a valid GitHub repo URL."; exit 1
fi
ok "Detected owner=${OWNER}  repo=${REPO}"

ask "Project description (used in README): "
read -r DESCRIPTION
DESCRIPTION="${DESCRIPTION:-A new project.}"

echo
echo "  1) Public    2) Private"
ask "Visibility [1]: "
read -r VIS_CHOICE
[[ "$VIS_CHOICE" == "2" ]] && VIS="private" || VIS="public"
set -e
# Re-enable strict mode for the rest of the script.
true

# ---------- detect gh CLI / token ----------
HAS_GH=false
HAS_TOKEN=false
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    HAS_GH=true; ok "GitHub CLI authenticated."
fi
if [[ -n "${GITHUB_TOKEN:-}" ]] && command -v curl >/dev/null 2>&1; then
    HAS_TOKEN=true
    $HAS_GH || ok "Using \$GITHUB_TOKEN + curl for repo creation."
fi

step "Checking GitHub authentication"

# ---------- does the remote repo exist? ----------
# Race `gh repo view` against `git ls-remote` in parallel — whichever responds
# first wins, so we don't pay the cost of two slow sequential round-trips.
REPO_EXISTS=false
EXISTENCE_RC_FILE=$(mktemp)
GH_RC_FILE=""      # populated only when HAS_GH=true; initialized for set -u safety
trap 'rm -f "$EXISTENCE_RC_FILE" 2>/dev/null; [[ -n "$GH_RC_FILE" ]] && rm -f "$GH_RC_FILE" 2>/dev/null' EXIT

if $HAS_GH; then
    GH_RC_FILE=$(mktemp)
    (
        timeout_run "${NET_TIMEOUT:-15}" gh repo view "$OWNER/$REPO" >/dev/null 2>&1
        echo $? > "$GH_RC_FILE"
    ) &
    GH_PID=$!
    (
        timeout_run "${NET_TIMEOUT:-15}" git ls-remote "$REPO_URL" >/dev/null 2>&1
        echo $? > "$EXISTENCE_RC_FILE"
    ) &
    LS_PID=$!

    # Wait for whichever finishes first.
    wait -n $GH_PID $LS_PID 2>/dev/null || true

    # Read final results so we don't leave background jobs running.
    GH_RC=$(cat "$GH_RC_FILE" 2>/dev/null || echo 1)
    LS_RC=$(cat "$EXISTENCE_RC_FILE" 2>/dev/null || echo 1)

    if [[ "$GH_RC" -eq 0 || "$LS_RC" -eq 0 ]]; then
        REPO_EXISTS=true
    fi

    # Stop any still-running checks to avoid hanging on slow networks.
    kill $GH_PID $LS_PID 2>/dev/null || true
    wait $GH_PID $LS_PID 2>/dev/null || true

    # Case-insensitive retry: try gh first, then fall back to git ls-remote
    # for users without `gh` authed (still catches 'PrintWearX' vs 'printwearx').
    if ! $REPO_EXISTS && [[ "$REPO" =~ [A-Z] ]]; then
        LOWER_REPO=$(printf '%s' "$REPO" | tr '[:upper:]' '[:lower:]')
        LOWER_MATCH=false
        if [[ "$LOWER_REPO" != "$REPO" ]]; then
            if $HAS_GH && timeout_run "${NET_TIMEOUT:-15}" gh repo view "$OWNER/$LOWER_REPO" >/dev/null 2>&1; then
                LOWER_MATCH=true
            elif timeout_run "${NET_TIMEOUT:-15}" git ls-remote "https://github.com/$OWNER/$LOWER_REPO.git" >/dev/null 2>&1; then
                LOWER_MATCH=true
            fi
        fi
        if $LOWER_MATCH; then
            warn "Repo ${BOLD}$OWNER/$REPO${NC} does not exist, but ${BOLD}$OWNER/$LOWER_REPO${NC} does."
            echo "  ${DIM}(GitHub treats repo names as case-sensitive — MyRepo ≠ myrepo)${NC}"
            ask "Switch to ${BOLD}$LOWER_REPO${NC}? [Y/n]: "
            read -r NAME_FIX
            if [[ ! "$NAME_FIX" =~ ^[nN]$ ]]; then
                REPO="$LOWER_REPO"
                REPO_URL="https://github.com/$OWNER/$LOWER_REPO.git"
                REPO_EXISTS=true
                ok "Using ${BOLD}$OWNER/$LOWER_REPO${NC} instead."
            fi
        fi
    fi
else
    # No gh CLI; fall back to git ls-remote alone.
    if timeout_run "${NET_TIMEOUT:-15}" git ls-remote "$REPO_URL" >/dev/null 2>&1; then
        REPO_EXISTS=true
    # Also probe lowercase variant if user typed mixed case.
    elif [[ "$REPO" =~ [A-Z] ]]; then
        LOWER_REPO=$(printf '%s' "$REPO" | tr '[:upper:]' '[:lower:]')
        if [[ "$LOWER_REPO" != "$REPO" ]] \
            && timeout_run "${NET_TIMEOUT:-15}" git ls-remote "https://github.com/$OWNER/$LOWER_REPO.git" >/dev/null 2>&1; then
            warn "Repo ${BOLD}$OWNER/$REPO${NC} does not exist, but ${BOLD}$OWNER/$LOWER_REPO${NC} does."
            echo "  ${DIM}(GitHub treats repo names as case-sensitive — MyRepo ≠ myrepo)${NC}"
            ask "Switch to ${BOLD}$LOWER_REPO${NC}? [Y/n]: "
            read -r NAME_FIX
            if [[ ! "$NAME_FIX" =~ ^[nN]$ ]]; then
                REPO="$LOWER_REPO"
                REPO_URL="https://github.com/$OWNER/$LOWER_REPO.git"
                REPO_EXISTS=true
                ok "Using ${BOLD}$OWNER/$LOWER_REPO${NC} instead."
            fi
        fi
    fi
fi
rm -f "$EXISTENCE_RC_FILE" "$GH_RC_FILE"

# ---------- detached HEAD recovery ----------
# After a botched rebase/merge the user can be in 'detached HEAD' state. Our
# commit/push operations expect a named branch — detect and recover early.
if git rev-parse --git-dir >/dev/null 2>&1; then
    HEAD_REF=$(git symbolic-ref --short HEAD 2>/dev/null || echo "DETACHED")
    if [[ "$HEAD_REF" == "DETACHED" || -z "$HEAD_REF" ]]; then
        warn "You are in ${BOLD}detached HEAD${NC} state (no current branch)."
        # Try to find a sensible local branch, prefer the one matching remote.
        LOCAL_BRANCH=""
        if git show-ref --verify --quiet "refs/heads/main"; then
            LOCAL_BRANCH="main"
        elif git show-ref --verify --quiet "refs/heads/master"; then
            LOCAL_BRANCH="master"
        fi

        if [[ -n "$LOCAL_BRANCH" ]]; then
            # Decide if it's safe to switch without losing detached commits.
            # Safe if HEAD is an ancestor of LOCAL_BRANCH (commits already exist there)
            # OR LOCAL_BRANCH is an ancestor of HEAD (fast-forward works).
            if git merge-base --is-ancestor "HEAD" "$LOCAL_BRANCH" 2>/dev/null \
                || git merge-base --is-ancestor "$LOCAL_BRANCH" "HEAD" 2>/dev/null; then
                info "Switching to local branch ${BOLD}$LOCAL_BRANCH${NC}..."
                if git checkout "$LOCAL_BRANCH" 2>/dev/null; then
                    ok "Now on $LOCAL_BRANCH."
                else
                    warn "Plain checkout failed (working tree dirt?). Trying forced..."
                    git checkout -f "$LOCAL_BRANCH" 2>/dev/null && ok "Now on $LOCAL_BRANCH." \
                        || { err "Could not switch. Resolve manually."; exit 1; }
                fi
            else
                # HEAD and LOCAL_BRANCH have diverged — neither contains the other.
                warn "Your detached HEAD has commits that aren't on ${BOLD}$LOCAL_BRANCH${NC}."
                info "Preserving them on a new branch so nothing gets lost."
                RECOVER_NAME="recovered-$(date +%Y%m%d-%H%M%S)"
                if git branch "$RECOVER_NAME" HEAD 2>/dev/null; then
                    git checkout "$RECOVER_NAME" 2>/dev/null && ok "Now on $RECOVER_NAME."
                    echo
                    echo "  ${BOLD}Next steps${NC} (you can do these now or later):"
                    echo "    ${DIM}•${NC} Merge your work into main:  ${BOLD}git checkout $LOCAL_BRANCH && git merge $RECOVER_NAME${NC}"
                    echo "    ${DIM}•${NC} Rename if you want:               ${BOLD}git branch -m $RECOVER_NAME main${NC}"
                    echo "    ${DIM}•${NC} See what you have:                  ${BOLD}git log --oneline -5${NC}"
                else
                    err "Could not create recovery branch. Resolve manually."
                    echo "      git checkout -b $LOCAL_BRANCH"
                    exit 1
                fi
            fi
        else
            err "No local branch exists. Create one (keeps your last commit):"
            echo "      git checkout -b main"
            echo "  then re-run."
            exit 1
        fi
    fi
fi

IS_UPDATE=false
if [[ "$MODE_FORCED" == "update" ]]; then
    IS_UPDATE=true
elif [[ "$MODE_FORCED" == "bootstrap" ]]; then
    IS_UPDATE=false
elif [[ -d .git ]] \
    && git rev-parse --verify HEAD >/dev/null 2>&1 \
    && git remote get-url origin >/dev/null 2>&1; then
    IS_UPDATE=true
fi

if $IS_UPDATE; then
    ok "Mode: UPDATE (existing repo with history + remote)"
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)
    LOCAL_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")

    # Normalize both URLs to "owner/repo" form before comparison so .git suffix
    # and protocol (https vs ssh) differences don't trigger false positives.
    if [[ "$LOCAL_REMOTE" =~ ^https://github\.com/([^/]+)/([^/]+)(\.git)?$ ]] \
        || [[ "$LOCAL_REMOTE" =~ ^git@github\.com:([^/]+)/([^/]+)(\.git)?$ ]]; then
        LOCAL_OWNER="${BASH_REMATCH[1]}"
        LOCAL_REPO="${BASH_REMATCH[2]%.git}"
    fi

    if [[ -n "$LOCAL_OWNER" && ( "$LOCAL_OWNER" != "$OWNER" || "$LOCAL_REPO" != "$REPO" ) ]]; then
        warn "Local origin:  $LOCAL_OWNER/$LOCAL_REPO"
        warn "Provided URL:  $OWNER/$REPO"
        ask "Update origin to the provided URL? [Y/n]: "
        read -r CHANGE_REMOTE
        if [[ ! "$CHANGE_REMOTE" =~ ^[nN]$ ]]; then
            run git remote set-url origin "$REPO_URL"
            ok "Remote updated."
        else
            OWNER="$LOCAL_OWNER"
            REPO="$LOCAL_REPO"
            ok "Sticking with $LOCAL_OWNER/$LOCAL_REPO."
        fi
    fi
else
    ok "Mode: BOOTSTRAP (new repo or no existing remote)"
fi
if ! $REPO_EXISTS && git ls-remote "$REPO_URL" >/dev/null 2>&1; then
    REPO_EXISTS=true
fi
$REPO_EXISTS && ok "Repo ${BOLD}$OWNER/$REPO${NC} already exists on GitHub." \
            || warn "Repo ${BOLD}$OWNER/$REPO${NC} does not exist on GitHub yet."

step "Resolving repository URL"

# ---------- create-on-GitHub fast path ----------
create_repo() {
    local vis_flag="$1"
    if $HAS_GH; then
        info "Creating repo via gh CLI..."
        run gh repo create "$OWNER/$REPO" "--$vis_flag" \
            --description "$DESCRIPTION" --source=. --remote=origin --push
    elif $HAS_TOKEN; then
        info "Creating repo via REST API..."
        local payload
        payload=$(printf '{"name":"%s","description":"%s","private":%s}' \
            "$REPO" "$DESCRIPTION" "$([[ $vis_flag == private ]] && echo true || echo false)")
        run curl -sS -X POST \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github+json" \
            -d "$payload" \
            "https://api.github.com/user/repos" >/dev/null
        ok "Repo created on GitHub."
    else
        err "Cannot create the repo — GitHub authentication required."
        echo
        if ! command -v gh >/dev/null 2>&1; then
            echo "  ${BOLD}Option A${NC} — Install + log in to GitHub CLI:"
            echo "    ${CYN}brew install gh${NC}        ${DIM}# macOS${NC}"
            echo "    ${CYN}sudo apt install gh${NC}    ${DIM}# Debian/Ubuntu${NC}"
            echo "    ${CYN}gh auth login${NC}          ${DIM}# then re-run this script${NC}"
        else
            echo "  ${BOLD}Option A${NC} — gh CLI is installed but not logged in:"
            echo "    ${CYN}gh auth login${NC}"
        fi
        echo
        echo "  ${BOLD}Option B${NC} — Use a Personal Access Token (no install):"
        echo "    1. Create one:    ${CYN}https://github.com/settings/tokens${NC}  (needs 'repo' scope)"
        echo "    2. Set it:        ${CYN}export GITHUB_TOKEN=ghp_xxxx${NC}"
        echo "    3. Re-run this script."
        echo
        return 1
    fi
}

if ! $REPO_EXISTS; then
    ask "Create it now? [Y/n]: "
    read -r CREATE_NOW
    if [[ ! "$CREATE_NOW" =~ ^[nN]$ ]]; then
        if ! create_repo "$VIS"; then
            if $DRY_RUN; then
                warn "(dry-run: continuing preview despite missing auth tool)"
            else
                exit 1
            fi
        fi
        if ! $DRY_RUN && [[ -d ".git" ]]; then
            git remote get-url origin >/dev/null 2>&1 || git remote add origin "$REPO_URL"
            git push -u origin main 2>/dev/null \
                || git push -u origin master 2>/dev/null \
                || true
        fi
        if ! $DRY_RUN; then
            ok "Repo created and code pushed!"
            printf "${GRN}View it at:${NC} https://github.com/%s/%s\n" "$OWNER" "$REPO"
            step_done
            print_summary "ok"
            exit 0
        fi
    fi
fi

# In update mode, skip bootstrap-only steps silently.
SKIP_INIT_SCAFFOLD=false
$IS_UPDATE && SKIP_INIT_SCAFFOLD=true

step "Initializing local git repository"

# ---------- init local repo ----------
if [[ ! -d ".git" ]]; then
    info "Initializing local git repo..."
    run git init -b main
fi

# git identity (local)
if ! git config user.name >/dev/null 2>&1; then
    ask "Git user.name (for this repo): "; read -r GIT_NAME
    [[ -n "$GIT_NAME" ]] && run git config user.name "$GIT_NAME"
fi
if ! git config user.email >/dev/null 2>&1; then
    ask "Git user.email: "; read -r GIT_EMAIL
    [[ -n "$GIT_EMAIL" ]] && run git config user.email "$GIT_EMAIL"
fi

# ---------- generate files ----------
# In update mode, never overwrite existing project files. Bootstrap mode
# generates .gitignore / README.md / LICENSE as usual.
if $IS_UPDATE; then
    info "Update mode — skipping file generation (using your existing files)."
else
    detect_gitignore() {
    if [[ -f "package.json" ]]; then
        printf "node_modules/\ndist/\nbuild/\n.env\n.env.local\n*.log\n"; return
    fi
    if [[ -f "requirements.txt" || -f "pyproject.toml" || -f "setup.py" ]]; then
        printf "__pycache__/\n*.pyc\n.venv/\nvenv/\n.env\n*.egg-info/\ndist/\nbuild/\n*.log\n"; return
    fi
    if [[ -f "go.mod" ]]; then
        printf "*.exe\n*.dll\n*.so\n*.dylib\nvendor/\n.env\n*.log\n"; return
    fi
    if [[ -f "Cargo.toml" ]]; then
        printf "target/\n.env\n*.log\n"; return
    fi
    printf '%s\n' \
        '# OS' '.DS_Store' 'Thumbs.db' \
        '# Editors' '.vscode/' '.idea/' '*.swp' '*.swo' '*~' \
        '# Env' '.env' '.env.local' '.env.*.local' \
        '# Logs' '*.log' 'logs/' \
        '# Build artifacts' 'dist/' 'build/' 'out/' '*.exe' '*.dll' '*.so' '*.dylib' \
        '# Misc' '*.tmp' '*.bak' '.cache/'
}

[[ -f ".gitignore" ]] && warn ".gitignore exists — skipping." \
    || { info "Creating .gitignore..."; detect_gitignore > .gitignore; ok ".gitignore created."; }

[[ -f "README.md" ]] && warn "README.md exists — skipping." \
    || { info "Creating README.md..."; cat > README.md <<EOF
# $REPO

$DESCRIPTION

## Getting Started

\`\`\`bash
git clone $REPO_URL
cd $REPO
\`\`\`

## Usage

_Add usage notes here._

## License

Update this section as needed.
EOF
    ok "README.md created."
}

# LICENSE picker
if [[ ! -f "LICENSE" ]]; then
    echo
    echo "  Add a LICENSE?"
    echo "    1) MIT"
    echo "    2) Apache-2.0"
    echo "    3) GPL-3.0"
    echo "    4) BSD-3-Clause"
    echo "    5) None / skip"
    ask "Pick one [1]: "
    read -r LIC_CHOICE
    case "$LIC_CHOICE" in
        2|Apache*|apache*) LICENSE_TYPE="Apache-2.0" ;;
        3|GPL*|gpl*)     LICENSE_TYPE="GPL-3.0" ;;
        4|BSD*|bsd*)     LICENSE_TYPE="BSD-3-Clause" ;;
        5|"")            LICENSE_TYPE="" ;;
        *)               LICENSE_TYPE="MIT" ;;
    esac
    if [[ -n "$LICENSE_TYPE" ]]; then
        YEAR=$(date +%Y)
        ask "Copyright holder [${OWNER}]: "; read -r COPYRIGHT_NAME
        COPYRIGHT_NAME="${COPYRIGHT_NAME:-$OWNER}"
        info "Creating LICENSE ($LICENSE_TYPE)..."
        case "$LICENSE_TYPE" in
            MIT)
                cat > LICENSE <<EOF
MIT License

Copyright (c) $YEAR $COPYRIGHT_NAME

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
                ;;
            Apache-2.0)
                cat > LICENSE <<EOF
Apache License, Version 2.0
Copyright (c) $YEAR $COPYRIGHT_NAME

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Full text: https://www.apache.org/licenses/LICENSE-2.0.txt
EOF
                ;;
            GPL-3.0)
                cat > LICENSE <<EOF
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007

Copyright (c) $YEAR $COPYRIGHT_NAME

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Full text: https://www.gnu.org/licenses/gpl-3.0.txt
EOF
                ;;
            BSD-3-Clause)
                cat > LICENSE <<EOF
BSD 3-Clause License

Copyright (c) $YEAR $COPYRIGHT_NAME

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED.
EOF
                ;;
        esac
        ok "LICENSE created ($LICENSE_TYPE)."
    fi
fi
fi   # end of bootstrap-only file generation block

step "Safety checks — gitignore audit + size limits"

# ---------- .gitignore audit ----------
if $QUICK_MODE; then
    dim "  (skipped due to --quick)"
elif [[ -f .gitignore ]]; then
    audit_gitignore
fi

# ---------- large-file check ----------
LARGE_FILES=$(find . -type f -not -path './.git/*' -size +10M 2>/dev/null || true)
if [[ -n "$LARGE_FILES" ]]; then
    warn "Large files detected (>10 MB) — consider Git LFS:"
    echo "$LARGE_FILES" | sed 's/^/    /'
    ask "Initialize Git LFS for this repo? [y/N]: "; read -r USE_LFS
    if [[ "$USE_LFS" =~ ^[yY]$ ]]; then
        if ! command -v git-lfs >/dev/null 2>&1; then
            warn "git-lfs isn't installed. Install: brew install git-lfs / apt install git-lfs"
        else
            run git lfs install
            run git lfs track "$(echo "$LARGE_FILES" | head -1 | sed 's|^\./||')"
            info "LFS tracking set up for the first large file. Add more with 'git lfs track'."
        fi
    fi
fi

step "Setting up remote origin"

# ---------- remote ----------
if ! git remote get-url origin >/dev/null 2>&1; then
    info "Adding remote origin..."
    run git remote add origin "$REPO_URL"
fi

# ---------- update-mode: fetch + divergence ----------
if $IS_UPDATE; then
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)
    reconcile_divergence "update" || exit 1
fi

# ---------- dry-run early exit ----------
if $DRY_RUN; then
    echo
    info "(dry-run: skipping git init / add / commit / push)"
    info "(dry-run: file generation above is real so you can preview contents)"
    ok "🎉  Dry-run complete."
    exit 0
fi

step "Staging changes + scanning for secrets"

# ---------- stage ----------
if $IS_UPDATE; then
    # In update mode, default to staging tracked-file modifications + deletions only.
    # Untracked files stay untracked unless user wants to include them.
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)
    UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | head -20)
    DIRTY=$(git status --porcelain 2>/dev/null | head -20)

    if [[ -z "$DIRTY" && -z "$UNTRACKED" ]]; then
        info "No local changes detected — will push upstream as-is."
        skip_stage_and_commit=true
    else
        if [[ -n "$DIRTY" ]]; then
            info "Staging tracked changes:"
            run git add -u   # tracked files only, no untracked
            echo "$DIRTY" | sed 's/^/    /'
        fi
        if [[ -n "$UNTRACKED" ]]; then
            warn "Untracked files present (not staged by default in update mode):"
            echo "$UNTRACKED" | sed 's/^/    /'
            ask "Stage these too? [y/N]: "; read -r STAGE_NEW
            if [[ "$STAGE_NEW" =~ ^[yY]$ ]]; then
                run git add .
            fi
        fi
    fi
else
    info "Staging files..."
    run git add .
fi

# Open the TUI dashboard if --tui was passed. Lets the user review staged
# files + diff + scan results before pushing. Press p to confirm, q to abort.
if $TUI_MODE; then
    # Populate TUI state from current run.
    STAGED_COUNT=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
    STAGED_SIZE=$(git diff --cached --numstat 2>/dev/null | awk '{s+=$1+$2} END{print s+0}')
    STAGED_SIZE_HUMAN=$(du -sh "$(git rev-parse --show-toplevel 2>/dev/null)/.git/index" 2>/dev/null | awk '{print $1}')
    [[ -z "$STAGED_SIZE_HUMAN" ]] && STAGED_SIZE_HUMAN="$(numfmt --to=iec "$STAGED_SIZE" 2>/dev/null || echo "${STAGED_SIZE} B")"
    mapfile -t TUI_FILE_LIST < <(git diff --cached --name-status 2>/dev/null | awk '{printf "  %s  %s", $1, $2}')
    mapfile -t TUI_SECRET_FINDINGS < <(find . -type f \( -name '*.env' -o -name '.env.*' -o -name '*.pem' -o -name '*.key' \) -print0 2>/dev/null \
        | xargs -0 -n1 -P4 grep -lE 'AKIA[0-9A-Z]{16}|sk_live_|sk_test_|ghp_[A-Za-z0-9]{36}' 2>/dev/null \
        | head -50)
    [[ ${#TUI_SECRET_FINDINGS[@]} -eq 0 ]] && TUI_SECRET_FINDINGS=()
    TUI_DIFF_TEXT=$(git diff --cached 2>/dev/null | head -200)
    TUI_FILE_SCROLL=0
    TUI_DIFF_SCROLL=0

    if tui_run; then
        if ! $TUI_CONFIRM; then
            err "Cancelled from TUI dashboard."
            exit 1
        fi
        ok "TUI confirmed — proceeding to commit + push."
    else
        warn "TUI unavailable; continuing with wizard flow."
    fi
fi

# ---------- secret scan (blocks if findings) ----------
TARGET_FILES=$(collect_target_files)
if $QUICK_MODE; then
    dim "  (secret scan skipped due to --quick)"
else
    scan_secrets "$TARGET_FILES" || {
        err "Secret scan aborted the push. Resolve findings then re-run."
        exit 1
    }
fi

# ---------- pre-commit review ----------
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    warn "Not inside a git repo — nothing to commit."
elif [[ "${skip_stage_and_commit:-false}" == "true" ]]; then
    info "Nothing to commit; proceeding straight to push."
else
    TRACKED=$(git diff --cached --name-only)
    if [[ -z "$TRACKED" ]]; then
        warn "Nothing to commit."
    else
        COUNT=$(echo "$TRACKED" | wc -l | tr -d ' ')
        TOTAL_BYTES=$(echo "$TRACKED" | while read -r f; do git cat-file -s ":$f" 2>/dev/null; done \
                      | awk '{s+=$1} END {print s+0}')
        TOTAL_HR=$(numfmt --to=iec --suffix=B "$TOTAL_BYTES" 2>/dev/null || echo "${TOTAL_BYTES}B")
        echo
        if $IS_UPDATE; then
            info "Update — $COUNT file(s) staged, $TOTAL_HR changed:"
            git diff --cached --stat 2>/dev/null | sed 's/^/    /'
        else
            info "About to commit $COUNT files ($TOTAL_HR):"
            echo "$TRACKED" | sed 's/^/    /'
        fi
        echo
        ask "Looks good? [Y/n]: "; read -r CONFIRM
        if [[ "$CONFIRM" =~ ^[nN]$ ]]; then
            warn "Aborted by user. Nothing was pushed."
            exit 1
        fi
        if $IS_UPDATE; then
            ask "Commit message [Update $(date +%Y-%m-%d)]: "; read -r COMMIT_MSG
            COMMIT_MSG="${COMMIT_MSG:-Update $(date +%Y-%m-%d)}"
        else
            ask "Commit message [Initial commit]: "; read -r COMMIT_MSG
            COMMIT_MSG="${COMMIT_MSG:-Initial commit}"
        fi
        info "Committing..."
        run git commit -m "$COMMIT_MSG"
        ok "Committed: $COMMIT_MSG"
    fi
fi

step "Pushing to GitHub"

# ---------- pre-push divergence check (for bootstrap case too) ----------
# If we're in bootstrap mode but the remote repo already has commits on this
# branch (e.g. someone created it via gh or the GitHub UI), a straight push
# will be rejected. Detect this and offer merge / rebase / force / abort.
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)
FORCE_PUSH_RESOLVED=false
if ! $IS_UPDATE; then
    reconcile_divergence "bootstrap" || exit 1
fi

# ---------- wipe + re-upload (short-circuit before regular push) ----------
if $WIPE_MODE; then
    info "Wipe + re-upload confirmed."
    if wipe_and_reset "$CURRENT_BRANCH"; then
        step_done
        print_summary "ok"
        exit 0
    else
        err "Wipe failed. Remote unchanged."
        print_summary "fail"
        exit 1
        exit 1
    fi
fi

# ---------- pre-push optimization ----------
# Tighten the local pack so the wire transfer is smaller and faster. For big
# changesets this can shave 30–70% off the push time.
if ! $DRY_RUN && ! $QUICK_MODE && git rev-parse --git-dir >/dev/null 2>&1; then
    # Run in background so the pre-push review can show simultaneously.
    info "Optimizing local pack (background)..."
    ( git gc --quiet 2>/dev/null ) &
    GC_PID=$!
fi

# ---------- push ----------
info "Pushing $CURRENT_BRANCH → origin (https://github.com/$OWNER/$REPO) ..."

PUSH_OK=false
PUSH_ARGS=(--progress)
HAS_UPSTREAM=false
if git rev-parse "origin/$CURRENT_BRANCH" >/dev/null 2>&1; then
    HAS_UPSTREAM=true
fi

# Decide force semantics. $FORCE_PUSH is the --force CLI flag.
# $FORCE_PUSH_RESOLVED is set true when the user picked "force push" in the
# divergence dialog (even without --force on the CLI, for bootstrap).
if $FORCE_PUSH_RESOLVED; then
    PUSH_ARGS+=(--force)
elif $FORCE_PUSH && $HAS_UPSTREAM; then
    # Safer than --force: refuses if remote advanced beyond what we expect.
    PUSH_ARGS+=(--force-with-lease)
fi
# Only use -u on bootstrap (or first push) — subsequent pushes just track.
if ! $HAS_UPSTREAM; then
    PUSH_ARGS+=(-u)
fi
# Bypass local hooks if user asked for it.
$NO_VERIFY && PUSH_ARGS+=(--no-verify)

# Wait for the background pack optimization to finish so it can be packed.
[[ -n "${GC_PID:-}" ]] && wait $GC_PID 2>/dev/null || true

if run git push "${PUSH_ARGS[@]}" origin "$CURRENT_BRANCH" 2>/tmp/push.err; then
    PUSH_OK=true
else
    PUSH_OK=false
    sed 's/^/    /' /tmp/push.err
fi

if $PUSH_OK; then
    ok "Pushed successfully!"
    printf "${GRN}View it at:${NC} https://github.com/%s/%s\n" "$OWNER" "$REPO"
    step_done
    print_summary "ok"
    exit 0
fi

h1 "Push failed"

# Detect specific failure modes and offer targeted recovery.
if grep -q "not a full refname\|detached HEAD\|HEAD:refs" /tmp/push.err 2>/dev/null; then
    err "Looks like you're pushing from detached HEAD (no current branch)."
    echo
    echo "  ${BOLD}Recovery:${NC}"
    echo "    ${GRN}1${NC}) Switch to your branch:    ${BOLD}git checkout main${NC}  (or master)"
    echo "    ${GRN}2${NC}) Keep your last commit:    ${BOLD}git checkout -b main${NC}"
    echo "    ${GRN}3${NC}) Re-run this script — it now auto-detects + recovers detached HEAD."
    exit 1
fi
if grep -qi "Permission denied\|publickey\|denied.*github" /tmp/push.err 2>/dev/null; then
    err "Authentication failed."
    echo "    ${GRN}1${NC}) For HTTPS: run ${BOLD}gh auth login${NC} (or set up a credential helper)"
    echo "    ${GRN}2${NC}) For SSH: run ${BOLD}ssh -T git@github.com${NC} to verify your key"
    exit 1
fi
if ! $REPO_EXISTS; then
    warn "Remote repo doesn't exist yet."
    echo "    ${GRN}1${NC}) Create it at ${BOLD}https://github.com/new${NC} (name: $REPO)"
    echo "    ${GRN}2${NC}) Run with ${BOLD}gh auth login${NC} so I can create it for you"
    exit 1
fi
# Branch protection on GitHub often blocks --force to default branches (main).
# Detect that specific rejection and route the user to --wipe, which works
# because it pushes to an orphan branch then force-deletes the protected one.
if grep -q "non-fast-forward\|rejected" /tmp/push.err 2>/dev/null \
   && [[ " $* " == *" --force "* ]] ; then
    warn "${BOLD}--force${NC} was rejected — branch protection is likely blocking force-pushes to ${CURRENT_BRANCH}."
    echo
    echo "  ${BOLD}Recovery:${NC}"
    echo "    ${RED}1${NC}) Use ${BOLD}${RED}--wipe${NC}${NC} — pushes to orphan branch then deletes ${CURRENT_BLANK}"
    echo "       (bypasses branch protection, single new commit on remote)"
    echo "       ${DIM}\$${NC} ${BOLD}$0 --wipe${NC}"
    echo "    ${GRN}2${NC}) Disable branch protection on GitHub:"
    echo "       ${DIM}Settings → Branches → Branch protection rules → unprotect ${CURRENT_BRANCH}${NC}"
    echo "    ${YEL}3${NC}) Push to a different branch instead:"
    echo "       ${DIM}\$${NC} ${BOLD}git push origin main:protected-main --force${NC}"
    echo
    exit 1
fi

echo
dim "  Common causes:"
echo "    ${DIM}•${NC} Wrong SSH key / no GitHub credentials"
echo "    ${DIM}•${NC} Branch protection rules on the remote"
echo "    ${DIM}•${NC} Remote has unpushed commits → re-run to fetch + rebase"
echo "    ${DIM}•${NC} Local diverged → re-run with ${BOLD}--force${NC} (only if you're sure)"
exit 1
