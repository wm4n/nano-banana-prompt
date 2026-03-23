#!/usr/bin/env bash
# scripts/tags.sh — Single source of truth for tag definitions.
# Source this file; do not execute directly.
# Each entry: "slug|Human Label|kw1|kw2|..."

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: tags.sh is a library — source it, do not execute it." >&2
  exit 1
fi

TAG_DEFS=(
  "city-architecture|City & Architecture|city|urban|isometric|animal crossing|simcity|claymorphism|white clay|3d led|architectural blueprint|souvenir magnet|city brush|city scene"
  "3d-miniature|3D & Miniature|miniature|diorama|hologram|glass marble|cube diorama|chibi|tilt 3d|3d relief|hand paint miniature|3d hand|3d story|3d newspaper|concept store|different angle|survey board"
  "art-styles|Art Styles|watercolor|ink painting|ink drawing|pencil|crayon|sketch|embroidery|paper cut|folded paper|botanical|scribble|claymation|painterly|step by step drawing|draw like|style drawing|watercolor style|blueprint schematic"
  "character-portrait|Character & Portrait|character|caricature|portrait|sticker|hair style|pose|pixar|cartoon|idol|dress|editorial portrait|cute character|chat sticker|soft toy|mechanical bird"
  "photo-cinematic|Photo & Cinematic|photo|cinematic|angle shot|motion blur|upscale|restore|cherry blossom|raining|lat lon|taking photo"
  "infographic-ui|Infographic & UI|hud|infographic|report|ui/ux|heatmap|species migration|boarding pass|profile card|notebooklm|tech evolution|status report|architect|real-time"
  "effects-composite|Effects & Composite|neon effect|blending|season blend|mirror reflection|firework|emerge from|split effect|combine different|imagine events|surreal|era"
  "food-commercial|Food & Commercial|food|cuisine|fruit|dish|pixelize food|advertising food|recipe"
  "poster-nature|Poster & Nature|poster|magazine cover|wallpaper|gta|brand poster|cloud formation|sea of clouds|mountain|forest|bookshelves|story telling|concept art|looking through|peeking through"
  "icons-stickers|Icons & Stickers|icon generation|themed icon|different style icon"
  "gamification-education|Gamification & Education|gamification|workshop|team building|educational tool|scoring table|evaluation guide|training material|quiz|ranking logic|step by step guide|learning path|instructional design"
  "storytelling-scenario|Storytelling & Scenario|survival scenario|storytelling|roleplay|narrative context|world building|game setting|adventure|situation analysis|decision making|lost at sea|survival guide"
)

ALL_SLUGS=()
ALL_LABELS=()
ALL_KEYWORDS=()

for _def in "${TAG_DEFS[@]}"; do
  IFS='|' read -r _slug _label _kw_rest <<< "$_def"
  ALL_SLUGS+=("$_slug")
  ALL_LABELS+=("$_label")
  ALL_KEYWORDS+=("$_kw_rest")
done

unset _def _slug _label _kw_rest
