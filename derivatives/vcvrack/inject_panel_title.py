#!/usr/bin/env python3
"""Generate outlined panel title paths and inject them into Rack SVG panels."""

from __future__ import annotations

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, replace
from pathlib import Path

try:
    from fontTools.pens.svgPathPen import SVGPathPen
    from fontTools.ttLib import TTFont
except Exception:
    print(
        "fontTools is required in ~/.main_python_venv for panel title generation.\n"
        "Install it with:\n"
        "  source ~/.main_python_venv/bin/activate && pip install fonttools",
        file=sys.stderr,
    )
    raise SystemExit(1)


SVG_NS = "http://www.w3.org/2000/svg"
INKSCAPE_NS = "http://www.inkscape.org/namespaces/inkscape"
ET.register_namespace("", SVG_NS)
ET.register_namespace("inkscape", INKSCAPE_NS)


@dataclass
class TitleConfig:
    title: str
    font: Path
    fill: str
    x: float
    y: float
    font_size: float
    tracking_em: float
    center_x: bool


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--module", required=True)
    parser.add_argument("--svg", required=True, type=Path)
    parser.add_argument("--config", required=True, type=Path)
    return parser.parse_args()


def load_title_config(module: str, config_path: Path) -> TitleConfig:
    data = json.loads(config_path.read_text())
    defaults = data["default"]
    module_data = data["modules"].get(module)
    if not module_data:
        raise SystemExit(f"No title configuration for module '{module}' in {config_path}")

    merged = dict(defaults)
    merged.update(module_data)
    return TitleConfig(
        title=merged["title"],
        font=Path(merged["font"]),
        fill=merged["fill"],
        x=float(merged["x"]),
        y=float(merged["y"]),
        font_size=float(merged["font_size"]),
        tracking_em=float(merged.get("tracking_em", 0.0)),
        center_x=bool(merged.get("center_x", False)),
    )


def parse_viewbox_width(svg_root: ET.Element) -> float:
    view_box = svg_root.attrib.get("viewBox")
    if not view_box:
        raise SystemExit("SVG must declare a viewBox so the generated title can be centered")
    parts = [float(part) for part in view_box.replace(",", " ").split()]
    if len(parts) != 4:
        raise SystemExit(f"Unexpected viewBox format: {view_box}")
    return parts[2]


def make_path_commands(font: TTFont, text: str, tracking_em: float) -> tuple[list[tuple[str, float]], float]:
    glyph_set = font.getGlyphSet()
    cmap = font.getBestCmap()
    hmtx = font["hmtx"]
    glyph_order = font.getGlyphOrder()
    units_per_em = float(font["head"].unitsPerEm)
    tracking_units = units_per_em * tracking_em

    missing_name = ".notdef"
    if missing_name not in glyph_order:
        missing_name = glyph_order[0]

    commands: list[tuple[str, float]] = []
    cursor_x = 0.0

    for char in text:
        if char == "\n":
            raise SystemExit("Panel titles must be a single line")
        if char == " ":
            advance_width, _ = hmtx[missing_name]
            cursor_x += advance_width * 0.5
            cursor_x += tracking_units
            continue

        glyph_name = cmap.get(ord(char), missing_name)
        pen = SVGPathPen(glyph_set)
        glyph_set[glyph_name].draw(pen)
        d = pen.getCommands()
        if d:
            commands.append((d, cursor_x))
        advance_width, _ = hmtx[glyph_name]
        cursor_x += advance_width + tracking_units

    return commands, max(cursor_x - tracking_units, 0.0)


def build_brand_group(svg_root: ET.Element, cfg: TitleConfig) -> ET.Element:
    if not cfg.font.is_file():
        raise SystemExit(f"Font file not found: {cfg.font}")

    font = TTFont(str(cfg.font))
    commands, text_width_units = make_path_commands(font, cfg.title, cfg.tracking_em)
    units_per_em = float(font["head"].unitsPerEm)
    scale = cfg.font_size / units_per_em
    text_width = text_width_units * scale
    start_x = cfg.x
    if cfg.center_x:
        svg_width = parse_viewbox_width(svg_root)
        start_x = (svg_width - text_width) * 0.5

    group = ET.Element(f"{{{SVG_NS}}}g", {"id": "woc-generated-branding"})
    for d, glyph_x in commands:
        path = ET.SubElement(
            group,
            f"{{{SVG_NS}}}path",
            {
                "d": d,
                "fill": cfg.fill,
                "transform": (
                    f"translate({start_x + glyph_x * scale:.3f},{cfg.y:.3f}) "
                    f"scale({scale:.6f},{-scale:.6f})"
                ),
            },
        )
        path.tail = "\n"
    return group


def main() -> int:
    args = parse_args()
    cfg = load_title_config(args.module, args.config)
    tree = ET.parse(args.svg)
    root = tree.getroot()
    generated_title = next(
        (child for child in list(root) if child.attrib.get("id") == "woc-generated-title"),
        None,
    )
    if generated_title is not None:
        cfg = replace(
            cfg,
            title="".join(generated_title.itertext()),
            x=float(generated_title.attrib["x"]),
            y=float(generated_title.attrib["y"]),
            center_x=False,
        )
        root.remove(generated_title)
    group = build_brand_group(root, cfg)

    for child in list(root):
        if child.attrib.get("id") == "woc-generated-branding":
            root.remove(child)
    insert_at = len(root)
    for idx, child in enumerate(list(root)):
        if child.attrib.get(f"{{{INKSCAPE_NS}}}label") == "components":
            insert_at = idx
            break
    root.insert(insert_at, group)
    tree.write(args.svg, encoding="UTF-8", xml_declaration=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
