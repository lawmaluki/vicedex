"""Parse secrets and easter eggs from the GTA Wiki.

Two layouts are understood:

* ``Secrets and Easter Eggs in GTA V`` -- the live source. Sections of
  ``|Image|Description|`` tables whose description cell opens with an
  underlined title: ``|<u>Alien Egg</u><br>There is a hidden ...``. Bullet
  lines inside that cell are continuation text, not separate secrets.
* ``Secrets and Easter Eggs in GTA VI`` -- does not exist yet (checked
  2026-11-14). It is written against plain ``==Area==`` headings with bulleted
  entries, so it starts producing records if editors create the page.
"""

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ingest import wiki  # noqa: E402
from ingest.normalize import slug  # noqa: E402

PAGE = "Secrets and Easter Eggs in GTA VI"
PAGE_V = "Secrets and Easter Eggs in GTA V"
PAGES = {"VI": PAGE, "V": PAGE_V}

MAX_SUMMARY = 420

SKIP_HEADINGS = ("navigation", "references", "see also", "gallery", "video",
                 "videos", "trivia", "contents",
                 # The GTA V page has a large adult-humour block. It is accurate
                 # but not suited to a general-audience companion app.
                 "adult humor/innuendos", "references to genitalia",
                 "references to sex", "references to the number 69")

# Wiki templates that stand for a game title. Anything else is dropped.
GAME_TEMPLATES = {
    "v": "GTA V", "iv": "GTA IV", "iii": "GTA III", "sa": "GTA San Andreas",
    "vc": "GTA Vice City", "lcs": "GTA Liberty City Stories", "vcs": "GTA Vice City Stories",
    "tlad": "The Lost and Damned", "tbogt": "The Ballad of Gay Tony",
    "eflc": "Episodes from Liberty City", "gtaop": "GTA Online", "gtaonline": "GTA Online",
    "red dead": "Red Dead Redemption", "'": "'",
}


def _template(match):
    parts = [p.strip() for p in match.group(1).split("|")]
    name = parts[0].lower()
    if name in ("wp", "wc"):  # Wikipedia / Commons link: the last argument is the display text
        return parts[-1] if len(parts) > 1 else ""
    return GAME_TEMPLATES.get(name, "")


def _clean(text):
    text = re.sub(r"<ref[^>]*>.*?</ref>|<ref[^>/]*/>", "", text, flags=re.S)
    # Templates nest ({{Ref|ref={{Quote|...}}}}), so expand innermost first.
    for _ in range(5):
        text, n = re.subn(r"\{\{([^{}]*)\}\}", _template, text)
        if not n:
            break
    text = re.sub(r"\[\[File:[^\]]*\]\]", "", text)
    text = re.sub(r"\[\[([^\]|]*\|)?([^\]]*)\]\]", r"\2", text)
    text = re.sub(r"<[^>]+>", "", text)
    text = text.replace(chr(39) * 3, "").replace(chr(39) * 2, "")
    return re.sub(r"\s+", " ", text).strip()


def _provenance(page):
    return {"source": wiki.page_url(page), "sourceName": "GTA Wiki", "licence": wiki.LICENCE}


def _shorten(text, limit):
    if len(text) <= limit:
        return text
    cut = text[:limit].rsplit(" ", 1)[0].rstrip(",;:- ")
    return cut + "..."


def _table_secrets(text, page):
    """One record per ``|<u>Title</u>...`` cell, filed under its nearest heading."""
    # Draft rows and notes the editors commented out are not content.
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    out, seen = [], set()
    area, cell = None, None

    def flush():
        nonlocal cell
        if cell is None:
            return
        raw = " ".join(cell)
        cell = None
        m = re.match(r"\s*<u>(.*?)</u>\s*(.*)$", raw, flags=re.S)
        if not m or area is None:
            return
        title = _clean(m.group(1))
        # The first <br> separates title from body; later ones are paragraphs.
        body = _clean(m.group(2).replace("<br>", " ").replace("<br />", " "))
        if not title or len(body) < 12:
            return
        key = "sec-" + slug(area + "-" + title)[:60]
        if key in seen:
            return
        seen.add(key)
        out.append({
            "id": key,
            "title": _shorten(title, 80),
            "area": area,
            "summary": _shorten(body, MAX_SUMMARY),
            # A wiki write-up is a community report, not our own testing.
            "status": "unverified",
            "provenance": _provenance(page),
        })

    for line in text.splitlines():
        stripped = line.strip()
        heading = re.match(r"^={2,}\s*(.*?)\s*={2,}$", stripped)
        if heading:
            flush()
            label = _clean(heading.group(1))
            area = None if label.lower() in SKIP_HEADINGS else label
            continue
        if stripped.startswith(("|-", "{|", "|}", "!")):
            flush()
            continue
        if stripped.startswith("|"):
            flush()
            first = stripped[1:].strip()
            # Only the description cell (opens with <u>) starts a record; the
            # image cell is skipped.
            if first.startswith("<u>"):
                cell = [first]
            continue
        if cell is not None:
            cell.append(stripped)
    flush()
    return out


def parse(text, game="VI"):
    page = PAGES[game]
    if "<u>" in text and "{|" in text:
        return _table_secrets(text, page)
    return _bullet_secrets(text, page, "Vice City" if game == "VI" else "General")


def _bullet_secrets(text, page, default_area):
    source_url = wiki.page_url(page)
    out = []
    area = default_area

    for line in text.splitlines():
        stripped = line.strip()
        heading = re.match(r"^={2,}\s*(.*?)\s*={2,}$", stripped)
        if heading:
            label = _clean(heading.group(1))
            if label.lower() in SKIP_HEADINGS:
                area = None
            else:
                area = label
            continue
        if area is None or not stripped.startswith("*"):
            continue
        body = _clean(stripped.lstrip("*").strip())
        if len(body) < 12:
            continue
        # First sentence is the title, the whole bullet is the summary.
        title = re.split(r"(?<=[.!?])\s", body)[0].rstrip(".")
        if len(title) > 80:
            title = title[:77].rsplit(" ", 1)[0] + "..."
        out.append({
            "id": "sec-" + slug(area + "-" + title)[:60],
            "title": title,
            "area": area,
            "summary": body,
            # Wiki write-ups are community reports, not our own testing.
            "status": "unverified",
            "provenance": {
                "source": source_url,
                "sourceName": "GTA Wiki",
                "licence": wiki.LICENCE,
            },
        })
    return out


def fetch(use_cache=True, game="V"):
    page = PAGES[game]
    if not wiki.exists(page, use_cache=use_cache):
        return []
    text = wiki.wikitext(page, use_cache=use_cache)
    if not text:
        return []
    return parse(text, game=game)
