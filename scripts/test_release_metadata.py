import unittest

import release_metadata


class ReleaseMetadataTests(unittest.TestCase):
    def test_versions(self):
        self.assertEqual(release_metadata.parse_version("1.3.9"), ((1, 3, 9), False))
        self.assertEqual(release_metadata.parse_version("1.3.9-beta.1"), ((1, 3, 9), True))
        self.assertEqual(release_metadata.parse_version("2.0.0-rc.10"), ((2, 0, 0), True))
        for value in ("v1.3.9", "1.03.9", "1.3.9-beta.01", "1.3.9-foo", "1.3.9; touch /tmp/x"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                release_metadata.parse_version(value)

    def test_release_must_have_newer_core_than_latest_stable(self):
        for version in ("1.3.8", "1.3.9", "1.3.8-beta.1", "1.3.9-rc.1"):
            with self.subTest(version=version), self.assertRaises(ValueError):
                release_metadata.require_newer_than_latest(version, "v1.3.9")
        release_metadata.require_newer_than_latest("1.3.10-beta.1", "v1.3.9")
        release_metadata.require_newer_than_latest("1.3.10", "v1.3.9")

    def test_cleanup_only_obsolete_marked_prereleases(self):
        releases = [
            {"id": 1, "tag_name": "v1.3.9-beta.1", "prerelease": True},
            {"id": 2, "tag_name": "v1.3.8-rc.1", "prerelease": True},
            {"id": 3, "tag_name": "v1.4.0-beta.1", "prerelease": True},
            {"id": 4, "tag_name": "v1.3.7", "prerelease": False},
            {"id": 5, "tag_name": "v1.3.8-beta.1", "prerelease": False},
            {"id": 6, "tag_name": "nightly", "prerelease": True},
            {"id": 7, "tag_name": "v1.3.9-beta.2", "prerelease": True, "draft": True},
        ]
        self.assertEqual(release_metadata.obsolete_releases(releases, "1.3.9"), [(1, "v1.3.9-beta.1"), (2, "v1.3.8-rc.1")])
        with self.assertRaises(ValueError):
            release_metadata.obsolete_releases(releases, "1.3.9-beta.1")


if __name__ == "__main__":
    unittest.main()
