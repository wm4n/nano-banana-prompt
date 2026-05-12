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
- Create temp file: `mktemp /tmp/nbp-prompt-XXXXX` (no suffix — BSD `mktemp` requires template to end with `X`)
- Open: `nano "$tmpfile"`
- Read file content after nano exits
- Delete temp file with `rm -f "$tmpfile"`

**Empty file handling (nano):**
- If the file is empty after nano exits (user saved nothing), warn and retry nano once
- On the second attempt, if still empty, accept as empty prompt (consistent with original behavior which allowed empty input)

**nano not available (all paths):**
- Check with `command -v nano` before opening, regardless of how we got to the editor step
- This covers: (a) pbpaste absent → go to nano → nano absent, and (b) pbpaste present, clipboard empty or declined → go to nano → nano absent
- In all cases where nano is absent, fallback to the original line-by-line `read` loop with `END` sentinel

**Temp file cleanup under `set -euo pipefail`:**
- Register cleanup immediately after `mktemp` with `trap 'rm -f "$tmpfile"' EXIT`
- Do NOT rely on a plain `rm -f` at the end of the block — a command failure before that line would leak the temp file
- The trap ensures cleanup on any exit path (success, error, or signal)

**Clipboard display:**
- Echo the full clipboard content to the terminal with `echo "$clipboard_content"` (no truncation — user chose full text display)

**Backward compatibility:**
- If `pbpaste` is absent (Linux/CI), nano is used; if nano is also absent, use the original `END` loop
- The `END` sentinel loop is retained as the final fallback only

---

## Files Changed

| File | Change |
|------|--------|
| `scripts/new-prompt.sh` | Replace prompt text input loop (lines ~117–129) with clipboard+nano flow |

## Out of Scope

- Other input fields (title, source URL, image drag-drop, tags)
- Multi-step flow
- Linux clipboard support (xclip/xsel)
