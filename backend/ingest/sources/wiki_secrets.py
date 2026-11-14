"""Parse GTA VI secrets and easter eggs from the GTA Wiki.

``Secrets and Easter Eggs in GTA VI`` does not exist yet (checked 2026-11-14),
so this source yields nothing and the build records a notice explaining why.
It is written against the layout the equivalent GTA V page uses -- ``==Area==``
headings with bulleted entries -- so it starts producing records as soon as
editors create the page after launch.
"""

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ingest import wiki  # noqa: E402
from ingest.normalize import slug  # noqa: E402

PAGE = "Secrets and Easter Eggs in GTA VI"

SKIP_HEADINGS = ("navigation", "references", "see also", "gallery", "video",
                 "videos", "trivia", "contents")


def _clean(text):
    text = re.sub(r"<ref[^>]*>.*?</ref>|<ref[^>/]*/>", "", text, flags=re.S)
    text = re.sub(r"\{\{[^}]*\}\}", "", text)
    text = re.sub(r"\[\[File:[^\]]*\]\]", "", text)
    text = re.sub(r"\[\[([^\]|]*\|)?([^\]]*)\]\]", r"\2", text)
    text = re.sub(r"<[^>]+>", "", text)
    text = text.replace(chr(39) * 3, "").replace(chr(39) * 2, "")
    return re.sub(r"\s+", " ", text).strip()


def parse(text):
    source_url = wiki.page_url(PAGE)
    out = []
    area = "Vice City"

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


def fetch(use_cache=True):
    if not wiki.exists(PAGE, use_cache=use_cache):
        return []
    text = wiki.wikitext(PAGE, use_cache=use_cache)
    if not text:
        return []
    return parse(text)
