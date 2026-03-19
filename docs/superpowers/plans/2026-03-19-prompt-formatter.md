# Prompt Formatter & Copy Button Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Copy Prompt" button and visual formatting to prompt blocks on individual prompt pages, with JSON syntax highlighting — requiring zero changes to existing content files.

**Architecture:** JavaScript in `single.html` auto-detects `<blockquote>` (plain-text prompts) and `<pre><code class="language-json">` (JSON prompts) inside `.prompt-content`, wraps each in a `.prompt-block` div, and injects a copy button. CSS in `main.css` styles the wrapper and button. A lightweight inline regex highlighter handles JSON colorization with no external dependencies.

**Tech Stack:** Hugo (static site), vanilla JS (inline), CSS custom properties (dark theme already in place via CSS vars)

---

## File Map

| File | Change |
|------|--------|
| `assets/css/main.css` | Add `.prompt-block`, `.copy-btn`, `.copy-btn.copied`, JSON highlight span classes |
| `layouts/_default/single.html` | Add `<script>` block at bottom of `{{ define "main" }}` for auto-detect, wrap, and copy logic |

No other files are modified. No new files are created.

---

### Task 1: Add CSS — Prompt Block Container & Copy Button

**Files:**
- Modify: `assets/css/main.css` (append after `/* ── Prompt Navigation ── */` section)

These styles provide the visual wrapper around both prompt types and the copy button positioned in the top-right corner.

- [ ] **Step 1: Open `assets/css/main.css` and append the following block** at the end of the file, just before the `/* ── Responsive ── */` media queries:

```css
/* ── Prompt Block (copy-enabled wrapper) ── */
.prompt-block {
  position: relative;
  margin: 16px 0;
  background: #1a1a1f;
  border-left: 3px solid var(--accent);
  border-radius: 0 8px 8px 0;
  padding: 16px 20px;
  overflow-x: auto;
}
.prompt-block > blockquote,
.prompt-block > pre {
  margin: 0;
  background: none;
  border: none;
  border-radius: 0;
  padding: 0;
}
.prompt-block.prompt-text {
  font-size: 14px;
  line-height: 1.8;
  color: #ccc;
  font-family: 'SF Mono', 'Fira Code', monospace;
}
.prompt-block.prompt-json {
  font-family: 'SF Mono', 'Fira Code', monospace;
  font-size: 13px;
  line-height: 1.6;
  white-space: pre-wrap;
}
.copy-btn {
  position: absolute;
  top: 10px;
  right: 10px;
  padding: 4px 11px;
  background: var(--bg3);
  border: 1px solid var(--border);
  border-radius: 6px;
  color: var(--muted);
  font-size: 11px;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition);
  letter-spacing: .3px;
  z-index: 1;
  line-height: 1.6;
  font-family: inherit;
}
.copy-btn:hover {
  border-color: var(--accent);
  color: var(--accent);
}
.copy-btn.copied {
  border-color: #4caf50;
  color: #4caf50;
}

/* ── JSON Syntax Highlight ── */
.json-key     { color: var(--accent); }
.json-string  { color: #7ec8a0; }
.json-number  { color: #79c0ff; }
.json-keyword { color: #f0883e; }
```

- [ ] **Step 2: Verify build succeeds**

```bash
cd /Users/william.chao/workspace/web/nano-banana-prompt && hugo --minify 2>&1 | tail -5
```

Expected output: `Total in ...ms` with no errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/william.chao/workspace/web/nano-banana-prompt
git add assets/css/main.css
git commit -m "style: add prompt-block wrapper and copy button styles"
```

---

### Task 2: Add JS — Plain-Text Prompt Detection & Copy

**Files:**
- Modify: `layouts/_default/single.html` (add `<script>` block before closing `{{ end }}`)

Wrap every `<blockquote>` inside `.prompt-content` in a `.prompt-block` div and attach a working copy button.

> **Note:** The actual wrapper class in `single.html` is `.prompt-content` (not `.content` as loosely referenced in the spec). This is confirmed by inspecting `layouts/_default/single.html` which renders `<div class="prompt-content">{{ .Content }}</div>`.

- [ ] **Step 1: Open `layouts/_default/single.html` and append the following `<script>` block** immediately before the final `{{ end }}` line at the bottom of the file:

```html
<script>
(function () {
  function makeCopyBtn(getText) {
    const btn = document.createElement('button');
    btn.className = 'copy-btn';
    btn.textContent = 'Copy Prompt';
    btn.addEventListener('click', () => {
      navigator.clipboard.writeText(getText()).then(() => {
        btn.textContent = '✓ Copied!';
        btn.classList.add('copied');
        setTimeout(() => {
          btn.textContent = 'Copy Prompt';
          btn.classList.remove('copied');
        }, 2000);
      }).catch(() => {});
    });
    return btn;
  }

  function wrapInBlock(el) {
    const wrapper = document.createElement('div');
    wrapper.className = 'prompt-block';
    el.parentNode.insertBefore(wrapper, el);
    wrapper.appendChild(el);
    return wrapper;
  }

  // Plain-text prompts: blockquotes
  document.querySelectorAll('.prompt-content > blockquote').forEach(bq => {
    const wrapper = wrapInBlock(bq);
    wrapper.classList.add('prompt-text');
    const text = bq.innerText.trim();
    wrapper.appendChild(makeCopyBtn(() => text));
  });
})();
</script>
```

- [ ] **Step 2: Start the Hugo dev server**

```bash
cd /Users/william.chao/workspace/web/nano-banana-prompt && hugo server --port 1313
```

- [ ] **Step 3: Open a plain-text prompt page in your browser**

Navigate to `http://localhost:1313/nano-banana-prompt/prompts/001-isometric-city-scene/`

