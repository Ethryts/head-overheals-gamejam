"""Measure packaged bytes and enforce an early jam budget. No dependencies."""

from copy import deepcopy
from datetime import datetime, timezone
import json
import math
import zipfile

MB = 1_000_000  # Decimal MB throughout; memory in build.json is still bytes.
DEFAULT_BUDGET = {
    "web_zip": {"warn_mb": 20, "fail_mb": 30},
    "game_unpacked": {"warn_mb": 50, "fail_mb": 100},
}
ITCH_LIMITS = {"file_bytes": 200 * MB, "total_bytes": 500 * MB,
               "file_count": 1000, "path_characters": 240}
SIZE_LABELS = {
    "web_zip_bytes": "Upload ZIP",
    "web_unpacked_bytes": "Extracted website",
    "game_archive_bytes": "Game bundle (.love / game.data)",
    "game_unpacked_bytes": "Included game files, before compression",
    "wasm_bytes": "WebAssembly runtime",
}


def validate_budget(value=None):
    """Merge explicit overrides; null disables an individual threshold."""
    result = deepcopy(DEFAULT_BUDGET)
    if value is None:
        return result
    if not isinstance(value, dict) or set(value) - set(result):
        raise ValueError("size_budget accepts only web_zip and game_unpacked objects.")
    for metric, thresholds in value.items():
        if not isinstance(thresholds, dict) or set(thresholds) - {"warn_mb", "fail_mb"}:
            raise ValueError(f"size_budget.{metric} accepts warn_mb and fail_mb.")
        for level, limit in thresholds.items():
            if limit is not None and (type(limit) not in (int, float)
                                      or not math.isfinite(limit) or limit <= 0):
                raise ValueError(f"size_budget.{metric}.{level} must be positive or null.")
            result[metric][level] = limit
        warn, fail = result[metric]["warn_mb"], result[metric]["fail_mb"]
        if warn is not None and fail is not None and warn > fail:
            raise ValueError(f"size_budget.{metric}.warn_mb must not exceed fail_mb.")
    return result


def host_errors(files):
    """files is a list of {path, bytes}; limits apply to the exported website."""
    errors = []
    if len(files) > ITCH_LIMITS["file_count"]:
        errors.append(f"itch.io allows at most 1,000 web files; found {len(files):,}.")
    total = sum(item["bytes"] for item in files)
    if total > ITCH_LIMITS["total_bytes"]:
        errors.append(f"Extracted website exceeds itch.io's 500 MB total limit ({format_bytes(total)}).")
    for item in files:
        if item["bytes"] > ITCH_LIMITS["file_bytes"]:
            errors.append(f"{item['path']} exceeds itch.io's 200 MB file limit ({format_bytes(item['bytes'])}).")
        if len(item["path"]) > ITCH_LIMITS["path_characters"]:
            errors.append(f"Web path exceeds itch.io's 240-character limit: {item['path']}")
    return errors


