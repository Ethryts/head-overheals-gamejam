"""Regression checks for size budgets, host limits, and failed web exports."""

from contextlib import redirect_stdout
from io import StringIO
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import build
import size_report


class SizeReportTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.love = self.root / "game.love"
        self.settings = {"name": "test-game", "memory": 67108864}

    def package(self, files):
        with zipfile.ZipFile(self.love, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for name, content in files.items():
                archive.writestr(name, content)
        return self.love

    def test_budget_override_is_independent_and_null_disables(self):
        override = {"web_zip": {"warn_mb": None, "fail_mb": 4}}
        result = size_report.validate_budget(override)
        self.assertEqual(result["web_zip"], {"warn_mb": None, "fail_mb": 4})
        self.assertEqual(result["game_unpacked"], {"warn_mb": 50, "fail_mb": 100})
        result["game_unpacked"]["fail_mb"] = 1
        self.assertEqual(size_report.validate_budget()["game_unpacked"]["fail_mb"], 100)
        self.assertEqual(override, {"web_zip": {"warn_mb": None, "fail_mb": 4}})

    def test_budget_rejects_malformed_values(self):
        malformed = [[], True, {"unknown": {}}, {"web_zip": None},
                     {"web_zip": {"other_mb": 1}},
                     {"web_zip": {"warn_mb": 31, "fail_mb": 30}}]
        malformed.extend({"web_zip": {"warn_mb": value}}
                         for value in (True, False, 0, -1, "20", float("nan"), float("inf")))
        for value in malformed:
            with self.subTest(value=value), self.assertRaises(ValueError):
                size_report.validate_budget(value)

    def test_raw_budget_warns_at_threshold_and_fails_only_above_limit(self):
        self.settings["size_budget"] = {"game_unpacked": {"warn_mb": .001, "fail_mb": .002}}
        for length, status in ((999, "ok"), (1000, "warning"), (2000, "warning"), (2001, "failed")):
            with self.subTest(length=length):
                self.package({"main.lua": b"x" * length})
                report = size_report.analyze(self.settings, self.love)
                self.assertEqual(report["status"], status)
        self.settings["size_budget"] = {"game_unpacked": {"warn_mb": None, "fail_mb": None}}
        self.assertEqual(size_report.analyze(self.settings, self.love)["status"], "ok")

    def test_upload_budget_uses_actual_archive_bytes(self):
        self.package({"main.lua": "return {}"})
        upload = self.root / "web.zip"
        upload.write_bytes(b"x" * 1000)
        self.settings["size_budget"] = {"web_zip": {"warn_mb": .001, "fail_mb": .001}}
        at_limit = size_report.analyze(self.settings, self.love, upload_zip=upload)
        self.assertEqual(at_limit["status"], "warning")
        upload.write_bytes(b"x" * 1001)
        self.assertEqual(size_report.analyze(self.settings, self.love, upload_zip=upload)["status"], "failed")

    def test_compression_and_memory_are_separate_from_raw_asset_size(self):
        self.package({"main.lua": b"x" * 1_000_000})
        compressed = self.love.stat().st_size
        self.settings["memory"] = compressed
        report = size_report.analyze(self.settings, self.love)
        self.assertEqual(report["metrics"]["game_unpacked_bytes"], 1_000_000)
        self.assertLess(compressed, 10_000)
        self.assertEqual(report["status"], "ok")
        self.settings["memory"] = compressed - 1
        failed = size_report.analyze(self.settings, self.love)
        self.assertTrue(any("compressed .love" in message for message in failed["errors"]))

    def test_itch_limits_apply_to_web_files_not_members_inside_game_bundle(self):
        self.package({f"asset-{index}.txt": "x" for index in range(1001)})
        web = self.root / "web"
        web.mkdir()
        (web / "game.data").write_bytes(self.love.read_bytes())
        (web / "love.wasm").write_bytes(b"wasm")
        report = size_report.analyze(self.settings, self.love, web_directory=web)
        self.assertEqual(report["game_file_count"], 1001)
        self.assertEqual(report["web_file_count"], 2)
        self.assertEqual(report["status"], "ok")
        self.assertEqual(report["metrics"]["web_unpacked_bytes"], self.love.stat().st_size + 4)
        self.assertEqual(report["metrics"]["wasm_bytes"], 4)

    def test_host_boundaries_without_allocating_large_files(self):
        allowed = [{"path": "a", "bytes": 200_000_000},
                   {"path": "b", "bytes": 200_000_000},
                   {"path": "c" * 240, "bytes": 100_000_000}]
        self.assertEqual(size_report.host_errors(allowed), [])
        over = [{"path": "a" * 241, "bytes": 200_000_001},
                {"path": "b", "bytes": 200_000_000},
                {"path": "c", "bytes": 100_000_000}]
        errors = size_report.host_errors(over)
        self.assertEqual(len(errors), 3)
        for text in ("200 MB", "500 MB", "240-character"):
            self.assertTrue(any(text in error for error in errors))
        files = [{"path": str(index), "bytes": 0} for index in range(1000)]
        self.assertEqual(size_report.host_errors(files), [])
        files.append({"path": "one-more", "bytes": 0})
        self.assertIn("1,000", size_report.host_errors(files)[0])

    def test_deltas_ignore_other_projects_and_record_asset_reduction(self):
        self.package({"main.lua": b"x" * 200})
        upload = self.root / "web.zip"
        upload.write_bytes(b"x" * 100)
        previous = size_report.analyze(self.settings, self.love, upload_zip=upload)
        self.package({"main.lua": b"x" * 150})
        current = size_report.analyze(self.settings, self.love, previous=previous)
        self.assertEqual(current["delta_bytes"]["game_unpacked_bytes"], -50)
        self.assertIn("-50 B", size_report.markdown(current))
        previous["project"] = "another-game"
        self.assertEqual(size_report.analyze(self.settings, self.love, previous=previous)["delta_bytes"], {})

    def test_unreadable_baselines_are_ignored(self):
        baseline = self.root / "size-baseline.json"
        for data in ("{partial", "[]", "null"):
            baseline.write_text(data)
            self.assertIsNone(size_report.read_baseline(self.root))


class WebBuildSizeIntegrationTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.dist = self.root / "dist"
        self.settings = {"name": "test-game", "title": "Test Game", "memory": 67108864}
        (self.root / "build.json").write_text(json.dumps(self.settings))
        (self.root / "game").mkdir()
        (self.root / "game" / "main.lua").write_text("return {}")
        (self.root / "game" / "README.md").write_text("Excluded documentation" * 1000)
        (self.root / "web").mkdir()
        for name in ("index.html", "player.js", "style.css", "love-LICENSE.txt"):
            (self.root / "web" / name).write_text("placeholder __GAME_TITLE__ __INITIAL_MEMORY__")
        (self.root / "THIRD-PARTY.md").write_text("Test licenses")
        self.exporter = self.root / "node_modules" / "love.js" / "index.js"
        self.exporter.parent.mkdir(parents=True)
        self.exporter.write_text("placeholder exporter")
        (self.exporter.parent / "LICENSE").write_text("Exporter license")
        self.node = patch.object(build.shutil, "which", return_value="/test/node").start()
        self.addCleanup(patch.stopall)
        self.stdout = redirect_stdout(StringIO())
        self.stdout.__enter__()
        self.addCleanup(self.stdout.__exit__, None, None, None)

    def fake_export(self, command, **kwargs):
        source, destination = map(Path, command[-2:])
        for name in ("game.js", "love.js", "love.wasm"):
            (destination / name).write_bytes(b"runtime")
        (destination / "game.data").write_bytes(source.read_bytes())

    def successful_build(self):
        with patch.object(build.subprocess, "run", side_effect=self.fake_export):
            return build.build_web(self.root)

    def read_report(self):
        return json.loads((self.dist / "size-report.json").read_text())

    def test_successful_report_excludes_docs_and_is_not_inside_upload(self):
        upload = self.successful_build()
        report = self.read_report()
        self.assertEqual(report["status"], "ok")
        self.assertEqual(report["metrics"]["game_unpacked_bytes"], len("return {}"))
        self.assertEqual(report["metrics"]["web_zip_bytes"], upload.stat().st_size)
        with zipfile.ZipFile(upload) as archive:
            self.assertIn("index.html", archive.namelist())
            self.assertNotIn("size-report.json", archive.namelist())
        self.assertTrue((self.dist / "size-baseline.json").is_file())

    def test_failed_export_discards_old_zip_and_preserves_successful_baseline(self):
        upload = self.successful_build()
        baseline = (self.dist / "size-baseline.json").read_bytes()
        (self.root / "game" / "main.lua").write_text("return {changed = true}")
        with patch.object(build.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "exporter")):
            with self.assertRaises(subprocess.CalledProcessError):
                build.build_web(self.root)
        report = self.read_report()
        self.assertFalse(upload.exists())
        self.assertEqual(report["status"], "failed")
        self.assertEqual(report["phase"], "preflight")
        self.assertIsNone(report["metrics"]["web_zip_bytes"])
        self.assertIsNone(report["metrics"]["web_unpacked_bytes"])
        self.assertGreater(report["delta_bytes"]["game_unpacked_bytes"], 0)
        self.assertEqual((self.dist / "size-baseline.json").read_bytes(), baseline)

    def test_missing_exporter_still_saves_current_asset_report(self):
        self.exporter.unlink()
        with self.assertRaisesRegex(build.BuildError, "exporter is missing"):
            build.build_web(self.root)
        report = self.read_report()
        self.assertEqual(report["metrics"]["game_unpacked_bytes"], len("return {}"))
        self.assertEqual(report["status"], "failed")
        self.assertFalse((self.dist / "size-baseline.json").exists())

    def test_raw_asset_budget_stops_before_invoking_exporter(self):
        self.settings["size_budget"] = {"game_unpacked": {"warn_mb": None, "fail_mb": .000001}}
        (self.root / "build.json").write_text(json.dumps(self.settings))
        with patch.object(build.subprocess, "run") as exporter:
            with self.assertRaisesRegex(build.BuildError, "preflight failed"):
                build.build_web(self.root)
            exporter.assert_not_called()
        self.assertEqual(self.read_report()["status"], "failed")

    def test_upload_budget_failure_keeps_measurements_but_removes_upload(self):
        upload = self.successful_build()
        baseline = (self.dist / "size-baseline.json").read_bytes()
        self.settings["size_budget"] = {"web_zip": {"warn_mb": None, "fail_mb": .000001}}
        (self.root / "build.json").write_text(json.dumps(self.settings))
        with patch.object(build.subprocess, "run", side_effect=self.fake_export):
            with self.assertRaisesRegex(build.BuildError, "exceeds its size limits"):
                build.build_web(self.root)
        report = self.read_report()
        self.assertEqual(report["phase"], "complete")
        self.assertEqual(report["status"], "failed")
        self.assertGreater(report["metrics"]["web_zip_bytes"], 1)
        self.assertFalse(upload.exists())
        self.assertEqual((self.dist / "size-baseline.json").read_bytes(), baseline)


if __name__ == "__main__":
    unittest.main()
