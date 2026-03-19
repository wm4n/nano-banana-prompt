#!/usr/bin/env python3
"""
Parse README.md and generate Hugo content files for each prompt.
Each prompt becomes content/prompts/<num>-<slug>.md with frontmatter.
"""

import re
import os
import sys
from datetime import date

README_PATH = os.path.join(os.path.dirname(__file__), '..', 'README.md')
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), '..', 'content', 'prompts')

# ---------------------------------------------------------------------------
# Tag assignment rules — keyword matching against lowercased title
# A prompt can match multiple categories
# ---------------------------------------------------------------------------
TAG_RULES = [
    ("city-architecture", ["city", "urban", "isometric", "animal crossing", "simcity",
                            "claymorphism", "white clay", "3d led", "architectural blueprint",
                            "souvenir magnet", "city brush", "city scene"]),
    ("3d-miniature",      ["miniature", "diorama", "hologram", "glass marble", "cube diorama",
                            "chibi", "tilt 3d", "3d relief", "hand paint miniature",
                            "3d hand", "3d story", "3d newspaper", "concept store",
                            "different angle", "survey board"]),
    ("art-styles",        ["watercolor", "ink painting", "ink drawing", "pencil", "crayon",
                            "sketch", "embroidery", "paper cut", "folded paper",
                            "botanical", "scribble", "claymation", "painterly",
                            "step by step drawing", "draw like", "style drawing",
                            "watercolor style", "blueprint schematic", "成語"]),
    ("character-portrait",["character", "caricature", "portrait", "sticker", "hair style",
                            "pose", "pixar", "cartoon", "idol", "dress", "editorial portrait",
                            "cute character", "chat sticker", "soft toy", "mechanical bird"]),
    ("photo-cinematic",   ["photo", "cinematic", "angle shot", "motion blur", "upscale",
                            "restore", "cherry blossom", "raining", "lat & lon",
                            "lat lon", "taking photo"]),
    ("infographic-ui",    ["hud", "infographic", "report", "ui/ux", "heatmap",
                            "species migration", "boarding pass", "profile card",
                            "3d newspaper", "notebooklm", "tech evolution", "status report",
                            "architect", "real-time"]),
    ("effects-composite", ["neon effect", "blending", "season blend", "mirror reflection",
                            "firework", "emerge from", "split effect", "combine different",
                            "imagine events", "surreal", "era"]),
    ("food-commercial",   ["food", "cuisine", "fruit", "dish", "pixelize food",
                            "advertising food", "middle eastern food", "recipe"]),
    ("poster-nature",     ["poster", "magazine cover", "wallpaper", "gta", "brand poster",
                            "cloud formation", "sea of clouds", "mountain", "forest",
                            "bookshelves", "story telling", "concept art", "looking through",
                            "peeking through"]),
    ("icons-stickers",    ["icon generation", "themed icon", "different style icon"]),
]

# Manual overrides: prompt_num -> [list of tag slugs]
MANUAL_TAGS = {
    4:   ["infographic-ui"],
    8:   ["art-styles", "effects-composite"],
    9:   ["3d-miniature", "art-styles"],
    10:  ["infographic-ui"],
    14:  ["effects-composite"],
    19:  ["art-styles"],
    20:  ["3d-miniature"],
    26:  ["infographic-ui", "3d-miniature"],
    29:  ["effects-composite", "art-styles"],
    32:  ["photo-cinematic", "infographic-ui"],
    37:  ["infographic-ui", "effects-composite"],
    38:  ["3d-miniature"],
    40:  ["art-styles", "infographic-ui"],
    42:  ["effects-composite", "photo-cinematic"],
    46:  ["art-styles"],
    47:  ["3d-miniature", "effects-composite"],
    56:  ["icons-stickers"],
    59:  ["poster-nature", "art-styles"],
    60:  ["poster-nature"],
    61:  ["infographic-ui"],
    63:  ["art-styles", "poster-nature"],
    65:  ["city-architecture", "art-styles"],
    67:  ["art-styles"],
    68:  ["character-portrait", "art-styles"],
    69:  ["character-portrait", "art-styles"],
    70:  ["art-styles", "character-portrait"],
    71:  ["city-architecture"],
    72:  ["infographic-ui", "3d-miniature"],
    73:  ["art-styles"],
    75:  ["icons-stickers"],
    77:  ["infographic-ui"],
    79:  ["infographic-ui", "poster-nature"],
    82:  ["character-portrait", "3d-miniature"],
    83:  ["art-styles"],
    85:  ["infographic-ui"],
    86:  ["infographic-ui"],
    87:  ["art-styles"],
    88:  ["character-portrait"],
    89:  ["character-portrait", "art-styles"],
    91:  ["3d-miniature"],
    92:  ["photo-cinematic", "effects-composite"],
    93:  ["effects-composite"],
    95:  ["infographic-ui", "3d-miniature"],
    96:  ["poster-nature", "art-styles"],
    97:  ["3d-miniature", "art-styles"],
    98:  ["character-portrait", "3d-miniature"],
    99:  ["3d-miniature"],
    101: ["poster-nature"],
    102: ["poster-nature"],
    104: ["character-portrait", "3d-miniature"],
    107: ["city-architecture"],
    108: ["city-architecture", "3d-miniature"],
    109: ["photo-cinematic"],
    110: ["art-styles", "infographic-ui"],
    111: ["character-portrait", "icons-stickers"],
    112: ["art-styles"],
    113: ["city-architecture", "3d-miniature"],
}

