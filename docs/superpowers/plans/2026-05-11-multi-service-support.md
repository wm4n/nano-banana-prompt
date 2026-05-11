# Multi-Service Image Gen Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand the Hugo gallery site to support multiple image generation services (starting with Nano Banana + GPT Image), with service filter bar, service badges on cards, and side-by-side comparison on detail pages.

**Architecture:** No new Hugo taxonomy. Services are declared via `services` frontmatter array (slugs). A canonical `data/services.yaml` list owns slug→display-name mappings. CSS owns badge colors via `.service-{slug}` classes. A shared Hugo partial handles service resolution so logic is not duplicated across templates.

**Tech Stack:** Hugo (Go templates), vanilla JS, CSS grid, bash 3.2+

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `hugo.toml` | Site title + description |
| Create | `data/services.yaml` | Canonical service registry (list format, order-deterministic) |
| Modify | `assets/css/main.css` | Service badge color classes; `.service-comparison` grid styles |
| Create | `layouts/partials/service-resolve.html` | Shared service resolution logic (DRY) |
| Modify | `layouts/partials/card.html` | `data-services` attr + service badges in tag row |
| Modify | `layouts/index.html` | Service filter bar; refactor inline card markup to use card partial |
| Modify | `layouts/_default/baseof.html` | Logo text; extend filter JS for services; extend lightbox to `.service-comparison img` |
| Modify | `layouts/_default/single.html` | Conditional `service-comparison` block |
| Modify | `scripts/new-prompt.sh` | Service multi-select step; `service_images` collection; updated frontmatter |

---

## Task 1: Site Config + Service Registry

**Files:**
- Modify: `hugo.toml`
- Create: `data/services.yaml`

- [ ] **Step 1.1: Update hugo.toml**

  In `hugo.toml`, change:
  ```toml
  title = "Image Gen Prompts"

  [params]
    description = "AI image generation prompts gallery"
  ```
  (Keep all other settings unchanged.)

- [ ] **Step 1.2: Create data/services.yaml**

  ```yaml
  # data/services.yaml — list format; order determines display order everywhere.
  # To add a service: append entry here AND add a .service-{slug} CSS rule in assets/css/main.css.
  - slug: "nano-banana"
    name: "Nano Banana"
  - slug: "gpt-image"
    name: "GPT Image"
  ```

- [ ] **Step 1.3: Verify Hugo builds**

  ```bash
  cd /Users/william.chao/workspace/web/nano-banana-prompt
  hugo --minify 2>&1 | tail -5
  ```
  Expected: `Total in NNN ms` with no errors.

- [ ] **Step 1.4: Commit**

  ```bash
  git add hugo.toml data/services.yaml
  git commit -m "feat: rename site to Image Gen Prompts; add service registry

  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
  ```

---

## Task 2: CSS — Badge Colors + Comparison Grid

**Files:**
- Modify: `assets/css/main.css`

- [ ] **Step 2.1: Add service badge styles + comparison grid**

  Append to the end of `assets/css/main.css`:

  ```css
  /* ── Service Badges ── */
  .service-badge {
    font-size: 10px;
    font-weight: 600;
    padding: 2px 8px;
    border-radius: 12px;
    color: #fff;
    border: none;
    white-space: nowrap;
  }
  /* Per-service colors — add one rule per service slug */
  .service-nano-banana { background: #f5a623; color: #000; }
  .service-gpt-image   { background: #10b981; color: #fff; }

  /* ── Service Comparison Block (detail page) ── */
  .service-comparison {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    gap: 16px;
    margin-bottom: 32px;
  }
  .service-col {
    display: flex;
    flex-direction: column;
    gap: 8px;
    align-items: flex-start;
  }
  .service-col img {
    width: 100%;
    border-radius: var(--radius);
    cursor: zoom-in;
  }
  ```

- [ ] **Step 2.2: Verify Hugo builds**

  ```bash
  hugo --minify 2>&1 | tail -5
  ```
  Expected: no errors.

- [ ] **Step 2.3: Commit**

  ```bash
  git add assets/css/main.css
  git commit -m "feat: add service badge colors and comparison grid CSS

  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
  ```

---

## Task 3: Service Resolution Partial (DRY)

**Files:**
- Create: `layouts/partials/service-resolve.html`

This partial sets `$services` in the calling template's scope via `{{ $services := partial "service-resolve.html" . }}`.

