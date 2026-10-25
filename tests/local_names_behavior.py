"""Run the ranked-name regression against baseline and current Luau source."""
from pathlib import Path
import os, re, subprocess, tempfile

root = Path(__file__).resolve().parents[1]
source = (root / "local_names.lua").read_text(encoding="utf-8")
fixture = Path(__file__).with_name("local_names.lua").read_text(encoding="utf-8")
fixture = fixture.replace("children={},signals={},attrs={},DescendantAdded=signal()",
                          "children={},signals={},attrs={},DescendantAdded=signal(),DescendantRemoving=signal()")
marker = 'assert(conflictingRank.Text=="#3 - OriginalUser","conflicting ranked identity stays untouched")'
fixture = fixture[:fixture.index(marker) + len(marker)] + '\nprint("PASS: ranked leaderboard names")\n'

def run(code, same_names=False):
    with tempfile.TemporaryDirectory(prefix="larpblox-names-") as folder:
        path = Path(folder) / "local_names.lua"
        scenario = fixture.replace('Original Display', 'OriginalUser') if same_names else fixture
        path.write_text(scenario.replace('local make=dofile("local_names.lua")',
                                         f"local make=(function()\n{code}\nend)()"), encoding="utf-8")
        return subprocess.run([os.environ.get("LUAU", "luau"), str(path)], capture_output=True, text=True)

baseline = re.sub(r'\n    local semanticField\n    local ancestor=entry.object.*?\n    local name=text:match',
                  '\n    local name=text:match', source, count=1, flags=re.S)
old = run(baseline)
assert old.returncode != 0, "baseline unexpectedly passed ranked-name regression"
print("baseline: RED (ranked names stayed real)")
current = run(source)
print(current.stdout, end="")
current.check_returncode()
same = run(source, same_names=True)
same.check_returncode()
print("PASS: identical original username/display still select separate aliases")
