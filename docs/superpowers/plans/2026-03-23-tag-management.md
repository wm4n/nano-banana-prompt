# Tag Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Centralize tag definitions in `scripts/tags.sh`, extract shared inference functions to `scripts/lib.sh`, and create `scripts/migrate-tags.sh` for retagging existing prompts.

**Architecture:** Tag data lives in `tags.sh` (sourced by all scripts). Inference functions live in `lib.sh` (which sources `tags.sh`). `new-prompt.sh` sheds its inline definitions and sources `lib.sh`. `migrate-tags.sh` is a new standalone script that sources `lib.sh` and rewrites frontmatter using `awk`.

**Tech Stack:** Bash 3.2+, awk, sed, Copilot CLI (`copilot --model claude-haiku-4.5`)

---

## File Map

| Action | File | Responsibility |
|---|---|---|
| Create | `scripts/tags.sh` | `TAG_DEFS` array + `ALL_SLUGS` / `ALL_LABELS` / `ALL_KEYWORDS` build loop |
| Create | `scripts/lib.sh` | Sources `tags.sh`; defines `ai_infer_tags()` and `keyword_infer_tags()` |
| Modify | `scripts/new-prompt.sh` | Remove inline tag data/functions; add `source lib.sh` |
| Create | `scripts/migrate-tags.sh` | Retag tool — single file, batch interactive, batch `--auto` |

---

## Task 1: Create `scripts/tags.sh`

**Files:**
- Create: `scripts/tags.sh`

- [ ] **Step 1: Create the file with TAG_DEFS and the build loop**

The content below is copied verbatim from `new-prompt.sh` lines 19–44:

```bash
#!/usr/bin/env bash
# scripts/tags.sh — Single source of truth for tag definitions.
# Source this file; do not execute directly.
# Each entry: "slug|Human Label|kw1|kw2|..."
TAG_DEFS=(
  "city-architecture|City & Architecture|city|urban|isometric|animal crossing|simcity|claymorphism|white clay|3d led|architectural blueprint|souvenir magnet|city brush|city scene"
  "3d-miniature|3D & Miniature|miniature|diorama|hologram|glass marble|cube diorama|chibi|tilt 3d|3d relief|hand paint miniature|3d hand|3d story|3d newspaper|concept store|different angle|survey board"
  "art-styles|Art Styles|watercolor|ink painting|ink drawing|pencil|crayon|sketch|embroidery|paper cut|folded paper|botanical|scribble|claymation|painterly|step by step drawing|draw like|style drawing|watercolor style|blueprint schematic"
  "character-portrait|Character & Portrait|character|caricature|portrait|sticker|hair style|pose|pixar|cartoon|idol|dress|editorial portrait|cute character|chat sticker|soft toy|mechanical bird"
  "photo-cinematic|Photo & Cinematic|photo|cinematic|angle shot|motion blur|upscale|restore|cherry blossom|raining|lat lon|taking photo"
  "infographic-ui|Infographic & UI|hud|infographic|report|ui/ux|heatmap|species migration|boarding pass|profile card|notebooklm|tech evolution|status report|architect|real-time"
  "effects-composite|Effects & Composite|neon effect|blending|season blend|mirror reflection|firework|emerge from|split effect|combine different|imagine events|surreal|era"
  "food-commercial|Food & Commercial|food|cuisine|fruit|dish|pixelize food|advertising food|recipe"
  "poster-nature|Poster & Nature|poster|magazine cover|wallpaper|gta|brand poster|cloud formation|sea of clouds|mountain|forest|bookshelves|story telling|concept art|looking through|peeking through"
  "icons-stickers|Icons & Stickers|icon generation|themed icon|different style icon"
)

ALL_SLUGS=()
ALL_LABELS=()
ALL_KEYWORDS=()

for _def in "${TAG_DEFS[@]}"; do
  IFS='|' read -r _slug _label _kw_rest <<< "$_def"
  ALL_SLUGS+=("$_slug")
  ALL_LABELS+=("$_label")
  ALL_KEYWORDS+=("$_kw_rest")
done
```

- [ ] **Step 2: Verify the file sources correctly and arrays are populated**

```bash
bash -c 'source scripts/tags.sh; echo "Slugs: ${#ALL_SLUGS[@]}"; echo "Labels: ${ALL_LABELS[*]}"'
```

Expected output:
```
Slugs: 10
Labels: City & Architecture 3D & Miniature Art Styles Character & Portrait Photo & Cinematic Infographic & UI Effects & Composite Food & Commercial Poster & Nature Icons & Stickers
```

- [ ] **Step 3: Commit**

```bash
git add scripts/tags.sh
git commit -m "feat: add scripts/tags.sh as single source of truth for tag definitions"
```

