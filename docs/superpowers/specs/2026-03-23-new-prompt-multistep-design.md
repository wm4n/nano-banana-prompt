# new-prompt.sh Multi-Step Support — Design Spec

**Date:** 2026-03-23
**Status:** Draft
**Scope:** `scripts/new-prompt.sh` only — no template, CSS, or JS changes needed

---

## Problem

`new-prompt.sh` currently supports only a single image and single prompt text. Multi-step posts (multiple images + multiple prompts) must be written manually. The interactive CLI should support creating these posts end-to-end.

## Design Summary

Restructure the interactive flow so that Steps 1 (image) and 4 (prompt text) become a **step loop** — the user adds one step at a time, each with its own title, optional image, and prompt text. After each step they are asked "Add another step?".

Everything else (post title, source URL, tags, preview, commit) is unchanged. Single-step output is functionally equivalent to current output, except the image file gets a `-1` step suffix (e.g., `117-slug-1.jpg` instead of `117-slug.jpg`). This naming change is acceptable for new content; existing prompts are unaffected.

---

## New Interactive Flow

```
=== New Prompt ==========================

Prompt title: <input>
Source URL (Twitter/X link, or press Enter to skip): <input>

=== Step 1 ==============================
Step title [Prompt]: <input>          ← Enter → default "Prompt"
Image (drag & drop, or Enter to skip): <input>
Prompt text (END to finish):
<input lines>
END

✓ Step 1 added.
Add another step? [y/N]: <input>      ← N/Enter → end loop; y → next step

=== Step 2 ==============================
...

--- Tags ---
  Classifying tags with Copilot (claude-haiku-4.5)…
  (AI inference from N prompts combined)
[tag selection UI — unchanged]

=== Preview =============================
[full markdown]

Looks good? [Y/n]: <input>
✓ Image → static/images/prompts/NNN-slug-1.ext
✓ Image → static/images/prompts/NNN-slug-2.ext   ← only if step 2 has image
✓ Markdown → content/prompts/NNN-slug.md
✓ Pushed! Site will rebuild automatically.
✓ Done! Prompt #NNN 'Title' added (N steps).
```

---

## Data Structure per Step

Each step is collected during the loop:

| Field | Source | Required |
|-------|--------|----------|
| `step_title` | User input, default `"Prompt"` | Yes (has default) |
| `step_image_src` | User input file path | No (Enter = skip) |
| `step_prompt_text` | Multi-line until `END` | Yes |

Stored in parallel arrays (bash 3.2 compatible — no associative arrays):
- `STEP_TITLES[]`
- `STEP_IMAGE_SRCS[]` — empty string if skipped
- `STEP_PROMPTS[]`

---

## Image Naming

Images are always numbered with a 1-based step index:

```
{PADDED}-{SLUG}-{N}.{EXT}
```

Examples:
- `116-activity-slide-deck-1.png`
- `116-activity-slide-deck-2.jpg`

**Why always numbered even for single step?** Consistent naming regardless of step count. The `-1` suffix signals "this image belongs to step 1" and avoids ambiguity if a second image is added later manually.

**Note on backward compat:** Existing prompts are unaffected (they have already-committed image URLs in their md files). New single-step prompts will have `-1` suffix — this is a minor naming change acceptable for new content.

---

## Cover Image

`cover:` frontmatter uses the first step that has an image:
- If step 1 has image → `cover:` = step 1 image URL
- If step 1 has no image but step 2 does → `cover:` = step 2 image URL
- If no steps have images → `cover: ""` (empty string)

---

## Tag Inference

All step prompt texts are concatenated with newline separators and passed to `ai_infer_tags()` as a single string:

```bash
ALL_PROMPTS=""
for i in "${!STEP_PROMPTS[@]}"; do
  ALL_PROMPTS="${ALL_PROMPTS}${STEP_PROMPTS[$i]}"$'\n'
done
inferred_str=$(ai_infer_tags "$ALL_PROMPTS")
```

Keyword fallback uses post title (unchanged from current behavior).

---

## Generated Markdown

### Single step (step title = "Prompt", has image)

Output is functionally equivalent to current `new-prompt.sh`. The only difference is the image gets a `-1` step suffix (`117-slug-1.jpg` instead of `117-slug.jpg`), which is acceptable for new content:

