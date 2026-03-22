# 🍌 Nano Banana Prompt Collection

A curated gallery of **115+ AI image generation prompts** for [Nano Banana](https://gemini.google/overview/image-generation/) — organized by category, searchable, with example images.

## 🌐 Browse the Gallery

**→ [wm4n.github.io/nano-banana-prompt](https://wm4n.github.io/nano-banana-prompt/)**

Browse prompts by category:

| Category | Count |
|---|---|
| [🎨 Art Styles](https://wm4n.github.io/nano-banana-prompt/tags/art-styles/) | 22 |
| [👤 Character & Portrait](https://wm4n.github.io/nano-banana-prompt/tags/character-portrait/) | 16 |
| [🏙️ City & Architecture](https://wm4n.github.io/nano-banana-prompt/tags/city-architecture/) | 11 |
| [🧸 3D & Miniature](https://wm4n.github.io/nano-banana-prompt/tags/3d-miniature/) | 13 |
| [📊 Infographic & UI](https://wm4n.github.io/nano-banana-prompt/tags/infographic-ui/) | 12 |
| [✨ Effects & Composite](https://wm4n.github.io/nano-banana-prompt/tags/effects-composite/) | 9 |
| [📸 Photo & Cinematic](https://wm4n.github.io/nano-banana-prompt/tags/photo-cinematic/) | 8 |
| [🍕 Food & Commercial](https://wm4n.github.io/nano-banana-prompt/tags/food-commercial/) | 6 |
| [🌿 Poster & Nature](https://wm4n.github.io/nano-banana-prompt/tags/poster-nature/) | 10 |
| [🎯 Icons & Stickers](https://wm4n.github.io/nano-banana-prompt/tags/icons-stickers/) | 4 |

## 🆕 Recently Added

- **#113** [Emerging from Architectural Blueprint](https://wm4n.github.io/nano-banana-prompt/prompts/113-emerging-from-architectural-blueprint/) — `City & Architecture` `3D & Miniature`
- **#112** [Jap Ink Painting](https://wm4n.github.io/nano-banana-prompt/prompts/112-jap-ink-painting/) — `Art Styles`
- **#111** [Cartoon Character Sticker](https://wm4n.github.io/nano-banana-prompt/prompts/111-cartoon-character-sticker/) — `Character & Portrait`
- **#110** [Botanical Diagram](https://wm4n.github.io/nano-banana-prompt/prompts/110-botanical-diagram/) — `Art Styles`
- **#109** [Taking Photo Under Cherry Blossom](https://wm4n.github.io/nano-banana-prompt/prompts/109-taking-photo-under-cherry-blossom/) — `Photo & Cinematic`

## ➕ Adding New Prompts

Use the interactive CLI script (recommended):

```bash
./scripts/new-prompt.sh
```

Or manually add a new `.md` file in `content/prompts/` following the format below, then push to `main` — GitHub Actions automatically rebuilds the site.

```yaml
---
title: "Your Prompt Title"
num: 114
tags:
  - "Art Styles"       # pick from existing tags
cover: "https://github.com/user-attachments/assets/..."
source: "@handle"
sourceUrl: "https://x.com/..."
date: 2026-03-19
---

<img src="..." alt="..." />

### Prompt

> Your prompt text here...

from [@handle](https://x.com/...)
```

## 🏷️ Managing Tags

Tag definitions are centrally managed in `scripts/tags.sh`.

### Adding a new tag

1. Edit `scripts/tags.sh` — add one line to `TAG_DEFS` with format `"slug|Human Label|kw1|kw2|..."`
2. (Optional) Run `./scripts/migrate-tags.sh` to retag existing prompts with the new taxonomy

### Splitting or renaming a tag

1. Edit `scripts/tags.sh` — update or replace the relevant `TAG_DEFS` entry
2. Run `./scripts/migrate-tags.sh` to let AI reclassify affected prompts
3. Hugo automatically removes tag pages that no prompts reference

### Retagging prompts

```bash
# Retag a single prompt
./scripts/migrate-tags.sh content/prompts/115-black-and-white-photograph.md

# Retag all prompts (interactive, confirms each file)
./scripts/migrate-tags.sh

# Retag all prompts non-interactively (auto-accept AI suggestions)
./scripts/migrate-tags.sh --auto
```

## 🛠️ Local Development

```bash
brew install hugo
hugo server
# open http://localhost:1313/nano-banana-prompt/
```