- [ ] **Step 3.1: Create layouts/partials/service-resolve.html**

  ```go-html-template
  {{/*
    service-resolve.html
    Usage: {{ $services := partial "service-resolve.html" . }}
    Returns a slice of service slugs for the given page.
    Resolution order:
      1. .Params.services if set
      2. Derived from .Params.service_images keys, sorted by data/services.yaml order
      3. Default: ["nano-banana"]
  */}}
  {{ $services := .Params.services }}
  {{ if and (not $services) .Params.service_images }}
    {{ $services = slice }}
    {{ range site.Data.services }}
      {{ if index $.Params.service_images .slug }}
        {{ $services = $services | append .slug }}
      {{ end }}
    {{ end }}
    {{ range $slug, $_ := .Params.service_images }}
      {{ if not (in $services $slug) }}
        {{ $services = $services | append $slug }}
      {{ end }}
    {{ end }}
  {{ end }}
  {{ $services = $services | default (slice "nano-banana") }}
  {{ return $services }}
  ```

- [ ] **Step 3.2: Verify Hugo builds**

  ```bash
  hugo --minify 2>&1 | tail -5
  ```
  Expected: no errors (partial is not yet called anywhere, so this is just a parse check).

- [ ] **Step 3.3: Commit**

  ```bash
  git add layouts/partials/service-resolve.html
  git commit -m "feat: add service-resolve partial for DRY service resolution

  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
  ```

---

## Task 4: Card Partial — Service Badges + data-services

**Files:**
- Modify: `layouts/partials/card.html`

Current card.html (24 lines) does not use `service-resolve.html` and has no `data-services` attribute. Replace the entire file:

- [ ] **Step 4.1: Update layouts/partials/card.html**

  Replace the full content with:

  ```go-html-template
  {{ define "card" }}
  {{ $services := partial "service-resolve.html" . }}
  <div class="card"
    data-tags="{{ delimit .Params.tags "," }}"
    data-services="{{ delimit $services "," }}"
    data-title="{{ .Title }}">
    <a class="card-link" href="{{ .RelPermalink }}">
      <div class="card-img{{ if not .Params.cover }} card-no-img{{ end }}">
        {{ if .Params.cover }}
          <img src="{{ .Params.cover }}" alt="{{ .Title }}" loading="lazy">
        {{ else }}
          🖼️
        {{ end }}
        <span class="card-num">#{{ .Params.num }}</span>
      </div>
      <div class="card-body">
        <h3 class="card-title">{{ .Title }}</h3>
        <div class="card-tags">
          {{/* Service badges first, then category tags */}}
          {{ range $slug := $services }}
            {{ $displayName := $slug }}
            {{ range site.Data.services }}
              {{ if eq .slug $slug }}{{ $displayName = .name }}{{ end }}
            {{ end }}
            <span class="service-badge service-{{ $slug }}">{{ $displayName }}</span>
          {{ end }}
          {{ range .Params.tags }}
            <span class="card-tag">{{ . }}</span>
          {{ end }}
        </div>
      </div>
    </a>
  </div>
  {{ end }}
  ```

- [ ] **Step 4.2: Verify Hugo builds**

  ```bash
  hugo --minify 2>&1 | tail -5
  ```
  Expected: no errors.

- [ ] **Step 4.3: Commit**

  ```bash
  git add layouts/partials/card.html
  git commit -m "feat: add service badges and data-services to card partial

  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
  ```

---

## Task 5: Homepage — Service Filter Bar + Refactor to Card Partial

**Files:**
- Modify: `layouts/index.html`

Current `layouts/index.html` has inline card markup (39 lines) and a single tag filter bar. Replace both.