```markdown
---
title: "Black & White Photo"
num: 117
tags:
  - "Photo & Cinematic"
cover: "/nano-banana-prompt/images/prompts/117-black-and-white-photo-1.jpg"
source: "@handle"
sourceUrl: "https://x.com/..."
date: 2026-03-23
---

<img width="750" alt="Black & White Photo" src="/nano-banana-prompt/images/prompts/117-black-and-white-photo-1.jpg" />

### Prompt

> A dramatic black-and-white street photo...

from [@handle](https://x.com/...)
```

### Multi-step (two steps with images)

```markdown
---
title: "Activity Slide Deck"
num: 116
tags:
  - "Infographic & UI"
cover: "/nano-banana-prompt/images/prompts/116-activity-slide-deck-1.png"
source: "@handle"
sourceUrl: "https://x.com/..."
date: 2026-03-23
---

### Activity Overview

<img width="750" alt="Activity Slide Deck" src="/nano-banana-prompt/images/prompts/116-activity-slide-deck-1.png" />

> Generate an activity overview slide for a team workshop...

### Step Instructions

<img width="750" alt="Activity Slide Deck" src="/nano-banana-prompt/images/prompts/116-activity-slide-deck-2.png" />

> Generate step-by-step instruction slides with icons...

from [@handle](https://x.com/...)
```

### Multi-step (step with no image)

```markdown
### Step 3 — Summary

> Generate a closing reflection slide...
```

(No `<img>` tag is emitted for steps without an image.)

---

## Implementation: Code Changes

### `new-prompt.sh` structure (new)

```
1.  [unchanged]  REPO_ROOT / colours / source lib.sh / helpers
2.  [unchanged]  Print "=== New Prompt ============================"
3.  [changed]    Prompt title (was same)
4.  [changed]    Source URL (was same)
5.  [NEW]        Step loop:
      - Print "=== Step N =============================="
      - Read step_title (default "Prompt")
      - Read image path (optional)
      - Read prompt text (END sentinel)
      - Append to STEP_TITLES / STEP_IMAGE_SRCS / STEP_PROMPTS
      - Ask "Add another step? [y/N]"
6.  [changed]    Tags: ai_infer_tags on combined prompts
7.  [unchanged]  Tag selection UI
8.  [changed]    Build markdown (loop over steps)
9.  [unchanged]  Preview + confirm
10. [changed]    Write files: copy each step image, write md
11. [changed]    Git add (all step images + md) + commit + push
12. [changed]    Final success message includes step count
```

### Key code patterns

```bash
# Parallel arrays for steps (bash 3.2 compatible — no associative arrays)
STEP_TITLES=()
STEP_IMAGE_SRCS=()
STEP_PROMPTS=()
STEP_IMAGE_URLS=()
STEP_IMAGE_DESTS=()
STEP_NUM=0

# Step loop
while true; do
  STEP_NUM=$((STEP_NUM + 1))
  echo ""
  info "=== Step ${STEP_NUM} =============================="

  # Step title (no `local` — this is top-level scope, not inside a function)
  printf "Step title [Prompt]: "
  IFS= read -r step_title
  step_title="${step_title:-Prompt}"
  STEP_TITLES+=("$step_title")

  # Image (optional)
  step_img_src=""
  while true; do
    printf "Image (drag & drop, or Enter to skip): "
    IFS= read -r step_img_src
    # strip quotes/spaces (same as current image parsing)
    step_img_src="${step_img_src//\\ / }"
    step_img_src="${step_img_src# }"; step_img_src="${step_img_src% }"
    step_img_src="${step_img_src#\'}"; step_img_src="${step_img_src%\'}"
    step_img_src="${step_img_src#\"}"; step_img_src="${step_img_src%\"}"
    if [[ -z "$step_img_src" ]]; then
      break  # skip
    elif [[ -f "$step_img_src" ]]; then
      break  # valid file
    else
      err "File not found: $step_img_src — try again, or press Enter to skip."
    fi
  done
  STEP_IMAGE_SRCS+=("$step_img_src")

  # Prompt text
  info "--- Prompt text ---"
  echo "(Type or paste the prompt. Enter END on its own line to finish.)"
  step_prompt=""
  while IFS= read -r line; do
    [[ "$line" == "END" ]] && break
    if [[ -z "$step_prompt" ]]; then
      step_prompt="$line"
    else
      step_prompt="${step_prompt}"$'\n'"${line}"
    fi
  done
  STEP_PROMPTS+=("$step_prompt")

  success "Step ${STEP_NUM} added."

  printf "Add another step? [y/N]: "
  IFS= read -r more
  [[ "$more" != "y" && "$more" != "Y" ]] && break
done
```

