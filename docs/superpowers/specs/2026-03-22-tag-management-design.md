# Tag Management Design

**Date:** 2026-03-22  
**Status:** Approved

## Problem

Tag definitions are currently scattered across three locations:

1. `scripts/new-prompt.sh` — `TAG_DEFS` array (slug + label + keywords)
2. `scripts/new-prompt.sh` — `ai_infer_tags()` hardcoded slug list
3. `scripts/parse_readme.py` — `TAG_RULES` + `TAG_LABELS`

Adding a new tag or renaming an existing one requires editing multiple files. There is also no mechanism to retag existing prompts after taxonomy changes.

## Goals

- Single source of truth for tag definitions
- Ability to retag individual or all prompts after taxonomy changes
- Shell scripts remain dependency-free (no `yq`, `jq`)

## Out of Scope

- Automatic retagging on taxonomy change
- Updating `scripts/parse_readme.py` (Python codebase, separate concern)

---

## Design

### 1. `scripts/tags.sh` — Centralized Tag Definitions

A sourced bash file that replaces all inline tag arrays in shell scripts.

**Format** (identical to current `TAG_DEFS` in `new-prompt.sh`):

```bash
# scripts/tags.sh
# Each entry: "slug|Human Label|kw1|kw2|..."
TAG_DEFS=(
  "city-architecture|City & Architecture|city|urban|isometric|..."
  "3d-miniature|3D & Miniature|miniature|diorama|..."
  "art-styles|Art Styles|watercolor|ink painting|..."
  "character-portrait|Character & Portrait|character|caricature|..."
  "photo-cinematic|Photo & Cinematic|photo|cinematic|..."
  "infographic-ui|Infographic & UI|hud|infographic|..."
  "effects-composite|Effects & Composite|neon effect|blending|..."
  "food-commercial|Food & Commercial|food|cuisine|..."
  "poster-nature|Poster & Nature|poster|magazine cover|..."
  "icons-stickers|Icons & Stickers|icon generation|themed icon|..."
)
```

Any script that needs tag data adds at the top:

```bash
source "$(dirname "$0")/tags.sh"
```

### 2. `scripts/lib.sh` — Shared Tag Functions

`ai_infer_tags()` and `keyword_infer_tags()` are currently defined in `new-prompt.sh`. Both `new-prompt.sh` and the new `migrate-tags.sh` need them. Rather than duplicating or sourcing the full interactive script, they are extracted to a shared library.

```bash
# scripts/lib.sh — sourced by new-prompt.sh and migrate-tags.sh
source "$(dirname "$0")/tags.sh"   # loads TAG_DEFS → ALL_SLUGS, ALL_LABELS, ALL_KEYWORDS

ai_infer_tags()       { ... }  # calls Copilot CLI; returns space-separated slugs
keyword_infer_tags()  { ... }  # keyword fallback; returns space-separated slugs
```

Any script that needs tag inference adds:

```bash
source "$(dirname "$0")/lib.sh"
```

### 3. Updates to `new-prompt.sh`

Two changes:

1. **Remove inline `TAG_DEFS` and tag functions** — replace with `source "$(dirname "$0")/lib.sh"` (which in turn sources `tags.sh`)
2. **Fix `ai_infer_tags()` slug list in `lib.sh`** — build dynamically from `ALL_SLUGS` instead of hardcoding:

```bash
# Before (hardcoded in new-prompt.sh):
local tag_list="city-architecture, 3d-miniature, art-styles, ..."

# After (dynamic in lib.sh):
local tag_list
tag_list=$(IFS=', '; echo "${ALL_SLUGS[*]}")
```

This ensures the AI always receives the current tag list without manual updates.

### 4. `scripts/migrate-tags.sh` — Retag Tool

A standalone script for retagging existing prompts after taxonomy changes.

#### Modes

```bash
# Retag a single prompt (interactive)
./scripts/migrate-tags.sh content/prompts/115-black-and-white-photograph.md

# Retag all prompts (interactive, confirms each file)
./scripts/migrate-tags.sh

# Retag all prompts non-interactively (auto-accept AI suggestions)
./scripts/migrate-tags.sh --auto
```

#### Per-File Flow