- [ ] **Step 5.1: Replace layouts/index.html**

  Replace the full content with:

  ```go-html-template
  {{ define "main" }}
  {{ $allTags := site.Taxonomies.tags }}

  {{/* ── Service filter bar (top row) ── */}}
  <nav class="filter-bar service-filter-bar" role="navigation" aria-label="Filter by service">
    <button class="tag-btn service-btn active" data-service="all">
      All Services
    </button>
    {{ range site.Data.services }}
    <button class="tag-btn service-btn" data-service="{{ .slug }}">
      {{ .name }}
    </button>
    {{ end }}
  </nav>

  {{/* ── Tag filter bar (bottom row) ── */}}
  <nav class="filter-bar" role="navigation" aria-label="Filter by tag">
    <button class="tag-btn active" data-tag="all">
      All ({{ len site.RegularPages }})
    </button>
    {{ range $allTags.ByCount }}
    <button class="tag-btn" data-tag="{{ .Page.Title }}">
      {{ .Page.Title }} <span style="opacity:.6">({{ .Count }})</span>
    </button>
    {{ end }}
  </nav>

  <div class="gallery-wrap">
    <div class="gallery" id="gallery">
      {{ range sort site.RegularPages "Params.num" "desc" }}
        {{ template "card" . }}
      {{ end }}
    </div>
    <p class="gallery-empty" id="gallery-empty" hidden>No prompts found.</p>
  </div>
  {{ end }}
  ```

- [ ] **Step 5.2: Verify Hugo builds**

  ```bash
  hugo --minify 2>&1 | tail -5
  ```
  Expected: no errors.

- [ ] **Step 5.3: Commit**

  ```bash
  git add layouts/index.html
  git commit -m "feat: add service filter bar and refactor homepage to use card partial

  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
  ```

---

## Task 6: baseof.html — Logo, Filter JS, Lightbox

**Files:**
- Modify: `layouts/_default/baseof.html`

Three changes to this file:
1. Line 23: Update logo text `🍌 <span>Nano Banana</span> Prompts` → `🖼️ <span>Image Gen</span> Prompts`
2. JS filter: extend to handle service filter buttons + `data-services` matching
3. Lightbox: extend binding from `.prompt-content img` to also cover `.service-comparison img`

- [ ] **Step 6.1: Update logo text**

  In `layouts/_default/baseof.html`, replace:
  ```html
    <a class="site-logo" href="{{ site.Home.RelPermalink }}">🍌 <span>Nano Banana</span> Prompts</a>
  ```
  With:
  ```html
    <a class="site-logo" href="{{ site.Home.RelPermalink }}">🖼️ <span>Image Gen</span> Prompts</a>
  ```

- [ ] **Step 6.2: Extend lightbox binding**

  Replace:
  ```js
  // ── Image lightbox on prompt pages ──
  document.querySelectorAll('.prompt-content img').forEach(img => {
    img.addEventListener('click', () => openLightbox(img.src, img.alt));
  });
  ```
  With:
  ```js
  // ── Image lightbox on prompt pages + service comparison ──
  document.querySelectorAll('.prompt-content img, .service-comparison img').forEach(img => {
    img.addEventListener('click', () => openLightbox(img.src, img.alt));
  });
  ```

- [ ] **Step 6.3: Extend filter JS for service filter**

  Replace the entire gallery search + tag filter script block:
  ```js
  // ── Gallery search + tag filter ──
  const cards = document.querySelectorAll('.card');
  const filterBtns = document.querySelectorAll('.tag-btn');
  const searchInput = document.getElementById('search-input');
  let activeTag = 'all';

  function applyFilters() {
    const q = (searchInput?.value || '').toLowerCase().trim();
    let visible = 0;
    cards.forEach(card => {
      const tags = (card.dataset.tags || '').toLowerCase();
      const title = (card.dataset.title || '').toLowerCase();
      const tagMatch = activeTag === 'all' || tags.includes(activeTag.toLowerCase());
      const searchMatch = !q || title.includes(q) || tags.includes(q);
      const show = tagMatch && searchMatch;
      card.hidden = !show;
      if (show) visible++;
    });
    const empty = document.getElementById('gallery-empty');
    if (empty) empty.hidden = visible > 0;
  }

  filterBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      filterBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      activeTag = btn.dataset.tag;
      applyFilters();
    });
  });
  if (searchInput) searchInput.addEventListener('input', applyFilters);
  ```

  With:
  ```js
  // ── Gallery search + service + tag filter ──
  const cards = document.querySelectorAll('.card');
  const tagBtns = document.querySelectorAll('.tag-btn[data-tag]');
  const serviceBtns = document.querySelectorAll('.service-btn[data-service]');
  const searchInput = document.getElementById('search-input');
  let activeTag = 'all';
  let activeService = 'all';

  function applyFilters() {
    const q = (searchInput?.value || '').toLowerCase().trim();
    let visible = 0;
    cards.forEach(card => {
      const tags = (card.dataset.tags || '').toLowerCase();
      const services = (card.dataset.services || '').split(',');
      const title = (card.dataset.title || '').toLowerCase();
      const tagMatch = activeTag === 'all' || tags.includes(activeTag.toLowerCase());
      const serviceMatch = activeService === 'all' || services.includes(activeService);
      const searchMatch = !q || title.includes(q) || tags.includes(q);
      const show = tagMatch && serviceMatch && searchMatch;
      card.hidden = !show;
      if (show) visible++;
    });
    const empty = document.getElementById('gallery-empty');
    if (empty) empty.hidden = visible > 0;
  }

  tagBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      tagBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      activeTag = btn.dataset.tag;
      applyFilters();
    });
  });

  serviceBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      serviceBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      activeService = btn.dataset.service;
      applyFilters();
    });
  });

  if (searchInput) searchInput.addEventListener('input', applyFilters);
  ```

