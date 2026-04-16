# Design: new-prompt.sh — Clipboard & Editor Prompt Input

**Date:** 2026-04-16  
**Status:** Approved

## Problem

When running `scripts/new-prompt.sh`, the prompt text input step asks the user to type or paste text directly into the terminal and type `END` to finish. Long prompts copied from a browser exceed terminal paste buffer limits, causing truncation or dropped characters.

## Goal

Allow users to input long prompt text reliably without hitting terminal paste limitations.

## Scope

Single file change: `scripts/new-prompt.sh`, prompt-text input section only.  
All other input fields and flow remain unchanged.

---

## Solution

Replace the line-by-line `read` loop with a clipboard-first, editor-fallback flow.

### Flow

```
pbpaste available?
├─ yes → read clipboard content
│         ├─ content present → display full text → ask "Use? [Y/n]"
│         │   ├─ Y → use clipboard text
│         │   └─ n → open nano (temp file)
│         └─ empty → inform user → open nano (temp file)
└─ no  → (non-macOS) open nano directly
```

### Implementation Details

**Clipboard read:**
- Use `pbpaste` (macOS built-in)
- Check availability with `command -v pbpaste`
- If unavailable, skip clipboard step, go directly to nano

**Editor fallback:**
- Create temp file: `mktemp /tmp/nbp-prompt-XXXXX.txt`
- Open: `nano "$tmpfile"`
- Read file content after nano exits
- Delete temp file with `rm -f "$tmpfile"`

**Backward compatibility:**
- If `pbpaste` is absent (Linux/CI), nano is used automatically — no error
- The `END` sentinel approach is removed for this step only

---

## Files Changed

| File | Change |
|------|--------|
| `scripts/new-prompt.sh` | Replace prompt text input loop (lines ~117–129) with clipboard+nano flow |

## Out of Scope

- Other input fields (title, source URL, image drag-drop, tags)
- Multi-step flow
- Linux clipboard support (xclip/xsel)