# Human-readable tag labels
TAG_LABELS = {
    "city-architecture":  "City & Architecture",
    "3d-miniature":       "3D & Miniature",
    "art-styles":         "Art Styles",
    "character-portrait": "Character & Portrait",
    "photo-cinematic":    "Photo & Cinematic",
    "infographic-ui":     "Infographic & UI",
    "effects-composite":  "Effects & Composite",
    "food-commercial":    "Food & Commercial",
    "poster-nature":      "Poster & Nature",
    "icons-stickers":     "Icons & Stickers",
}


def slugify(text: str) -> str:
    text = text.lower()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[\s_]+', '-', text)
    text = re.sub(r'-+', '-', text)
    return text.strip('-')[:60]


def auto_assign_tags(num: int, title: str) -> list[str]:
    if num in MANUAL_TAGS:
        return MANUAL_TAGS[num]
    title_lower = title.lower()
    matched = []
    for tag_slug, keywords in TAG_RULES:
        if any(kw in title_lower for kw in keywords):
            matched.append(tag_slug)
    return matched if matched else ["art-styles"]  # fallback


def extract_cover(text: str) -> str:
    """Return first image src found in section text."""
    m = re.search(r'<img[^>]+src="([^"]+)"', text)
    return m.group(1) if m else ""


def extract_source(text: str) -> tuple[str, str]:
    """Return (handle, url) from 'from [@handle](url)' pattern."""
    m = re.search(r'from\s+\[@([^\]]+)\]\(([^)]+)\)', text)
    if m:
        return m.group(1), m.group(2)
    return "", ""


def parse_readme(readme_path: str) -> list[dict]:
    with open(readme_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Split on section headers: ## N. Title
    # Using lookahead to keep the delimiter
    parts = re.split(r'\n(?=## \d+\.)', content)

    prompts = []
    seen_nums = {}

    for part in parts:
        part = part.strip()
        header_match = re.match(r'^## (\d+)\.\s+(.+?)$', part, re.MULTILINE)
        if not header_match:
            continue

        num = int(header_match.group(1))
        title = header_match.group(2).strip()

        # Body = everything after the header line
        body_start = part.index('\n', 0) + 1 if '\n' in part else len(part)
        body = part[body_start:].strip()

        cover = extract_cover(body)
        handle, source_url = extract_source(body)
        tags = auto_assign_tags(num, title)

        # Build a unique slug (handle duplicate nums)
        base_slug = slugify(title)
        if num in seen_nums:
            seen_nums[num] += 1
            suffix = chr(ord('a') + seen_nums[num] - 1)
            file_slug = f"{num:03d}{suffix}-{base_slug}"
        else:
            seen_nums[num] = 1
            file_slug = f"{num:03d}-{base_slug}"

        prompts.append({
            "num": num,
            "title": title,
            "slug": file_slug,
            "tags": tags,
            "cover": cover,
            "source_handle": handle,
            "source_url": source_url,
            "body": body,
        })

    return prompts


def write_content_files(prompts: list[dict], output_dir: str):
    os.makedirs(output_dir, exist_ok=True)

    for p in prompts:
        tag_list = "\n".join(f'  - "{TAG_LABELS.get(t, t)}"' for t in p["tags"])
        frontmatter = f"""---
title: "{p['title'].replace('"', '\\"')}"
num: {p['num']}
tags:
{tag_list}
cover: "{p['cover']}"
source: "@{p['source_handle']}"
sourceUrl: "{p['source_url']}"
date: {date.today().isoformat()}
---

{p['body']}
"""
        filename = os.path.join(output_dir, f"{p['slug']}.md")
        with open(filename, 'w', encoding='utf-8') as f:
            f.write(frontmatter)
        print(f"  ✓ {filename.split('/')[-1]}")


if __name__ == "__main__":
    print("Parsing README.md...")
    prompts = parse_readme(README_PATH)
    print(f"Found {len(prompts)} prompts\n")

    print("Writing content files...")
    write_content_files(prompts, OUTPUT_DIR)
    print(f"\nDone! {len(prompts)} files written to {OUTPUT_DIR}")