- [ ] **Step 6.4: Verify Hugo builds**

  ```bash
  hugo --minify 2>&1 | tail -5
  ```
  Expected: no errors.

- [ ] **Step 6.5: Commit**

  ```bash
  git add layouts/_default/baseof.html
  git commit -m "feat: update logo, extend filter JS for services, extend lightbox

  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
  ```

---

## Task 7: Detail Page — Service Comparison Block

**Files:**
- Modify: `layouts/_default/single.html`

Add the `service-comparison` block between `<header>` and `<div class="prompt-content">`.

- [ ] **Step 7.1: Add service comparison block to single.html**

  In `layouts/_default/single.html`, replace:
  ```html
    <div class="prompt-content">
      {{ .Content }}
    </div>
  ```
  With:
  ```go-html-template
    {{ $images := .Params.service_images }}
    {{ if $images }}
      {{ $services := partial "service-resolve.html" . }}
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

    <div class="prompt-content">
      {{ .Content }}
    </div>
  ```

- [ ] **Step 7.2: Verify Hugo builds**

  ```bash
  hugo --minify 2>&1 | tail -5
  ```
  Expected: no errors.

- [ ] **Step 7.3: Smoke test with a multi-service prompt**

  Write a temporary test file directly and verify comparison block renders:
  ```bash
  cat > content/prompts/999-test-multi-service.md << 'TESTEOF'
  ---
  title: "Test Multi Service"
  num: 9999
  tags:
    - "Art Styles"
  cover: "https://picsum.photos/400/300"
  services:
    - "nano-banana"
    - "gpt-image"
  service_images:
    nano-banana: "https://picsum.photos/400/301"
    gpt-image: "https://picsum.photos/400/302"
  date: 2026-05-11
  ---
  ### Prompt
  > A test prompt for multi-service comparison.
  TESTEOF
  hugo --minify 2>&1 | tail -5
  grep -c "service-comparison" public/prompts/999-test-multi-service/index.html
  ```
  Expected: build succeeds and grep outputs `1` or more (block rendered in HTML).

- [ ] **Step 7.4: Remove temporary test file**

  ```bash
  rm content/prompts/999-test-multi-service.md
  rm -rf public/prompts/999-test-multi-service/
  ```

- [ ] **Step 7.5: Commit**

  ```bash
  git add layouts/_default/single.html
  git commit -m "feat: add service comparison block to detail page

  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
  ```

---

## Task 8: new-prompt.sh — Service Multi-Select + Service Images

**Files:**
- Modify: `scripts/new-prompt.sh`

Three changes:
1. Update header comment (line 2)
2. Add service selection step (after Source URL, before step loop)
3. Add service_images collection step (after step loop, only when 2+ services)
4. Update frontmatter generation

- [ ] **Step 8.1: Update header comment**

  Replace line 2:
  ```bash
  # new-prompt.sh — Interactively add a new prompt to the Nano Banana gallery.
  ```
  With:
  ```bash
  # new-prompt.sh — Interactively add a new prompt to the Image Gen Prompts gallery.
  ```

