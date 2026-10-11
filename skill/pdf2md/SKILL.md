---
name: pdf2md
description: Organize and translate an academic PDF into a semantically named reading folder containing the renamed source PDF, faithful original-language Markdown, Chinese Markdown translation, and embedded figures. Use for requests such as "pdf2md", "PDF转md", "提取PDF论文", translating a paper, organizing papers for later reading, or switching conveniently between a paper's PDF and Markdown versions.
---

# PDF Paper Organizer and Translator

Create a self-contained paper reading package. Preserve the complete technical content, reconstruct tables faithfully, embed verified figures, and keep the PDF beside the original and translated Markdown.

## Output contract

Create this structure under the user-specified target base directory, or under the source PDF's parent directory when none is specified:

```text
<target-base>/<semantic_short_name>/
├── <semantic_short_name>.pdf
├── assets/
│   └── fig<N>_<descriptive_name>.<readable-format>
├── origin.md
└── translated.md
```

Choose `<semantic_short_name>` after reading the title and abstract. It must:

- contain 3-7 English content words
- use lowercase `snake_case`, matching `^[a-z]+(_[a-z]+){2,6}$`
- describe the research object, central problem, method, or main claim
- contain no submission id, year, digit, random suffix, truncated filename fragment, or garbled text
- avoid generic names such as `llm_paper` and `agent_research`

If the name collides with a different paper, make it more semantically specific; never append a number. Rename the canonical PDF to match the folder.

## Workflow

### 1. Start an isolated task and inspect the paper

Resolve all script paths relative to this `SKILL.md`. Create one task-specific temporary directory before any extraction:

```bash
TMP_DIR=$(mktemp -d /tmp/pdf2md_translate_XXXX)
```

The four-character random suffix permits concurrent translation jobs without shared files. Put every temporary text file, page preview, image list, and manifest under `TMP_DIR`.

If the user did not identify a PDF, use the single PDF in the current directory. If several PDFs exist and the user did not authorize an arbitrary choice, ask which paper to process.

Confirm readability and extract enough front matter to find the title and abstract:

```bash
pdfinfo "$SOURCE_PDF" > "$TMP_DIR/pdfinfo.txt"
pdftotext -f 1 -l 2 "$SOURCE_PDF" "$TMP_DIR/frontmatter.txt"
```

Extend the front-matter extraction only when the abstract is not yet present. Read the title and abstract, then choose the semantic short name.

### 2. Create the canonical reading package

Run:

```bash
<skill-dir>/scripts/prepare_package.sh \
  --pdf "$SOURCE_PDF" \
  --target-base "$TARGET_BASE" \
  --name "$SHORT_NAME" \
  --tmp-dir "$TMP_DIR" \
  --move
```

Omit `--target-base` when no destination was specified. Use `--copy` only when the user explicitly asks to preserve the source copy. Capture the printed `OUT_DIR`, `PDF_PATH`, and `ASSETS_DIR`; use the canonical PDF path for every later step.

Do not overwrite or merge with a non-empty folder belonging to another paper.

### 3. Detect layout and extract one canonical text

Render 120-150 DPI previews of several text-dense body pages. Exclude the title page, full-page figures/tables, and the final reference page. Inspect an early, middle, and late body page when possible.

Classify the paper as:

- **Single-column:** prose spans most of the text width with no persistent central gutter.
- **Double-column:** most sampled pages contain two prose blocks separated by a persistent central gutter.
- **Mixed-layout:** body pages switch between single- and double-column layouts.

Set `TEXT="$TMP_DIR/paper_text.txt"`, then select one extraction:

- Single-column: `pdftotext -layout "$PDF_PATH" "$TEXT"`.
- Double-column: start with `pdftotext "$PDF_PATH" "$TEXT"`; use `-raw` only if inspection proves that it improves column order.
- Mixed-layout: extract pages according to their detected layout and concatenate them in page order, preserving a form-feed page break between pages.

Do not keep two whole-paper text extractions as competing sources. For a damaged table, run `pdftotext -layout` only on that table's page or use a cropped page rendering.

Inspect the abstract, an ordinary body page, a cross-page section, and the start of the references. Reject text containing left/right-column interleaving, paragraph jumps, or captions inserted into unrelated prose.

### 4. Extract raster candidates and figure-page previews

Run:

```bash
<skill-dir>/scripts/extract_assets.sh \
  --pdf "$PDF_PATH" \
  --assets "$ASSETS_DIR" \
  --tmp-dir "$TMP_DIR" \
  --text "$TEXT"
```

The script deliberately filters raster objects whose width or height is at most 100 px and deletes extracted candidates smaller than 10 KB. Papers normally contain few meaningful figures, so favor removing noise over retaining every small object.

Keep JPEG, PNG, GIF, WebP, and SVG in their original readable format. Convert only formats that ordinary Markdown/browser renderers cannot display, such as PPM or PBM.

Review these generated task files:

