# Multi-Service Image Gen Support Design

**Date:** 2026-05-11  
**Status:** Approved

## Problem

The site title is "Nano Banana Prompts" and the architecture assumes a single image generation service (Nano Banana). As more image gen services emerge (e.g., GPT Image), the site needs to support multiple services — including displaying per-service result images side-by-side for comparison.

## Goals

- Rename the site to "Image Gen Prompts" (service-agnostic branding)
- Allow prompts to declare which services they support
- Allow prompts to include per-service result images for side-by-side comparison
- Add a service filter bar on the homepage
- Show service badges on prompt cards
- Maintain full backward compatibility with all 141 existing prompts

## Out of Scope

- Separate Hugo taxonomy pages per service (e.g., `/services/nano-banana/`)
- Automatic migration of existing prompt frontmatter
- Per-service prompt text variations

---

## Architecture

### 1. Site Title & Description (`hugo.toml`)

```toml
title = "Image Gen Prompts"

[params]
  description = "AI image generation prompts gallery"
```

### 2. Frontmatter Schema

Two new optional fields are added. All existing fields remain unchanged.

```yaml
# New fields
services:
  - "Nano Banana"
  - "GPT Image"

service_images:
  nano-banana: "https://..."
  gpt-image: "https://..."

# Existing fields (unchanged)
title: "..."
num: 1
tags:
  - "City & Architecture"
cover: "https://..."
source: "@handle"
sourceUrl: "https://..."
date: 2026-05-11
```

**`services`** — array of service names this prompt supports. Drives the filter bar and card badges.  
**`service_images`** — map of service slug → image URL. When present, the detail page renders a side-by-side comparison block above the markdown content.

**Backward compatibility:** Prompts without a `services` field are treated as `["Nano Banana"]` via a template default. No existing files need to be modified.

### 3. Homepage Filter Bars (`layouts/index.html`)

Two stacked filter bars replace the current single tag filter:

1. **Service filter bar** (top row) — "All Services" + one button per service, colored badges
2. **Tag filter bar** (bottom row) — unchanged from current implementation

Both filters are applied simultaneously (AND logic): a card must match the active service AND the active tag to be visible. Selecting "All Services" or "All Tags" removes that filter dimension.

Card filtering uses `data-services` and `data-tags` HTML attributes, driven by JavaScript — consistent with the existing tag filter implementation.

### 4. Prompt Card (`layouts/index.html`, `layouts/partials/card.html`)

Cards gain:
- `data-services="{{ delimit (.Params.services | default (slice "Nano Banana")) "," }}"` attribute
- Service badges in the card tag row, rendered before category tags, with distinct colors

Service badge colors:
- Nano Banana: `#f5a623` (orange)
- GPT Image: `#10b981` (green)
- Future services: additional colors defined in CSS

### 5. Detail Page (`layouts/_default/single.html`)

When `service_images` is set and has more than one entry, a comparison block is rendered at the top of the page (before the markdown content):

- Two-column grid, one column per service
- Each column: service badge label + image
- Falls back gracefully when only one service image is present (single column, no comparison header)
- When `service_images` is absent, the page renders exactly as today

---

## Component Summary

| Component | Change |
|---|---|
| `hugo.toml` | Update `title` and `description` |
| `content/prompts/*.md` | No changes required for existing prompts |
| `layouts/index.html` | Add service filter bar; add `data-services` to cards; add service badges to card tag row |
| `layouts/partials/card.html` | Add `data-services` attribute; add service badges |
| `layouts/_default/single.html` | Add conditional side-by-side comparison block |
| `static/` CSS | Add service badge color variables |

---

## Data Flow

```
Frontmatter (services, service_images)
    │
    ├─► Card (data-services attr + service badges in tag row)
    │       │
    │       └─► JS filter on homepage (service filter bar)
    │
    └─► Detail page (side-by-side comparison block if service_images present)
```

---

## Template Logic

### Service default fallback (index.html / card.html)
```go-html-template
{{ $services := .Params.services | default (slice "Nano Banana") }}
```

### Side-by-side comparison (single.html)
```go-html-template
{{ if gt (len .Params.service_images) 1 }}
  <div class="service-comparison">
    {{ range $service, $img := .Params.service_images }}
      <div class="service-col">
        <span class="service-badge service-{{ $service }}">{{ $service }}</span>
        <img src="{{ $img }}" alt="{{ $service }} result" loading="lazy">
      </div>
    {{ end }}
  </div>
{{ end }}
```

### JS filter (homepage)
Both filters use the same pattern. Active service and active tag are tracked independently; a card is visible only when it matches both.

```js
function isVisible(card) {
  const matchService = activeService === 'all' ||
    card.dataset.services.split(',').includes(activeService);
  const matchTag = activeTag === 'all' ||
    card.dataset.tags.split(',').includes(activeTag);
  return matchService && matchTag;
}
```
