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
1. Image path    → validate file, copy to static/images/prompts/
2. Title         → derive slug, auto-calculate next num
3. Tags          → keyword-infer from title, show numbered list, user confirms/edits
4. Source URL    → extract @handle via regex
5. Prompt text   → multiline input, type END on its own line to finish
6. Preview       → show generated .md frontmatter, user confirms
7. Commit        → git add + git commit + git push
```

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

---

## Tags Inference

Rules ported from `scripts/parse_readme.py` into a bash associative array. The title is lowercased and checked against keyword lists for each tag category:

| Tag | Sample Keywords |
|-----|----------------|
| Art Styles | watercolor, ink, sketch, botanical, embroidery, crayon |
| Character & Portrait | character, caricature, portrait, sticker, cartoon, pixar |
| City & Architecture | city, urban, isometric, architectural |
| 3D & Miniature | miniature, diorama, hologram, glass marble, chibi |
| Infographic & UI | hud, infographic, report, ui/ux, boarding pass |
| Effects & Composite | composite, double exposure, holographic |
| Photo & Cinematic | photo, cinematic, motion blur |
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

---

## Out of Scope

- Fetching prompt data automatically from a tweet URL (requires API or scraping)
- Mobile / browser-based UI
- Batch import from Twitter bookmarks
- Tag editing UI beyond numbered toggle list

---

## Files Changed

| Path | Action |
|------|--------|
| `scripts/new-prompt.sh` | Create (new script) |
| `static/images/prompts/` | Create directory |
| Existing `.md` files | No change |
| Hugo templates | No change |
