"""Regression coverage for docs/skills validator scripts."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).parent.parent
SCRIPTS = ROOT / "scripts"


def _copy_validator_scripts(tmp_path: Path) -> Path:
    scripts_dir = tmp_path / "scripts"
    scripts_dir.mkdir(parents=True, exist_ok=True)
    for script in (
        "check-doc-links.sh",
        "check-skill-frontmatter.sh",
        "generate_skill_index.py",
    ):
        shutil.copy2(SCRIPTS / script, scripts_dir / script)
    return scripts_dir


def _write_skill(path: Path, skill_id: str = "qa-smoke") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    entry_point = f"docs/skills/{path.name}"
    path.write_text(
        "\n".join(
            [
                "---",
                f"name: {skill_id}",
                'version: "1.0"',
                'last_updated: "2026-08-01"',
                f"id: {skill_id}",
                "one_line_purpose: validator coverage smoke skill",
                f"entry_point: {entry_point}",
                "category: test-authoring",
                "status: active",
                "tags: [qa, docs]",
                "description: Minimal test skill.",
                "metadata:",
                "  type: reference",
                "---",
                "",
                "# Test skill",
            ]
        )
        + "\n",
        encoding="utf-8",
    )


def test_check_doc_links_reports_broken_link(tmp_path: Path) -> None:
    _copy_validator_scripts(tmp_path)
    docs = tmp_path / "docs"
    docs.mkdir()
    (docs / "guide.md").write_text("[Missing](missing.md)\n", encoding="utf-8")

    result = subprocess.run(
        ["python3", "scripts/check-doc-links.sh"],
        cwd=tmp_path,
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 1
    assert "error: broken link in docs/guide.md -> missing.md" in result.stdout


def test_check_skill_frontmatter_fails_without_frontmatter(tmp_path: Path) -> None:
    _copy_validator_scripts(tmp_path)
    skills = tmp_path / "docs" / "skills"
    skills.mkdir(parents=True)
    (skills / "broken.md").write_text("# no front matter\n", encoding="utf-8")

    result = subprocess.run(
        ["bash", "scripts/check-skill-frontmatter.sh"],
        cwd=tmp_path,
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 1
    assert "error: docs/skills/broken.md has no front-matter" in result.stdout


def test_generate_skill_index_write_creates_catalog(tmp_path: Path) -> None:
    _copy_validator_scripts(tmp_path)
    skills = tmp_path / "docs" / "skills"
    skills.mkdir(parents=True)
    shutil.copy2(ROOT / "docs/skills/index.schema.json", skills / "index.schema.json")
    _write_skill(skills / "qa-smoke.md")

    result = subprocess.run(
        ["python3", "scripts/generate_skill_index.py", "--write"],
        cwd=tmp_path,
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 0
    assert (skills / "index.json").exists()
    assert (skills / "index.md").exists()
    assert '"id": "qa-smoke"' in (skills / "index.json").read_text(encoding="utf-8")


def test_generate_skill_index_check_fails_on_stale_files(tmp_path: Path) -> None:
    _copy_validator_scripts(tmp_path)
    skills = tmp_path / "docs" / "skills"
    skills.mkdir(parents=True)
    shutil.copy2(ROOT / "docs/skills/index.schema.json", skills / "index.schema.json")
    _write_skill(skills / "qa-smoke.md")
    (skills / "index.json").write_text("{}\n", encoding="utf-8")
    (skills / "index.md").write_text("stale\n", encoding="utf-8")

    result = subprocess.run(
        ["python3", "scripts/generate_skill_index.py", "--check"],
        cwd=tmp_path,
        text=True,
        capture_output=True,
        check=False,
    )

    assert result.returncode == 1
    assert "error: docs/skills/index.json is stale." in result.stderr
    assert "error: docs/skills/index.md is stale." in result.stderr
