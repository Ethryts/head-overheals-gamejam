"""Regression checks for the boundaries of a packaged game."""

from pathlib import Path
import tempfile
import unittest
import zipfile

import build


class PackagingTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.game = self.root / "game"
        self.game.mkdir()
        (self.game / "main.lua").write_text("function love.draw() end\n")

    def test_runtime_assets_only_and_main_at_archive_root(self):
        for filename in ("README.md", ".secret", "scratch.swp", "conf.lua", "image.png"):
            (self.game / filename).write_text("data")
        for directory in (".git", "cache", "__pycache__", "node_modules"):
            (self.game / directory).mkdir()
            (self.game / directory / "ignored.txt").write_text("data")
        (self.game / "src").mkdir()
        (self.game / "src" / "game.lua").write_text("return {}")
        archive_path = self.root / "game.love"
        build.write_zip(build.runtime_files(self.game), self.game, archive_path)
        with zipfile.ZipFile(archive_path) as archive:
            self.assertEqual(archive.namelist(), ["conf.lua", "image.png", "main.lua", "src/game.lua"])

    def test_rebuilding_removes_deleted_files(self):
        asset = self.game / "old.txt"
        asset.write_text("old")
        archive_path = self.root / "game.love"
        build.write_zip(build.runtime_files(self.game), self.game, archive_path)
        asset.unlink()
        build.write_zip(build.runtime_files(self.game), self.game, archive_path)
        with zipfile.ZipFile(archive_path) as archive:
            self.assertEqual(archive.namelist(), ["main.lua"])
        output = self.root / "web"
        output.mkdir()
        (output / "stale.data").write_text("old")
        build.replace_directory(output)
        self.assertEqual(list(output.iterdir()), [])

    def test_rejects_external_symlinks(self):
        secret = self.root / "private.txt"
        secret.write_text("never package")
        try:
            (self.game / "asset.txt").symlink_to(secret)
        except (NotImplementedError, OSError):
            self.skipTest("Creating symlinks is unavailable on this platform.")
        with self.assertRaises(build.BuildError):
            build.runtime_files(self.game)

    def test_missing_main_is_an_error(self):
        (self.game / "main.lua").unlink()
        with self.assertRaises(build.BuildError):
            build.runtime_files(self.game)


if __name__ == "__main__":
    unittest.main()