---

## Task 2: Create `scripts/lib.sh`

**Files:**
- Create: `scripts/lib.sh`
- Reference: `scripts/new-prompt.sh` lines 67–105 (the two inference functions)

- [ ] **Step 1: Create the file**

`lib.sh` sources `tags.sh` for array data, then defines both inference functions. The slug list in `ai_infer_tags()` is built dynamically from `ALL_SLUGS` (fixing the hardcoded list from `new-prompt.sh`). Note the correct idiom for comma-space joining: `printf '%s\n' "${ALL_SLUGS[@]}" | paste -sd', '` — this works on macOS and Linux without additional dependencies.

```bash
#!/usr/bin/env bash
# scripts/lib.sh — Shared tag inference functions.
# Source this file; do not execute directly.

source "$(dirname "${BASH_SOURCE[0]}")/tags.sh"

# Keyword-based tag inference. Always returns at least one slug.
# Returns space-separated slugs on stdout.
keyword_infer_tags() {
  local title_lower i slug kw matched=()
  title_lower=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  for i in "${!ALL_SLUGS[@]}"; do
    slug="${ALL_SLUGS[$i]}"
    IFS='|' read -ra kws <<< "${ALL_KEYWORDS[$i]}"
    for kw in "${kws[@]}"; do
      if [[ "$title_lower" == *"$kw"* ]]; then
        matched+=("$slug")
        break
      fi
    done
  done
  if [[ ${#matched[@]} -eq 0 ]]; then
    echo "art-styles"
  else
    echo "${matched[*]}"
  fi
}

# AI-based tag inference using Copilot CLI (claude-haiku-4.5).
# Returns space-separated slugs on stdout, or exits non-zero on failure.
ai_infer_tags() {
  local prompt_text="$1"
  local tag_list
  tag_list=$(printf '%s\n' "${ALL_SLUGS[@]}" | paste -sd', ')
  local result
  result=$(copilot --model claude-haiku-4.5 --no-ask-user -s \
    -p "You are a classifier for AI image generation prompts.
Given the prompt below, pick which tags apply from the list.
Return ONLY the matching tag slugs as a comma-separated list, nothing else.
You may return one or multiple tags. Use only slugs from the list.

Tags: ${tag_list}

Prompt: ${prompt_text}" 2>/dev/null) || return 1

  echo "$result" | tr ',' ' ' | tr -s ' ' | sed 's/^ //;s/ $//'
}
```

- [ ] **Step 2: Verify keyword_infer_tags works correctly**

```bash
bash -c 'source scripts/lib.sh; keyword_infer_tags "watercolor portrait of a cat"'
```

Expected: `art-styles character-portrait` (both match)

```bash
bash -c 'source scripts/lib.sh; keyword_infer_tags "unrelated text xyz"'
```

Expected: `art-styles` (no-match fallback)

- [ ] **Step 3: Verify the AI slug list is now dynamic**

```bash
bash -c 'source scripts/lib.sh; printf "%s\n" "${ALL_SLUGS[@]}" | paste -sd", "'
```

Expected: `city-architecture, 3d-miniature, art-styles, character-portrait, photo-cinematic, infographic-ui, effects-composite, food-commercial, poster-nature, icons-stickers`

- [ ] **Step 4: Commit**

```bash
git add scripts/lib.sh
git commit -m "feat: add scripts/lib.sh with shared tag inference functions (dynamic slug list)"
```

---

## Task 3: Update `scripts/new-prompt.sh`

**Files:**
- Modify: `scripts/new-prompt.sh`

The goal is to remove three inline sections and replace them with a single `source` call. Everything else stays unchanged.

- [ ] **Step 1: Replace the TAG_DEFS block with a source call**

Find and remove the comment + TAG_DEFS array + build loop (currently lines ~19–44):

```bash
# ── Tag definitions (ported from scripts/parse_readme.py TAG_RULES) ───────────
# Each entry: "slug|Human Label|kw1|kw2|..."
TAG_DEFS=(
  ...10 entries...
)

ALL_SLUGS=()
ALL_LABELS=()
ALL_KEYWORDS=()   # pipe-separated keyword string per tag

for _def in "${TAG_DEFS[@]}"; do
  IFS='|' read -r _slug _label _kw_rest <<< "$_def"
  ALL_SLUGS+=("$_slug")
  ALL_LABELS+=("$_label")
  ALL_KEYWORDS+=("$_kw_rest")
done
```

Replace with:

```bash
# ── Tag definitions and inference functions ───────────────────────────────────
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
```

- [ ] **Step 2: Remove the inline keyword_infer_tags() function**

Find and delete (currently lines ~67–85):

