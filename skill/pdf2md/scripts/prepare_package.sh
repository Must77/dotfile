#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  prepare_package.sh --pdf FILE --name SHORT_NAME [--target-base DIR]
                     [--tmp-dir DIR] [--move|--copy]

Creates a canonical paper reading package. SHORT_NAME must contain 3-7
lowercase English words separated by underscores. The default mode is --move.
EOF
}

die() {
  printf 'prepare_package.sh: %s\n' "$*" >&2
  exit 1
}

require_value() {
  [[ $# -ge 2 && -n ${2:-} ]] || die "missing value for $1"
}

source_pdf=
target_base=
short_name=
tmp_dir=
mode=move
tmp_created=0
out_created=0
out_dir=

while (($#)); do
  case "$1" in
    --pdf)
      require_value "$@"
      source_pdf=$2
      shift 2
      ;;
    --target-base)
      require_value "$@"
      target_base=$2
      shift 2
      ;;
    --name)
      require_value "$@"
      short_name=$2
      shift 2
      ;;
    --tmp-dir)
      require_value "$@"
      tmp_dir=$2
      shift 2
      ;;
    --move)
      mode=move
      shift
      ;;
    --copy)
      mode=copy
      shift
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

[[ -n $source_pdf ]] || die "--pdf is required"
[[ -n $short_name ]] || die "--name is required"
[[ $short_name =~ ^[a-z]+(_[a-z]+){2,6}$ ]] ||
  die "SHORT_NAME must be 3-7 lowercase English words joined by underscores"
[[ -f $source_pdf ]] || die "source PDF does not exist: $source_pdf"
command -v pdfinfo >/dev/null 2>&1 || die "pdfinfo is required"
command -v realpath >/dev/null 2>&1 || die "realpath is required"

source_pdf=$(realpath "$source_pdf")
pdfinfo "$source_pdf" >/dev/null 2>&1 || die "source PDF is unreadable: $source_pdf"

if [[ -z $target_base ]]; then
  target_base=$(dirname "$source_pdf")
fi
mkdir -p -- "$target_base"
target_base=$(realpath "$target_base")
out_dir="$target_base/$short_name"
pdf_path="$out_dir/$short_name.pdf"
assets_dir="$out_dir/assets"

if [[ -n $tmp_dir ]]; then
  [[ -d $tmp_dir ]] || die "--tmp-dir is not a directory: $tmp_dir"
  [[ $tmp_dir == /tmp/pdf2md_translate_???? ]] ||
    die "temporary directory must match /tmp/pdf2md_translate_XXXX"
  tmp_dir=$(realpath "$tmp_dir")
else
  tmp_dir=$(mktemp -d /tmp/pdf2md_translate_XXXX)
  tmp_created=1
fi

cleanup_on_error() {
  status=$?
  if ((status != 0)); then
    if ((tmp_created)); then
      rmdir -- "$tmp_dir" 2>/dev/null || true
    fi
    if ((out_created)); then
      rmdir -- "$assets_dir" 2>/dev/null || true
      rmdir -- "$out_dir" 2>/dev/null || true
    fi
  fi
  return "$status"
}
trap cleanup_on_error EXIT

canonical_existing=0
if [[ -e $out_dir ]]; then
  if [[ -f $pdf_path ]] && [[ $(realpath "$pdf_path") == "$source_pdf" ]]; then
    canonical_existing=1
    mkdir -p -- "$assets_dir"
  else
    die "destination already exists; choose a more specific semantic name: $out_dir"
  fi
else
  mkdir -- "$out_dir"
  out_created=1
  mkdir -- "$assets_dir"
fi

if ((!canonical_existing)); then
  if [[ $mode == copy ]]; then
    cp -- "$source_pdf" "$pdf_path"
  else
    mv -- "$source_pdf" "$pdf_path"
  fi
fi

manifest="$tmp_dir/run.tsv"
printf 'key\tvalue\n' > "$manifest"
printf 'TMP_DIR\t%s\n' "$tmp_dir" >> "$manifest"
printf 'OUT_DIR\t%s\n' "$out_dir" >> "$manifest"
printf 'PDF_PATH\t%s\n' "$pdf_path" >> "$manifest"
printf 'ASSETS_DIR\t%s\n' "$assets_dir" >> "$manifest"
printf 'MODE\t%s\n' "$mode" >> "$manifest"

trap - EXIT
printf 'TMP_DIR\t%s\n' "$tmp_dir"
printf 'OUT_DIR\t%s\n' "$out_dir"
printf 'PDF_PATH\t%s\n' "$pdf_path"
printf 'ASSETS_DIR\t%s\n' "$assets_dir"
printf 'MANIFEST\t%s\n' "$manifest"
