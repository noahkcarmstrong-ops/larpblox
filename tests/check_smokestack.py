"""Run the real seasonal helper with a small Roblox-shaped fixture."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
source = (root / "avatar.lua").read_text()
fixture = (root / "tests/smokestack_seasons.lua").read_text()
with tempfile.NamedTemporaryFile(mode="w", suffix=".lua", delete=False, encoding="utf-8") as stream:
    stream.write("avatarSource=[====[" + source + "]====]\n" + fixture)
    runner = Path(stream.name)
try:
    result = subprocess.run(["npx.cmd", "--offline", "--package=fengari-node-cli", "fengari", str(runner)], cwd=root, text=True, capture_output=True)
    print(result.stdout + result.stderr, end="")
    assert result.returncode == 0 and "cleanup passed." in result.stdout, "seasonal checks failed"
finally:
    runner.unlink()
