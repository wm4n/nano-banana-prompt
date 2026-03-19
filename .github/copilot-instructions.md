# Copilot Instructions for Nano Banana Prompt Gallery

## Project Overview

A **Hugo-based static gallery website** displaying 115+ AI image generation prompts for the Nano Banana ChatGPT integration. The site is published to GitHub Pages and automatically rebuilt on push to `main`.

- **Stack**: Hugo (static site generator), HTML/CSS, Markdown
- **Hosting**: GitHub Pages (https://wm4n.github.io/nano-banana-prompt/)
- **CI/CD**: GitHub Actions workflow on push to `main`

## Build & Deployment

### Local Development
```bash
brew install hugo                    # Install Hugo (macOS)
hugo server                          # Start dev server at http://localhost:1313/nano-banana-prompt/
hugo server --buildDrafts           # Include draft content
hugo --minify                        # Production build (creates ./public/)
```

### Automated Deployment
- GitHub Actions (`.github/workflows/deploy.yml`) automatically builds and deploys on every push to `main`
- Uses Hugo v0.158.0 extended version
- Builds with `hugo --minify` and deploys to GitHub Pages

## Content Structure

### Adding New Prompts
1. Create a new `.md` file in `content/prompts/` named with the pattern: `{number}-{slug}.md`
2. Use the frontmatter format below
3. Push to `main` — site rebuilds automatically

### Prompt Frontmatter Template
```yaml
---
title: "Prompt Title"
num: 114                             # Sequential number
tags:
  - "Category Name"                  # Must match existing tags
cover: "https://github.com/user-attachments/assets/..."
source: "@twitter_handle"
sourceUrl: "https://x.com/..."
date: 2026-03-19
---

<img src="..." alt="..." />

### Prompt

> Your prompt text here...

from [@handle](https://x.com/...)
```

### Existing Categories (Tags)
Pick from these when adding tags:
- Art Styles
- Character & Portrait
- City & Architecture
- 3D & Miniature
- Infographic & UI
- Effects & Composite
- Photo & Cinematic
- Food & Commercial
- Poster & Nature
- Icons & Stickers

## Key Configuration Files

### `hugo.toml`
- **baseURL**: Set to GitHub Pages URL (`https://wm4n.github.io/nano-banana-prompt/`)
- **Taxonomies**: Configured with `tag` taxonomy for categorization
- **Pagination**: Set to 200 items per page
- **Markup**: Goldmark with unsafe HTML allowed (needed for `<img>` tags in prompts)

## Layout & Templating

### Template Structure
- `layouts/_default/baseof.html` — Base HTML template with head/body structure
- `layouts/_default/single.html` — Individual prompt page layout
- `layouts/_default/list.html` — Category/tag listing page
- `layouts/_default/terms.html` — Terms (tags) overview page
- `layouts/partials/card.html` — Reusable prompt card component
- `layouts/partials/head.html` — HTML head section (meta tags, styles)
- `layouts/index.html` — Custom homepage

### Templating Notes
- All page templates use Hugo's `{{ }}` syntax
- The site uses `{{ range }}` loops for displaying prompt collections
- Unsafe HTML rendering enabled in frontmatter allows embedding `<img>` tags directly in prompt content

## Hugo Conventions in This Project

- **Content Organization**: All prompts live in `content/prompts/`
- **Data Files**: Use `data/` directory for structured data (currently unused)
- **Static Assets**: `static/` directory for CSS, images, scripts
- **Internationalization**: `i18n/` directory (configured for `en-us`)
- **Archetypes**: `archetypes/` contains default templates for new content (useful for prompt templates)

## File Naming Conventions

- **Prompts**: `{3-digit-number}-{kebab-case-slug}.md` (e.g., `113-emerging-from-architectural-blueprint.md`)
- Keep numbers sequential; they appear in the gallery listings

## Common Tasks

### Add a new prompt
Create file in `content/prompts/` with frontmatter following the template above and push to `main`.

### Update the homepage
Edit `layouts/index.html` to customize the gallery overview page.

### Modify tags/categories
Edit the `tags:` array in frontmatter of existing prompts. Add new tag names as needed — Hugo automatically generates tag listing pages.

### Adjust styling
CSS files are in `static/` directory. Changes are reflected on rebuild.

## Deployment Notes

- Builds run with `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true` for Node.js action compatibility
- Artifacts uploaded to GitHub Pages after successful build
- Failed builds prevent deployment (no partial updates)