def analyze(settings, love_file, *, web_directory=None, upload_zip=None, error=None, previous=None):
    """Only pass web_directory/upload_zip for a finished export of these sources."""
    with zipfile.ZipFile(love_file) as archive:
        game_files = [{"path": item.filename, "bytes": item.file_size,
                       "compressed_bytes": item.compress_size}
                      for item in archive.infolist() if not item.is_dir()]
    metrics = {
        "web_zip_bytes": upload_zip.stat().st_size if upload_zip else None,
        "web_unpacked_bytes": None,
        "game_archive_bytes": love_file.stat().st_size,
        "game_unpacked_bytes": sum(item["bytes"] for item in game_files),
        "wasm_bytes": None,
    }
    web_files = None
    if web_directory is not None:
        web_files = [{"path": item.relative_to(web_directory).as_posix(), "bytes": item.stat().st_size}
                     for item in sorted(web_directory.rglob("*")) if item.is_file()]
        metrics["web_unpacked_bytes"] = sum(item["bytes"] for item in web_files)
        metrics["wasm_bytes"] = next((item["bytes"] for item in web_files
                                       if item["path"] == "love.wasm"), None)

    budget = validate_budget(settings.get("size_budget"))
    warnings, errors = [], []
    for name, thresholds in budget.items():
        value = metrics[f"{name}_bytes"]
        if value is None:
            continue
        label = SIZE_LABELS[f"{name}_bytes"]
        warn, fail = thresholds["warn_mb"], thresholds["fail_mb"]
        if fail is not None and value > fail * MB:
            errors.append(f"{label}: {format_bytes(value)} exceeds the {fail:g} MB jam budget.")
        elif warn is not None and value >= warn * MB:
            warnings.append(f"{label}: {format_bytes(value)} has reached the {warn:g} MB warning threshold.")

    if metrics["game_archive_bytes"] > settings["memory"]:
        errors.append("The exporter cannot build: the compressed .love exceeds configured initial memory "
                      f"({format_bytes(settings['memory'])}). Review assets or increase build.json memory "
                      "in multiples of 65,536 bytes, then browser-test.")
    if web_files is not None:
        errors.extend(host_errors(web_files))
    elif metrics["game_archive_bytes"] > ITCH_LIMITS["file_bytes"]:
        errors.append("The game bundle would exceed itch.io's 200 MB limit for game.data.")
    if error:
        errors.append(error)

    previous = previous if isinstance(previous, dict) else {}
    comparable = (previous.get("schema_version") == 1
                  and previous.get("project") == settings["name"]
                  and previous.get("phase") == "complete"
                  and previous.get("status") != "failed")
    old_metrics = previous.get("metrics", {}) if comparable else {}
    if not isinstance(old_metrics, dict):
        old_metrics = {}
        comparable = False
    deltas = {name: value - old_metrics[name] for name, value in metrics.items()
              if value is not None and type(old_metrics.get(name)) is int}
    return {
        "schema_version": 1,
        "project": settings["name"],
        "generated_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "phase": "complete" if upload_zip is not None else "preflight",
        "status": "failed" if errors else "warning" if warnings else "ok",
        "metrics": metrics,
        "delta_bytes": deltas,
        "baseline_at_utc": previous.get("generated_at_utc") if comparable else None,
        "game_file_count": len(game_files),
        "web_file_count": len(web_files) if web_files is not None else None,
        "largest_web_file": max(web_files, key=lambda item: item["bytes"]) if web_files else None,
        "largest_game_files": sorted(game_files, key=lambda item: (-item["bytes"], item["path"]))[:10],
        "initial_memory_bytes": settings["memory"],
        "size_budget": budget,
        "itch_limits": ITCH_LIMITS,
        "warnings": warnings,
        "errors": errors,
    }


def format_bytes(value):
    if abs(value) >= MB:
        return f"{value / MB:,.2f} MB"
    if abs(value) >= 1000:
        return f"{value / 1000:,.2f} KB"
    return f"{value:,} B"


def safe_text(value):
    return str(value).replace("\n", " ").replace("\r", " ").replace("|", "\\|").replace("`", "'")


