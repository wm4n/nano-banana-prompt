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
  2. If `services` is absent but `service_images` is set, derive `services` from the keys of `service_images`, **sorted by the order they appear in `data/services.yaml`** (unknown slugs appended alphabetically at the end)
  3. If neither is set, default to `["nano-banana"]`
- `service_images` keys must be a subset of (or equal to) the resolved `services` list.
- **Best practice: always set `services` explicitly** — this guarantees display order and avoids runtime sorting.

**Template resolution logic:**
```go-html-template
{{ $services := .Params.services }}
{{ if and (not $services) .Params.service_images }}
  {{/* Derive services from service_images keys, sorted by data/services.yaml order */}}
  {{ $services = slice }}
  {{ range $svc := site.Data.services }}
    {{ if index $.Params.service_images $svc.slug }}
      {{ $services = $services | append $svc.slug }}
    {{ end }}
  {{ end }}
  {{/* Append any slugs not in services.yaml, sorted alphabetically */}}
  {{ range $slug, $_ := .Params.service_images }}
    {{ if not (in $services $slug) }}
      {{ $services = $services | append $slug }}
    {{ end }}
  {{ end }}
{{ end }}
{{ $services = $services | default (slice "nano-banana") }}
```

> **Note:** The derivation code above requires `data/services.yaml` to be a list (not a map) so that iteration order is deterministic. See the Service Data section for the list format.

**Backward compatibility:** Prompts without `services` or `service_images` resolve to `["nano-banana"]` via step 3 above. No existing files need to be modified.

### Service Model

All service references use slugs as the canonical key. Responsibilities are split to avoid duplication:

- **`data/services.yaml`** — canonical source for slug → display name only. **Format: a YAML list** (not map) so Hugo template iteration is order-deterministic. Templates read display names by scanning the list. The service filter bar enumerates all services from this file (not derived from content).
- **`assets/css/main.css`** — canonical source for badge colors, via per-slug CSS classes (`.service-nano-banana`, `.service-gpt-image`, etc.). CSS owns colors; no color duplication in the data file.

```yaml
# data/services.yaml  — list format (order determines display order everywhere)
- slug: "nano-banana"
  name: "Nano Banana"
- slug: "gpt-image"
  name: "GPT Image"
```

```css
/* assets/css/main.css — badge colors */
.service-nano-banana { background: #f5a623; color: #fff; }
.service-gpt-image   { background: #10b981; color: #fff; }
```

Templates apply the CSS class by slug and read display name by scanning the list:
```go-html-template
{{/* Helper: look up display name for a slug */}}
{{ $displayName := $slug }}
{{ range site.Data.services }}
  {{ if eq .slug $slug }}{{ $displayName = .name }}{{ end }}
{{ end }}
<span class="service-badge service-{{ $slug }}">{{ $displayName }}</span>
```

Adding a new service: append one entry to `data/services.yaml` and one CSS rule to `assets/css/main.css`. No template or JS changes required.

> **Important:** If a prompt's frontmatter uses a `services` slug not present in `data/services.yaml`, the card badge will fall back to showing the raw slug and the homepage filter bar will have **no button** for that service. Always add new slugs to `data/services.yaml` before (or at the same time as) using them in content.

| Slug | Display Name | Badge CSS Class |
|---|---|---|
| `nano-banana` | Nano Banana | `.service-nano-banana` |
| `gpt-image` | GPT Image | `.service-gpt-image` |

### 3. Homepage Filter Bars (`layouts/index.html`)

Two stacked filter bars replace the current single tag filter:

1. **Service filter bar** (top row) — "All Services" + one button per service. Buttons are enumerated from `data/services.yaml` (all defined services, regardless of whether any current content uses them). Display name shown on button; slug used as the filter value.
2. **Tag filter bar** (bottom row) — unchanged from current implementation

Both filters are applied simultaneously (AND logic): a card must match the active service AND the active tag to be visible. Selecting "All Services" or "All Tags" removes that filter dimension.

Card filtering uses `data-services` and `data-tags` HTML attributes, driven by JavaScript — consistent with the existing tag filter implementation.

### 4. Prompt Card (`layouts/index.html`, `layouts/partials/card.html`)

> **Note:** The homepage (`layouts/index.html`) currently has its own inline card markup and does **not** use `layouts/partials/card.html`. Both files contain card markup and both must be updated. The partial is the authoritative card definition; as part of this change, `layouts/index.html` should be refactored to use `{{ template "card" . }}` instead of duplicating the markup.

Cards gain:
- `data-services` attribute populated using the full service resolution logic from the **Template Logic** section below — not a simple `default`. This ensures `service_images`-only prompts are also filterable.
- Service badges in the card tag row, rendered before category tags. Each badge shows the display name from `site.Data.services` and applies the `.service-{slug}` CSS class for coloring.

### 5. Detail Page (`layouts/_default/single.html`)

When `service_images` is set, a comparison block is rendered at the top of the detail page (before the markdown content). The card thumbnail always uses the `cover` field regardless of whether `service_images` is present — `cover` and `service_images` are independent.

- Layout uses a CSS `auto-fit` grid (`grid-template-columns: repeat(auto-fit, minmax(220px, 1fr))`): 1 image = full-width, 2 images = side-by-side, 3+ = wrapping rows. No separate layout logic per count.
- Each column: service badge label + image
- When `service_images` is absent, the page renders exactly as today
- Comparison block images participate in the lightbox. Since the existing lightbox JS (`baseof.html`) only binds to `.prompt-content img`, the binding must be extended to also cover `.service-comparison img`.

