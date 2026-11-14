"""Parser tests against pinned wikitext fixtures.

The parsers read a live wiki page whose layout can change, so these fixtures
are deliberately small, hand-written copies of the real markup. If the GTA Wiki
restructures a page the ingest run produces fewer records and these tests still
pass -- which is why build_pack.py also prints the counts, and why a sudden drop
should be treated as a layout change to investigate.

Run:  python3 -m unittest discover -s tests -t .   (from backend/)
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ingest.normalize import PackInvalid, keywords, slug, validate
from ingest.sources import wiki_cheats, wiki_secrets, wiki_vehicles

VEHICLE_FIXTURE = """
==Table==
<!--
===Key===
{|class="wikitable"
!Reference
!Meaning
|-
|
|
|}
-->
===New vehicles===
{| class="wikitable" width="100%"
|-
!Sports & super cars
!Motorcycles
|-
|
*[[Mamba GT]]*<!--September 2022 leaks-->
*[[Unnamed GTA VI Pegassi sports car|Pegassi sports car]]<!--Trailer 1: 0:32-->
|
*[[Alvino V1]]<!--Trailer 2: 1:10-->
|-
!Boats
!Helicopters
|-
|
*[[Airboat 09]]<!--Official Screenshot: Vice City 09-->
|
*[[Buzzard Attack Chopper]]<!--September 2022 leaks-->
|}

===Returning vehicles===
{| class="wikitable" width="100%"
|-
!Sedans
|-
|
*[[Vapid Stanier]]<!--Trailer 1: 0:14-->
|}
"""

CHEAT_FIXTURE = """
This article lists all of the '''Cheats'''.

==[[Xbox 360]], [[Xbox One]] and [[Xbox Series X and Series S|Xbox Series X/S]]==
{| class="wikitable"
!Effect
!Code
|-
|Spawn [[Comet]]
|'''RB''', [[File:XBox B.png|25px|B]], [[File:Xbox Right.png|25px|D-Pad Right]]
|-
|Max Health & Armor
|[[File:XBox B.png|25px|B]], [[File:Xbox LTrigger.png|25px|LT]]
|}

==[[PS3]], [[PS4]] and [[PS5]]==
{| class="wikitable"
!Effect
!Code
|-
|Spawn [[Comet]]
|
[[File:PS3 R1.png|25px|R1]], [[File:PS3 Circle.png|25px|Circle]], [[File:PS3 Right.png|25px|D-Pad right]]
|-
|Max Health & Armor
|
[[File:PS3 Circle.png|25px|Circle]], [[File:PS3 L2.png|25px|L2]]
|}

==[[PC]]==
{| class="wikitable"
!Effect
!Code
|-
|Spawn [[Comet]]
|COMET
|}

==Phone Cheats==
{| class="wikitable"
!Effect
!Number
|-
|Spawn [[Comet]]
|1-999-266-38
|}
"""

EMPTY_VI_CHEATS = """
==Cheats==
There are currently no confirmed cheat codes for GTA VI.