```bash
# Keyword-based fallback (used when AI inference fails)
keyword_infer_tags() {
  ...
}
```

- [ ] **Step 3: Remove the inline ai_infer_tags() function**

Find and delete (currently lines ~87–105):

```bash
# AI-based tag inference using copilot CLI + claude-haiku-4.5
# Returns space-separated slugs, or exits with non-zero on failure
ai_infer_tags() {
  ...
}
```

- [ ] **Step 4: Smoke-test new-prompt.sh still runs**

Run the script up to the first interactive prompt, then Ctrl-C. The key check is that it does not error out before the first input prompt:

```bash
echo "" | timeout 3 ./scripts/new-prompt.sh 2>&1 | head -5 || true
```

Expected: no `command not found` or `unbound variable` errors. You should see the `=== New Prompt ===` header.

- [ ] **Step 5: Commit**

```bash
git add scripts/new-prompt.sh
git commit -m "refactor: new-prompt.sh sources lib.sh instead of inline tag definitions"
```

---

## Task 4: Create `scripts/migrate-tags.sh`

**Files:**
- Create: `scripts/migrate-tags.sh`

This is the most complex task. Build it in three sub-steps: argument parsing + prompt extraction, the interactive toggle loop, and the frontmatter rewriting.

- [ ] **Step 1: Create the file with scaffolding, arg parsing, and prompt extraction**

```bash
#!/usr/bin/env bash
# scripts/migrate-tags.sh — Retag existing prompts with the current taxonomy.
#
# Usage:
#   ./scripts/migrate-tags.sh [--auto] [file.md ...]
#
#   No args          : retag all prompts interactively
#   --auto           : retag all prompts, auto-accept AI suggestions
#   file.md [...]    : retag specific files interactively
#   --auto file.md   : retag specific files non-interactively
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

# ── Extract prompt text from a .md file ──────────────────────────────────────
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
# $1 = file path, $2 = newline-separated "  - \"Label\"" lines
rewrite_tags() {
  local file="$1"
  local new_tags_yaml="$2"
  local tmp
  tmp=$(mktemp)
  awk -v new_tags="$new_tags_yaml" '
    /^tags:/ {
      print "tags:"
      printf "%s\n", new_tags
      in_tags=1; next
    }
    in_tags && /^  - / { next }
    in_tags { in_tags=0 }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

# ── Retag one file ────────────────────────────────────────────────────────────
retag_file() {
  local file="$1"
  local title num

  title=$(grep -m1 '^title:' "$file" | sed 's/^title: *"\?//;s/"\? *$//')
  num=$(grep -m1 '^num:' "$file" | grep -o '[0-9]*')

  echo ""
  info "[${num}] ${title}"

  # Read current tags from frontmatter
  local current_labels=()
  while IFS= read -r line; do
    current_labels+=("$line")
  done < <(awk '/^tags:/,/^[a-z]/' "$file" | grep '^  - ' | sed 's/^  - "//;s/"//')

  echo "  Current tags : $(IFS=', '; echo "${current_labels[*]}")"

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
  # Note: SELECTED_ARR is intentionally NOT declared local so _write_selected can access it
  SELECTED_ARR=()
  for i in "${!ALL_SLUGS[@]}"; do
    if echo "$inferred_str" | grep -qw "${ALL_SLUGS[$i]}"; then
      SELECTED_ARR+=(1)
    else
      SELECTED_ARR+=(0)
    fi
  done

  echo "  AI suggests  : $(
    for i in "${!ALL_SLUGS[@]}"; do
      [[ "${SELECTED_ARR[$i]}" == "1" ]] && echo -n "${ALL_LABELS[$i]}, "
    done | sed 's/, $//'
  )"

  # Auto mode: accept immediately
  if [[ "$AUTO" == "true" ]]; then
    _write_selected "$file"
    return
  fi

  # Interactive toggle loop
  while true; do
    echo ""
    for i in "${!ALL_SLUGS[@]}"; do
      local mark="  "
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
        local idx=$((t - 1))
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

# Write the selected tags back to a file.
# Reads from the global SELECTED_ARR set by retag_file (bash 3.2 compatible,
# avoids local -n nameref which requires bash 4.3+).
_write_selected() {
  local file="$1"

  local chosen_labels=()
  for i in "${!ALL_SLUGS[@]}"; do
    [[ "${SELECTED_ARR[$i]}" == "1" ]] && chosen_labels+=("${ALL_LABELS[$i]}")
  done

  if [[ ${#chosen_labels[@]} -eq 0 ]]; then
    warn "  No tags selected — defaulting to Art Styles"
    chosen_labels=("Art Styles")
  fi

  local new_tags_yaml=""
  for label in "${chosen_labels[@]}"; do
    new_tags_yaml="${new_tags_yaml}  - \"${label}\""$'\n'
  done
  # Remove trailing newline for awk compatibility
  new_tags_yaml="${new_tags_yaml%$'\n'}"

  rewrite_tags "$file" "$new_tags_yaml"
  success "  Updated: $(IFS=', '; echo "${chosen_labels[*]}")"
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
```

