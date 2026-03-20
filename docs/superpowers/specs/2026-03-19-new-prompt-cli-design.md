# Design: New Prompt CLI Script

**Date:** 2026-03-19  
**Status:** Approved  
**Topic:** Streamlining the workflow for adding new prompts to the Nano Banana gallery

---

## Problem

Adding a new prompt currently requires 4–5 manual steps:
1. Upload image to GitHub Issues to obtain a CDN URL
2. Manually create a `.md` file in `content/prompts/`
3. Fill in frontmatter (title, num, tags, cover, source, sourceUrl, date)
4. Write the body (img tag + prompt blockquote + attribution)
5. `git add`, `git commit`, `git push`

The image upload step is especially awkward — it depends on the GitHub Issues CDN, which may break if the issue is deleted.

---

## Solution

A single interactive shell script `scripts/new-prompt.sh` that guides the user through all inputs and handles the rest automatically. Images are stored in `static/images/prompts/` inside the repo, eliminating the dependency on GitHub Issues CDN.

---

## Script: `scripts/new-prompt.sh`

### Usage

```bash
cd /path/to/nano-banana-prompt
./scripts/new-prompt.sh
```

### Interactive Flow

```
1. Image path    → validate file exists (retry on failure), copy to static/images/prompts/
2. Title         → derive slug, auto-calculate next num
3. Tags          → keyword-infer from title, show numbered list, user confirms/edits
4. Source URL    → extract @handle via regex
5. Prompt text   → multiline input, type END on its own line to finish
6. Preview       → show generated .md frontmatter + body, user confirms
7. Commit        → git add + git commit + git push (print warning if push fails)
```

**Image validation:** if the given path does not exist or is not a regular file, print an error and re-prompt. Do not proceed until a valid file is provided.

---

## File Naming & Storage

### Image

- Destination: `static/images/prompts/{num}-{slug}.{ext}`
- Example: `static/images/prompts/115-kawaii-robot.jpg`
- Referenced in `.md` as:
  - `cover:` → `/nano-banana-prompt/images/prompts/115-kawaii-robot.jpg`
  - `<img src=...>` → same path

### Markdown

- Destination: `content/prompts/{num}-{slug}.md`
- Example: `content/prompts/115-kawaii-robot.md`

---

## Auto-Numbering

The script scans all `content/prompts/*.md` files, extracts the `num:` frontmatter field, takes the maximum value, and adds 1. This is the canonical next number.

## Slug Generation

The title is converted to a slug using these rules (applied in order):
1. Lowercase all characters
2. Replace `&` with `and`
3. Remove all characters that are not alphanumeric, space, or hyphen
4. Replace one or more spaces with a single hyphen
5. Strip leading/trailing hyphens

Example: `"Icons & Stickers 3D"` → `"icons-and-stickers-3d"`

---

## Tags Inference

Rules ported from `scripts/parse_readme.py` (`TAG_RULES` list) into a bash associative array. The title is lowercased and checked against keyword lists for each tag category. **The complete and authoritative keyword list is the `TAG_RULES` variable in `scripts/parse_readme.py`** — the implementation must replicate it exactly, not the abbreviated table below (shown for orientation only):

| Tag | Sample Keywords (partial) |
|-----|--------------------------|
| Art Styles | watercolor, ink painting, sketch, botanical, embroidery, crayon, step by step drawing |
| Character & Portrait | character, caricature, portrait, sticker, cartoon, pixar, idol, soft toy |
| City & Architecture | city, urban, isometric, architectural blueprint, souvenir magnet |
| 3D & Miniature | miniature, diorama, hologram, glass marble, chibi, tilt 3d, cube diorama |
| Infographic & UI | hud, infographic, report, ui/ux, boarding pass, profile card |
| Effects & Composite | neon effect, blending, double exposure, firework, season blend |
| Photo & Cinematic | photo, cinematic, motion blur, cherry blossom, lat & lon |
| Food & Commercial | food, product, commercial |
| Poster & Nature | poster, nature, landscape |
| Icons & Stickers | icon, sticker, emoji |

Display format:
```
Inferred tags:
  [1] Art Styles        ✓
  [2] Character & Portrait  ✓
  [3] City & Architecture
Enter numbers to toggle (or press Enter to accept):
```

---

## Source Parsing

Given a URL like `https://x.com/azed_ai/status/2034584692998201813?s=20`:
- Extract username: `azed_ai` → `source: "@azed_ai"`
- Store full URL: `sourceUrl: "https://x.com/azed_ai/status/..."`

Regex: extract the path segment after `x.com/` or `twitter.com/`.

---

## Prompt Text Input

```
Enter prompt text (type END on its own line to finish):
> A flat design illustration of a [subject]...
> END
```

Stored as a blockquote in the markdown body.

---

## Generated `.md` Template

```markdown
---
title: "{Title}"
num: {N}
tags:
  - "{Tag1}"
  - "{Tag2}"
cover: "/nano-banana-prompt/images/prompts/{num}-{slug}.{ext}"
source: "@{handle}"
sourceUrl: "{url}"
date: {YYYY-MM-DD}
---

<img width="750" alt="{Title}" src="/nano-banana-prompt/images/prompts/{num}-{slug}.{ext}" />


### Prompt

> {prompt text}

from [@{handle}]({url})
```

---

## Git Commit

After confirmation:
```bash
git add static/images/prompts/{num}-{slug}.{ext}
git add content/prompts/{num}-{slug}.md
git commit -m "feat: add prompt #{num} - {Title}"
git push
```

If `git push` fails, the script prints the error output and displays:
```
⚠ Push failed. Files are committed locally. Run `git push` manually when ready.
```
The script exits with a non-zero code but does NOT roll back the commit or file copies.

---

## Notes

- **`source` format:** always stored with `@` prefix, e.g. `source: "@azed_ai"`. This normalises inconsistency in older files.
- **`cover` path change:** new prompts use local paths (`/nano-banana-prompt/images/prompts/...`) instead of GitHub CDN URLs. Existing prompts are unchanged — the mixed state is intentional and both formats work fine in Hugo.
- **`<img>` height attribute:** omitted in the generated template. Hugo/browsers infer height from the image; omitting it is consistent with most recent prompt files.

## Out of Scope

- Fetching prompt data automatically from a tweet URL (requires API or scraping)
- Mobile / browser-based UI
- Batch import from Twitter bookmarks
- Tag editing UI beyond numbered toggle list
- Multiple images per prompt (single image only)

---

## Files Changed

| Path | Action |
|------|--------|
| `scripts/new-prompt.sh` | Create (new script) |
| `static/images/prompts/` | Create directory |
| Existing `.md` files | No change |
| Hugo templates | No change |