- `image_candidates.tsv`: retained raster objects with source index, page, dimensions, format, and filename
- `figure_mentions.tsv`: pages and text lines mentioning Figure/Fig.
- `vector_previews/`: 150 DPI previews of likely figure pages
- `figure_mapping.tsv`: mapping sheet to complete during figure review

### 5. Verify figures and complete the mapping

Build one mapping row per paper figure using:

```text
figure_id | page | caption | source_indices | candidate_files | final_file | status
```

Cross-check PDF page order, captions, retained raster objects, and previews. Do not assume that one PDF image object equals one paper figure: a figure may contain several objects, and a page may contain several figures.

For a complete raster figure, rename it to `assets/fig<N>_<2-4-word-description>.<ext>`. For a vector or composite figure:

1. Inspect the 150 DPI page preview.
2. Determine the exact figure boundary.
3. Render the source page at 300 DPI.
4. Crop only the figure into the final asset.
5. Inspect the final crop and confirm it contains no caption, page header/footer, or neighboring prose.

Set `status` to `verified` only after visual inspection. Store `final_file` as the relative path used by Markdown, such as `assets/fig2_routing_overview.jpg`.

### 6. Choose whole-paper or sectioned writing

Use whole-paper writing for ordinary papers. Enable sectioned writing when the canonical text exceeds approximately 10,000 words or when a one-shot write is likely to be unreliable.

For sectioned writing, create `$TMP_DIR/sections/` and `$TMP_DIR/section_manifest.tsv`. The manifest must contain:

```text
section_order | title | source_pages | origin_status | translation_status
```

Use tab-separated values without the visual `|` separators. Add row `0` with title `front_matter`, then one row for every H2 section in `origin.md`, in final document order. Use the exact original-language H2 title in each manifest row. Include the References section.

Name temporary chunks with zero-padded order numbers:

```text
sections/000_origin.md
sections/000_translated.md
sections/001_origin.md
sections/001_translated.md
...
```

Set each status to `pending` initially and to `completed` only after that chunk has been checked. Make every chunk end with the exact whitespace and separators required when concatenated directly with the next chunk.

After all rows are `completed`, concatenate the origin chunks in order into `origin.md` and the translated chunks in the same order into `translated.md`. Do not place chunk files or the section manifest in the final reading package.

### 7. Create origin.md

Read the complete canonical text and use the PDF to resolve extraction ambiguity. Preserve all technical content; do not summarize or omit prose.

Write `origin.md` with:

- the paper title as H1 and authors/metadata below it
- `##` main sections and `###` subsections
- horizontal rules between major sections
- equations preserved faithfully in Markdown/LaTeX
- aligned source tables reconstructed as Markdown tables
- numeric columns right-aligned and text columns left-aligned
- figures inserted near their first prose reference, or at the original caption position when no prose reference exists
- verified mapping paths and the full original caption in image alt text
- page headers, footers, page numbers, watermarks, and publication boilerplate removed
- the reference section normalized to `## References`

If extraction cannot preserve a table's values reliably, crop and embed that table rather than inventing values.

### 8. Create translated.md

Translate `origin.md` faithfully into Chinese while preserving its Markdown structure.

- Keep standard technical terms in English where appropriate, including LLM, RAG, CoT, API, TTL, and domain-specific identifiers.
- Keep author names unchanged.
- Keep mathematical symbols, structure, and equation numbers unchanged. Translate natural-language words inside constructs such as `\text{...}` when needed.
- Keep every image path identical and translate only its alt-text caption.
- Keep table dimensions and numeric values unchanged.
- Use `## 参考文献` and keep all reference entries byte-for-byte identical to `origin.md`.

### 9. Validate before cleanup

Run:

```bash
<skill-dir>/scripts/validate_package.sh \
  --out "$OUT_DIR" \
  --name "$SHORT_NAME" \
  --mapping "$TMP_DIR/figure_mapping.tsv"
```

For sectioned writing, also pass:

```bash
--section-manifest "$TMP_DIR/section_manifest.tsv"
```

The validator checks that all section rows are complete, their titles match the final original H2 order, every chunk exists, and direct chunk concatenation reproduces the final Markdown files exactly.

Fix every reported failure. Then manually compare the PDF, `origin.md`, and `translated.md` for:

- title and abstract
- one methods section
- every reported experimental number
- every table in the PDF, enumerated by label or caption; confirm each appears in `origin.md` as a Markdown table or embedded table crop, and that `translated.md` preserves the same tables in the same order
- all figure and table captions
- conclusion
- reference entries

Mechanical validation cannot prove translation fidelity or complete PDF coverage.

### 10. Clean up and report

Clean up only after mechanical and manual validation pass. First confirm that the path matches the task prefix, then delete only that directory's contents and empty directories:

```bash
[[ "$TMP_DIR" == /tmp/pdf2md_translate_???? ]]
find "$TMP_DIR" -type f -delete
find "$TMP_DIR" -depth -type d -empty -delete
```

Never delete the canonical PDF or anything inside the completed reading package.

Report:

- semantic folder name and absolute path
- canonical PDF filename
- detected layout and selected extraction mode
- figure, table, main-section, and subsection counts
- final file sizes
- validation result
