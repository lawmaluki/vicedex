"""Parse GTA cheat tables from the GTA Wiki.

Two pages matter:

* ``Cheats in GTA VI`` — the live target. As of November 12 2026 it is a stub
  that states no cheat codes have been confirmed, so this parser correctly
  yields nothing. It is written against the table layout the wiki already uses
  for GTA V, so the moment editors fill the VI tables in (launch is days away)
  a re-run picks them up with no code change.
* ``Cheats in GTA V`` — a complete, real, verified data set. Shipped as the
  reference/legacy section so the app has genuine content on day one instead of
  invented placeholders.

Each cheat row is ``Effect | Code`` where the code is a comma-separated run of
file-image button glyphs:

    |Spawn [[Comet]]
    |'''RB''', [[File:XBox B.png|25px|B]], [[File:Xbox Right.png|25px|D-Pad Right]], ...

The alt text of each image (``B``, ``D-Pad Right``) is the button, which maps
onto the glyphs the app's sequence chips render.
"""

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ingest import wiki  # noqa: E402
from ingest.normalize import keywords, slug  # noqa: E402

VI_PAGE = "Cheats in GTA VI"
V_PAGE = "Cheats in GTA V"

def platform_for(heading):
    """Classify a section heading as a platform key, ``None`` to skip, or
    ``"other"`` when the heading is not a platform section at all.

    Headings differ between pages and games: GTA VI uses plain
    ``===PlayStation 5===`` while GTA V uses a linked, combined
    ``==[[PS3]], [[PS4]] and [[PS5]]==``. Matching on keywords handles both.
    """
    text = re.sub(r"\[\[([^\]|]*\|)?([^\]]*)\]\]", r"\2", heading).lower()
    if "phone" in text:
        return None  # phone numbers, not button codes
    if "xbox" in text:
        return "xbox"
    if "playstation" in text or re.search(r"\bps[345]\b", text):
        return "ps5"
    if re.search(r"\bpc\b", text):
        return "pc"
    return "other"


# Button alt text -> the glyph the app shows. PlayStation face buttons are
# symbols; shoulders, triggers and the d-pad stay as short labels.
PS_GLYPHS = {
    "circle": "○", "triangle": "△", "square": "□", "cross": "✕", "x": "✕",
    "l1": "L1", "l2": "L2", "r1": "R1", "r2": "R2",
    "d-pad left": "←", "d-pad right": "→", "d-pad up": "↑", "d-pad down": "↓",
    "left": "←", "right": "→", "up": "↑", "down": "↓",
}
XBOX_GLYPHS = {
    "a": "A", "b": "B", "x": "X", "y": "Y",
    "lb": "LB", "rb": "RB", "lt": "LT", "rt": "RT",
    "d-pad left": "←", "d-pad right": "→", "d-pad up": "↑", "d-pad down": "↓",
    "left": "←", "right": "→", "up": "↑", "down": "↓",
}

CATEGORY_RULES = (
    ("weapons", ("weapon", "ammo", "gun", "explosi", "flaming", "bullet", "melee")),
    ("vehicles", ("spawn", "vehicle", "car", "bike", "plane", "heli", "boat", "tank",
                  "slippery", "drift", "bmx", "golf")),
    ("player", ("health", "armor", "armour", "invincib", "run", "jump", "swim",
                "lung", "ability", "skyfall", "parachute", "drunk", "slow motion")),
    ("world", ("weather", "wanted", "police", "star", "gravity", "time", "traffic",
               "pedestrian", "director")),
)


def categorise(effect):
    low = effect.lower()
    for category, needles in CATEGORY_RULES:
        if any(n in low for n in needles):
            return category
    return "world"