```bash
# Image naming: NNN-slug-N.ext — using indexed assignment to keep aligned with STEP_TITLES
for i in "${!STEP_IMAGE_SRCS[@]}"; do
  src="${STEP_IMAGE_SRCS[$i]}"
  if [[ -z "$src" ]]; then
    STEP_IMAGE_URLS[$i]=""        # keep array aligned — no +=, always index by i
    STEP_IMAGE_DESTS[$i]=""
    continue
  fi
  ext=$(lowercase_ext "${src##*.}")
  step_idx=$((i + 1))
  STEP_IMAGE_URLS[$i]="${BASE_URL}/images/prompts/${FILENAME}-${step_idx}.${ext}"
  STEP_IMAGE_DESTS[$i]="$IMAGES_DIR/${FILENAME}-${step_idx}.${ext}"
done
```

```bash
# Cover = first step with an image
COVER_URL=""
for url in "${STEP_IMAGE_URLS[@]:-}"; do
  if [[ -n "$url" ]]; then
    COVER_URL="$url"
    break
  fi
done
```

```bash
# Markdown generation (step loop)
# Multi-line prompts: prefix each line with "> " to produce valid blockquote
CONTENT_BODY=""
for i in "${!STEP_TITLES[@]}"; do
  step_title="${STEP_TITLES[$i]}"
  img_url="${STEP_IMAGE_URLS[$i]:-}"
  prompt="${STEP_PROMPTS[$i]}"

  CONTENT_BODY="${CONTENT_BODY}"$'\n'"### ${step_title}"$'\n'
  if [[ -n "$img_url" ]]; then
    CONTENT_BODY="${CONTENT_BODY}"$'\n'"<img width=\"750\" alt=\"${TITLE}\" src=\"${img_url}\" />"$'\n'
  fi
  # Prefix every line with "> " to form a valid markdown blockquote
  formatted_prompt=""
  while IFS= read -r pline; do
    formatted_prompt="${formatted_prompt}> ${pline}"$'\n'
  done <<< "$prompt"
  CONTENT_BODY="${CONTENT_BODY}"$'\n'"${formatted_prompt}"
done
```

---

## What Does NOT Change

| Component | Status |
|-----------|--------|
| `layouts/_default/single.html` | No change |
| `assets/css/main.css` | No change (updated in previous session) |
| JS copy-button logic | No change |
| `scripts/lib.sh` / `tags.sh` | No change |
| `scripts/migrate-tags.sh` | No change |
| GitHub Actions workflow | No change |
| Frontmatter fields | No new fields; all existing fields keep same meaning |

---

## Edge Cases

| Case | Behavior |
|------|----------|
| Single step, Enter for title → default "Prompt", has image | Output functionally equivalent to current script (image gets `-1` suffix, e.g., `117-slug-1.jpg`) |
| Single step, no image | `cover: ""`, no `<img>` tag in body |
| Multiple steps, all without images | `cover: ""`, no `<img>` tags |
| Prompt text is multi-line | Each line collected until END; each line prefixed with `> ` in output |
| Step image file not found | Error + re-prompt; user can then press Enter to skip |

---

## Implementation Checklist

- [ ] Remove Step 1 (image input) from top-level flow; merge into step loop
- [ ] Remove Step 4 (prompt text) from top-level flow; merge into step loop
- [ ] Add step loop with `STEP_TITLES`, `STEP_IMAGE_SRCS`, `STEP_PROMPTS` arrays
- [ ] Build `STEP_IMAGE_URLS` and `STEP_IMAGE_DESTS` during/after loop
- [ ] Compute `COVER_URL` from first step with image
- [ ] Update tag inference to concatenate all step prompts
- [ ] Rewrite markdown generator to loop over steps
- [ ] Update file-write section: copy each step image; git-add all step images using repo-relative paths:
  ```bash
  for i in "${!STEP_IMAGE_DESTS[@]}"; do
    dest="${STEP_IMAGE_DESTS[$i]}"
    [[ -z "$dest" ]] && continue
    cp "${STEP_IMAGE_SRCS[$i]}" "$dest"
    success "Image → static/images/prompts/${FILENAME}-$((i+1)).ext"
    git add "${dest#$REPO_ROOT/}"
  done
  git add "$MD_DEST"
  ```
- [ ] Update final success message to include step count
- [ ] Smoke test: single-step output has `-1` image suffix and all other fields match current format
- [ ] Smoke test: multi-step (2 steps, mixed image/no-image) — verify `<img>` tags align correctly with steps
- [ ] Update README interactive flow description
