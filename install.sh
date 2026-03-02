#!/usr/bin/env bash
set -euo pipefail

# resolve script's own directory regardless of where it's invoked from
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/skills"
RULES_DIR="$SCRIPT_DIR/rules"

# ---------------------------------------------------------------------------
# colors (disabled when stdout is not a terminal)
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
    BOLD='\033[1m'
    DIM='\033[2m'
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    RESET='\033[0m'
else
    BOLD='' DIM='' RED='' GREEN='' YELLOW='' CYAN='' RESET=''
fi

# ---------------------------------------------------------------------------
# print helpers
# ---------------------------------------------------------------------------
print_header()  { printf "\n${BOLD}${CYAN}%s${RESET}\n" "$1"; }
print_info()    { printf "${DIM}%s${RESET}\n" "$1"; }
print_success() { printf "${GREEN}✓${RESET} %s\n" "$1"; }
print_warn()    { printf "${YELLOW}⚠${RESET} %s\n" "$1"; }
print_error()   { printf "${RED}✗${RESET} %s\n" "$1" >&2; }

# ---------------------------------------------------------------------------
# CLI state
# ---------------------------------------------------------------------------
TARGET_MODE=""        # "user" or "project"
PROJECT_PATH=""
FORCE=false
USE_LINKS=false
DRY_RUN=false

# ---------------------------------------------------------------------------
# parse_args
# ---------------------------------------------------------------------------
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --user)
                TARGET_MODE="user"
                shift
                ;;
            --project)
                TARGET_MODE="project"
                if [ $# -lt 2 ]; then
                    print_error "--project requires a path argument"
                    exit 1
                fi
                PROJECT_PATH="$2"
                shift 2
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --link)
                USE_LINKS=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat <<'EOF'
Usage: install.sh [OPTIONS]

Install AI skills and rules for Claude Code and Cursor.

Options:
  --user              Install to user-global directories (~/.claude, ~/.cursor)
  --project <path>    Install to a specific project directory
  --force             Overwrite conflicts without prompting
  --link              Create symlinks instead of copies
  --dry-run           Show what would be done without making changes
  -h, --help          Show this help message

When no options are given, the script runs interactively.
EOF
}

# ---------------------------------------------------------------------------
# checksum helper — portable across macOS (shasum) and Linux (sha256sum)
# ---------------------------------------------------------------------------
file_checksum() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | cut -d' ' -f1
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    else
        # fallback: cksum (always available on POSIX)
        cksum "$1" | cut -d' ' -f1
    fi
}

# ---------------------------------------------------------------------------
# front-matter parsing — extracts a value between --- delimiters
# expects: parse_frontmatter <file> <key>
# ---------------------------------------------------------------------------
parse_frontmatter() {
    local file="$1" key="$2"
    # grab lines between the first pair of --- delimiters, then extract the key
    sed -n '/^---$/,/^---$/p' "$file" \
        | sed -n "s/^${key}: *//p" \
        | head -1
}

# ---------------------------------------------------------------------------
# discover_skills — populates parallel arrays SKILL_NAMES, SKILL_DESCS, SKILL_PATHS
# ---------------------------------------------------------------------------
SKILL_NAMES=()
SKILL_DESCS=()
SKILL_PATHS=()

