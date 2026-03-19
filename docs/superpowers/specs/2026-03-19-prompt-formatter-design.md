# Prompt Formatter & Copy Button — Design Spec

**Date:** 2026-03-19  
**Status:** Draft

---

## Problem

Individual prompt pages (`/prompts/<slug>/`) display prompt content that comes in two formats:

1. **Plain text** — rendered as `<blockquote>` from Markdown `> ...` syntax
2. **JSON** — rendered as `<pre><code class="language-json">` from Markdown fenced code blocks

Currently there is no copy-to-clipboard functionality, and JSON prompts have no syntax highlighting or visual distinction from plain text. Users must manually select and copy text, which is friction for the primary use case (copying prompts into Gemini).

---

## Goal

- Make it trivially easy to copy any prompt with one click
- Visually distinguish prompt blocks from surrounding content
- Apply lightweight JSON formatting/highlighting for JSON prompts
- Require **zero changes to existing content files** (115+ `.md` files)

---

## Approach: Auto-detection JS on `single.html`

JavaScript injected in `layouts/_default/single.html` scans `.content` after DOM load, detects prompt elements by type, wraps them in a styled container, and injects a copy button.

This approach is chosen because:
- No content file migration required
- No global side effects (only runs on single prompt pages)
- Self-contained and easy to debug or remove

---

## Component Design

### `.prompt-block` Container

Both prompt types are wrapped in a `<div class="prompt-block">` that provides:
- Dark themed background (`#1a1a1f`) with a yellow left-border accent (`#f5c518`)
- Rounded corners, comfortable padding
- Relative positioning to anchor the copy button
- Scrollable overflow for long prompts

### Copy Button (`.copy-btn`)

- Positioned top-right of `.prompt-block`
- Label: **"Copy Prompt"**
- On click: copies text to clipboard, changes label to **"✓ Copied!"** for 2 seconds, then resets
- Uses the site's yellow accent color (`#f5c518`) for hover state

### Plain Text Prompts

**Detection:** All `blockquote` elements that are direct children of `.content` (not nested inside other elements). If a `blockquote` is not the prompt itself but a citation, it will still be wrapped — acceptable for the current content corpus where all blockquotes in prompt pages are prompts.

**Behaviour:**
- Wrapped in `.prompt-block.prompt-text`
- Inner text extracted (stripping HTML tags) for clipboard copy
- Displayed in monospace font for readability

### JSON Prompts

**Detection:** `pre > code.language-json` inside `.content`

**Behaviour:**
- Wrapped in `.prompt-block.prompt-json`
- JSON is parsed and re-serialized with 2-space indentation (pretty-print). If `JSON.parse()` throws (malformed JSON), fall back to displaying the raw code block text without syntax highlighting, but still show the copy button.
- Lightweight CSS-class syntax highlighting applied via regex:
  - String values → `.json-string` (green)
  - Numbers → `.json-number` (cyan)
  - Booleans/null → `.json-keyword` (orange)
  - Keys → `.json-key` (yellow)
- Copy button copies the prettified JSON string

---

## File Changes

### `layouts/_default/single.html`

Add an inline `<script>` block before `</body>` that:
1. Queries all `blockquote` elements within `.content` → wraps as plain text prompt blocks
2. Queries all `pre > code.language-json` elements within `.content` → wraps as JSON prompt blocks
3. For each: injects `.copy-btn`, wires `click` event to `navigator.clipboard.writeText()` (async, HTTPS-only — GitHub Pages satisfies this). On clipboard API rejection, silently fail (no visible error, button does not change state).

### `assets/css/main.css`

Add styles for:
- `.prompt-block` — container layout, background, border, padding
- `.prompt-block.prompt-text` — text formatting
- `.prompt-block.prompt-json` — monospace, pre-wrap
- `.copy-btn` — button positioning and default appearance
- `.copy-btn.copied` — green tint when "Copied!" state is active
- `.json-key`, `.json-string`, `.json-number`, `.json-keyword` — syntax highlight colors

---

## Non-Goals

- No external syntax-highlighting library (Prism, highlight.js) — keep zero new dependencies
- No changes to content files
- No changes to homepage or list pages (copy button is single-page only)
- No server-side rendering of highlighted JSON

---

## Success Criteria

- [ ] Every plain text prompt on a single page shows a "Copy Prompt" button that copies the full prompt text
- [ ] Every JSON prompt shows a formatted, syntax-highlighted block with a "Copy Prompt" button
- [ ] "Copied!" feedback appears and resets after 2 seconds
- [ ] No visual regressions on existing single page layout
- [ ] Works on mobile (button accessible, prompt scrollable)
