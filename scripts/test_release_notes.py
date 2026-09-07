import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("release_notes", Path(__file__).with_name("release-notes.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ReleaseNotesTests(unittest.TestCase):
    def test_exact_version_only(self):
        text = "## [Unreleased]\n- Future\n## [0.0.1]\n- Current\n## [0.0.0]\n- Old\n[0.0.0]: https://example.com\n"
        self.assertEqual(module.extract_notes(text, "0.0.1"), "## Changes in 0.0.1\n\n- Current\n")
        self.assertNotIn("https://", module.extract_notes(text, "0.0.0"))

    def test_missing_duplicate_and_empty_sections_fail(self):
        for text in ["## [Unreleased]\n- Future", "## [0.0.1]\n", "## [0.0.1]\n- A\n## [0.0.1]\n- B"]:
            with self.assertRaises(ValueError):
                module.extract_notes(text, "0.0.1")

    def test_invalid_version_fails(self):
        for version in ["Unreleased", "v0.0.1", "0.0.1\n", "../main"]:
            with self.assertRaises(ValueError):
                module.extract_notes("", version)


if __name__ == "__main__":
    unittest.main()