discover_skills() {
    if [ ! -d "$SKILLS_DIR" ]; then
        return
    fi

    for dir in "$SKILLS_DIR"/*/; do
        [ -d "$dir" ] || continue
        local skill_file="${dir}SKILL.md"
        if [ ! -f "$skill_file" ]; then
            print_warn "Skipping $(basename "$dir") — no SKILL.md found"
            continue
        fi

        local name desc
        name="$(parse_frontmatter "$skill_file" "name")"
        desc="$(parse_frontmatter "$skill_file" "description")"
        # fallback name to directory name
        [ -z "$name" ] && name="$(basename "$dir")"

        SKILL_NAMES+=("$name")
        SKILL_DESCS+=("$desc")
        SKILL_PATHS+=("$skill_file")
    done
}

# ---------------------------------------------------------------------------
# discover_rules — populates parallel arrays RULE_NAMES, RULE_DESCS, RULE_PATHS
# ---------------------------------------------------------------------------
RULE_NAMES=()
RULE_DESCS=()
RULE_PATHS=()

discover_rules() {
    if [ ! -d "$RULES_DIR" ]; then
        return
    fi

    for file in "$RULES_DIR"/*.mdc; do
        [ -f "$file" ] || continue

        local name desc
        name="$(basename "$file" .mdc)"
        desc="$(parse_frontmatter "$file" "description")"

        RULE_NAMES+=("$name")
        RULE_DESCS+=("$desc")
        RULE_PATHS+=("$file")
    done
}

# ---------------------------------------------------------------------------
# choose_target — interactive target selection
# ---------------------------------------------------------------------------
choose_target() {
    if [ -n "$TARGET_MODE" ]; then
        if [ "$TARGET_MODE" = "project" ] && [ -z "$PROJECT_PATH" ]; then
            print_error "--project requires a path"
            exit 1
        fi
        return
    fi

    print_header "Where should items be installed?"
    echo "  1) User-global  (~/.claude, ~/.cursor)"
    echo "  2) Project directory"
    echo ""

    local attempts=0
    while [ $attempts -lt 3 ]; do
        printf "Select [1-2]: "
        read -r choice
        case "$choice" in
            1)
                TARGET_MODE="user"
                return
                ;;
            2)
                TARGET_MODE="project"
                printf "Enter project path: "
                read -r PROJECT_PATH
                if [ -d "$PROJECT_PATH" ]; then
                    return
                fi
                print_warn "Directory does not exist: $PROJECT_PATH"
                attempts=$((attempts + 1))
                ;;
            *)
                print_warn "Invalid choice"
                attempts=$((attempts + 1))
                ;;
        esac
    done

    print_error "Too many invalid attempts"
    exit 1
}

# ---------------------------------------------------------------------------
# present_items — numbered checklist with toggle support
# accepts: array of "name|description" strings, writes selected indices to SELECTED
# ---------------------------------------------------------------------------
SELECTED=()

present_items() {
    local items=("$@")
    local count=${#items[@]}

    # start with all selected
    local selected=()
    local i
    for i in $(seq 0 $((count - 1))); do
        selected+=("1")
    done

    while true; do
        echo ""
        for i in $(seq 0 $((count - 1))); do
            local name desc marker
            name="$(echo "${items[$i]}" | cut -d'|' -f1)"
            desc="$(echo "${items[$i]}" | cut -d'|' -f2)"

            if [ "${selected[$i]}" = "1" ]; then
                marker="${GREEN}✓${RESET}"
            else
                marker="${DIM}·${RESET}"
            fi

            if [ -n "$desc" ]; then
                printf "  ${marker} ${BOLD}%d)${RESET} %-30s ${DIM}%s${RESET}\n" $((i + 1)) "$name" "$desc"
            else
                printf "  ${marker} ${BOLD}%d)${RESET} %s\n" $((i + 1)) "$name"
            fi
        done

        echo ""
        printf "Toggle items by number (e.g. 1 3), ${BOLD}a${RESET}=all, ${BOLD}n${RESET}=none, ${BOLD}enter${RESET}=confirm: "
        read -r input

        if [ -z "$input" ]; then
            break
        fi

        case "$input" in
            a|A)
                for i in $(seq 0 $((count - 1))); do
                    selected[$i]="1"
                done
                ;;
            n|N)
                for i in $(seq 0 $((count - 1))); do
                    selected[$i]="0"
                done
                ;;
            *)
                for num in $input; do
                    # validate numeric
                    case "$num" in
                        ''|*[!0-9]*) continue ;;
                    esac
                    local idx=$((num - 1))
                    if [ "$idx" -ge 0 ] && [ "$idx" -lt "$count" ]; then
                        if [ "${selected[$idx]}" = "1" ]; then
                            selected[$idx]="0"
                        else
                            selected[$idx]="1"
                        fi
                    fi
                done
                ;;
        esac
    done

    SELECTED=()
    for i in $(seq 0 $((count - 1))); do
        if [ "${selected[$i]}" = "1" ]; then
            SELECTED+=("$i")
        fi
    done
}

# ---------------------------------------------------------------------------
# install_file — copy or link a single file with conflict detection
# returns: 0=installed, 1=skipped, 2=error
# ---------------------------------------------------------------------------
INSTALLED=0
SKIPPED=0
ERRORED=0

install_file() {
    local src="$1" dest="$2"
    local dest_dir
    dest_dir="$(dirname "$dest")"

    # dry-run mode
    if $DRY_RUN; then
        if $USE_LINKS; then
            print_info "[dry-run] symlink $src → $dest"
        else
            print_info "[dry-run] copy $src → $dest"
        fi
        INSTALLED=$((INSTALLED + 1))
        return 0
    fi

    # create destination directory
    if ! mkdir -p "$dest_dir" 2>/dev/null; then
        print_error "Could not create directory: $dest_dir"
        ERRORED=$((ERRORED + 1))
        return 2
    fi

    # check for existing file
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        # resolve symlink for comparison
        local cmp_dest="$dest"
        if [ -L "$dest" ]; then
            cmp_dest="$(readlink "$dest")"
        fi

        if [ -f "$cmp_dest" ]; then
            local src_sum dest_sum
            src_sum="$(file_checksum "$src")"
            dest_sum="$(file_checksum "$cmp_dest")"

            if [ "$src_sum" = "$dest_sum" ]; then
                print_info "Identical, skipping: $dest"
                SKIPPED=$((SKIPPED + 1))
                return 1
            fi
        fi

        if $FORCE; then
            rm -f "$dest"
        else
            echo ""
            print_warn "Conflict: $dest already exists and differs from source"
            printf "  ${BOLD}o${RESET})verwrite  ${BOLD}s${RESET})kip  ${BOLD}d${RESET})iff : "
            read -r action
            case "$action" in
                o|O)
                    rm -f "$dest"
                    ;;
                d|D)
                    echo ""
                    if diff --color=auto "$dest" "$src" 2>/dev/null || diff "$dest" "$src"; then
                        : # diff shown
                    fi
                    echo ""
                    printf "  ${BOLD}o${RESET})verwrite  ${BOLD}s${RESET})kip : "
                    read -r action2
                    case "$action2" in
                        o|O) rm -f "$dest" ;;
                        *)
                            SKIPPED=$((SKIPPED + 1))
                            return 1
                            ;;
                    esac
                    ;;
                *)
                    SKIPPED=$((SKIPPED + 1))
                    return 1
                    ;;
            esac
        fi
    fi

    if $USE_LINKS; then
        if ln -sf "$src" "$dest" 2>/dev/null; then
            print_success "Linked: $dest"
            INSTALLED=$((INSTALLED + 1))
            return 0
        else
            print_error "Failed to link: $dest"
            ERRORED=$((ERRORED + 1))
            return 2
        fi
    else
        if cp "$src" "$dest" 2>/dev/null; then
            print_success "Copied: $dest"
            INSTALLED=$((INSTALLED + 1))
            return 0
        else
            print_error "Failed to copy: $dest"
            ERRORED=$((ERRORED + 1))
            return 2
        fi
    fi
}

# ---------------------------------------------------------------------------
# install_skill — installs a skill to both Claude Code and Cursor targets
# ---------------------------------------------------------------------------
install_skill() {
    local name="$1" src="$2" claude_base="$3" cursor_base="$4"

    local claude_dest="$claude_base/skills/$name/SKILL.md"
    local cursor_dest="$cursor_base/skills/$name/SKILL.md"

    install_file "$src" "$claude_dest" || true
    install_file "$src" "$cursor_dest" || true
}

# ---------------------------------------------------------------------------
# install_rule — installs a rule to Cursor target only
# ---------------------------------------------------------------------------
install_rule() {
    local name="$1" src="$2" cursor_base="$3"

    local cursor_dest="$cursor_base/rules/$name.mdc"
    install_file "$src" "$cursor_dest" || true
}

# ---------------------------------------------------------------------------
# preview — show what will be installed
# ---------------------------------------------------------------------------
preview_install() {
    local claude_base="$1" cursor_base="$2"
    shift 2
    local skill_indices=() rule_indices=()

    # split selected indices into skills and rules
    local total_skills=${#SKILL_NAMES[@]}
    for idx in "$@"; do
        if [ "$idx" -lt "$total_skills" ]; then
            skill_indices+=("$idx")
        else
            rule_indices+=("$idx")
        fi
    done

    print_header "Preview"

    if [ ${#skill_indices[@]} -gt 0 ]; then
        echo ""
        printf "  ${BOLD}Skills → Claude Code${RESET}\n"
        for idx in "${skill_indices[@]}"; do
            printf "    %s → %s\n" "${SKILL_NAMES[$idx]}" "$claude_base/skills/${SKILL_NAMES[$idx]}/SKILL.md"
        done

        echo ""
        printf "  ${BOLD}Skills → Cursor${RESET}\n"
        for idx in "${skill_indices[@]}"; do
            printf "    %s → %s\n" "${SKILL_NAMES[$idx]}" "$cursor_base/skills/${SKILL_NAMES[$idx]}/SKILL.md"
        done
    fi

    if [ ${#rule_indices[@]} -gt 0 ]; then
        echo ""
        printf "  ${BOLD}Rules → Cursor${RESET}\n"
        for idx in "${rule_indices[@]}"; do
            local rule_idx=$((idx - total_skills))
            printf "    %s → %s\n" "${RULE_NAMES[$rule_idx]}" "$cursor_base/rules/${RULE_NAMES[$rule_idx]}.mdc"
        done
    fi

    echo ""
    if $USE_LINKS; then
        print_info "Mode: symlink"
    else
        print_info "Mode: copy"
    fi
}

# ---------------------------------------------------------------------------
# confirm_prompt
# ---------------------------------------------------------------------------
confirm_prompt() {
    local msg="${1:-Proceed?}"
    printf "${BOLD}%s${RESET} [Y/n] " "$msg"
    read -r answer
    case "$answer" in
        n|N|no|No|NO) return 1 ;;
        *) return 0 ;;
    esac
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
    parse_args "$@"

    print_header "AI Skills Installer"

    # discover available items
    discover_skills
    discover_rules

    local total_skills=${#SKILL_NAMES[@]}
    local total_rules=${#RULE_NAMES[@]}

    if [ "$total_skills" -eq 0 ] && [ "$total_rules" -eq 0 ]; then
        print_warn "No skills or rules found in $SCRIPT_DIR"
        exit 0
    fi

    # choose target
    choose_target

    # resolve base directories
    local claude_base cursor_base
    if [ "$TARGET_MODE" = "user" ]; then
        claude_base="$HOME/.claude"
        cursor_base="$HOME/.cursor"
    else
        claude_base="$PROJECT_PATH/.claude"
        cursor_base="$PROJECT_PATH/.cursor"
    fi

    # build item list for selection
    local items=()
    local i
    for i in $(seq 0 $((total_skills - 1))); do
        items+=("${SKILL_NAMES[$i]}|${SKILL_DESCS[$i]}")
    done
    for i in $(seq 0 $((total_rules - 1))); do
        items+=("${RULE_NAMES[$i]}|${RULE_DESCS[$i]}")
    done

    # item selection (skip in non-interactive modes with no TTY)
    print_header "Select items to install"
    present_items "${items[@]}"

    if [ ${#SELECTED[@]} -eq 0 ]; then
        print_warn "No items selected"
        exit 0
    fi

    # split selection into skill and rule indices
    local selected_skills=() selected_rules=()
    for idx in "${SELECTED[@]}"; do
        if [ "$idx" -lt "$total_skills" ]; then
            selected_skills+=("$idx")
        else
            selected_rules+=("$idx")
        fi
    done

    # preview
    preview_install "$claude_base" "$cursor_base" "${SELECTED[@]}"

    # confirm
    if ! $DRY_RUN && ! $FORCE; then
        if ! confirm_prompt "Install?"; then
            print_info "Aborted"
            exit 0
        fi
    fi

    # execute
    echo ""
    for idx in "${selected_skills[@]}"; do
        install_skill "${SKILL_NAMES[$idx]}" "${SKILL_PATHS[$idx]}" "$claude_base" "$cursor_base"
    done

    for idx in "${selected_rules[@]}"; do
        local rule_idx=$((idx - total_skills))
        install_rule "${RULE_NAMES[$rule_idx]}" "${RULE_PATHS[$rule_idx]}" "$cursor_base"
    done

    # summary
    echo ""
    print_header "Summary"
    printf "  Installed: ${GREEN}%d${RESET}\n" "$INSTALLED"
    printf "  Skipped:   ${YELLOW}%d${RESET}\n" "$SKIPPED"
    if [ "$ERRORED" -gt 0 ]; then
        printf "  Errors:    ${RED}%d${RESET}\n" "$ERRORED"
    fi
    echo ""
}

main "$@"
