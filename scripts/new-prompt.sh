#!/usr/bin/env bash
# new-prompt.sh — Interactively add a new prompt to the Image Gen Prompts gallery.
# Usage: ./scripts/new-prompt.sh   (run from repo root, requires bash 3.2+)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROMPTS_DIR="$REPO_ROOT/content/prompts"
IMAGES_DIR="$REPO_ROOT/static/images/prompts"
BASE_URL="/nano-banana-prompt"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BOLD='\033[1m'; RESET='\033[0m'
info()    { echo -e "${BOLD}$*${RESET}"; }
success() { echo -e "${GREEN}✓ $*${RESET}"; }
warn()    { echo -e "${YELLOW}⚠ $*${RESET}"; }
err()     { echo -e "${RED}✗ $*${RESET}" >&2; }

# ── Prompt text input (clipboard → nano → END loop) ──────────────────────────
_STEP_PROMPT_RESULT=""

read_prompt_text() {
  _STEP_PROMPT_RESULT=""
  local clipboard_content use_clipboard tmpfile _old_exit_trap

  # Path 1: pbpaste (macOS clipboard)
  if command -v pbpaste &>/dev/null; then
    clipboard_content=$(pbpaste)
    if [[ -n "$clipboard_content" ]]; then
      echo ""
      info "--- Clipboard content ---"
      echo "$clipboard_content"
      echo ""
      printf "Use clipboard content? [Y/n]: "
      IFS= read -r use_clipboard || true
      use_clipboard="${use_clipboard:-Y}"
      if [[ "$use_clipboard" == "Y" || "$use_clipboard" == "y" ]]; then
        _STEP_PROMPT_RESULT="$clipboard_content"
        return 0
      fi
    else
      warn "Clipboard is empty."
    fi
  fi

  # Path 2: nano editor
  if command -v nano &>/dev/null; then
    tmpfile=$(mktemp /tmp/nbp-prompt-XXXXX)
    # Save any pre-existing EXIT trap and restore it after cleanup
    _old_exit_trap=$(trap -p EXIT)
    # Double-quote so $tmpfile path is captured immediately (not at EXIT time)
    # shellcheck disable=SC2064
    trap "rm -f '$tmpfile'" EXIT
    info "Opening nano — paste or type your prompt, then Ctrl+X → Y to save and exit."
    nano "$tmpfile"
    # Note: $(...) strips trailing newlines — acceptable for prompt text
    _STEP_PROMPT_RESULT=$(cat "$tmpfile")
    rm -f "$tmpfile"
    eval "${_old_exit_trap:-trap - EXIT}"
    if [[ -z "$_STEP_PROMPT_RESULT" ]]; then
      warn "Prompt is empty. Re-opening nano — press Ctrl+X to accept empty."
      tmpfile=$(mktemp /tmp/nbp-prompt-XXXXX)
      _old_exit_trap=$(trap -p EXIT)
      # shellcheck disable=SC2064
      trap "rm -f '$tmpfile'" EXIT
      nano "$tmpfile"
      _STEP_PROMPT_RESULT=$(cat "$tmpfile")
      rm -f "$tmpfile"
      eval "${_old_exit_trap:-trap - EXIT}"
    fi
    return 0
  fi

  # Path 3: fallback — original END-sentinel loop
  info "(Type or paste the prompt. Enter END on its own line to finish.)"
  local line
  while IFS= read -r line; do
    [[ "$line" == "END" ]] && break
    if [[ -z "$_STEP_PROMPT_RESULT" ]]; then
      _STEP_PROMPT_RESULT="$line"
    else
      _STEP_PROMPT_RESULT="${_STEP_PROMPT_RESULT}"$'\n'"${line}"
    fi
  done
}

# ── Tag definitions and inference functions ───────────────────────────────────
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# ── Helpers ───────────────────────────────────────────────────────────────────
slugify() {
  local text="$1"
  text=$(echo "$text" | tr '[:upper:]' '[:lower:]')   # lowercase
  text="${text//&/and}"                                # & → and
  text=$(echo "$text" | tr -cs 'a-z0-9' '-')          # non-alphanum → hyphen
  text=$(echo "$text" | sed 's/-\{2,\}/-/g')          # collapse hyphens
  text="${text#-}"; text="${text%-}"                   # strip edge hyphens
  text="${text:0:60}"
  echo "$text"
}

