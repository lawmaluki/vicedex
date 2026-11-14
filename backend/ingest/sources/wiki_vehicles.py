"""Parse the GTA Wiki "Vehicles in GTA VI/table" page into ViceDex vehicles.

The page is a set of wikitables whose column headers are vehicle classes and
whose cells are bullet lists of links. Each bullet usually carries an HTML
comment recording where the vehicle was seen, e.g.

    *[[Unnamed GTA VI Vapid sedan|Vapid sedan]]<!--Trailer 1: 0:46-->
    *[[Mamba GT]]*<!--September 2022 leaks-->

A trailing ``*`` on the link means the vehicle only appears in leaks. That
distinction, plus the comment, is what drives the verification status:

    official trailer / screenshot / website  -> unverified  (officially shown,
                                                 but nothing measured in-game)
    leaks only                               -> rumour

Nothing from this source is ever ``verified``: that status is reserved for
entries confirmed in the released game.
"""

import re
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ingest import wiki  # noqa: E402
from ingest.normalize import slug  # noqa: E402

PAGE = "Vehicles in GTA VI/table"
PAGE_V = "Vehicles in GTA V/table"

PAGES = {"VI": PAGE, "V": PAGE_V}

# Wiki column header -> ViceDex VehicleClass enum name. Headers not listed here
# (trailers, trains, unknown) are skipped; the app has no class for them.
CLASS_MAP = {
    "sports & super cars": "cars",
    "sedans & coupes": "cars",
    "muscle cars": "cars",
    "compact cars": "cars",
    "suvs & station wagons": "cars",
    "pickups & off-road": "cars",
    "recreational": "cars",
    "emergency, rescue & government": "cars",
    "industrial & construction": "cars",
    "trucks & vans": "cars",
    "sports": "cars",
    "muscle": "cars",
    "super": "cars",
    "sports classics": "cars",
    "sedans": "cars",
    "suvs": "cars",
    "compacts": "cars",
    "coupes": "cars",
    "off-road": "cars",
    "vans": "cars",
    "utility": "cars",
    "industrial": "cars",
    "service": "cars",
    "commercial": "cars",
    "emergency": "cars",
    "military": "cars",
    "motorcycles": "bikes",
    "bicycles & mobility devices": "bikes",
    "cycles": "bikes",
    "boats": "boats",
    "planes & blimps": "aircraft",
    "helicopters": "aircraft",
    "planes": "aircraft",
}

MANUFACTURERS = [
    "Albany", "Annis", "Benefactor", "BF", "Bollokan", "Bravado", "Brute", "Buckingham",
    "Canis", "Caracara", "Chariot", "Cheval", "Classique", "Coil", "Declasse", "Dewbauchee",
    "Dinka", "Dundreary", "Emperor", "Enus", "Fathom", "Gallivanter", "Grotti", "Hijak",
    "Imponte", "Invetero", "Jobuilt", "Karin", "Lampadati", "Maibatsu", "Mammoth", "MTL",
    "Nagasaki", "Obey", "Ocelot", "Overflod", "Pegassi", "Pfister", "Principe", "Progen",
    "RUNE", "Schyster", "Shitzu", "Speedophile", "Stanley", "Truffade", "Ubermacht",
    "Vapid", "Vulcar", "Weeny", "Western", "Willard", "Zirconium",
]


def _strip_comments(text):
    return re.sub(r"<!--.*?-->", "", text, flags=re.S)


def _drop_commented_blocks(text):
    """Remove only comments that span several lines.

    The page wraps a whole draft section in a multi-line ``<!-- ... -->`` block,
    which would otherwise be parsed as real tables. Single-line comments are the
    per-bullet provenance notes, so those must survive.
    """
    return re.sub(r"<!--(?:[^-]|-(?!->))*?\n(?:[^-]|-(?!->))*?-->", "", text, flags=re.S)


def _tables(wikitext):
    """Yield (section_title, table_body) for each wikitable, skipping any that
    sits inside a commented-out block. Bullet lines keep their inline comments
    so provenance can be read in :func:`_bullets`."""
    text = _drop_commented_blocks(wikitext)
    section = ""
    depth_buf = []
    in_table = False
    for line in text.splitlines():
        stripped = line.strip()
        heading = re.match(r"^={2,}\s*(.*?)\s*={2,}$", stripped)
        if heading and not in_table:
            section = heading.group(1)
            continue
        if stripped.startswith("{|"):
            in_table, depth_buf = True, []
            continue
        if in_table and stripped.startswith("|}"):
            in_table = False
            yield section, depth_buf
            continue
        if in_table:
            depth_buf.append(line)


def _cells(body):
    """Yield ``(column_header, cell_lines)`` for every data cell in a table.

    The page puts several header rows in a single table (one group of classes,
    then its vehicles, then the next group), so headers are tracked per group
    and reset whenever a new header row begins. Tracking them table-wide is
    what makes every vehicle look like the first column's class.
    """
    headers = []
    column = -1
    cell = None
    after_data = False

    for line in body:
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("!"):
            if after_data:
                headers, after_data = [], False
            for part in re.split(r"!!", stripped.lstrip("!")):
                headers.append(_header_label(part))
            continue
        if stripped.startswith("|-"):
            column, cell = -1, None
            continue
        if stripped.startswith("|"):
            after_data = True
            column += 1
            header = headers[column] if 0 <= column < len(headers) else ""
            cell = []
            yield header, cell
            rest = stripped[1:].strip()
            if rest.startswith("*"):
                cell.append(rest)
            continue
        if stripped.startswith("*") and cell is not None:
            cell.append(stripped)


