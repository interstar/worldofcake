#!/usr/bin/env python3
"""Build the World of Cake web previews.

Compiles each app to JavaScript with `lime build ... html5`, then renders:

  - site/index.html        the landing page
  - site/<app>/index.html  an app page (optional markdown intro + embedded app)

Layout:

  website/
    make.py      this script
    template/    HTML/CSS templates and favicon (source, not uploaded)
    content/     optional per-app markdown intros (source, not uploaded)
    site/        generated, deployable output (upload only this)

Requires Haxe + Lime/OpenFL on PATH. Goldenpond is included only when its
external library checkout is present.
"""

import html
import os
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEBSITE = os.path.join(ROOT, "website")
SITE = os.path.join(WEBSITE, "site")
TPL = os.path.join(WEBSITE, "template")
CONTENT = os.path.join(WEBSITE, "content")
EXPORT_BIN = os.path.join(ROOT, "derivatives", "openfl", "Export", "html5", "bin")

APPS = ["gbloink", "zewp", "kdiagram", "tileland", "timeslider"]
GOLDENPOND_SRC = os.path.join(
    ROOT, "..", "goldenpond", "goldenpond", "current", "haxe", "src", "goldenpond"
)
if os.path.isdir(GOLDENPOND_SRC):
    APPS.append("goldenpond")

DESCRIPTIONS = {
    "gbloink": "Bouncing balls that emit MIDI notes when they collide.",
    "zewp": "Line agents that turn at obstacles and emit MIDI CC.",
    "kdiagram": "A network of nodes walked by statistical cursors.",
    "tileland": "A Truchet-tile maze with three moving cursors.",
    "timeslider": "Four time-to-target tracks emitting MIDI CC.",
    "goldenpond": "A text-driven multi-part looping note sequencer.",
}


def parse_project(app):
    path = os.path.join(ROOT, "derivatives", "openfl", f"project-{app}.xml")
    root = ET.parse(path).getroot()
    title = root.find("meta").get("title")
    file = root.find("app").get("file")
    window = root.find("window")
    return title, file, window.get("width"), window.get("height")


def inline(text):
    text = html.escape(text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"\*(.+?)\*", r"<em>\1</em>", text)
    text = re.sub(r"`(.+?)`", r"<code>\1</code>", text)
    text = re.sub(r"\[(.+?)\]\((.+?)\)", r'<a href="\2">\1</a>', text)
    return text


def markdown(text):
    """Minimal markdown renderer: paragraphs, headings, lists, bold/italic/code/links."""
    out = []
    paragraph = []
    in_list = False

    def flush_paragraph():
        nonlocal paragraph
        if paragraph:
            out.append("<p>" + inline(" ".join(paragraph)) + "</p>")
            paragraph = []

    for raw in text.strip().splitlines():
        line = raw.rstrip()
        if not line.strip():
            flush_paragraph()
            if in_list:
                out.append("</ul>")
                in_list = False
            continue
        if line.lstrip().startswith(("- ", "* ")):
            flush_paragraph()
            if not in_list:
                out.append("<ul>")
                in_list = True
            out.append(f"<li>{inline(line.lstrip()[2:])}</li>")
            continue
        m = re.match(r"^(#{1,4})\s+(.*)$", line)
        if m:
            flush_paragraph()
            if in_list:
                out.append("</ul>")
                in_list = False
            n = len(m.group(1))
            out.append(f"<h{n}>{inline(m.group(2))}</h{n}>")
            continue
        paragraph.append(line)

    flush_paragraph()
    if in_list:
        out.append("</ul>")
    return "\n".join(out)


def app_block(file, width, height):
    return (
        '<div class="app-stage" id="openfl-content"></div>\n'
        f'<script type="text/javascript" src="./{file}.js"></script>\n'
        '<script type="text/javascript">\n'
        '  window.addEventListener("touchmove", function (e) { e.preventDefault(); }, { passive: false });\n'
        f'  lime.embed("{file}", "openfl-content", {width}, {height}, {{ parameters: {{}} }});\n'
        '</script>'
    )


def read(name):
    with open(os.path.join(TPL, name), encoding="utf-8") as f:
        return f.read()


def main():
    shutil.rmtree(SITE, ignore_errors=True)
    os.makedirs(SITE, exist_ok=True)
    for asset in ("style.css", "favicon.svg"):
        shutil.copy(os.path.join(TPL, asset), os.path.join(SITE, asset))

    app_tpl = read("app.html")
    landing_tpl = read("index.html")

    links = []
    for app in APPS:
        title, file, width, height = parse_project(app)
        desc = DESCRIPTIONS.get(app, "")

        print(f"=== web build: {app} ===")
        shutil.rmtree(EXPORT_BIN, ignore_errors=True)
        subprocess.run(
            ["lime", "build", f"derivatives/openfl/project-{app}.xml", "html5"],
            cwd=ROOT,
            check=True,
        )

        outdir = os.path.join(SITE, app)
        os.makedirs(outdir, exist_ok=True)
        shutil.copy(os.path.join(EXPORT_BIN, f"{file}.js"), os.path.join(outdir, f"{file}.js"))
        shutil.copy(os.path.join(TPL, "style.css"), os.path.join(outdir, "style.css"))
        shutil.copy(os.path.join(TPL, "favicon.svg"), os.path.join(outdir, "favicon.svg"))

        md_path = os.path.join(CONTENT, f"{app}.md")
        intro = markdown(open(md_path, encoding="utf-8").read()) if os.path.exists(md_path) else ""

        page = (
            app_tpl
            .replace("{title}", html.escape(title))
            .replace("{description}", html.escape(desc, quote=True))
            .replace("{intro}", intro)
            .replace("{app}", app_block(file, width, height))
        )
        with open(os.path.join(outdir, "index.html"), "w", encoding="utf-8") as f:
            f.write(page)

        links.append(
            f'      <a class="card" href="{app}/">'
            f'<span class="card-title">{html.escape(title)}</span>'
            f'<span class="card-desc">{html.escape(desc)}</span></a>'
        )

    landing = landing_tpl.replace("{links}", "\n".join(links))
    with open(os.path.join(SITE, "index.html"), "w", encoding="utf-8") as f:
        f.write(landing)

    print("\nDone. To view locally:")
    print("  python3 -m http.server -d website/site 8000")
    print("then open http://localhost:8000/")


if __name__ == "__main__":
    main()