next_num() {
  local max=0 n f
  while IFS= read -r f; do
    n=$(grep -m1 '^num:' "$f" 2>/dev/null | grep -o '[0-9]*' || true)
    [[ -n "$n" && "$n" -gt "$max" ]] && max=$n
  done < <(find "$PROMPTS_DIR" -name "*.md")
  echo $((max + 1))
}

extract_handle() {
  local url="$1" handle
  handle=$(echo "$url" | grep -oE '(x\.com|twitter\.com)/[^/?]+' | head -1 | cut -d'/' -f2 || true)
  echo "${handle:-unknown}"
}

lowercase_ext() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

# ── Title → slug, num ────────────────────────────────────────────────────────
echo ""
info "=== New Prompt =========================="
echo ""
printf "Prompt title: "
IFS= read -r TITLE

SLUG=$(slugify "$TITLE")
NUM=$(next_num)
PADDED=$(printf "%03d" "$NUM")
FILENAME="${PADDED}-${SLUG}"
MD_DEST="$PROMPTS_DIR/${FILENAME}.md"

echo ""
info "  num  : #${NUM}"
info "  slug : ${FILENAME}"

# ── Source URL ────────────────────────────────────────────────────────────────
echo ""
printf "Source URL (Twitter/X link, or press Enter to skip): "
IFS= read -r SOURCE_URL
SOURCE_URL="${SOURCE_URL# }"; SOURCE_URL="${SOURCE_URL% }"

HANDLE=""
[[ -n "$SOURCE_URL" ]] && HANDLE=$(extract_handle "$SOURCE_URL")
SOURCEVAL="${HANDLE:+@${HANDLE}}"

# ── Service selection ─────────────────────────────────────────────────────────
# Read available services from data/services.yaml using bash 3.2+ compatible parsing.
# Uses parallel arrays (no associative arrays).
SVC_SLUGS=()
SVC_NAMES=()
SERVICES_YAML_FILE="$REPO_ROOT/data/services.yaml"

