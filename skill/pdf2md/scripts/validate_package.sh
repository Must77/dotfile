#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  validate_package.sh --out DIR [--name SHORT_NAME] [--mapping FILE]
                      [--section-manifest FILE]

Performs mechanical validation of a completed PDF reading package. Translation
meaning and PDF-to-Markdown content coverage still require manual review.
EOF
}

die() {
  printf 'validate_package.sh: %s\n' "$*" >&2
  exit 1
}

require_value() {
  [[ $# -ge 2 && -n ${2:-} ]] || die "missing value for $1"
}

out_dir=
short_name=
mapping_file=
section_manifest=

while (($#)); do
  case "$1" in
    --out)
      require_value "$@"
      out_dir=$2
      shift 2
      ;;
    --name)
      require_value "$@"
      short_name=$2
      shift 2
      ;;
    --mapping)
      require_value "$@"
      mapping_file=$2
      shift 2
      ;;
    --section-manifest)
      require_value "$@"
      section_manifest=$2
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

[[ -d $out_dir ]] || die "package directory does not exist: $out_dir"
command -v realpath >/dev/null 2>&1 || die "realpath is required"
out_dir=$(realpath "$out_dir")
if [[ -z $short_name ]]; then
  short_name=$(basename "$out_dir")
fi
[[ $short_name =~ ^[a-z]+(_[a-z]+){2,6}$ ]] ||
  die "package name must be 3-7 lowercase English words joined by underscores"
[[ $(basename "$out_dir") == "$short_name" ]] ||
  die "package directory name does not match SHORT_NAME"

for cmd in pdfinfo iconv diff sed awk grep find sort tr cat head tail wc dirname; do
  command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required"
done

