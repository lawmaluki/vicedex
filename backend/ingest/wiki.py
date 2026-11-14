"""Minimal MediaWiki API client for the GTA Wiki (gta.fandom.com).

Content there is CC BY-SA, so every record we emit carries a source URL and
licence string. Responses are cached on disk so repeated runs of the pipeline
do not hammer the API.
"""

import hashlib
import json
import os
import time
import urllib.parse
import urllib.request

API = "https://gta.fandom.com/api.php"
LICENCE = "CC BY-SA 3.0"
# Generic client name on purpose: no project or personal details leave the machine.
USER_AGENT = "ViceDex-ingest/1.0 (fan companion app; contact via repository)"

CACHE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".wikicache")
CACHE_TTL = 60 * 60  # 1 hour


class WikiError(RuntimeError):
    pass


def _cache_path(params):
    key = hashlib.sha256(json.dumps(params, sort_keys=True).encode()).hexdigest()[:32]
    return os.path.join(CACHE_DIR, key + ".json")


def _get(params, use_cache=True):
    params = dict(params)
    params.setdefault("format", "json")
    params.setdefault("formatversion", "2")
    path = _cache_path(params)

    if use_cache and os.path.exists(path) and time.time() - os.path.getmtime(path) < CACHE_TTL:
        with open(path) as fh:
            return json.load(fh)

    url = API + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = json.loads(resp.read().decode("utf-8"))
    except Exception as exc:  # network, timeout, bad JSON
        # Serve a stale cache rather than failing the whole build.
        if os.path.exists(path):
            with open(path) as fh:
                return json.load(fh)
        raise WikiError("GTA Wiki request failed: %s" % exc)

    if "error" in body:
        raise WikiError(body["error"].get("info", "unknown API error"))

    os.makedirs(CACHE_DIR, exist_ok=True)
    with open(path, "w") as fh:
        json.dump(body, fh)
    return body


def wikitext(title, use_cache=True):
    """Raw wikitext of a page, or None when the page does not exist yet."""
    body = _get({"action": "parse", "page": title, "prop": "wikitext", "redirects": "1"},
                use_cache=use_cache)
    parse = body.get("parse")
    if not parse:
        return None
    return parse.get("wikitext")


def exists(title, use_cache=True):
    body = _get({"action": "query", "prop": "revisions", "rvprop": "ids|timestamp",
                 "titles": title}, use_cache=use_cache)
    pages = body.get("query", {}).get("pages", [])
    if not pages or pages[0].get("missing"):
        return None
    rev = pages[0]["revisions"][0]
    return {"revid": rev["revid"], "timestamp": rev["timestamp"]}


def page_url(title):
    return "https://gta.fandom.com/wiki/" + urllib.parse.quote(title.replace(" ", "_"))
