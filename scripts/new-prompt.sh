#!/usr/bin/env bash
# new-prompt.sh — Interactively add a new prompt to the Nano Banana gallery.
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

# ── Step 1: Image ─────────────────────────────────────────────────────────────
echo ""
info "=== New Prompt =========================="
echo ""

IMAGE_SRC=""
while true; do
  printf "Image file path (drag & drop OK): "
  IFS= read -r IMAGE_SRC
  IMAGE_SRC="${IMAGE_SRC//\\ / }"
  IMAGE_SRC="${IMAGE_SRC%$'\r'}"
  IMAGE_SRC="${IMAGE_SRC#\'}" ; IMAGE_SRC="${IMAGE_SRC%\'}"
  IMAGE_SRC="${IMAGE_SRC#\"}" ; IMAGE_SRC="${IMAGE_SRC%\"}"
  IMAGE_SRC="${IMAGE_SRC# }"  ; IMAGE_SRC="${IMAGE_SRC% }"
  if [[ -f "$IMAGE_SRC" ]]; then
    break
  fi
  err "File not found: $IMAGE_SRC — please try again."
done

IMG_EXT=$(lowercase_ext "${IMAGE_SRC##*.}")

# ── Step 2: Title → slug, num ─────────────────────────────────────────────────
echo ""
printf "Prompt title: "
IFS= read -r TITLE

SLUG=$(slugify "$TITLE")
NUM=$(next_num)
PADDED=$(printf "%03d" "$NUM")
FILENAME="${PADDED}-${SLUG}"
IMG_DEST_REL="images/prompts/${FILENAME}.${IMG_EXT}"
IMG_DEST_ABS="$IMAGES_DIR/${FILENAME}.${IMG_EXT}"
MD_DEST="$PROMPTS_DIR/${FILENAME}.md"
IMG_URL="${BASE_URL}/${IMG_DEST_REL}"

echo ""
info "  num  : #${NUM}"
info "  slug : ${FILENAME}"
info "  image: ${IMG_DEST_REL}"

# ── Step 3: Source URL ────────────────────────────────────────────────────────
echo ""
printf "Source URL (Twitter/X link, or press Enter to skip): "
IFS= read -r SOURCE_URL
SOURCE_URL="${SOURCE_URL# }"; SOURCE_URL="${SOURCE_URL% }"

HANDLE=""
[[ -n "$SOURCE_URL" ]] && HANDLE=$(extract_handle "$SOURCE_URL")
SOURCEVAL="${HANDLE:+@${HANDLE}}"

# ── Step 4: Prompt text ───────────────────────────────────────────────────────
echo ""
info "--- Prompt text ---"
echo "(Type or paste the prompt. Enter END on its own line to finish.)"
PROMPT_TEXT=""
while IFS= read -r line; do
  [[ "$line" == "END" ]] && break
  if [[ -z "$PROMPT_TEXT" ]]; then
    PROMPT_TEXT="$line"
  else
    PROMPT_TEXT="${PROMPT_TEXT}
${line}"
  fi
done

# ── Step 5: Tags (AI inference from prompt text, fallback to keywords) ────────
echo ""
info "--- Tags ---"

echo -n "  Classifying tags with Copilot (claude-haiku-4.5)…"
inferred_str=""
if inferred_str=$(ai_infer_tags "$PROMPT_TEXT") && [[ -n "$inferred_str" ]]; then
  echo " ✓"
  info "  (AI inference)"
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
  TAG_YAML="${TAG_YAML}  - \"${label}\"
"
done

ATTRIBUTION=""
if [[ -n "$HANDLE" && -n "$SOURCE_URL" ]]; then
  ATTRIBUTION="from [@${HANDLE}](${SOURCE_URL})"
fi

TODAY=$(date +%Y-%m-%d)

CONTENT="---
title: \"${TITLE}\"
num: ${NUM}
tags:
${TAG_YAML}cover: \"${IMG_URL}\"
source: \"${SOURCEVAL}\"
sourceUrl: \"${SOURCE_URL}\"
date: ${TODAY}
---

<img width=\"750\" alt=\"${TITLE}\" src=\"${IMG_URL}\" />

### Prompt

> ${PROMPT_TEXT}
"
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

# ── Step 7: Write files ───────────────────────────────────────────────────────
mkdir -p "$IMAGES_DIR"
cp "$IMAGE_SRC" "$IMG_DEST_ABS"
success "Image → static/${IMG_DEST_REL}"

printf '%s' "$CONTENT" > "$MD_DEST"
success "Markdown → content/prompts/${FILENAME}.md"

# ── Step 8: Git commit + push ─────────────────────────────────────────────────
echo ""
info "--- Committing ---"
cd "$REPO_ROOT"
git add "static/${IMG_DEST_REL}" "$MD_DEST"
git commit -m "feat: add prompt #${NUM} - ${TITLE}

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"

if git push; then
  success "Pushed! Site will rebuild automatically."
else
  warn "Push failed. Files are committed locally. Run 'git push' manually when ready."
  exit 1
fi

echo ""
success "Done! Prompt #${NUM} '${TITLE}' added."