1. Extract prompt text from `### Prompt` block — read lines after `### Prompt`, strip `> ` blockquote prefix via `sed 's/^> //'`, stop at the next `^###`, `^---`, or EOF
2. Call `ai_infer_tags()` (from `lib.sh`) with the extracted prompt text
3. Map returned slugs to Human Labels using `ALL_LABELS[]` before displaying
4. Display current tags vs AI-suggested tags
5. Prompt user to accept, toggle, or skip:
   - **Enter** — accept displayed selection and rewrite `tags:` in frontmatter
   - **Number(s)** — toggle tag on/off (same UI as `new-prompt.sh`)
   - **`s` + Enter** — skip this file; leave frontmatter unchanged
6. Convert final selected slugs to Human Labels via `ALL_LABELS[]`, then rewrite `tags:` block

**Example output:**

```
[115] Black and White Photograph
  Current tags : Art Styles, Photo & Cinematic, Effects & Composite
  AI suggests  : Art Styles, Photo & Cinematic

  1) Art Styles           ✓
  2) Photo & Cinematic    ✓
  3) Effects & Composite  ✓
  ...

Toggle tag number(s), s to skip, or press Enter to accept:
```

#### AI Failure Handling

`keyword_infer_tags()` always returns at least one slug (defaults to `art-styles` when no keyword matches), so there is no "both fail" scenario.

If `ai_infer_tags()` fails (non-zero exit or empty output):

| Mode | Behavior |
|---|---|
| Interactive | Fall back to `keyword_infer_tags()`, display result, prompt user normally |
| `--auto` | Fall back to `keyword_infer_tags()`, auto-accept result |

`keyword_infer_tags()` in `lib.sh` retains the existing `art-styles` no-match fallback from `new-prompt.sh`. This behavior is intentional and unchanged.

#### Frontmatter Rewriting

Before writing, convert each selected slug to its Human Label using `ALL_LABELS[]`. Then use `awk` to rewrite only the `tags:` block:

- Enter replacement mode on the line matching `^tags:`
- While in replacement mode, skip lines matching `^  - ` (existing YAML list items)
- Exit replacement mode (and emit new `  - "Label"` lines) when a line matches `^[a-z]` (next frontmatter key) or `^---` (end of frontmatter)
- All other lines are passed through unchanged

This requires only `awk`, consistent with the no-new-dependencies constraint.

#### Extensibility

For future AI-analyzed fields beyond `tags`, add a handler block in `migrate-tags.sh` following the same pattern: infer → confirm → convert to frontmatter format → rewrite with `awk`. No shared variable is needed — each field is a self-contained block.

---

## Tag Management Workflow

### Adding a New Tag

1. Edit `scripts/tags.sh` — add one line to `TAG_DEFS`
2. (Optional) Run `./scripts/migrate-tags.sh` to retag existing prompts with the new taxonomy

### Renaming a Tag

1. Edit `scripts/tags.sh` — update the slug and/or label
2. Run `./scripts/migrate-tags.sh` — AI uses new tag names; old tag disappears from any prompt it no longer matches
3. Hugo automatically removes the old tag page once no prompts reference it

### Splitting a Tag

1. Edit `scripts/tags.sh` — remove old tag, add two new tags
2. Run `./scripts/migrate-tags.sh` — AI reclassifies all affected prompts

### Retagging a Specific Prompt

```bash
./scripts/migrate-tags.sh content/prompts/115-black-and-white-photograph.md
```

---

## Files Changed

| File | Change |
|---|---|
| `scripts/tags.sh` | New file — single source of truth for TAG_DEFS |
| `scripts/lib.sh` | New file — shared `ai_infer_tags()` and `keyword_infer_tags()` functions |
| `scripts/new-prompt.sh` | Replace inline TAG_DEFS + functions with `source lib.sh` |
| `scripts/migrate-tags.sh` | New file — retag tool |
| `README.md` | Add tag management workflow section |

## Out-of-Scope Reminder

`scripts/parse_readme.py` has its own `TAG_RULES` / `TAG_LABELS` in Python. That file is not a shell script and cannot source `tags.sh`. If `parse_readme.py` is still actively used, its tag list should be kept in sync manually, or it should be refactored separately to read from a shared JSON/YAML format.
