#!/usr/bin/env python3
"""Build the project's deterministic Noto Sans CJK subset from runtime sources."""

from __future__ import annotations

import argparse
from pathlib import Path

from fontTools import subset


SOURCE_EXTENSIONS = {".gd", ".godot", ".json", ".tres", ".tscn"}
IGNORED_DIRECTORIES = {".godot", "fonts", "tests"}


def runtime_sources(godot_dir: Path) -> list[Path]:
    return sorted(
        path
        for path in godot_dir.rglob("*")
        if path.is_file()
        and path.suffix.lower() in SOURCE_EXTENSIONS
        and not any(part in IGNORED_DIRECTORIES for part in path.relative_to(godot_dir).parts[:-1])
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_font", type=Path, help="verified upstream NotoSansCJKsc-Regular.otf")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("godot/fonts/NotoSansCJKsc-ProjectSubset.otf"),
    )
    args = parser.parse_args()

    godot_dir = Path("godot")
    sources = runtime_sources(godot_dir)
    if not sources:
        raise SystemExit("no runtime glyph sources found")

    characters = {chr(codepoint) for codepoint in range(0x20, 0x7F)}
    for source_path in sources:
        characters.update(source_path.read_text(encoding="utf-8"))

    options = subset.Options()
    options.layout_features = ["*"]
    options.glyph_names = True
    options.symbol_cmap = True
    options.legacy_cmap = True
    options.notdef_glyph = True
    options.notdef_outline = True
    options.recommended_glyphs = True
    options.name_IDs = ["*"]
    options.name_legacy = True
    options.name_languages = ["*"]

    font = subset.load_font(str(args.source_font), options)
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(text="".join(sorted(characters)))
    subsetter.subset(font)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    subset.save_font(font, str(args.output), options)
    print(f"wrote {args.output} from {len(sources)} sources and {len(characters)} characters")


if __name__ == "__main__":
    main()
