"""Shared helpers plus validation of a built content pack.

The pack is the contract between this pipeline and the Flutter app, so the
enum spellings below must stay in step with ``lib/models/models.dart``.
"""

import re
import unicodedata

PLATFORMS = ("ps5", "xbox", "pc")
STATUSES = ("verified", "unverified", "rumour")
CHEAT_CATEGORIES = ("weapons", "vehicles", "player", "world")
VEHICLE_CLASSES = ("cars", "bikes", "boats", "aircraft")
PERF_STATS = ("topSpeed", "acceleration", "handling", "braking")


def slug(text):
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    text = re.sub(r"[^a-zA-Z0-9]+", "-", text).strip("-").lower()
    return text or "untitled"


def keywords(*parts):
    """Lower-cased distinct word list used by the app's search."""
    words = []
    for part in parts:
        for word in re.split(r"[^a-zA-Z0-9]+", (part or "").lower()):
            if len(word) > 2 and word not in words:
                words.append(word)
    return words


class PackInvalid(ValueError):
    pass


def validate(pack):
    """Raise :class:`PackInvalid` on anything the app could not render."""
    errors = []

    def check(cond, msg):
        if not cond:
            errors.append(msg)

    check(isinstance(pack.get("version"), int), "version must be an int")
    check(bool(pack.get("generatedAt")), "generatedAt missing")

    ids = set()
    for kind, required in (("cheats", ("id", "title", "category", "summary", "status", "sequences")),
                           ("vehicles", ("id", "name", "vehicleClass", "status")),
                           ("secrets", ("id", "title", "area", "summary", "status"))):
        items = pack.get(kind)
        check(isinstance(items, list), "%s must be a list" % kind)
        for i, item in enumerate(items or []):
            where = "%s[%d]" % (kind, i)
            for field in required:
                check(item.get(field) is not None, "%s missing %s" % (where, field))
            if item.get("id") in ids:
                errors.append("%s duplicate id %s" % (where, item.get("id")))
            ids.add(item.get("id"))
            check(item.get("status") in STATUSES, "%s bad status %r" % (where, item.get("status")))
            if kind == "cheats":
                check(item.get("category") in CHEAT_CATEGORIES,
                      "%s bad category %r" % (where, item.get("category")))
                for plat, seq in (item.get("sequences") or {}).items():
                    check(plat in PLATFORMS, "%s bad platform %r" % (where, plat))
                    check(isinstance(seq, list) and all(isinstance(s, str) for s in seq),
                          "%s sequence for %s must be a list of strings" % (where, plat))
                # A verified cheat without any code is a contradiction.
                if item.get("status") == "verified":
                    check(any((item.get("sequences") or {}).values()),
                          "%s is verified but has no sequence" % where)
            if kind == "vehicles":
                check(item.get("vehicleClass") in VEHICLE_CLASSES,
                      "%s bad vehicleClass %r" % (where, item.get("vehicleClass")))
                for stat, value in (item.get("performance") or {}).items():
                    check(stat in PERF_STATS, "%s bad stat %r" % (where, stat))
                    check(isinstance(value, (int, float)) and 0.0 <= value <= 1.0,
                          "%s stat %s must be 0..1" % (where, stat))

    if errors:
        raise PackInvalid("content pack failed validation:\n  - " + "\n  - ".join(errors))
    return pack
