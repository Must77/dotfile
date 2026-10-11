#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  extract_assets.sh --pdf FILE --assets DIR --tmp-dir DIR --text FILE

Extracts large raster images, removes small/noise candidates, converts only
formats that common Markdown renderers cannot display, and prepares manifests
plus 150-DPI previews for pages that mention figures.
EOF
}

die() {
  printf 'extract_assets.sh: %s\n' "$*" >&2
  exit 1
}

require_value() {
  [[ $# -ge 2 && -n ${2:-} ]] || die "missing value for $1"
}

pdf=
assets_dir=
tmp_dir=
text_file=

while (($#)); do
  case "$1" in
    --pdf)
      require_value "$@"
      pdf=$2
      shift 2
      ;;
    --assets)
      require_value "$@"
      assets_dir=$2
      shift 2
      ;;
    --tmp-dir)
      require_value "$@"
      tmp_dir=$2
      shift 2
      ;;
    --text)
      require_value "$@"
      text_file=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[[ -f $pdf ]] || die "PDF does not exist: $pdf"
[[ -f $text_file ]] || die "canonical text does not exist: $text_file"
[[ -d $tmp_dir ]] || die "temporary directory does not exist: $tmp_dir"
[[ $tmp_dir == /tmp/pdf2md_translate_???? ]] ||
  die "temporary directory must match /tmp/pdf2md_translate_XXXX"
mkdir -p -- "$assets_dir"

for cmd in pdfimages pdftoppm awk cut find grep sed sort; do
  command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required"
done

image_list="$tmp_dir/pdfimages-list.txt"
large_tsv="$tmp_dir/pdf_large_images.tsv"
allowlist="$tmp_dir/pdf_large_images.txt"
candidate_manifest="$tmp_dir/image_candidates.tsv"
figure_mentions="$tmp_dir/figure_mentions.tsv"
figure_mapping="$tmp_dir/figure_mapping.tsv"
preview_dir="$tmp_dir/vector_previews"

pdfimages -list "$pdf" > "$image_list"

awk '
  !seen_header {
    for (i = 1; i <= NF; i++) {
      if ($i == "page") page_col = i
      if ($i == "num") num_col = i
      if ($i == "width") width_col = i
      if ($i == "height") height_col = i
    }
    if (num_col && width_col && height_col) seen_header = 1
    next
  }
  $num_col ~ /^[0-9]+$/ && $width_col ~ /^[0-9]+$/ && $height_col ~ /^[0-9]+$/ {
    if ($width_col > 100 && $height_col > 100) {
      printf "%03d\t%s\t%s\t%s\n", $num_col, (page_col ? $page_col : "?"), $width_col, $height_col
    }
  }
' "$image_list" > "$large_tsv"
cut -f1 "$large_tsv" > "$allowlist"

pdfimages -j "$pdf" "$assets_dir/img"

find "$assets_dir" -maxdepth 1 -type f -name 'img-*' -print0 |
  while IFS= read -r -d '' file; do
    image_index=$(basename "$file" | sed -E 's/^img-([0-9]+).*/\1/')
    if ! grep -qx "$image_index" "$allowlist"; then
      unlink "$file"
    fi
  done

convert_command=
if command -v magick >/dev/null 2>&1; then
  convert_command=magick
elif command -v convert >/dev/null 2>&1; then
  convert_command=convert
fi

find "$assets_dir" -maxdepth 1 -type f -name 'img-*' -print0 |
  while IFS= read -r -d '' file; do
    extension=${file##*.}
    extension=${extension,,}
    case "$extension" in
      jpg|jpeg|png|gif|webp|svg)
        ;;
      *)
        [[ -n $convert_command ]] ||
          die "cannot convert Markdown-incompatible image format: $file"
        output="${file%.*}.png"
        if [[ $convert_command == magick ]]; then
          magick "$file" "$output"
        else
          convert "$file" "$output"
        fi
        [[ -s $output ]] || die "image conversion produced no output: $file"
        unlink "$file"
        ;;
    esac
  done

# The user prefers aggressive noise removal for papers with few figures.
find "$assets_dir" -maxdepth 1 -type f -name 'img-*' -size -10k -print0 |
  while IFS= read -r -d '' file; do
    unlink "$file"
  done

printf 'source_index\tpage\twidth\theight\tformat\tcandidate_file\n' > "$candidate_manifest"
find "$assets_dir" -maxdepth 1 -type f -name 'img-*' -print0 | sort -z |
  while IFS= read -r -d '' file; do
    image_index=$(basename "$file" | sed -E 's/^img-([0-9]+).*/\1/')
    row=$(awk -F '\t' -v image_index="$image_index" \
      '$1 == image_index {print; exit}' "$large_tsv")
    [[ -n $row ]] || continue
    page=$(printf '%s\n' "$row" | cut -f2)
    width=$(printf '%s\n' "$row" | cut -f3)
    height=$(printf '%s\n' "$row" | cut -f4)
    extension=${file##*.}
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$image_index" "$page" "$width" "$height" "${extension,,}" "$(basename "$file")" \
      >> "$candidate_manifest"
  done

printf 'page\tline\tmention\n' > "$figure_mentions"
awk '
  BEGIN { page = 1 }
  {
    segment_count = split($0, segments, /\f/)
    for (segment = 1; segment <= segment_count; segment++) {
      if (segment > 1) page++
      line = segments[segment]
      if (line ~ /(^|[^[:alnum:]_])(Figure|Fig\.)[[:space:]]*[0-9]+/) {
        gsub(/\t/, " ", line)
        print page "\t" NR "\t" line
      }
    }
  }
' "$text_file" >> "$figure_mentions"

mkdir -p -- "$preview_dir"
tail -n +2 "$figure_mentions" | cut -f1 | sort -n -u |
  while IFS= read -r page; do
    [[ $page =~ ^[0-9]+$ ]] || continue
    pdftoppm -f "$page" -l "$page" -singlefile -r 150 -png \
      "$pdf" "$preview_dir/page-$page" >/dev/null 2>&1
  done

printf 'figure_id\tpage\tcaption\tsource_indices\tcandidate_files\tfinal_file\tstatus\n' \
  > "$figure_mapping"

raster_count=$(tail -n +2 "$candidate_manifest" | wc -l)
preview_count=$(find "$preview_dir" -maxdepth 1 -type f -name 'page-*.png' | wc -l)
printf 'RASTER_CANDIDATES\t%s\n' "$raster_count"
printf 'VECTOR_PREVIEWS\t%s\n' "$preview_count"
printf 'IMAGE_MANIFEST\t%s\n' "$candidate_manifest"
printf 'FIGURE_MENTIONS\t%s\n' "$figure_mentions"
printf 'FIGURE_MAPPING\t%s\n' "$figure_mapping"
printf 'PREVIEW_DIR\t%s\n' "$preview_dir"