def _header_label(part):
    # Drop cell attributes such as `colspan=2|` and wiki italics.
    if "|" in part:
        part = part.split("|", 1)[1]
    return part.replace("''", "").strip()


_BULLET = re.compile(r"^\*+\s*(?:\[\[(?P<target>[^\]|]+)(?:\|(?P<label>[^\]]+))?\]\]|(?P<plain>[^<*]+))"
                     r"(?P<leak>\s*\*)?\s*(?P<rest>.*)$")


def _parse_bullet(raw, note):
    m = _BULLET.match(raw)
    if not m:
        return None
    target = (m.group("target") or "").strip()
    label = (m.group("label") or target or (m.group("plain") or "")).strip()
    # Drop wiki italics/bold and any stray markup from the display name.
    label = label.replace(chr(39) * 3, "").replace(chr(39) * 2, "")
    label = re.sub(r"<[^>]+>", "", label).strip(" *")
    if not label:
        return None
    leak_marker = bool(m.group("leak")) or "*" in (m.group("rest") or "")
    return {"target": target or label, "name": label, "leak": leak_marker, "note": note,
            "qualifier": _qualifier(m.group("rest"))}


def _bullets(cell_lines):
    """Pair each bullet with the HTML comment that followed it."""
    out = []
    for raw in cell_lines:
        stripped = raw.strip()
        if not stripped.startswith("*"):
            continue
        comment = re.search(r"<!--(.*?)-->", stripped, flags=re.S)
        note = comment.group(1).strip() if comment else ""
        parsed = _parse_bullet(_strip_comments(stripped).strip(), note)
        if parsed:
            out.append(parsed)
    return out


def _qualifier(rest):
    """A trailing ``(cabrio)`` / ``(rusted)`` after the link tells variants apart.

    The GTA V table links several variants to one display name, e.g.
    ``[[Tornado (cabrio)|Tornado]] (cabrio)``. Without the qualifier they would
    all collapse into one record.
    """
    rest = re.sub(r"\{\{[^}]*\}\}|\[[A-Z*]+\]", "", rest or "")
    m = re.search(r"\(([^)]+)\)", rest)
    return m.group(1).strip() if m else ""


def _status_for(entry, game="VI"):
    """GTA V: every listed model exists in the released game. GTA VI: leaks are
    rumour; anything officially depicted is unverified."""
    if game == "V":
        return "verified", "Controllable vehicle in GTA V."
    note = entry["note"].lower()
    if entry["leak"] or "leak" in note:
        return "rumour", "Appears only in the September 2022 leaks."
    if "trailer" in note:
        return "unverified", "Seen in an official trailer (%s)." % entry["note"]
    if "screenshot" in note or "website" in note or "artwork" in note:
        return "unverified", "Seen in official Rockstar material (%s)." % entry["note"]
    return "rumour", "Community-tracked; provenance not recorded on the wiki."


def _manufacturer(name):
    for maker in MANUFACTURERS:
        if re.search(r"\b%s\b" % re.escape(maker), name):
            return maker
    return None


def fetch(use_cache=True, game="V"):
    text = wiki.wikitext(PAGES[game], use_cache=use_cache)
    if not text:
        return []
    return parse(text, game=game)


def parse(text, game="VI"):
    page = PAGES[game]
    source_url = wiki.page_url(page)
    seen = {}
    ordered = []

    # Re-walk with comments intact so bullets keep their provenance notes.
    for section, body in _tables(text):
        # _cells yields cells whose line lists are filled in as the walk
        # proceeds, so collect first and read after.
        collected = [(header, cell) for header, cell in _cells(body)]
        for header, cell in collected:
            vclass = CLASS_MAP.get(header.lower())
            if vclass:
                for entry in _bullets(cell):
                    status, note = _status_for(entry, game)
                    name = entry["name"]
                    if game == "V" and entry.get("qualifier") and entry["qualifier"].lower() not in name.lower():
                        name = "%s (%s)" % (name, entry["qualifier"])
                    vid = "veh-" + slug(name)
                    if vid in seen:
                        continue
                    record = {
                        "id": vid,
                        "name": name,
                        "vehicleClass": vclass,
                        "status": status,
                        "wikiClass": header,
                        "returning": game == "VI" and section.lower().startswith("returning"),
                        "specs": {"manufacturer": _manufacturer(name)},
                        "performance": {},
                        "addedIn": None,
                        "provenance": {
                            "note": note,
                            "sighting": entry["note"] or None,
                            "source": source_url,
                            "sourceName": "GTA Wiki",
                            "licence": wiki.LICENCE,
                        },
                    }
                    seen[vid] = record
                    ordered.append(record)
    return ordered

