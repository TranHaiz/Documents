# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

--
Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.
Tradeoff: These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Doding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## 5. Comments and Explanations

Code should be readable first. Comments are not documentation.

Do not over-comment obvious code or explain line-by-line behavior.
Prefer clear naming and simple logic over excessive comments.
Add comments only when they explain non-obvious reasoning, constraints, tradeoffs, protocol behavior, or implementation intent.
Avoid redundant comments that merely restate the code.

### Bad

speed = distance / dt; // calculate speed

### Good

// Clamp dt to avoid velocity spikes when timestamp jitter occurs
speed = distance / dt;

When detailed explanation is needed:

First inspect the current implementation and explain based on actual code behavior.
Do not invent reasoning or architecture that is not present in the implementation.
Explain from the implementation outward: what it does, why it exists, tradeoffs, and limitations.
Prefer referencing execution flow and design decisions over rewriting the code in prose.

The rule: if removing a comment makes the code equally understandable, the comment probably should not exist.

These guidelines are working if: fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

--

## What this workspace is

`C:\NGOL_HAq\Docs` is a **document-conversion workspace**, not an application. Its job is to turn reference documents (PDFs, Office files) into Markdown so they can be fed to LLMs while working on the final-year university project whose code lives in the second working directory, `C:\NGOL_HAq\tai_lieu\A_SCHOOL\A.FINAL_UNIVERSITY_PROJECT\tools`.

- `pdf/` — source documents to convert (e.g. Bluetooth Low Energy specs).
- `markdown/` — conversion output.
- `markitdown/` — a **clone of `microsoft/markitdown`** (`git@github.com:microsoft/markitdown.git`, branch `main`, v0.1.6). It is the conversion engine, plus its `.venv`.
- `.codegraph/` — generated index database; not hand-edited.

`Docs/` itself is **not** a git repository. The only git repo inside it is `markitdown/`.

## Treat `markitdown/` as vendored upstream

The clone is pristine — zero local commits, and the working tree differs from upstream only by untracked files (`convert_file_to_md.bat`, `convert_folder_to_md.bat`). Preserve that: keep project-specific scripts and outputs outside the clone (or untracked, as the `.bat`s are), and don't edit files under `markitdown/packages/` for local convenience. A change there is either an upstream contribution or, more likely, belongs in a plugin (see Architecture).

## Running conversions

Two scripts in `markitdown/` are the normal entry points. Edit the two variables at the top of either one, then run it:

- `convert_file_to_md.bat` — one file. Set `INPUT_FILE` (path to the file) and `OUTPUT_DIR` (folder); the `.md` name is derived from the input's basename.
- `convert_folder_to_md.bat` — a whole tree. Set `INPUT_DIR` and `OUTPUT_DIR`; it recurses, mirrors subdirectories into the output, skips `.md`/`.py`/`~*` inputs, **skips any file whose `.md` already exists in the output**, and prints a `Converted / Skipped / Failed` tally. Delete an output file to force it to be regenerated.

Both default to `Docs\pdf` → `Docs\markdown`.

### Do not call `markitdown.exe`, and do not activate the venv

`.venv\Scripts\markitdown.exe` is a **uv trampoline with the venv's original absolute path baked in, and the venv has since been moved** — it dies with `uv trampoline failed to canonicalize script path`. Activating the venv doesn't help, because activation is what puts that broken shim on `PATH`.

Call the interpreter directly instead — this works, and is what both `.bat`s do:

```powershell
C:\NGOL_HAq\Docs\markitdown\.venv\Scripts\python.exe -m markitdown "C:\NGOL_HAq\Docs\pdf\some-doc.pdf" -o "C:\NGOL_HAq\Docs\markdown\some-doc.md"
```

(Recreating the venv would also fix the shim; nobody has bothered. Plugins are opt-in: `-p` / `--use-plugins`, list them with `--list-plugins`.)

### Two ways these `.bat` files break

Both were hit for real while writing them; both produce baffling cmd parse errors rather than an honest failure:

1. **Keep `.bat` content ASCII-only.** With `chcp 65001` on line 2, Vietnamese diacritics elsewhere in the file shift cmd's byte offsets as it re-reads the script, and it starts executing fragments of its own source (`'wn' is not recognized as an internal or external command`). Console messages in these scripts are therefore unaccented.
2. **No `|` or escaped `\"` inside the PowerShell one-liner.** The `\"` closes cmd's quoting early, after which a `|` is parsed as a cmd pipe (`'Skipped:' is not recognized...`). Build strings with `+` concatenation instead.

## Architecture of the conversion engine

Understanding a conversion means reading three layers, not one file:

1. **`MarkItDown` (`packages/markitdown/src/markitdown/_markitdown.py`)** is a registry + dispatcher. `convert()` and its narrower siblings (`convert_local`, `convert_stream`, `convert_uri`) build a `StreamInfo` (mimetype, extension, charset, filename, url) and offer the stream to each registered converter.
2. **Converters (`converters/_*.py`)** each implement the two-method `DocumentConverter` contract in `_base_converter.py`: `accepts(file_stream, stream_info)` is a cheap yes/no probe, and `convert(...)` returns a `DocumentConverterResult`. The signatures match deliberately — if `accepts()` says yes, `convert()` must be able to follow through. **If `accepts()` reads from the stream to decide, it must `seek()` back to the original position**, because `convert()` is called next and expects an unmoved stream.
3. **Priority** decides order. `PRIORITY_SPECIFIC_FILE_FORMAT` (0) is the default for format-specific converters; `PRIORITY_GENERIC_FILE_FORMAT` (10) is reserved for the catch-alls (`PlainTextConverter`, `HtmlConverter`, `ZipConverter`) that must run last. Lower value wins. Pass `priority=` to `register_converter()`.

Optional dependencies are grouped per format in `packages/markitdown/pyproject.toml` (`pdf`, `docx`, `xlsx`, `audio-transcription`, `az-doc-intel`, …; `all` pulls everything). A converter whose extra is missing raises `MissingDependencyException` rather than failing obscurely — so "this file type doesn't work" is usually a missing extra, not a bug.

### Packages in the monorepo

- `packages/markitdown` — the library and `markitdown` CLI.
- `packages/markitdown-mcp` — MCP server exposing a single `convert_to_markdown(uri)` tool. Local/STDIO use only; do not bind it to non-local interfaces.
- `packages/markitdown-ocr` — LLM-vision plugin that OCRs images embedded in PDF/DOCX/PPTX/XLSX and does full-page OCR for scanned PDFs. Reuses the existing `llm_client`/`llm_model` options, so it needs an LLM client rather than a native OCR binary.
- `packages/markitdown-sample-plugin` — the template to copy when adding a format.

### Adding a format

Write a plugin, not a core converter. Plugins are discovered through the `markitdown.plugin` entry-point group (see `_load_plugins()` in `_markitdown.py`), stay disabled until `enable_plugins=True` / `--use-plugins`, and register themselves via `register_converter()`. Copy `packages/markitdown-sample-plugin` as the starting point — this keeps the vendored clone clean.

## Developing inside the clone

Upstream uses `hatch`, and tests/type-checks run per package (each `packages/*` has its own `pyproject.toml`):

```powershell
cd C:\NGOL_HAq\Docs\markitdown\packages\markitdown
hatch test                                  # full suite for this package
hatch test tests/test_module_misc.py        # a single file
hatch test -- -k test_docx                  # a single test by name
hatch run types:check                       # mypy
pre-commit run --all-files                  # black formatting (the only hook configured)
```

Vendored formatting is Black; match it if you touch clone code.