---

### 6. New Prompt Script (`scripts/new-prompt.sh`)

The script is updated to support service selection and per-service image collection. Changes:

**Header comment:** Update from "Nano Banana gallery" to "Image Gen Prompts gallery".

**New step — Service selection** (inserted after Source URL, before the step loop):

- Reads the service list from `data/services.yaml` (parsed with `yq` or a simple line-by-line grep; fall back to hardcoded slug list if `yq` is unavailable)
- Presents a numbered multi-select list identical in style to the existing tag selector
- Default: `nano-banana` pre-selected (all existing behaviour is preserved when user presses Enter without changing selection)
- Stores result in `SELECTED_SERVICES` array of slugs

**New step — Service images** (inserted after the step loop, only when `${#SELECTED_SERVICES[@]} > 1`):

- For each selected service, prompt: `Service image URL for <display-name> (or press Enter to skip):`
- Stores results in two parallel indexed arrays: `SERVICE_IMAGE_SLUGS` and `SERVICE_IMAGE_URLS` (index-aligned with `SELECTED_SERVICES`), to maintain bash 3.2+ compatibility (no associative arrays)
- If a URL is provided, it is written to `service_images` in the frontmatter
- No image file copy is performed for service images (URLs only, consistent with how `cover` works for GitHub-hosted images)

**Frontmatter template update:**

```bash
# services block (always written)
SERVICES_YAML=""
for slug in "${SELECTED_SERVICES[@]}"; do
  SERVICES_YAML="${SERVICES_YAML}  - \"${slug}\""$'\n'
done

# service_images block (only written if any URL was provided)
# Uses parallel arrays (bash 3.2 compatible — no associative arrays)
SERVICE_IMAGES_YAML=""
for i in "${!SERVICE_IMAGE_SLUGS[@]}"; do
  slug="${SERVICE_IMAGE_SLUGS[$i]}"
  url="${SERVICE_IMAGE_URLS[$i]}"
  [[ -n "$url" ]] && SERVICE_IMAGES_YAML="${SERVICE_IMAGES_YAML}  ${slug}: \"${url}\""$'\n'
done
```

The generated frontmatter includes `services:` always, and `service_images:` only when at least one URL was provided. Single-service prompts (the common case) produce only the `services:` block with one entry — no `service_images` block.

---

| Component | Change |
|---|---|
| `hugo.toml` | Update `title` and `description` |
| `layouts/_default/baseof.html` | Update hardcoded brand name in site logo; extend JS filter to handle `data-services` attribute and service filter bar buttons; extend lightbox binding to include `.service-comparison img` |
| `data/services.yaml` | New file — slug → display name mapping (canonical); colors are in `assets/css/main.css` |
| `content/prompts/*.md` | No changes required for existing prompts |
| `layouts/index.html` | Add service filter bar (enumerate from `site.Data.services`); refactor card markup to use `partials/card.html` |
| `layouts/partials/card.html` | Add `data-services` attribute (full resolution logic); add service badges with display names and `.service-{slug}` CSS classes |
| `layouts/_default/single.html` | Add conditional side-by-side comparison block; badge shows display name; comparison images participate in existing lightbox |
| `assets/css/main.css` | Add `.service-{slug}` badge color classes; add `.service-comparison` grid styles |
| `scripts/new-prompt.sh` | Add service multi-select step; add service_images URL collection; update frontmatter generation; update header comment |

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
  {{/* Derive services from service_images keys, sorted by data/services.yaml order */}}
  {{ $services = slice }}
  {{ range site.Data.services }}
    {{ if index $.Params.service_images .slug }}
      {{ $services = $services | append .slug }}
    {{ end }}
  {{ end }}
  {{/* Append any slugs not in services.yaml, sorted alphabetically */}}
  {{ range $slug, $_ := .Params.service_images }}
    {{ if not (in $services $slug) }}
      {{ $services = $services | append $slug }}
    {{ end }}
  {{ end }}
{{ end }}
{{ $services = $services | default (slice "nano-banana") }}
```

### Side-by-side comparison (single.html)

Rendering rules based on number of entries in `service_images`:
- **0 entries / absent** — no comparison block; page renders exactly as today
- **1+ entries** — comparison block rendered using CSS `auto-fit` grid (`repeat(auto-fit, minmax(220px, 1fr))`). 1 image = full-width; 2 = side-by-side; 3+ = wrapping rows. No separate layout logic per count.

**Image display order** follows the `services` array (not map iteration order). The template iterates over the resolved `$services` slice and looks up each slug in `service_images`:

```go-html-template
{{ $images := .Params.service_images }}
{{ if $images }}
  <div class="service-comparison">
    {{ range $slug := $services }}
      {{ $img := index $images $slug }}
      {{ if $img }}
        {{ $displayName := $slug }}
        {{ range site.Data.services }}
          {{ if eq .slug $slug }}{{ $displayName = .name }}{{ end }}
        {{ end }}
        <div class="service-col">
          <span class="service-badge service-{{ $slug }}">{{ $displayName }}</span>
          <img src="{{ $img }}" alt="{{ $displayName }} result" loading="lazy">
        </div>
      {{ end }}
    {{ end }}
  </div>
{{ end }}
```

Lightbox: the existing lightbox JS in `baseof.html` binds only to `.prompt-content img`. The binding must be extended to `.service-comparison img` as well (see `baseof.html` changes in Component Summary).

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