- [ ] **Step 8.2: Add service selection step**

  After the Source URL block (after line `SOURCEVAL="${HANDLE:+@${HANDLE}}"`), and before the step loop comment `# ── Step loop`, insert:

  ```bash
  # ── Service selection ─────────────────────────────────────────────────────────
  # Read available services from data/services.yaml using bash 3.2+ compatible parsing.
  # Uses parallel arrays (no associative arrays).
  SVC_SLUGS=()
  SVC_NAMES=()
  SERVICES_YAML_FILE="$REPO_ROOT/data/services.yaml"

  if [[ -f "$SERVICES_YAML_FILE" ]]; then
    if command -v yq &>/dev/null; then
      # Fast path: yq available
      while IFS= read -r slug; do
        SVC_SLUGS+=("$slug")
      done < <(yq '.[].slug' "$SERVICES_YAML_FILE" 2>/dev/null | tr -d '"')
      while IFS= read -r name; do
        SVC_NAMES+=("$name")
      done < <(yq '.[].name' "$SERVICES_YAML_FILE" 2>/dev/null | tr -d '"')
    else
      # Fallback: line-by-line grep parsing of the YAML list format
      # Matches: `  slug: "nano-banana"` and `  name: "Nano Banana"`
      while IFS= read -r line; do
        if [[ "$line" =~ slug:[[:space:]]+\"([^\"]+)\" ]]; then
          SVC_SLUGS+=("${BASH_REMATCH[1]}")
        elif [[ "$line" =~ name:[[:space:]]+\"([^\"]+)\" ]]; then
          SVC_NAMES+=("${BASH_REMATCH[1]}")
        fi
      done < "$SERVICES_YAML_FILE"
    fi
  fi

  # Last-resort fallback: file missing or parse yielded nothing
  if [[ ${#SVC_SLUGS[@]} -eq 0 ]]; then
    warn "Could not read data/services.yaml — using built-in defaults"
    SVC_SLUGS=("nano-banana" "gpt-image")
    SVC_NAMES=("Nano Banana" "GPT Image")
  fi

  # Default: nano-banana pre-selected
  SVC_SELECTED=()
  for i in "${!SVC_SLUGS[@]}"; do
    [[ "${SVC_SLUGS[$i]}" == "nano-banana" ]] && SVC_SELECTED+=(1) || SVC_SELECTED+=(0)
  done

  echo ""
  info "--- Services ---"
  while true; do
    echo ""
    for i in "${!SVC_SLUGS[@]}"; do
      mark="  "
      [[ "${SVC_SELECTED[$i]}" == "1" ]] && mark="✓ "
      printf "  [%2d] %s%s\n" "$((i+1))" "$mark" "${SVC_NAMES[$i]}"
    done
    echo ""
    printf "Toggle service number(s) (space-separated), or press Enter to accept: "
    IFS= read -r toggles
    [[ -z "$toggles" ]] && break
    for t in $toggles; do
      if [[ "$t" =~ ^[0-9]+$ ]] && (( t >= 1 && t <= ${#SVC_SLUGS[@]} )); then
        idx=$((t - 1))
        [[ "${SVC_SELECTED[$idx]}" == "1" ]] && SVC_SELECTED[$idx]=0 || SVC_SELECTED[$idx]=1
      else
        warn "  Invalid: $t (must be 1–${#SVC_SLUGS[@]})"
      fi
    done
  done

  SELECTED_SERVICES=()
  SELECTED_SERVICE_NAMES=()
  for i in "${!SVC_SLUGS[@]}"; do
    if [[ "${SVC_SELECTED[$i]}" == "1" ]]; then
      SELECTED_SERVICES+=("${SVC_SLUGS[$i]}")
      SELECTED_SERVICE_NAMES+=("${SVC_NAMES[$i]}")
    fi
  done

  # Ensure at least one service is selected
  if [[ ${#SELECTED_SERVICES[@]} -eq 0 ]]; then
    warn "No service selected — defaulting to Nano Banana"
    SELECTED_SERVICES=("nano-banana")
    SELECTED_SERVICE_NAMES=("Nano Banana")
  fi
  ```