def _glyphs(code, platform):
    """Turn a wikitext code cell into a list of button glyphs."""
    table = PS_GLYPHS if platform == "ps5" else XBOX_GLYPHS
    out = []
    # Images carry the button in their alt text (last pipe-separated field).
    tokens = re.split(r",(?![^\[]*\]\])", code)
    for token in tokens:
        token = token.strip()
        if not token:
            continue
        img = re.search(r"\[\[File:[^\]]*?\|([^|\]]+)\]\]", token)
        label = img.group(1) if img else token
        label = re.sub(r"\[\[([^\]|]*\|)?([^\]]*)\]\]", r"\2", label)
        label = label.replace("'''", "").replace("''", "").replace("&nbsp;", " ")
        label = re.sub(r"<[^>]+>", "", label).strip().strip(".")
        if not label or label.lower().endswith("px"):
            continue
        out.append(table.get(label.lower(), label))
    return out


def _effect_text(cell):
    text = re.sub(r"\[\[([^\]|]*\|)?([^\]]*)\]\]", r"\2", cell)
    text = text.replace("'''", "").replace("''", "")
    text = re.sub(r"<ref[^>]*>.*?</ref>|<[^>]+>|\{\{[^}]*\}\}", "", text, flags=re.S)
    return re.sub(r"\s+", " ", text).strip()


def _sections(text):
    """Yield (heading, section_text) for every ``===`` level heading."""
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    parts = re.split(r"^={2,}\s*(.*?)\s*={2,}\s*$", text, flags=re.M)
    # parts = [preamble, heading, body, heading, body, ...]
    for i in range(1, len(parts) - 1, 2):
        yield parts[i], parts[i + 1]


def _table_rows(section_text):
    """Yield (effect_cell, code_cell) pairs from the first wikitable."""
    for table in re.findall(r"\{\|.*?\n\|\}", section_text, flags=re.S):
        lines = [l.rstrip() for l in table.splitlines()]
        row = []
        for line in lines:
            stripped = line.strip()
            if stripped.startswith("!") or stripped.startswith("{|") or stripped.startswith("|}"):
                continue
            if stripped.startswith("|-"):
                if len(row) >= 2:
                    yield row[0], row[1]
                row = []
                continue
            if stripped.startswith("|"):
                row.append(stripped[1:].strip())
                continue
            # A cell may open with a bare `|` and carry its content on the
            # following lines (the PlayStation tables are written this way).
            if row:
                row[-1] = (row[-1] + " " + stripped).strip()
        if len(row) >= 2:
            yield row[0], row[1]


def parse(text, page, game, status, use_cache=True):
    """Merge each platform's table into one cheat per effect."""
    by_effect = {}
    order = []
    source_url = wiki.page_url(page)

    for heading, body in _sections(text):
        platform = platform_for(heading)
        if platform is None:
            continue  # known-but-ignored section, e.g. phone numbers
        if platform == "other":
            continue  # not a platform section
        for effect_cell, code_cell in _table_rows(body):
            effect = _effect_text(effect_cell)
            if not effect or effect.lower().startswith("no confirmed"):
                continue
            sequence = _glyphs(code_cell, platform)
            if not sequence:
                continue
            key = slug(effect)
            if key not in by_effect:
                by_effect[key] = {
                    "id": "%s-%s" % (game.lower(), key),
                    "title": effect,
                    "category": categorise(effect),
                    "summary": effect + ".",
                    "keywords": keywords(effect),
                    "status": status,
                    "sequences": {},
                    "confirmations": 0,
                    "isPlaceholder": False,
                    "game": game,
                    "addedIn": None,
                    "provenance": {
                        "source": source_url,
                        "sourceName": "GTA Wiki",
                        "licence": wiki.LICENCE,
                    },
                }
                order.append(key)
            by_effect[key]["sequences"][platform] = sequence

    return [by_effect[k] for k in order]


def fetch_vi(use_cache=True):
    """Confirmed GTA VI cheats. Empty until Rockstar/testers confirm any."""
    text = wiki.wikitext(VI_PAGE, use_cache=use_cache)
    if not text:
        return []
    return parse(text, VI_PAGE, "VI", "verified")


def fetch_v(use_cache=True):
    """GTA V cheats: real codes, verified in a released game."""
    text = wiki.wikitext(V_PAGE, use_cache=use_cache)
    if not text:
        return []
    return parse(text, V_PAGE, "V", "verified")
