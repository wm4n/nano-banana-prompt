#!/usr/bin/env bash
# scripts/lib.sh — Shared tag inference functions.
# Source this file; do not execute directly.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: lib.sh is a library — source it, do not execute it." >&2
  exit 1
fi

source "$(dirname "${BASH_SOURCE[0]}")/tags.sh"

# Keyword-based tag inference. Always returns at least one slug.
# Returns space-separated slugs on stdout.
keyword_infer_tags() {
  local title_lower i slug kw kws matched=()
  title_lower=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  for i in "${!ALL_SLUGS[@]}"; do
    slug="${ALL_SLUGS[$i]}"
    IFS='|' read -ra kws <<< "${ALL_KEYWORDS[$i]}"
    for kw in "${kws[@]}"; do
      if [[ "$title_lower" == *"$kw"* ]]; then
        matched+=("$slug")
        break
      fi
    done
  done
  if [[ ${#matched[@]} -eq 0 ]]; then
    echo "art-styles"
  else
    echo "${matched[*]}"
  fi
}

# AI-based tag inference using Copilot CLI (claude-haiku-4.5).
# Returns space-separated slugs on stdout, or exits non-zero on failure.
ai_infer_tags() {
  local prompt_text="$1"
  local tag_list
  tag_list=$(printf '%s\n' "${ALL_SLUGS[@]}" | paste -sd',' - | sed 's/,/, /g')
  local result
  result=$(copilot --model claude-haiku-4.5 --no-ask-user -s \
    -p "You are a classifier for AI image generation prompts.
Given the prompt below, pick which tags apply from the list.
Return ONLY the matching tag slugs as a comma-separated list, nothing else.
You may return one or multiple tags. Use only slugs from the list.

Tags: ${tag_list}

Prompt: ${prompt_text}" 2>/dev/null) || return 1
  [[ -z "$result" ]] && return 1

  echo "$result" | tr ',' ' ' | tr -s ' ' | sed 's/^ //;s/ $//'
}