Verify:
- A "Copy Prompt" button appears in the top-right of the blockquote
- Clicking it copies the prompt text to clipboard (paste into a text editor to confirm)
- Button shows "✓ Copied!" for 2 seconds then resets

- [ ] **Step 4: Stop the dev server** (Ctrl+C)

- [ ] **Step 5: Commit**

```bash
cd /Users/william.chao/workspace/web/nano-banana-prompt
git add layouts/_default/single.html
git commit -m "feat: add copy button to plain-text prompt blocks"
```

---

### Task 3: Add JS — JSON Prompt Detection, Syntax Highlighting & Copy

**Files:**
- Modify: `layouts/_default/single.html` (extend the `<script>` block added in Task 2)

Inside the same IIFE in `single.html`, add the JSON handling logic after the plain-text block.

- [ ] **Step 1: Replace the entire `<script>` block** added in Task 2 with the complete final version below (includes both plain-text and JSON handling):

```html
<script>
(function () {
  function makeCopyBtn(getText) {
    const btn = document.createElement('button');
    btn.className = 'copy-btn';
    btn.textContent = 'Copy Prompt';
    btn.addEventListener('click', () => {
      navigator.clipboard.writeText(getText()).then(() => {
        btn.textContent = '✓ Copied!';
        btn.classList.add('copied');
        setTimeout(() => {
          btn.textContent = 'Copy Prompt';
          btn.classList.remove('copied');
        }, 2000);
      }).catch(() => {});
    });
    return btn;
  }

  function wrapInBlock(el) {
    const wrapper = document.createElement('div');
    wrapper.className = 'prompt-block';
    el.parentNode.insertBefore(wrapper, el);
    wrapper.appendChild(el);
    return wrapper;
  }

  // Plain-text prompts: blockquotes
  document.querySelectorAll('.prompt-content > blockquote').forEach(bq => {
    const wrapper = wrapInBlock(bq);
    wrapper.classList.add('prompt-text');
    const text = bq.innerText.trim();
    wrapper.appendChild(makeCopyBtn(() => text));
  });

  // JSON syntax highlighter (no external deps)
  function highlightJSON(str) {
    str = str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    return str.replace(
      /("(?:\\.|[^"\\])*")(\s*:)?|(-?\d+\.?\d*(?:[eE][+-]?\d+)?)|(\btrue\b|\bfalse\b|\bnull\b)/g,
      (match, strVal, colon, num, kw) => {
        if (strVal && colon) return `<span class="json-key">${strVal}</span>${colon}`;
        if (strVal)          return `<span class="json-string">${strVal}</span>`;
        if (num !== undefined) return `<span class="json-number">${num}</span>`;
        if (kw)              return `<span class="json-keyword">${kw}</span>`;
        return match;
      }
    );
  }

  // JSON prompts: pre > code.language-json
  document.querySelectorAll('.prompt-content pre > code.language-json').forEach(codeEl => {
    const pre = codeEl.parentElement;
    const raw = codeEl.textContent.trim();
    let pretty = raw;
    try {
      pretty = JSON.stringify(JSON.parse(raw), null, 2);
    } catch (_) {
      // malformed JSON: fall back to raw text, no highlighting
    }
    codeEl.innerHTML = highlightJSON(pretty);
    const wrapper = wrapInBlock(pre);
    wrapper.classList.add('prompt-json');
    wrapper.appendChild(makeCopyBtn(() => pretty));
  });
})();
</script>
```

- [ ] **Step 2: Start the Hugo dev server**

```bash
cd /Users/william.chao/workspace/web/nano-banana-prompt && hugo server --port 1313
```

- [ ] **Step 3: Open a JSON prompt page in your browser**

Navigate to `http://localhost:1313/nano-banana-prompt/prompts/003-watercolor-fashion-illustration-of-the-attached-photo/`

Verify:
- JSON block is syntax-highlighted: keys in yellow, strings in green, numbers in cyan, booleans/null in orange
- A "Copy Prompt" button appears top-right of the JSON block
- Clicking it copies the prettified JSON to clipboard
- Button shows "✓ Copied!" for 2 seconds then resets

- [ ] **Step 4: Also verify a plain-text prompt still works** — navigate to `http://localhost:1313/nano-banana-prompt/prompts/001-isometric-city-scene/` and confirm the copy button is still present and functional.

- [ ] **Step 5: Verify on mobile viewport** — in DevTools (or browser responsive mode), set viewport to 375px width. Confirm:
  - The "Copy Prompt" button is visible and tappable (not clipped by overflow)
  - Long prompts scroll horizontally within the block (not the page)

- [ ] **Step 6: Stop the dev server** (Ctrl+C)

- [ ] **Step 7: Run production build to confirm no regressions**

```bash
cd /Users/william.chao/workspace/web/nano-banana-prompt && hugo --minify 2>&1 | tail -5
```

Expected: no errors.

- [ ] **Step 8: Commit**

```bash
cd /Users/william.chao/workspace/web/nano-banana-prompt
git add layouts/_default/single.html
git commit -m "feat: add JSON syntax highlighting and copy button for JSON prompts"
```
