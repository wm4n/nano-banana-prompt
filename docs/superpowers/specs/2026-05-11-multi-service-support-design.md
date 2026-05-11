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
  - "nano-banana"
  - "gpt-image"

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

**`services`** — array of service slugs this prompt supports. Drives the filter bar and card badges. This is the canonical source for which services a prompt belongs to.  
**`service_images`** — map of service slug → image URL. Keys must be a subset of (or equal to) the `services` array.

**Relationship between `services` and `service_images`:**
- `services` is the canonical source for filter/badge. Resolution order (first match wins):
  1. Use `services` if explicitly set in frontmatter
  2. If `services` is absent but `service_images` is set, derive `services` from the keys of `service_images`
  3. If neither is set, default to `["nano-banana"]`
- `service_images` keys must be a subset of (or equal to) the resolved `services` list.
- Best practice: always set `services` explicitly.

**Template resolution logic:**
```go-html-template
{{ $services := .Params.services }}
{{ if and (not $services) .Params.service_images }}
  {{ $services = slice }}
  {{ range $slug, $_ := .Params.service_images }}
    {{ $services = $services | append $slug }}
  {{ end }}
{{ end }}
{{ $services = $services | default (slice "nano-banana") }}
```

**Backward compatibility:** Prompts without `services` or `service_images` resolve to `["nano-banana"]` via step 3 above. No existing files need to be modified.

### Service Model

All service references use slugs as the canonical key. The single source of truth for display names and colors is **`data/services.yaml`** — templates access it via `site.Data.services`, and CSS badge colors are defined as custom properties in `static/` referencing the same values.

```yaml
# data/services.yaml
nano-banana:
  name: "Nano Banana"
  color: "#f5a623"
gpt-image:
  name: "GPT Image"
  color: "#10b981"
```

Adding a new service: add one entry to `data/services.yaml`. No template or JS changes required.

| Slug | Display Name | Badge Color |
|---|---|---|
| `nano-banana` | Nano Banana | `#f5a623` |
| `gpt-image` | GPT Image | `#10b981` |

### 3. Homepage Filter Bars (`layouts/index.html`)

Two stacked filter bars replace the current single tag filter:

1. **Service filter bar** (top row) — "All Services" + one button per service, colored badges
2. **Tag filter bar** (bottom row) — unchanged from current implementation

Both filters are applied simultaneously (AND logic): a card must match the active service AND the active tag to be visible. Selecting "All Services" or "All Tags" removes that filter dimension.

Card filtering uses `data-services` and `data-tags` HTML attributes, driven by JavaScript — consistent with the existing tag filter implementation.

### 4. Prompt Card (`layouts/index.html`, `layouts/partials/card.html`)

> **Note:** The homepage (`layouts/index.html`) currently has its own inline card markup and does **not** use `layouts/partials/card.html`. Both files contain card markup and both must be updated. The partial is the authoritative card definition; as part of this change, `layouts/index.html` should be refactored to use `{{ template "card" . }}` instead of duplicating the markup.

Cards gain:
- `data-services="{{ delimit (.Params.services | default (slice "nano-banana")) "," }}"` attribute
- Service badges in the card tag row, rendered before category tags, with distinct colors per the service model table above

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
| `data/services.yaml` | New file — canonical service model (slug, display name, color) |
| `content/prompts/*.md` | No changes required for existing prompts |
| `layouts/index.html` | Add service filter bar; refactor card markup to use `partials/card.html` |
| `layouts/partials/card.html` | Add `data-services` attribute; add service badges; read display names from `site.Data.services` |
| `layouts/_default/single.html` | Add conditional side-by-side comparison block |
| `static/` CSS | Add service badge CSS custom properties matching `data/services.yaml` |

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
{{ $services := .Params.services }}
{{ if and (not $services) .Params.service_images }}
  {{ $services = slice }}
  {{ range $slug, $_ := .Params.service_images }}
    {{ $services = $services | append $slug }}
  {{ end }}
{{ end }}
{{ $services = $services | default (slice "nano-banana") }}
```

### Side-by-side comparison (single.html)

Rendering rules based on number of entries in `service_images`:
- **0 entries / absent** — no comparison block; page renders exactly as today
- **1 entry** — single-column image block with service label (no comparison framing)
- **2 entries** — two-column side-by-side comparison grid (current maximum scope: Nano Banana + GPT Image)
- **3+ entries** — CSS `auto-fit` grid (`repeat(auto-fit, minmax(220px, 1fr))`), columns wrap to new rows automatically; no special layout change needed

```go-html-template
{{ $images := .Params.service_images }}
{{ if $images }}
  <div class="service-comparison service-comparison--{{ if gt (len $images) 1 }}multi{{ else }}single{{ end }}">
    {{ range $slug, $img := $images }}
      <div class="service-col">
        <span class="service-badge service-{{ $slug }}">{{ $slug }}</span>
        <img src="{{ $img }}" alt="{{ $slug }} result" loading="lazy">
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
