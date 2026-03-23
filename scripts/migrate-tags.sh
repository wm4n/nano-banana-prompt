#!/usr/bin/env bash
# scripts/migrate-tags.sh — Retag existing prompts with the current taxonomy.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROMPTS_DIR="$REPO_ROOT/content/prompts"

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BOLD='\033[1m'; RESET='\033[0m'
info()    { echo -e "${BOLD}$*${RESET}"; }
success() { echo -e "${GREEN}✓ $*${RESET}"; }
warn()    { echo -e "${YELLOW}⚠ $*${RESET}"; }
err()     { echo -e "${RED}✗ $*${RESET}" >&2; }

# Bug #4 fix: proper ", " separator (IFS only uses first char)
join_labels() {
  local first=1 item
  for item in "$@"; do
    [[ $first -eq 0 ]] && printf ', '
    printf '%s' "$item"
    first=0
  done
  printf '\n'
}

# ── Argument parsing ──────────────────────────────────────────────────────────
AUTO=false
FILES=()

for arg in "$@"; do
  if [[ "$arg" == "--auto" ]]; then
    AUTO=true
  else
    FILES+=("$arg")
  fi
done

if [[ ${#FILES[@]} -eq 0 ]]; then
  while IFS= read -r f; do FILES+=("$f"); done \
    < <(find "$PROMPTS_DIR" -name "*.md" | sort)
fi

# ── Extract prompt text from ### Prompt block ─────────────────────────────────
# Reads lines after "### Prompt", strips "> " prefix, stops at next ### or --- or EOF
extract_prompt_text() {
  local file="$1"
  awk '
    /^### Prompt/ { in_prompt=1; next }
    in_prompt && /^###/ { exit }
    in_prompt && /^---/ { exit }
    in_prompt { sub(/^> /, ""); print }
  ' "$file" | sed '/^[[:space:]]*$/d'
}

# ── Rewrite tags: block in frontmatter using awk ──────────────────────────────
# $1 = file path, $2 = newline-separated lines like:  - "Label"
rewrite_tags() {
  local file="$1"
  local new_tags_yaml="$2"
  local escaped_tags tmp
  escaped_tags=$(printf '%s' "$new_tags_yaml" | awk '{printf "%s\\n", $0}')
  tmp=$(mktemp)
  awk -v new_tags="$escaped_tags" '
    /^tags:/ {
      print "tags:"
      gsub(/\\n/, "\n", new_tags)
      sub(/\n$/, "", new_tags)
      printf "%s\n", new_tags
      in_tags=1; next
    }
    in_tags && /^  - / { next }
    in_tags { in_tags=0 }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

# ── Write selected tags to file ───────────────────────────────────────────────
# Reads from global SELECTED_ARR (bash 3.2 compatible — no local -n nameref)
_write_selected() {
  local file="$1"
  local chosen_labels=()
  local i
  for i in "${!ALL_SLUGS[@]}"; do
    [[ "${SELECTED_ARR[$i]}" == "1" ]] && chosen_labels+=("${ALL_LABELS[$i]}")
  done

  if [[ ${#chosen_labels[@]} -eq 0 ]]; then
    warn "  No tags selected — defaulting to Art Styles"
    chosen_labels=("Art Styles")
  fi

  local new_tags_yaml="" label
  for label in "${chosen_labels[@]}"; do
    new_tags_yaml="${new_tags_yaml}  - \"${label}\""$'\n'
  done
  new_tags_yaml="${new_tags_yaml%$'\n'}"

  rewrite_tags "$file" "$new_tags_yaml"
  success "  Updated: $(join_labels "${chosen_labels[@]}")"
}

# ── Retag one file ────────────────────────────────────────────────────────────
retag_file() {
  local file="$1"
  local title num

  title=$(grep -m1 '^title:' "$file" | sed -E 's/^title: *"?//;s/"? *$//')
  num=$(grep -m1 '^num:' "$file" | grep -o '[0-9]*')

  echo ""
  info "[${num}] ${title}"

  # Read current tags from frontmatter
  local current_labels=()
  while IFS= read -r line; do
    current_labels+=("$line")
  done < <(awk '/^tags:/,/^[a-z]/' "$file" | grep '^  - ' | sed 's/^  - "//;s/"$//')

  echo "  Current tags : $(join_labels "${current_labels[@]:-}")"

  # Infer new tags
  local prompt_text inferred_str
  prompt_text=$(extract_prompt_text "$file")

  echo -n "  Classifying with AI…"
  if inferred_str=$(ai_infer_tags "$prompt_text") && [[ -n "$inferred_str" ]]; then
    echo " ✓"
  else
    echo " failed, using keyword fallback"
    inferred_str=$(keyword_infer_tags "$title")
    warn "  (keyword fallback)"
  fi

  # Build SELECTED_ARR from AI suggestion
  # Note: intentionally NOT local — _write_selected reads it as a global
  SELECTED_ARR=()
  local i
  for i in "${!ALL_SLUGS[@]}"; do
    if echo "$inferred_str" | grep -qw "${ALL_SLUGS[$i]}"; then
      SELECTED_ARR+=(1)
    else
      SELECTED_ARR+=(0)
    fi
  done

  # Display AI suggestion
  local ai_labels=()
  for i in "${!ALL_SLUGS[@]}"; do
    [[ "${SELECTED_ARR[$i]}" == "1" ]] && ai_labels+=("${ALL_LABELS[$i]}")
  done
  echo "  AI suggests  : $(join_labels "${ai_labels[@]:-}")"

  # Auto mode: accept immediately
  if [[ "$AUTO" == "true" ]]; then
    _write_selected "$file"
    return
  fi

  # Interactive toggle loop
  local toggles mark idx t
  while true; do
    echo ""
    for i in "${!ALL_SLUGS[@]}"; do
      mark="  "
      [[ "${SELECTED_ARR[$i]}" == "1" ]] && mark="✓ "
      printf "  [%2d] %s%s\n" "$((i+1))" "$mark" "${ALL_LABELS[$i]}"
    done
    echo ""
    printf "Toggle number(s), s to skip, or Enter to accept: "
    IFS= read -r toggles

    if [[ -z "$toggles" ]]; then
      _write_selected "$file"
      return
    elif [[ "$toggles" == "s" ]]; then
      warn "  Skipped — no changes written."
      return
    fi

    for t in $toggles; do
      if [[ "$t" =~ ^[0-9]+$ ]] && (( t >= 1 && t <= ${#ALL_SLUGS[@]} )); then
        idx=$((t - 1))
        if [[ "${SELECTED_ARR[$idx]}" == "1" ]]; then
          SELECTED_ARR[$idx]=0
        else
          SELECTED_ARR[$idx]=1
        fi
      else
        warn "  Invalid: $t"
      fi
    done
  done
}

# ── Main loop ─────────────────────────────────────────────────────────────────
total=${#FILES[@]}
echo ""
info "=== migrate-tags: ${total} prompt(s) ==="
[[ "$AUTO" == "true" ]] && warn "Auto mode: AI suggestions accepted automatically"

for file in "${FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    err "File not found: $file"
    continue
  fi
  retag_file "$file"
done

echo ""
success "Done."