- [ ] **Step 8.3: Add service_images collection step**

  After the step loop (after `[[ "$more" != "y" && "$more" != "Y" ]] && break` / `done`), and before the image URL / dest build block, insert:

  ```bash
  # ── Service images (only when 2+ services selected) ──────────────────────────
  # Parallel arrays for bash 3.2+ compatibility
  SERVICE_IMAGE_SLUGS=()
  SERVICE_IMAGE_URLS=()

  if [[ ${#SELECTED_SERVICES[@]} -gt 1 ]]; then
    echo ""
    info "--- Service Images ---"
    info "(Optional: provide a result image URL for each service, or press Enter to skip)"
    for i in "${!SELECTED_SERVICES[@]}"; do
      slug="${SELECTED_SERVICES[$i]}"
      name="${SELECTED_SERVICE_NAMES[$i]}"
      printf "  Image URL for %s (or Enter to skip): " "$name"
      IFS= read -r svc_img_url
      svc_img_url="${svc_img_url# }"; svc_img_url="${svc_img_url% }"
      if [[ -n "$svc_img_url" ]]; then
        SERVICE_IMAGE_SLUGS+=("$slug")
        SERVICE_IMAGE_URLS+=("$svc_img_url")
      fi
    done
  fi
  ```

- [ ] **Step 8.4: Update frontmatter generation**

  In the frontmatter block (around line 308), replace:
  ```bash
  CONTENT="---
  title: \"${TITLE}\"
  num: ${NUM}
  tags:
  ${TAG_YAML}cover: \"${COVER_URL}\"
  source: \"${SOURCEVAL}\"
  sourceUrl: \"${SOURCE_URL}\"
  date: ${TODAY}
  ---
  ```
  With:
  ```bash
  # Build services YAML block (always written)
  SERVICES_YAML_BLOCK=""
  for slug in "${SELECTED_SERVICES[@]}"; do
    SERVICES_YAML_BLOCK="${SERVICES_YAML_BLOCK}  - \"${slug}\""$'\n'
  done

  # Build service_images YAML block (only if any URLs were provided)
  SERVICE_IMAGES_YAML_BLOCK=""
  for i in "${!SERVICE_IMAGE_SLUGS[@]}"; do
    slug="${SERVICE_IMAGE_SLUGS[$i]}"
    url="${SERVICE_IMAGE_URLS[$i]}"
    [[ -n "$url" ]] && SERVICE_IMAGES_YAML_BLOCK="${SERVICE_IMAGES_YAML_BLOCK}  ${slug}: \"${url}\""$'\n'
  done

  # Build service_images frontmatter section (empty string if no images)
  SVC_IMAGES_FM=""
  if [[ -n "$SERVICE_IMAGES_YAML_BLOCK" ]]; then
    SVC_IMAGES_FM="service_images:
  ${SERVICE_IMAGES_YAML_BLOCK}"
  fi

  CONTENT="---
  title: \"${TITLE}\"
  num: ${NUM}
  tags:
  ${TAG_YAML}services:
  ${SERVICES_YAML_BLOCK}${SVC_IMAGES_FM}cover: \"${COVER_URL}\"
  source: \"${SOURCEVAL}\"
  sourceUrl: \"${SOURCE_URL}\"
  date: ${TODAY}
  ---
  ```

- [ ] **Step 8.5: Verify script syntax**

  ```bash
  bash -n scripts/new-prompt.sh
  ```
  Expected: no output (syntax OK).

- [ ] **Step 8.6: Commit**

  ```bash
  git add scripts/new-prompt.sh
  git commit -m "feat: add service selection and service_images to new-prompt.sh

  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
  ```

---

## Task 9: Final Verification

- [ ] **Step 9.1: Clean build**

  ```bash
  rm -rf public/
  hugo --minify 2>&1 | tail -10
  ```
  Expected: `Total in NNN ms` with no WARN or ERROR lines.

- [ ] **Step 9.2: Verify backward compatibility**

  Check that an existing prompt without `services` renders with default service badge:
  ```bash
  grep -l "nano-banana" public/prompts/001-*/index.html 2>/dev/null | head -3
  ```
  Expected: at least one file listed (existing prompts default to nano-banana badge).

- [ ] **Step 9.3: Verify service filter bar exists on homepage**

  ```bash
  grep -c "service-btn" public/index.html
  ```
  Expected: `3` or more (All Services + 2 service buttons).

- [ ] **Step 9.4: Verify card data-services attribute**

  ```bash
  grep -m3 'data-services=' public/index.html
  ```
  Expected: cards have `data-services="nano-banana"` (or other slugs).

- [ ] **Step 9.5: Push and confirm GitHub Pages deployment**

  ```bash
  git push
  ```
  Then check GitHub Actions at https://github.com/wm4n/nano-banana-prompt/actions — wait for green.

---

## Spec Reference

Full design spec: `docs/superpowers/specs/2026-05-11-multi-service-support-design.md`
