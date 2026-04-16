# new-prompt.sh Clipboard Input Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the terminal `END`-sentinel prompt input loop in `new-prompt.sh` with a clipboard-first (pbpaste), nano-fallback, END-loop final-fallback flow so long prompts can be entered reliably.

**Architecture:** Add a `read_prompt_text` helper function that sets a global `_STEP_PROMPT_RESULT` variable. The function tries `pbpaste` first, then `nano` with a temp file, then falls back to the original `END` loop. Replace the inline input block (lines 117–129) with a single call to this function.

**Tech Stack:** Bash 3.2+, `pbpaste` (macOS), `nano`, `mktemp` (BSD-compatible)

---

## File Map

| Action | Path | Responsibility |
|--------|------|---------------|
| Modify | `scripts/new-prompt.sh` | Add `read_prompt_text` function; replace inline input block |

No other files change.

---

## Task 1: Add `read_prompt_text` helper function

**Files:**
- Modify: `scripts/new-prompt.sh` — add function in the `# ── Helpers` section, before the `next_num` function

The function implements the three-path input flow and stores its result in the global `_STEP_PROMPT_RESULT` variable. This avoids command-substitution newline-stripping issues.

- [ ] **Step 1: Add global result variable declaration after the colour/helper block**

  Find this line in `new-prompt.sh`:
  ```bash
  # ── Tag definitions and inference functions ───────────────────────────────────
  ```

  Insert the following block **immediately before** that line:

  ```bash
  # ── Prompt text input (clipboard → nano → END loop) ──────────────────────────
  _STEP_PROMPT_RESULT=""

  read_prompt_text() {
    _STEP_PROMPT_RESULT=""
    local clipboard_content use_clipboard tmpfile

    # Path 1: pbpaste (macOS clipboard)
    if command -v pbpaste &>/dev/null; then
      clipboard_content=$(pbpaste)
      if [[ -n "$clipboard_content" ]]; then
        echo ""
        info "--- Clipboard content ---"
        echo "$clipboard_content"
        echo ""
        printf "Use clipboard content? [Y/n]: "
        IFS= read -r use_clipboard
        use_clipboard="${use_clipboard:-Y}"
        if [[ "$use_clipboard" == "Y" || "$use_clipboard" == "y" ]]; then
          _STEP_PROMPT_RESULT="$clipboard_content"
          return 0
        fi
      else
        warn "Clipboard is empty."
      fi
    fi

    # Path 2: nano editor
    if command -v nano &>/dev/null; then
      tmpfile=$(mktemp /tmp/nbp-prompt-XXXXX)
      # Double-quote trap so $tmpfile path is captured immediately (not at EXIT time)
      # shellcheck disable=SC2064
      trap "rm -f '$tmpfile'" EXIT
      info "Opening nano — paste or type your prompt, then Ctrl+X → Y to save and exit."
      nano "$tmpfile"
      _STEP_PROMPT_RESULT=$(cat "$tmpfile")
      rm -f "$tmpfile"; trap - EXIT
      if [[ -z "$_STEP_PROMPT_RESULT" ]]; then
        warn "Prompt is empty. Re-opening nano — press Ctrl+X to accept empty."
        tmpfile=$(mktemp /tmp/nbp-prompt-XXXXX)
        # shellcheck disable=SC2064
        trap "rm -f '$tmpfile'" EXIT
        nano "$tmpfile"
        _STEP_PROMPT_RESULT=$(cat "$tmpfile")
        rm -f "$tmpfile"; trap - EXIT
      fi
      return 0
    fi

    # Path 3: fallback — original END-sentinel loop
    info "(Type or paste the prompt. Enter END on its own line to finish.)"
    local line
    while IFS= read -r line; do
      [[ "$line" == "END" ]] && break
      if [[ -z "$_STEP_PROMPT_RESULT" ]]; then
        _STEP_PROMPT_RESULT="$line"
      else
        _STEP_PROMPT_RESULT="${_STEP_PROMPT_RESULT}"$'\n'"${line}"
      fi
    done
  }

  ```

- [ ] **Step 2: Verify the function block was inserted correctly**

  Run:
  ```bash
  grep -n "read_prompt_text\|_STEP_PROMPT_RESULT\|Path 1\|Path 2\|Path 3" scripts/new-prompt.sh
  ```
  Expected: function declaration visible, three path comments present, no duplicate lines.

---

## Task 2: Replace inline input block with function call

**Files:**
- Modify: `scripts/new-prompt.sh` — replace lines 117–129 of the original file (the prompt text `while` loop)

- [ ] **Step 1: Locate the block to replace**

  The target block looks like this (line numbers may shift by a few after Task 1):
  ```bash
    echo ""
    info "--- Prompt text ---"
    echo "(Type or paste the prompt. Enter END on its own line to finish.)"
    step_prompt=""
    while IFS= read -r line; do
      [[ "$line" == "END" ]] && break
      if [[ -z "$step_prompt" ]]; then
        step_prompt="$line"
      else
        step_prompt="${step_prompt}"$'\n'"${line}"
      fi
    done
    STEP_PROMPTS+=("$step_prompt")
  ```

- [ ] **Step 2: Replace the block**

  Replace the entire block above with:
  ```bash
    echo ""
    info "--- Prompt text ---"
    read_prompt_text
    STEP_PROMPTS+=("$_STEP_PROMPT_RESULT")
  ```

- [ ] **Step 3: Verify the old while loop is gone and the new call is present**

  Run:
  ```bash
  grep -n "read_prompt_text\|Enter END\|STEP_PROMPTS" scripts/new-prompt.sh
  ```
  Expected:
  - `read_prompt_text` function definition line (from Task 1)
  - `read_prompt_text` call line (just added)
  - `STEP_PROMPTS+=("$_STEP_PROMPT_RESULT")` line
  - **No** `"Enter END on its own line to finish."` at the call site (only inside the function)

---

## Task 3: Manual smoke tests

Run the script interactively to verify all three paths:

```bash
./scripts/new-prompt.sh
```

- [ ] **Test A: Clipboard path (happy path)**
  1. Copy any text to clipboard (e.g. `echo "Test prompt content" | pbcopy`)
  2. Run the script, enter a title, skip image
  3. When `--- Prompt text ---` appears, it should display clipboard content and ask `Use clipboard content? [Y/n]:`
  4. Press Enter (defaults to Y)
  5. Expected: prompt text accepted, continues to tags

- [ ] **Test B: Clipboard declined → nano**
  1. Ensure clipboard has text
  2. At `Use clipboard content? [Y/n]:` type `n` and press Enter
  3. Expected: nano opens — paste some text, Ctrl+X → Y to save
  4. Expected: prompt text from nano is accepted

- [ ] **Test C: Empty clipboard → nano**
  1. Clear clipboard: `echo -n "" | pbcopy`
  2. Run script
  3. Expected: "Clipboard is empty." warning, then nano opens automatically

- [ ] **Test D: Abort preview (type `n` at final confirm)**
  - Verify no files are written — confirm "Aborted" message

---

## Task 4: Commit

- [ ] **Step 1: Stage and commit**

  ```bash
  git add scripts/new-prompt.sh
  git commit -m "feat: support clipboard and nano editor input for long prompts in new-prompt.sh

  - Add read_prompt_text helper: tries pbpaste first, then nano, then END-sentinel fallback
  - Replace inline END-loop with read_prompt_text call
  - Handles empty clipboard, empty nano file (retry once), and missing commands gracefully

  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
  ```

- [ ] **Step 2: Push**

  ```bash
  git push
  ```
