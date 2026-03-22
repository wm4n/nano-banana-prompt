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

### 2. Updates to `new-prompt.sh`

Two changes:

1. **Remove inline `TAG_DEFS`** — replace with `source "$(dirname "$0")/tags.sh"`
2. **Fix `ai_infer_tags()`** — build the slug list dynamically from `ALL_SLUGS` instead of hardcoding it:

```bash
# Before (hardcoded):
local tag_list="city-architecture, 3d-miniature, art-styles, ..."

# After (dynamic):
local tag_list
tag_list=$(IFS=', '; echo "${ALL_SLUGS[*]}")
```

This ensures the AI always receives the current tag list without manual updates.

### 3. `scripts/migrate-tags.sh` — Retag Tool

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

1. Extract prompt text from `### Prompt` block in the `.md` file
2. Run `ai_infer_tags()` with the current `TAG_DEFS` (sourced from `tags.sh`)
3. Display current tags vs AI-suggested tags
4. Prompt user to accept, toggle, or skip (same toggle UI as `new-prompt.sh`)
5. Rewrite only the `tags:` block in frontmatter, leaving all other content untouched

**Example output:**

```
[115] Black and White Photograph
  Current tags : Art Styles, Photo & Cinematic, Effects & Composite
  AI suggests  : Art Styles, Photo & Cinematic

  1) Art Styles           ✓
  2) Photo & Cinematic    ✓
  3) Effects & Composite  ✓
  ...

Toggle tag number(s), or press Enter to accept:
```

#### Frontmatter Rewriting

The script rewrites only the `tags:` block between `tags:` and the next frontmatter key. It does **not** regenerate cover, source, sourceUrl, or date. All other content (prompt body, images) is untouched.

#### Extensibility

The "fields to update" list is confined to a `RETAG_FIELDS` variable at the top of the script. Future AI-analyzed fields (e.g., `style`, `subject`) can be added without restructuring the script.

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
| `scripts/tags.sh` | New file — single source of truth |
| `scripts/new-prompt.sh` | Source `tags.sh`, fix dynamic slug list in `ai_infer_tags()` |
| `scripts/migrate-tags.sh` | New file — retag tool |
| `README.md` | Add tag management workflow section |

## Out-of-Scope Reminder

`scripts/parse_readme.py` has its own `TAG_RULES` / `TAG_LABELS` in Python. That file is not a shell script and cannot source `tags.sh`. If `parse_readme.py` is still actively used, its tag list should be kept in sync manually, or it should be refactored separately to read from a shared JSON/YAML format.