===PlayStation 5===
{| class="wikitable"
!Effect
!Code
|-
| colspan="2" style="text-align:center;" | No confirmed cheats
|}
"""

SECRETS_FIXTURE = """
==Downtown Vice City==
*A mural of a flamingo is painted on the wall of the arcade. It matches the one from an earlier game.
*Short
==Navigation==
*{{Navbox}}
"""


class TestVehicles(unittest.TestCase):
    def setUp(self):
        self.records = wiki_vehicles.parse(VEHICLE_FIXTURE)
        self.by_name = {r["name"]: r for r in self.records}

    def test_commented_out_table_is_ignored(self):
        # The key table lives inside a multi-line comment block.
        self.assertNotIn("Reference", self.by_name)
        self.assertNotIn("Meaning", self.by_name)

    def test_each_column_keeps_its_own_class(self):
        # A single table with repeated header rows must not collapse every
        # vehicle into the first column's class.
        self.assertEqual(self.by_name["Pegassi sports car"]["vehicleClass"], "cars")
        self.assertEqual(self.by_name["Alvino V1"]["vehicleClass"], "bikes")
        self.assertEqual(self.by_name["Airboat 09"]["vehicleClass"], "boats")
        self.assertEqual(self.by_name["Buzzard Attack Chopper"]["vehicleClass"], "aircraft")

    def test_leaked_vehicles_are_rumours_and_trailers_are_unverified(self):
        self.assertEqual(self.by_name["Mamba GT"]["status"], "rumour")
        self.assertEqual(self.by_name["Pegassi sports car"]["status"], "unverified")
        self.assertEqual(self.by_name["Airboat 09"]["status"], "unverified")
        # A leak comment with no trailing asterisk is still a leak.
        self.assertEqual(self.by_name["Buzzard Attack Chopper"]["status"], "rumour")

    def test_nothing_from_the_wiki_is_ever_verified(self):
        # Verified means tested in the released game, which a scrape cannot know.
        self.assertFalse([r for r in self.records if r["status"] == "verified"])

    def test_provenance_is_carried_for_attribution(self):
        prov = self.by_name["Pegassi sports car"]["provenance"]
        self.assertEqual(prov["sighting"], "Trailer 1: 0:32")
        self.assertIn("gta.fandom.com", prov["source"])
        self.assertTrue(prov["licence"])

    def test_returning_vehicles_are_flagged(self):
        self.assertTrue(self.by_name["Vapid Stanier"]["returning"])
        self.assertFalse(self.by_name["Mamba GT"]["returning"])

    def test_manufacturer_is_inferred_when_present(self):
        self.assertEqual(self.by_name["Pegassi sports car"]["specs"]["manufacturer"], "Pegassi")
        self.assertIsNone(self.by_name["Mamba GT"]["specs"]["manufacturer"])

    def test_ids_are_unique(self):
        ids = [r["id"] for r in self.records]
        self.assertEqual(len(ids), len(set(ids)))


class TestCheats(unittest.TestCase):
    def setUp(self):
        self.records = wiki_cheats.parse(CHEAT_FIXTURE, "Cheats in GTA V", "V", "verified")
        self.by_title = {r["title"]: r for r in self.records}

    def test_platforms_merge_into_one_cheat(self):
        self.assertEqual(len(self.records), 2)
        comet = self.by_title["Spawn Comet"]
        self.assertEqual(set(comet["sequences"]), {"xbox", "ps5", "pc"})

    def test_button_glyphs_are_platform_specific(self):
        comet = self.by_title["Spawn Comet"]
        self.assertEqual(comet["sequences"]["xbox"], ["RB", "B", "→"])
        self.assertEqual(comet["sequences"]["ps5"], ["R1", "○", "→"])
        # PC codes are typed words, not buttons.
        self.assertEqual(comet["sequences"]["pc"], ["COMET"])

    def test_multi_line_code_cells_are_read(self):
        # The PlayStation tables open a cell with a bare `|` and put the code on
        # the next line; missing this silently drops every PS code.
        self.assertIn("ps5", self.by_title["Max Health & Armor"]["sequences"])

    def test_phone_numbers_are_not_treated_as_codes(self):
        self.assertNotIn("1-999-266-38", str(self.records))

    def test_category_is_inferred(self):
        self.assertEqual(self.by_title["Spawn Comet"]["category"], "vehicles")
        self.assertEqual(self.by_title["Max Health & Armor"]["category"], "player")

    def test_wiki_links_are_stripped_from_the_effect(self):
        self.assertEqual(self.by_title["Spawn Comet"]["title"], "Spawn Comet")

    def test_an_empty_vi_table_yields_nothing(self):
        # The live GTA VI page says "No confirmed cheats". Inventing a record
        # from that row would put a fake code in front of users.
        records = wiki_cheats.parse(EMPTY_VI_CHEATS, "Cheats in GTA VI", "VI", "verified")
        self.assertEqual(records, [])


class TestSecrets(unittest.TestCase):
    def test_bullets_become_records_under_their_area(self):
        records = wiki_secrets.parse(SECRETS_FIXTURE)
        self.assertEqual(len(records), 1)
        self.assertEqual(records[0]["area"], "Downtown Vice City")
        self.assertTrue(records[0]["title"].startswith("A mural of a flamingo"))
        # Community write-ups are reports, not our own testing.
        self.assertEqual(records[0]["status"], "unverified")

    def test_navigation_sections_are_skipped(self):
        records = wiki_secrets.parse(SECRETS_FIXTURE)
        self.assertNotIn("Navigation", [r["area"] for r in records])


class TestNormalize(unittest.TestCase):
    def test_slug(self):
        self.assertEqual(slug("Unnamed GTA VI Vapid sedan"), "unnamed-gta-vi-vapid-sedan")
        self.assertEqual(slug("Max Health & Armour"), "max-health-armour")
        self.assertEqual(slug("!!!"), "untitled")

    def test_keywords_are_distinct_and_useful(self):
        self.assertEqual(keywords("Spawn Helicopter", "a chopper"), ["spawn", "helicopter", "chopper"])

    def test_validate_accepts_a_good_pack(self):
        validate({
            "version": 1, "generatedAt": "2026-11-14T00:00:00Z",
            "cheats": [{"id": "c1", "title": "T", "category": "world", "summary": "s",
                        "status": "rumour", "sequences": {"ps5": ["A"]}}],
            "vehicles": [], "secrets": [],
        })

    def test_validate_rejects_a_verified_cheat_with_no_code(self):
        with self.assertRaises(PackInvalid):
            validate({
                "version": 1, "generatedAt": "x",
                "cheats": [{"id": "c1", "title": "T", "category": "world", "summary": "s",
                            "status": "verified", "sequences": {}}],
                "vehicles": [], "secrets": [],
            })

    def test_validate_rejects_duplicate_ids(self):
        row = {"id": "dup", "name": "n", "vehicleClass": "cars", "status": "rumour"}
        with self.assertRaises(PackInvalid):
            validate({"version": 1, "generatedAt": "x", "cheats": [],
                      "vehicles": [row, dict(row)], "secrets": []})

    def test_validate_rejects_unknown_enums(self):
        with self.assertRaises(PackInvalid):
            validate({"version": 1, "generatedAt": "x", "cheats": [],
                      "vehicles": [{"id": "v", "name": "n", "vehicleClass": "hovercraft",
                                    "status": "rumour"}], "secrets": []})

    def test_validate_rejects_out_of_range_performance(self):
        with self.assertRaises(PackInvalid):
            validate({"version": 1, "generatedAt": "x", "cheats": [],
                      "vehicles": [{"id": "v", "name": "n", "vehicleClass": "cars",
                                    "status": "rumour",
                                    "performance": {"topSpeed": 4.2}}], "secrets": []})


if __name__ == "__main__":
    unittest.main()