if [[ -f "$SERVICES_YAML_FILE" ]]; then
  if command -v yq &>/dev/null; then
    # Fast path: yq available
    while IFS= read -r slug; do
      SVC_SLUGS+=("$slug")
    done < <(yq '.[].slug' "$SERVICES_YAML_FILE" 2>/dev/null | tr -d '"')
    while IFS= read -r name; do
      SVC_NAMES+=("$name")
    done < <(yq '.[].name' "$SERVICES_YAML_FILE" 2>/dev/null | tr -d '"')
  else
    # Fallback: line-by-line grep parsing of the YAML list format
    # Matches: `  slug: "nano-banana"` and `  name: "Nano Banana"`
    while IFS= read -r line; do
      if [[ "$line" =~ slug:[[:space:]]+\"([^\"]+)\" ]]; then
        SVC_SLUGS+=("${BASH_REMATCH[1]}")
      elif [[ "$line" =~ name:[[:space:]]+\"([^\"]+)\" ]]; then
        SVC_NAMES+=("${BASH_REMATCH[1]}")
      fi
    done < "$SERVICES_YAML_FILE"
  fi
fi

# Last-resort fallback: file missing or parse yielded nothing
if [[ ${#SVC_SLUGS[@]} -eq 0 ]]; then
  warn "Could not read data/services.yaml — using built-in defaults"
  SVC_SLUGS=("nano-banana" "gpt-image")
  SVC_NAMES=("Nano Banana" "GPT Image")
fi

# Default: nano-banana pre-selected
SVC_SELECTED=()
for i in "${!SVC_SLUGS[@]}"; do
  [[ "${SVC_SLUGS[$i]}" == "nano-banana" ]] && SVC_SELECTED+=(1) || SVC_SELECTED+=(0)
done

echo ""
info "--- Services ---"
while true; do
  echo ""
  for i in "${!SVC_SLUGS[@]}"; do
    mark="  "
    [[ "${SVC_SELECTED[$i]}" == "1" ]] && mark="✓ "
    printf "  [%2d] %s%s\n" "$((i+1))" "$mark" "${SVC_NAMES[$i]}"
  done
  echo ""
  printf "Toggle service number(s) (space-separated), or press Enter to accept: "
  IFS= read -r toggles
  [[ -z "$toggles" ]] && break
  for t in $toggles; do
    if [[ "$t" =~ ^[0-9]+$ ]] && (( t >= 1 && t <= ${#SVC_SLUGS[@]} )); then
      idx=$((t - 1))
      [[ "${SVC_SELECTED[$idx]}" == "1" ]] && SVC_SELECTED[$idx]=0 || SVC_SELECTED[$idx]=1
    else
      warn "  Invalid: $t (must be 1–${#SVC_SLUGS[@]})"
    fi
  done
done

SELECTED_SERVICES=()
SELECTED_SERVICE_NAMES=()
for i in "${!SVC_SLUGS[@]}"; do
  if [[ "${SVC_SELECTED[$i]}" == "1" ]]; then
    SELECTED_SERVICES+=("${SVC_SLUGS[$i]}")
    SELECTED_SERVICE_NAMES+=("${SVC_NAMES[$i]}")
  fi
done

# Ensure at least one service is selected
if [[ ${#SELECTED_SERVICES[@]} -eq 0 ]]; then
  warn "No service selected — defaulting to Nano Banana"
  SELECTED_SERVICES=("nano-banana")
  SELECTED_SERVICE_NAMES=("Nano Banana")
fi

# ── Step loop ─────────────────────────────────────────────────────────────────
STEP_TITLES=()
STEP_IMAGE_SRCS=()
STEP_PROMPTS=()
STEP_IMAGE_URLS=()
STEP_IMAGE_DESTS=()
STEP_NUM=0

while true; do
  STEP_NUM=$((STEP_NUM + 1))
  echo ""
  info "=== Step ${STEP_NUM} =============================="

  printf "Step title [Prompt]: "
  IFS= read -r step_title
  step_title="${step_title:-Prompt}"
  STEP_TITLES+=("$step_title")

  step_img_src=""
  while true; do
    printf "Image (drag & drop, or Enter to skip): "
    IFS= read -r step_img_src
    step_img_src="${step_img_src//\\ / }"
    step_img_src="${step_img_src%$'\r'}"
    step_img_src="${step_img_src#\'}"; step_img_src="${step_img_src%\'}"
    step_img_src="${step_img_src#\"}"; step_img_src="${step_img_src%\"}"
    step_img_src="${step_img_src# }";  step_img_src="${step_img_src% }"
    if [[ -z "$step_img_src" ]]; then
      break
    elif [[ -f "$step_img_src" ]]; then
      break
    else
      err "File not found: $step_img_src — try again, or press Enter to skip."
    fi
  done
  STEP_IMAGE_SRCS+=("$step_img_src")

  echo ""
  info "--- Prompt text ---"
  read_prompt_text
  STEP_PROMPTS+=("$_STEP_PROMPT_RESULT")

  success "Step ${STEP_NUM} added."

  printf "Add another step? [y/N]: "
  IFS= read -r more
  [[ "$more" != "y" && "$more" != "Y" ]] && break
done

# ── Build image URL and dest arrays (needed before service image dedup check) ──
COVER_URL=""
for i in "${!STEP_IMAGE_SRCS[@]}"; do
  src="${STEP_IMAGE_SRCS[$i]}"
  if [[ -z "$src" ]]; then
    STEP_IMAGE_URLS[$i]=""
    STEP_IMAGE_DESTS[$i]=""
    continue
  fi
  IMG_EXT=$(lowercase_ext "${src##*.}")
  step_idx=$((i + 1))
  STEP_IMAGE_URLS[$i]="${BASE_URL}/images/prompts/${FILENAME}-${step_idx}.${IMG_EXT}"
  STEP_IMAGE_DESTS[$i]="$IMAGES_DIR/${FILENAME}-${step_idx}.${IMG_EXT}"
  [[ -z "$COVER_URL" ]] && COVER_URL="${STEP_IMAGE_URLS[$i]}"
done

# ── Service images (only when 2+ services selected) ──────────────────────────
# Parallel arrays for bash 3.2+ compatibility
SERVICE_IMAGE_SLUGS=()
SERVICE_IMAGE_URLS=()
SERVICE_IMAGE_DESTS=()

if [[ ${#SELECTED_SERVICES[@]} -gt 1 ]]; then
  echo ""
  info "--- Service Images ---"
  info "(Optional: provide a result image URL or local file for each service, or press Enter to skip)"
  
  # Show available step images for quick reference
  if [[ ${#STEP_IMAGE_URLS[@]} -gt 0 ]]; then
    echo ""
    info "Available step images (you can paste these URLs):"
    for i in "${!STEP_IMAGE_URLS[@]}"; do
      url="${STEP_IMAGE_URLS[$i]}"
      if [[ -n "$url" ]]; then
        step_idx=$((i + 1))
        printf "  Step %d: %s\n" "$step_idx" "$url"
      fi
    done
    echo ""
  fi
  
  for i in "${!SELECTED_SERVICES[@]}"; do
    slug="${SELECTED_SERVICES[$i]}"
    service_name="${SELECTED_SERVICE_NAMES[$i]}"
    while true; do
      printf "  Image for %s (URL, local file, or Enter to skip): " "$service_name"
      IFS= read -r svc_img_input
      svc_img_input="${svc_img_input//\\ / }"
      svc_img_input="${svc_img_input%$'\r'}"
      svc_img_input="${svc_img_input#\'}"; svc_img_input="${svc_img_input%\'}"
      svc_img_input="${svc_img_input#\"}"; svc_img_input="${svc_img_input%\"}"
      svc_img_input="${svc_img_input# }";  svc_img_input="${svc_img_input% }"
      
      # Empty input is valid (skip this service image)
      if [[ -z "$svc_img_input" ]]; then
        break
      fi
      
      svc_img_url=""
      svc_img_dest=""
      
      # Check if input is a local file path
      if [[ -f "$svc_img_input" ]]; then
        # Check if this file is identical to an existing step image — reuse URL if so
        svc_img_reused=false
        for j in "${!STEP_IMAGE_SRCS[@]}"; do
          if [[ "${STEP_IMAGE_SRCS[$j]}" == "$svc_img_input" && -n "${STEP_IMAGE_URLS[$j]:-}" ]]; then
            svc_img_url="${STEP_IMAGE_URLS[$j]}"
            info "    ✓ Reused step $((j+1)) image (same file): ${svc_img_url}"
            SERVICE_IMAGE_SLUGS+=("$slug")
            SERVICE_IMAGE_URLS+=("$svc_img_url")
            SERVICE_IMAGE_DESTS+=("")
            svc_img_reused=true
            break
          fi
        done
        if [[ "$svc_img_reused" == false ]]; then
          # Auto-upload local file
          IMG_EXT=$(lowercase_ext "${svc_img_input##*.}")
          svc_img_dest="$IMAGES_DIR/${FILENAME}-${slug}.${IMG_EXT}"
          cp "$svc_img_input" "$svc_img_dest"
          svc_img_url="${BASE_URL}/images/prompts/${FILENAME}-${slug}.${IMG_EXT}"
          info "    ✓ Uploaded: ${svc_img_input##*/} → static/images/prompts/${FILENAME}-${slug}.${IMG_EXT}"
          SERVICE_IMAGE_SLUGS+=("$slug")
          SERVICE_IMAGE_URLS+=("$svc_img_url")
          SERVICE_IMAGE_DESTS+=("$svc_img_dest")
        fi
        break
      elif [[ "$svc_img_input" =~ ^(https?://|/) ]]; then
        # Valid URL format
        SERVICE_IMAGE_SLUGS+=("$slug")
        SERVICE_IMAGE_URLS+=("$svc_img_input")
        SERVICE_IMAGE_DESTS+=("")
        break
      else
        # Invalid input
        err "    File not found and invalid URL format: '$svc_img_input'"
        warn "    Please provide either a local file path or a URL (https://... or /...)"
        continue
      fi
    done
  done
fi

# ── Tags (AI inference from all step prompts combined, fallback to keywords) ──
ALL_PROMPTS=""
for i in "${!STEP_PROMPTS[@]}"; do
  ALL_PROMPTS="${ALL_PROMPTS}${STEP_PROMPTS[$i]}"$'\n'
done

echo ""
info "--- Tags ---"
echo -n "  Classifying tags with Claude (claude-haiku-4.5)…"
inferred_str=""
if inferred_str=$(ai_infer_tags "$ALL_PROMPTS") && [[ -n "$inferred_str" ]]; then
  echo " ✓"
  info "  (AI inference from ${STEP_NUM} prompt(s) combined)"
else
  echo " failed, falling back to keyword matching"
  inferred_str=$(keyword_infer_tags "$TITLE")
  warn "  (keyword fallback)"
fi

# SELECTED_ARR is a parallel array to ALL_SLUGS (0 or 1)
SELECTED_ARR=()
for i in "${!ALL_SLUGS[@]}"; do
  slug="${ALL_SLUGS[$i]}"
  if echo "$inferred_str" | grep -qw "$slug"; then
    SELECTED_ARR+=(1)
  else
    SELECTED_ARR+=(0)
  fi
done

while true; do
  echo ""
  for i in "${!ALL_SLUGS[@]}"; do
    mark="  "
    [[ "${SELECTED_ARR[$i]}" == "1" ]] && mark="✓ "
    printf "  [%2d] %s%s\n" "$((i+1))" "$mark" "${ALL_LABELS[$i]}"
  done
  echo ""
  printf "Toggle tag number(s) (space-separated), or press Enter to accept: "
  IFS= read -r toggles
  [[ -z "$toggles" ]] && break
  for t in $toggles; do
    if [[ "$t" =~ ^[0-9]+$ ]] && (( t >= 1 && t <= ${#ALL_SLUGS[@]} )); then
      idx=$((t - 1))
      if [[ "${SELECTED_ARR[$idx]}" == "1" ]]; then
        SELECTED_ARR[$idx]=0
      else
        SELECTED_ARR[$idx]=1
      fi
    else
      warn "  Invalid: $t (must be 1–${#ALL_SLUGS[@]})"
    fi
  done
done

CHOSEN_LABELS=()
for i in "${!ALL_SLUGS[@]}"; do
  [[ "${SELECTED_ARR[$i]}" == "1" ]] && CHOSEN_LABELS+=("${ALL_LABELS[$i]}")
done

if [[ ${#CHOSEN_LABELS[@]} -eq 0 ]]; then
  warn "No tags selected — defaulting to Art Styles"
  CHOSEN_LABELS=("Art Styles")
fi

# ── Build markdown content ────────────────────────────────────────────────────
TAG_YAML=""
for label in "${CHOSEN_LABELS[@]}"; do
  TAG_YAML="${TAG_YAML}  - \"${label}\""$'\n'
done

ATTRIBUTION=""
if [[ -n "$HANDLE" && -n "$SOURCE_URL" ]]; then
  ATTRIBUTION="from [@${HANDLE}](${SOURCE_URL})"
fi

TODAY=$(date +%Y-%m-%d)

CONTENT_BODY=""
for i in "${!STEP_TITLES[@]}"; do
  step_title="${STEP_TITLES[$i]}"
  img_url="${STEP_IMAGE_URLS[$i]:-}"
  step_prompt="${STEP_PROMPTS[$i]}"

  CONTENT_BODY="${CONTENT_BODY}"$'\n'"### ${step_title}"$'\n'
  if [[ -n "$img_url" ]]; then
    CONTENT_BODY="${CONTENT_BODY}"$'\n'"<img width=\"750\" alt=\"${TITLE}\" src=\"${img_url}\" />"$'\n'
  fi
  formatted_prompt=""
  while IFS= read -r pline; do
    formatted_prompt="${formatted_prompt}> ${pline}"$'\n'
  done <<< "$step_prompt"
  CONTENT_BODY="${CONTENT_BODY}"$'\n'"${formatted_prompt}"
done

# Build services YAML block (always written)
SERVICES_YAML_BLOCK=""
for slug in "${SELECTED_SERVICES[@]}"; do
  SERVICES_YAML_BLOCK="${SERVICES_YAML_BLOCK}  - \"${slug}\""$'\n'
done

# Build service_images YAML block (only if any URLs were provided)
SERVICE_IMAGES_YAML_BLOCK=""
for i in "${!SERVICE_IMAGE_SLUGS[@]}"; do
  slug="${SERVICE_IMAGE_SLUGS[$i]}"
  url="${SERVICE_IMAGE_URLS[$i]}"
  [[ -n "$url" ]] && SERVICE_IMAGES_YAML_BLOCK="${SERVICE_IMAGES_YAML_BLOCK}  ${slug}: \"${url}\""$'\n'
done

# Build service_images frontmatter section (empty string if no images)
SVC_IMAGES_FM=""
if [[ -n "$SERVICE_IMAGES_YAML_BLOCK" ]]; then
  SVC_IMAGES_FM="service_images:"$'\n'"${SERVICE_IMAGES_YAML_BLOCK}"
fi

CONTENT="---
title: \"${TITLE}\"
num: ${NUM}
tags:
${TAG_YAML}services:
${SERVICES_YAML_BLOCK}${SVC_IMAGES_FM}cover: \"${COVER_URL}\"
source: \"${SOURCEVAL}\"
sourceUrl: \"${SOURCE_URL}\"
date: ${TODAY}
---
${CONTENT_BODY}"
[[ -n "$ATTRIBUTION" ]] && CONTENT="${CONTENT}
${ATTRIBUTION}
"

# ── Step 6: Preview ───────────────────────────────────────────────────────────
echo ""
info "=== Preview ============================="
echo ""
echo "$CONTENT"
echo ""
printf "Looks good? [Y/n]: "
IFS= read -r CONFIRM
CONFIRM="${CONFIRM:-Y}"
if [[ "$CONFIRM" != "Y" && "$CONFIRM" != "y" ]]; then
  warn "Aborted. No files were written."
  exit 0
fi

# ── Write files ───────────────────────────────────────────────────────────────
mkdir -p "$IMAGES_DIR"
for i in "${!STEP_IMAGE_DESTS[@]}"; do
  dest="${STEP_IMAGE_DESTS[$i]}"
  [[ -z "$dest" ]] && continue
  cp "${STEP_IMAGE_SRCS[$i]}" "$dest"
  step_idx=$((i + 1))
  success "Image → static/images/prompts/${FILENAME}-${step_idx}.${STEP_IMAGE_DESTS[$i]##*.}"
done

printf '%s' "$CONTENT" > "$MD_DEST"
success "Markdown → content/prompts/${FILENAME}.md"

# ── Git commit + push ─────────────────────────────────────────────────────────
echo ""
info "--- Committing ---"
cd "$REPO_ROOT"
for i in "${!STEP_IMAGE_DESTS[@]}"; do
  dest="${STEP_IMAGE_DESTS[$i]}"
  [[ -z "$dest" ]] && continue
  git add "${dest#$REPO_ROOT/}"
done
for i in "${!SERVICE_IMAGE_DESTS[@]}"; do
  dest="${SERVICE_IMAGE_DESTS[$i]}"
  [[ -z "$dest" ]] && continue
  git add "${dest#$REPO_ROOT/}"
done
git add "${MD_DEST#$REPO_ROOT/}"
git commit -m "feat: add prompt #${NUM} - ${TITLE}

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"

if git push; then
  success "Pushed! Site will rebuild automatically."
else
  warn "Push failed. Files are committed locally. Run 'git push' manually when ready."
  exit 1
fi

echo ""
success "Done! Prompt #${NUM} '${TITLE}' added (${STEP_NUM} step(s))."