mapfile -d '' pdf_files < <(find "$out_dir" -maxdepth 1 -type f -iname '*.pdf' -print0)
((${#pdf_files[@]} == 1)) || die "package must contain exactly one PDF"
pdf_path=${pdf_files[0]}
[[ $(basename "$pdf_path") == "$short_name.pdf" ]] ||
  die "canonical PDF must be named $short_name.pdf"
pdfinfo "$pdf_path" >/dev/null 2>&1 || die "canonical PDF is unreadable"

origin="$out_dir/origin.md"
translated="$out_dir/translated.md"
[[ -s $origin ]] || die "origin.md is missing or empty"
[[ -s $translated ]] || die "translated.md is missing or empty"
iconv -f UTF-8 -t UTF-8 "$origin" >/dev/null || die "origin.md is not valid UTF-8"
iconv -f UTF-8 -t UTF-8 "$translated" >/dev/null || die "translated.md is not valid UTF-8"

[[ $(grep -c '^# ' "$origin") -eq 1 ]] || die "origin.md must contain exactly one H1"
[[ $(grep -c '^# ' "$translated") -eq 1 ]] || die "translated.md must contain exactly one H1"

if ! diff -u \
  <(sed -nE 's/^(##|###) .*/\1/p' "$origin") \
  <(sed -nE 's/^(##|###) .*/\1/p' "$translated"); then
  die "H2/H3 heading-level sequences differ"
fi

extract_images() {
  sed -nE 's/.*\((assets\/[^)]+)\).*/\1/p' "$1"
}

if ! diff -u <(extract_images "$origin") <(extract_images "$translated"); then
  die "ordered image-path lists differ"
fi

mapfile -t image_paths < <(extract_images "$origin")
for image_path in "${image_paths[@]}"; do
  [[ $image_path != *'..'* ]] || die "unsafe image path: $image_path"
  [[ -f "$out_dir/$image_path" ]] || die "referenced image is missing: $image_path"
done

table_signature() {
  awk '
    function flush_table() {
      if (in_table) {
        print table_no ":" rows ":" columns
        in_table = 0
        rows = 0
        columns = 0
      }
    }
    /^\|/ {
      separators = gsub(/\|/, "&")
      cells = separators - 1
      if (!in_table) {
        table_no++
        in_table = 1
        columns = cells
      }
      if (cells != columns) {
        print "invalid table " table_no ": inconsistent column count" > "/dev/stderr"
        invalid = 1
      }
      rows++
      next
    }
    { flush_table() }
    END {
      flush_table()
      if (invalid) exit 2
    }
  ' "$1"
}

if ! table_signature "$origin" >/dev/null; then
  die "origin.md contains a Markdown table with inconsistent columns"
fi
if ! table_signature "$translated" >/dev/null; then
  die "translated.md contains a Markdown table with inconsistent columns"
fi
if ! diff -u <(table_signature "$origin") <(table_signature "$translated"); then
  die "Markdown table row/column structures differ"
fi

extract_table_numbers() {
  grep -E '^\|' "$1" | grep -Eo '[-+]?[0-9][0-9.,%]*' || true
}

if ! diff -u <(extract_table_numbers "$origin") <(extract_table_numbers "$translated"); then
  die "ordered numeric values in Markdown tables differ"
fi

normalize_display_math() {
  sed -n '/^\$\$$/,/^\$\$$/p' "$1" |
    sed -E 's/\\text\{[^}]*\}/\\text{}/g' |
    tr -d '[:space:]'
}

if ! diff -u <(normalize_display_math "$origin") <(normalize_display_math "$translated"); then
  die "display-equation structure differs outside translatable \\text{...} content"
fi

grep -qx '## References' "$origin" || die "origin.md must use the heading: ## References"
grep -qx '## 参考文献' "$translated" || die "translated.md must use the heading: ## 参考文献"

extract_references() {
  heading=$1
  file=$2
  awk -v heading="$heading" '$0 == heading {found=1; next} found {print}' "$file"
}

if ! diff -u \
  <(extract_references '## References' "$origin") \
  <(extract_references '## 参考文献' "$translated"); then
  die "reference entries differ"
fi

if [[ -n $section_manifest ]]; then
  [[ -s $section_manifest ]] ||
    die "section manifest is missing or empty: $section_manifest"
  expected_header=$'section_order\ttitle\tsource_pages\torigin_status\ttranslation_status'
  [[ $(head -n 1 "$section_manifest") == "$expected_header" ]] ||
    die "section manifest has an invalid header"

  if ! awk -F '\t' '
    NR == 1 {next}
    NF != 5 {
      print "section manifest row must contain five fields: " $0 > "/dev/stderr"
      invalid = 1
      next
    }
    $1 !~ /^[0-9]+$/ || $2 == "" || $3 == "" {
      print "invalid section order, title, or source_pages: " $0 > "/dev/stderr"
      invalid = 1
    }
    $4 != "completed" || $5 != "completed" {
      print "incomplete section row: " $0 > "/dev/stderr"
      invalid = 1
    }
    END {if (invalid) exit 2}
  ' "$section_manifest"; then
    die "section manifest contains invalid or incomplete rows"
  fi

  mapfile -t h2_titles < <(sed -nE 's/^## (.*)$/\1/p' "$origin")
  expected_rows=$((${#h2_titles[@]} + 1))
  actual_rows=$(tail -n +2 "$section_manifest" | wc -l)
  ((actual_rows == expected_rows)) ||
    die "section manifest must contain front_matter plus every origin.md H2 section"

  sections_dir="$(dirname "$section_manifest")/sections"
  [[ -d $sections_dir ]] || die "section chunk directory is missing: $sections_dir"
  expected_order=0
  while IFS=$'\t' read -r order title source_pages origin_status translation_status; do
    [[ $order == "$expected_order" ]] ||
      die "section order must be consecutive from 0; expected $expected_order, found $order"
    if ((expected_order == 0)); then
      [[ $title == front_matter ]] || die "section 0 must be titled front_matter"
    else
      title_index=$((expected_order - 1))
      [[ $title == "${h2_titles[$title_index]}" ]] ||
        die "section title does not match origin.md H2 order: $title"
    fi
    printf -v prefix '%03d' "$order"
    [[ -s "$sections_dir/${prefix}_origin.md" ]] ||
      die "missing origin section chunk: ${prefix}_origin.md"
    [[ -s "$sections_dir/${prefix}_translated.md" ]] ||
      die "missing translated section chunk: ${prefix}_translated.md"
    expected_order=$((expected_order + 1))
  done < <(tail -n +2 "$section_manifest")

  concatenate_chunks() {
    kind=$1
    while IFS=$'\t' read -r order title source_pages origin_status translation_status; do
      printf -v prefix '%03d' "$order"
      cat "$sections_dir/${prefix}_${kind}.md"
    done < <(tail -n +2 "$section_manifest")
  }

  if ! diff -u "$origin" <(concatenate_chunks origin); then
    die "origin section chunks do not reproduce origin.md exactly"
  fi
  if ! diff -u "$translated" <(concatenate_chunks translated); then
    die "translated section chunks do not reproduce translated.md exactly"
  fi
fi

mapfile -t figure_paths < <(extract_images "$origin" | grep '^assets/fig' || true)
if ((${#figure_paths[@]} > 0)); then
  [[ -n $mapping_file ]] || die "--mapping is required when figures are embedded"
  [[ -s $mapping_file ]] || die "figure mapping is missing or empty: $mapping_file"

  validate_mapping() {
    awk -F '\t' '
      NR == 1 {next}
      NF {
        if (NF < 7) {
          print "mapping row has fewer than seven fields: " $0 > "/dev/stderr"
          invalid = 1
        }
        if ($7 != "verified") {
          print "unverified mapping row: " $1 > "/dev/stderr"
          invalid = 1
        }
        if ($6 == "") {
          print "mapping row lacks final_file: " $1 > "/dev/stderr"
          invalid = 1
        }
      }
      END {if (invalid) exit 2}
    ' "$mapping_file"
  }

  if ! validate_mapping >/dev/null; then
    die "figure mapping contains incomplete or unverified rows"
  fi

  mapping_paths() {
    awk -F '\t' 'NR > 1 && NF {print $6}' "$mapping_file" | sort
  }

  if ! diff -u <(printf '%s\n' "${figure_paths[@]}" | sort) <(mapping_paths); then
    die "verified figure mapping does not cover the embedded figure paths"
  fi
fi

printf 'Validation passed: %s\n' "$out_dir"
printf 'PDF: %s\n' "$(basename "$pdf_path")"
printf 'Figures: %s\n' "${#figure_paths[@]}"
printf 'Images: %s\n' "${#image_paths[@]}"
