#!/usr/bin/env python3
"""Build the ViceDex content pack.

A *content pack* is one JSON document holding every static record the app
shows: cheats, vehicles and secrets. It is the read side of the backend. It is
generated, content-hashed and versioned, so it can be served from any static
host or CDN, and a copy is bundled into the app as the offline fallback.

Usage:
    python3 -m ingest.build_pack                 # build to backend/packs/
    python3 -m ingest.build_pack --no-cache      # ignore the local wiki cache
    python3 -m ingest.build_pack --out DIR
    python3 -m ingest.build_pack --check         # build, validate, don't write

The pack is built from GTA V, a released game with real, tested content: its
cheat codes, its controllable vehicles and its documented secrets. The GTA VI
parsers are kept in the source modules (``game="VI"``) but are not part of the
build: nothing there has been confirmed in a released game yet.
"""

import argparse
import datetime
import hashlib
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ingest import wiki
from ingest.normalize import PackInvalid, validate
from ingest.sources import wiki_cheats, wiki_secrets, wiki_vehicles

PACK_VERSION = 1
DEFAULT_OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "packs")
BUNDLED = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
                       "assets", "content_pack.json")


GAME = "V"


def build(use_cache=True):
    cheats = wiki_cheats.fetch_v(use_cache=use_cache)
    vehicles = wiki_vehicles.fetch(use_cache=use_cache, game=GAME)
    secrets = wiki_secrets.fetch(use_cache=use_cache, game=GAME)

    pack = {
        "version": PACK_VERSION,
        "game": GAME,
        "generatedAt": datetime.datetime.now(datetime.timezone.utc)
            .replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "sources": [
            {"name": "GTA Wiki", "url": "https://gta.fandom.com/", "licence": wiki.LICENCE,
             "pages": [wiki_cheats.V_PAGE, wiki_vehicles.PAGES[GAME], wiki_secrets.PAGES[GAME]]},
        ],
        "counts": {
            "cheats": len(cheats),
            "vehicles": len(vehicles),
            "secrets": len(secrets),
        },
        "notices": [],
        "cheats": cheats,
        "vehicles": vehicles,
        "secrets": secrets,
    }
    validate(pack)
    # Hash the records only, so an unchanged scrape keeps the same etag even
    # though generatedAt moved.
    payload = json.dumps({k: pack[k] for k in ("cheats", "vehicles", "secrets", "notices")},
                         sort_keys=True, separators=(",", ":")).encode()
    pack["etag"] = hashlib.sha256(payload).hexdigest()[:16]
    return pack


def write(pack, out_dir, bundle=True):
    os.makedirs(out_dir, exist_ok=True)
    blob = json.dumps(pack, indent=2, sort_keys=False, ensure_ascii=False) + "\n"

    versioned = os.path.join(out_dir, "v%d.json" % pack["version"])
    with open(versioned, "w") as fh:
        fh.write(blob)
    latest = os.path.join(out_dir, "latest.json")
    with open(latest, "w") as fh:
        fh.write(blob)

    written = [versioned, latest]
    if bundle:
        os.makedirs(os.path.dirname(BUNDLED), exist_ok=True)
        with open(BUNDLED, "w") as fh:
            fh.write(blob)
        written.append(BUNDLED)
    return written


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--no-cache", action="store_true", help="bypass the local wiki cache")
    ap.add_argument("--check", action="store_true", help="build and validate without writing")
    ap.add_argument("--no-bundle", action="store_true", help="skip writing assets/content_pack.json")
    args = ap.parse_args(argv)

    try:
        pack = build(use_cache=not args.no_cache)
    except PackInvalid as exc:
        print(exc, file=sys.stderr)
        return 1
    except wiki.WikiError as exc:
        print("source unavailable: %s" % exc, file=sys.stderr)
        return 2

    counts = pack["counts"]
    print("pack v%d  etag %s  generated %s" % (pack["version"], pack["etag"], pack["generatedAt"]))
    print("  cheats          %4d  (GTA V)" % counts["cheats"])
    print("  vehicles        %4d" % counts["vehicles"])
    print("  secrets         %4d" % counts["secrets"])
    for notice in pack["notices"]:
        print("  notice: %s" % notice["title"])

    if args.check:
        print("validated, nothing written (--check)")
        return 0

    for path in write(pack, args.out, bundle=not args.no_bundle):
        print("wrote %s" % path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