- [ ] **Step 2: Make the script executable**

```bash
chmod +x scripts/migrate-tags.sh
```

- [ ] **Step 3: Verify extract_prompt_text works on a known file**

```bash
bash -c '
  source scripts/lib.sh
  source scripts/migrate-tags.sh --help 2>/dev/null || true

  extract_prompt_text() {
    local file="$1"
    awk "
      /^### Prompt/ { in_prompt=1; next }
      in_prompt && /^###/ { exit }
      in_prompt && /^---/ { exit }
      in_prompt { sub(/^> /, \"\"); print }
    " "$file" | sed "/^[[:space:]]*$/d"
  }

  extract_prompt_text content/prompts/115-black-and-white-photograph.md
'
```

Expected: the raw prompt text without leading `> `, without surrounding blank lines.

- [ ] **Step 4: Verify rewrite_tags with a dry-run test**

Create a throwaway copy of a prompt and rewrite its tags, then inspect:

```bash
cp content/prompts/115-black-and-white-photograph.md /tmp/test-retag.md

bash -c '
  source scripts/tags.sh

  rewrite_tags() {
    local file="$1" new_tags_yaml="$2" tmp
    tmp=$(mktemp)
    awk -v new_tags="$new_tags_yaml" "
      /^tags:/ { print \"tags:\"; printf \"%s\n\", new_tags; in_tags=1; next }
      in_tags && /^  - / { next }
      in_tags { in_tags=0 }
      { print }
    " "$file" > "$tmp"
    mv "$tmp" "$file"
  }

  rewrite_tags /tmp/test-retag.md "  - \"3D & Miniature\""
  grep -A3 "^tags:" /tmp/test-retag.md
'
```

Expected:
```
tags:
  - "3D & Miniature"
cover: ...
```

- [ ] **Step 5: Run migrate-tags.sh on a single file in --auto mode**

```bash
cp content/prompts/115-black-and-white-photograph.md /tmp/test-retag.md
./scripts/migrate-tags.sh --auto /tmp/test-retag.md
grep -A5 "^tags:" /tmp/test-retag.md
```

Expected: script runs, prints AI result, updates tags. Verify `tags:` block has one or more `  - "Label"` lines and `cover:` follows immediately with no extra blank lines.

- [ ] **Step 6: Commit**

```bash
git add scripts/migrate-tags.sh
git commit -m "feat: add scripts/migrate-tags.sh for single and batch prompt retagging"
```

---

## Task 5: Update `README.md`

**Files:**
- Modify: `README.md`

The spec requires documenting the tag management workflow. This was already partially done during brainstorming; verify the section exists and is accurate now that the scripts are implemented.

- [ ] **Step 1: Verify the tag management section is present and accurate**

```bash
grep -A 30 "## 🏷️ Managing Tags" README.md
```

Expected: section exists with instructions for adding, splitting/renaming, and retagging. Script paths should match the implemented filenames (`scripts/tags.sh`, `scripts/migrate-tags.sh`).

- [ ] **Step 2: If needed, update script references to match implementation**

If anything is outdated (e.g., wrong script flags or paths), edit `README.md` to match. No changes needed if the section is already accurate.

- [ ] **Step 3: Commit (only if changes were made)**

```bash
git add README.md
git commit -m "docs: update README tag management section to match implementation"
```

---

## Task 6: Final Verification

- [ ] **Step 1: Confirm new-prompt.sh still works end-to-end (smoke test)**

```bash
echo "" | timeout 3 ./scripts/new-prompt.sh 2>&1 | head -10 || true
```

Expected: `=== New Prompt ===` header, no errors.

- [ ] **Step 2: Confirm migrate-tags.sh --auto runs on a few files without crashing**

Run on one known file and check output:

```bash
cp content/prompts/113-emerging-from-architectural-blueprint.md /tmp/test113.md
./scripts/migrate-tags.sh --auto /tmp/test113.md
cat /tmp/test113.md | head -15
```

Expected: frontmatter intact with updated `tags:` block. `title:`, `num:`, `cover:`, `source:`, `sourceUrl:`, `date:` all unchanged.

- [ ] **Step 3: Push all commits**

```bash
git push
```

- [ ] **Step 4: Verify GitHub Actions build passes**

Check https://github.com/wm4n/nano-banana-prompt/actions — the deploy workflow should complete successfully.