def markdown(report):
    lines = [f"# Build size: {report['status'].upper()}", "",
             "Decimal MB (1 MB = 1,000,000 bytes). Deltas compare with the last successful local web build.", "",
             "| Measurement | Current | Change |", "| --- | ---: | ---: |"]
    for name, label in SIZE_LABELS.items():
        value = report["metrics"][name]
        current = format_bytes(value) if value is not None else "Unavailable — no completed web build"
        delta = report["delta_bytes"].get(name)
        change = "—" if delta is None else ("+" if delta > 0 else "") + format_bytes(delta)
        lines.append(f"| {label} | {current} | {change} |")
    lines.extend(["", "| Jam budget | Warn at | Fail above |", "| --- | ---: | ---: |"])
    for key, values in report["size_budget"].items():
        warn = "Disabled" if values["warn_mb"] is None else f"{values['warn_mb']:g} MB"
        fail = "Disabled" if values["fail_mb"] is None else f"{values['fail_mb']:g} MB"
        lines.append(f"| {SIZE_LABELS[key + '_bytes']} | {warn} | {fail} |")
    lines.extend(["", f"Included game files: {report['game_file_count']:,}. "
                  f"Exported web files: {report['web_file_count'] if report['web_file_count'] is not None else 'unavailable'}."])
    if report["largest_web_file"]:
        item = report["largest_web_file"]
        lines.append(f"Largest web file: {safe_text(item['path'])} ({format_bytes(item['bytes'])}).")
    memory = report["initial_memory_bytes"]
    lines.extend([f"Configured initial WebAssembly memory: {memory / (1024 ** 2):g} MiB ({memory:,} bytes). "
                  "This is not measured browser RAM; decoded textures/audio and other allocations need additional memory.",
                  "", "## Largest included game files", "",
                  "| Path | Before compression | Inside .love |", "| --- | ---: | ---: |"])
    for item in report["largest_game_files"]:
        lines.append(f"| {safe_text(item['path'])} | {format_bytes(item['bytes'])} | {format_bytes(item['compressed_bytes'])} |")
    lines.extend(["", "The game bundle contains all these files; it is not additional content alongside game.data.",
                  "The .love and ZIP sizes do not predict decoded asset memory.", ""])
    for title, key in [("Warnings", "warnings"), ("Failures", "errors")]:
        if report[key]:
            lines.extend([f"## {title}", ""])
            lines.extend(f"- {safe_text(message)}" for message in report[key])
            lines.append("")
    if report["phase"] != "complete":
        lines.append("Web export did not complete; upload size and full hosting checks are unavailable.")
    else:
        lines.append("Hosting checks cover 200 MB per file, 500 MB extracted total, 1,000 web files, and 240-character paths.")
    lines.extend(["", "Budget thresholds live in build.json. They are early jam targets, not itch.io's maximums.",
                  "Playtest web builds regularly; passing size checks does not verify runtime behavior.", ""])
    return "\n".join(lines)


def read_baseline(dist):
    try:
        value = json.loads((dist / "size-baseline.json").read_text(encoding="utf-8"))
        return value if isinstance(value, dict) else None
    except (OSError, ValueError):
        return None


def save(report, dist):
    dist.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(report, indent=2, ensure_ascii=False) + "\n"
    (dist / "size-report.json").write_text(payload, encoding="utf-8")
    (dist / "size-report.md").write_text(markdown(report), encoding="utf-8")
    if report["phase"] == "complete" and report["status"] != "failed":
        (dist / "size-baseline.json").write_text(payload, encoding="utf-8")


def print_report(report):
    print(f"\nBuild size: {report['status'].upper()} (decimal MB)")
    for name, label in SIZE_LABELS.items():
        value = report["metrics"][name]
        current = format_bytes(value) if value is not None else "unavailable"
        delta = report["delta_bytes"].get(name)
        change = "" if delta is None else f" ({'+' if delta > 0 else ''}{format_bytes(delta)} since last successful build)"
        print(f"  {label}: {current}{change}")
    for key, values in report["size_budget"].items():
        warn = "off" if values["warn_mb"] is None else f"{values['warn_mb']:g} MB"
        fail = "off" if values["fail_mb"] is None else f"{values['fail_mb']:g} MB"
        print(f"  {SIZE_LABELS[key + '_bytes']} budget: warn at {warn}; fail above {fail}")
    print("  Largest included game files (raw / compressed inside .love):")
    for item in report["largest_game_files"]:
        print(f"    {format_bytes(item['bytes']):>11} / {format_bytes(item['compressed_bytes']):>11}  {safe_text(item['path'])}")
    for message in report["warnings"]:
        print(f"  WARNING: {message}")
    for message in report["errors"]:
        print(f"  FAIL: {message}")
    print("  Full report: dist/size-report.md (configured memory is not measured runtime RAM)\n")
