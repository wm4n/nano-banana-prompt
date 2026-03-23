# Multi-Prompt Post Support — Design Spec

**Date:** 2026-03-23  
**Status:** Draft  
**Scope:** Single page display only (card/gallery unchanged)

---

## Problem

A post currently supports one image and one prompt. Some content themes (e.g., activity slide decks, multi-step workflows) require multiple prompts and multiple images in a single post, each with its own copy button and optional description.

## Decision Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Where prompts live | Markdown body | Consistent with existing convention |
| Card changes | None | User confirmed single-page-only scope |
| JS changes | None | `querySelectorAll('.prompt-content > blockquote')` already handles multiple blockquotes |
| Template changes | None | No new Hugo template logic needed |
| Implementation | CSS-only + format convention | Minimal risk, fully backward-compatible |

## Key Discovery

The existing JavaScript already supports multiple prompts via `querySelectorAll` — each `blockquote` in `.prompt-content` gets its own Copy button automatically. The existing `h3` CSS rule (`font-size: 13px; text-transform: uppercase; border-bottom: 1px solid var(--border); margin: 32px 0 12px`) already creates visual separation between steps. **Only one CSS addition is needed.**

---

## Markdown Format Convention

### Single-prompt post (unchanged)

```markdown
---
title: "My Prompt"
num: 42
cover: "https://..."
tags:
  - "Art Styles"
source: "@handle"
sourceUrl: "https://x.com/..."
date: 2026-03-23
---

<img src="..." alt="..." />

### Prompt

> Prompt text here...

from [@handle](https://x.com/...)
```

### Multi-prompt post (new)

```markdown
---
title: "Activity Slide Deck"
num: 116
cover: "https://..."      # ← still required for card display; use first step's image
tags:
  - "Infographic & UI"
source: "@handle"
sourceUrl: "https://x.com/..."
date: 2026-03-23
---

### Step 1 — Activity Overview

<img src="https://..." alt="Activity overview example" />

*這個 prompt 用來產生活動說明頁，包含標題、目標與時間。*

> Generate an activity overview slide for a team workshop.
> Include title, objective, and duration...

### Step 2 — Step Instructions

<img src="https://..." alt="Step instructions example" />

*這個 prompt 產生每個步驟的說明，使用圖示和編號清單。*

> Generate step-by-step instruction slides with icons
> and numbered lists for each activity phase...

### Step 3 — Summary & Reflection

<img src="https://..." alt="Summary slide example" />

*產生結語與反思頁，幫助學員整理心得。*

> Generate a closing reflection slide with key takeaways
> and space for participant notes...

from [@handle](https://x.com/...)
```

### Format rules

1. **Each step starts with an `h3` heading** — text is free-form (e.g., `Step N — Title`, `### Prompt`, anything)
2. **Image is optional** — placed directly after the heading if present
3. **Description is optional** — plain paragraph or italic (`*text*`) between image and blockquote
4. **Prompt text is a blockquote** (`> ...`) — JS auto-detects and adds Copy button
5. **`cover` frontmatter is still required** for the card — use the first step's image URL
6. **Single-prompt posts** continue using `### Prompt` heading — fully backward-compatible

---

## CSS Change

**File:** `assets/css/main.css`

**Existing rule** (lines 236–244, no change):
```css
.prompt-content h3 {
  font-size: 13px;
  text-transform: uppercase;
  letter-spacing: 1px;
  color: var(--muted);
  margin: 32px 0 12px;
  padding-bottom: 6px;
  border-bottom: 1px solid var(--border);
}
```

**Addition** — insert immediately after the existing `.prompt-content h3` block:
```css
.prompt-content h3:first-of-type {
  margin-top: 0;
}
```

**Why:** The existing `margin: 32px 0 12px` creates good visual separation between steps, but the `32px` top margin on the *first* heading creates an awkward gap directly below the page header. Setting `margin-top: 0` on the first heading only removes this gap without affecting subsequent step headings.

---

## What Does NOT Change

| Component | Status |
|-----------|--------|
| `layouts/_default/single.html` | No change |
| `layouts/index.html` | No change |
| `layouts/partials/card.html` | No change |
| JS in `single.html` | No change |
| `scripts/new-prompt.sh` | No change (generates single-prompt posts; multi-prompt posts are written manually) |
| `scripts/tags.sh` / `lib.sh` / `migrate-tags.sh` | No change |
| Frontmatter fields | No change (all existing fields keep same meaning) |
| GitHub Actions workflow | No change |

---

## Visual Result

**Before (single-prompt):** Unchanged — `### Prompt` heading + blockquote with Copy button.

**After (multi-prompt):**
```
┌─────────────────────────────┐
│ Prompt #116                 │
│ Activity Slide Deck         │
│ [Infographic & UI]          │
├─────────────────────────────┤
│ STEP 1 — ACTIVITY OVERVIEW  │  ← h3, uppercase, border-bottom
│ ─────────────────────────── │
│ [image]                     │
│ 這個 prompt 用來產生活動...    │  ← p/em (muted color)
│ ┃ Generate an activity...   │  ← .prompt-block (accent border-left)
│   [Copy Prompt]             │
│                             │
│ STEP 2 — STEP INSTRUCTIONS  │  ← h3, 32px top margin creates separation
│ ─────────────────────────── │
│ [image]                     │
│ 這個 prompt 產生每個步驟...    │
│ ┃ Generate step-by-step...  │
│   [Copy Prompt]             │
└─────────────────────────────┘
```

---

## Implementation Checklist

- [ ] Add `.prompt-content h3:first-of-type { margin-top: 0; }` to `assets/css/main.css`
- [ ] Create a sample multi-prompt post in `content/prompts/` to verify display
- [ ] Verify existing single-prompt posts are unaffected
- [ ] Verify Copy button works on each blockquote
- [ ] Commit and push
