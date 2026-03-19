# 🍌 Nano Banana Prompt Collection

A curated gallery of **115+ AI image generation prompts** for [Nano Banana](https://chatgpt.com/g/g-6833NanoBanana) — organized by category, searchable, with example images.

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

1. Add a new `.md` file in `content/prompts/` following the format below
2. Push to `main` — GitHub Actions automatically rebuilds the site

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

## 🛠️ Local Development

```bash
brew install hugo
hugo server
# open http://localhost:1313/nano-banana-prompt/
```
