from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import unittest
import xml.etree.ElementTree as ET

from tree_sitter import Language, Parser
import tree_sitter_luau

ROOT = Path(__file__).resolve().parents[1]


class ProjectTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.parser = Parser(Language(tree_sitter_luau.language()))

    def test_luau_syntax(self) -> None:
        files = sorted((ROOT / "src").rglob("*.luau"))
        self.assertGreater(len(files), 10)
        for path in files:
            with self.subTest(path=path.relative_to(ROOT)):
                tree = self.parser.parse(path.read_bytes())
                self.assertFalse(tree.root_node.has_error, f"Syntax error in {path}")

    def test_rojo_project_paths(self) -> None:
        project = json.loads((ROOT / "default.project.json").read_text(encoding="utf-8"))
        tree = project["tree"]
        self.assertEqual(tree["$className"], "DataModel")
        for service, child in (("ReplicatedStorage", "Shared"), ("ServerScriptService", "Server")):
            self.assertTrue((ROOT / tree[service][child]["$path"]).is_dir())
        client = tree["StarterPlayer"]["StarterPlayerScripts"]["Client"]["$path"]
        self.assertTrue((ROOT / client).is_dir())

    def test_place_builder(self) -> None:
        output = ROOT / ".cache/test_place.rbxlx"
        output.parent.mkdir(parents=True, exist_ok=True)
        result = subprocess.run([sys.executable, str(ROOT / "tools/build_place.py"), "--output", str(output)], cwd=ROOT, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        root = ET.parse(output).getroot()
        self.assertEqual(root.tag, "roblox")
        classes = {item.attrib.get("class") for item in root.iter("Item")}
        for class_name in ("Workspace", "ReplicatedStorage", "ServerScriptService", "StarterPlayerScripts", "Script", "LocalScript", "ModuleScript"):
            self.assertIn(class_name, classes)
        sources = [node.text for node in root.iter("ProtectedString") if node.attrib.get("name") == "Source"]
        self.assertEqual(len(sources), len(list((ROOT / "src").rglob("*.luau"))))
        self.assertTrue(all(source and source.strip() for source in sources))

    def test_preview_and_docs(self) -> None:
        preview = ROOT / "docs/assets/rubezh-preview.svg"
        root = ET.parse(preview).getroot()
        self.assertEqual(root.tag, "{http://www.w3.org/2000/svg}svg")
        self.assertIn("НЕ СКРИНШОТ", preview.read_text(encoding="utf-8"))
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        self.assertIn("docs/assets/rubezh-preview.svg", readme)
        self.assertIn("Max Players = 4", readme)
        for name in ("CONTRIBUTING.md", "CHANGELOG.md", "docs/RELEASE.md", ".github/workflows/release.yml", ".github/pull_request_template.md"):
            self.assertTrue((ROOT / name).is_file(), name)

    def test_no_placeholder_sources(self) -> None:
        for path in (ROOT / "src").rglob("*.luau"):
            text = path.read_text(encoding="utf-8")
            self.assertNotIn("TODO", text, path)
            self.assertNotIn("TowerPlaceholder", text, path)
            self.assertGreater(len(text.strip()), 40, path)


if __name__ == "__main__":
    unittest.main()
