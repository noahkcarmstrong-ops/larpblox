"""Run the player-collision module in the real Luau interpreter."""
from pathlib import Path
import json
import subprocess
import tempfile


ROOT = Path(__file__).parents[1]
LUAU = Path(r"C:\Users\noahk\AppData\Local\Temp\larpblox-luau-0.743\luau.exe")


HARNESS = r'''
local function signal()
    local s = {listeners = {}}
    function s:Connect(fn)
        local c = {Connected = true}
        function c:Disconnect() c.Connected = false end
        table.insert(s.listeners, {c = c, fn = fn})
        return c
    end
    function s:Fire(...)
        for _, entry in ipairs(s.listeners) do if entry.c.Connected then entry.fn(...) end end
    end
    function s:activeCount()
        local count = 0
        for _, entry in ipairs(s.listeners) do if entry.c.Connected then count = count + 1 end end
        return count
    end
    return s
end

local function node(className, name)
    local n = {ClassName = className, Name = name or className, Parent = nil, children = {},
        DescendantAdded = signal(), DescendantRemoving = signal(), changed = {}}
    function n:IsA(kind) return kind == self.ClassName or (kind == "BasePart" and self.ClassName == "BasePart") end
    function n:GetPropertyChangedSignal(property)
        self.changed[property] = self.changed[property] or signal()
        return self.changed[property]
    end
    function n:GetDescendants()
        local result = {}
        local function visit(value)
            for _, child in ipairs(value.children) do table.insert(result, child); visit(child) end
        end
        visit(self)
        return result
    end
    function n:Add(child)
        table.insert(self.children, child); child.Parent = self; self.DescendantAdded:Fire(child)
    end
    function n:Remove(child)
        for i, value in ipairs(self.children) do if value == child then table.remove(self.children, i); break end end
        child.Parent = nil; self.DescendantRemoving:Fire(child)
    end
    function n:Destroy() self.destroyed = true; self.Parent = nil end
    return n
end

local workspace = node("Workspace", "Workspace")
local floor = node("BasePart", "WorldFloor"); floor.CanCollide = true; workspace:Add(floor)
local madeConstraints = {}
Instance = {new = function(className)
    local value = node(className)
    if className == "NoCollisionConstraint" then table.insert(madeConstraints, value) end
    return value
end}
local function player(name)
    local p = {Name = name, Character = nil, CharacterAdded = signal(), CharacterRemoving = signal()}
    return p
end
local players = {LocalPlayer = player("local"), PlayerAdded = signal(), PlayerRemoving = signal()}
function players:GetPlayers() return self.current end
players.current = {players.LocalPlayer}
local function setCharacter(p, character)
    if p.Character then p.CharacterRemoving:Fire(p.Character) end
    p.Character = character
    if character then p.CharacterAdded:Fire(character) end
end
local function rig(name, collide)
    local c = node("Model", name)
    local part = node("BasePart", name .. "Part"); part.CanCollide = collide
    c:Add(part)
    return c, part
end
local function activeConstraints()
    local count = 0
    for _, value in ipairs(madeConstraints) do if not value.destroyed then count = count + 1 end end
    return count
end

local factory = loadstring(__SOURCE__)()
local localCharacter, localPart = rig("local", true)
local remote = player("remote"); local remoteCharacter, remotePart = rig("remote", true)
setCharacter(players.LocalPlayer, localCharacter)
setCharacter(remote, remoteCharacter)
table.insert(players.current, remote); players.PlayerAdded:Fire(remote)
local originalLocal, originalRemote = localPart.CanCollide, remotePart.CanCollide
local api = factory(players, workspace)
assert(not api.isEnabled() and #madeConstraints == 0, "default is off")
api.setEnabled(true)
assert(api.isEnabled() and activeConstraints() == 1, "existing characters pair once")
local constraint = madeConstraints[1]
assert(constraint.Part0 == localPart or constraint.Part1 == localPart, "local part is paired")
local extra = node("BasePart", "extra"); extra.CanCollide = true; localCharacter:Add(extra)
assert(activeConstraints() == 2, "new local parts pair")
api.setEnabled(true); assert(activeConstraints() == 2, "repeated enable does not duplicate constraints")
local remote2, remotePart2 = rig("remote2", true); setCharacter(remote, remote2)
assert(activeConstraints() == 2, "remote respawn replaces old pairs")
local late = player("late"); local lateCharacter, latePart = rig("late", true); setCharacter(late, lateCharacter)
table.insert(players.current, late); players.PlayerAdded:Fire(late)
assert(activeConstraints() == 4, "new players pair all local parts")
latePart.CanCollide = false; latePart.changed.CanCollide:Fire()
assert(activeConstraints() == 2, "non-collidable parts do not keep a constraint")
latePart.CanCollide = true; latePart.changed.CanCollide:Fire()
assert(activeConstraints() == 4, "CanCollide true restores one pair")
remote2:Remove(remotePart2)
assert(activeConstraints() == 2, "DescendantRemoving removes remote pairs")
local replacement = node("BasePart", "replacement"); replacement.CanCollide = true; remote2:Add(replacement)
assert(activeConstraints() == 4, "DescendantAdded restores remote pairs")
local oldLocal = localPart
local freshLocal, freshLocalPart = rig("localRespawn", true); setCharacter(players.LocalPlayer, freshLocal)
assert(activeConstraints() == 2 and oldLocal ~= freshLocal, "local respawn replaces old pairs")
table.remove(players.current, 3); players.PlayerRemoving:Fire(late)
assert(activeConstraints() == 1, "player leave removes all pairs")
latePart.CanCollide = false; latePart.changed.CanCollide:Fire()
assert(activeConstraints() == 1, "removed players stay unwatched")
api.setEnabled(false)
assert(not api.isEnabled() and workspace.destroyed == nil and localPart.CanCollide == originalLocal
    and remotePart.CanCollide == originalRemote and latePart.CanCollide == false
    and floor.CanCollide == true and floor.Parent == workspace, "disable restores properties")
for _, value in ipairs(madeConstraints) do assert(value.destroyed, "disable destroys constraints") end
api.setEnabled(true); assert(activeConstraints() == 1, "re-enable creates a fresh set")
api.destroy(); assert(not api.isEnabled() and activeConstraints() == 0, "destroy cleans up")
assert(players.PlayerAdded:activeCount() == 0 and players.PlayerRemoving:activeCount() == 0
    and players.LocalPlayer.CharacterAdded:activeCount() == 0
    and players.LocalPlayer.CharacterRemoving:activeCount() == 0, "destroy disconnects lifecycle events")
print("player collision lifecycle, respawn, joins, CanCollide, toggle, and cleanup checks passed")
'''


def main() -> None:
    source = (ROOT / "player_collisions.lua").read_text(encoding="utf-8")
    script = HARNESS.replace("__SOURCE__", json.dumps(source))
    with tempfile.NamedTemporaryFile("w", suffix=".luau", encoding="utf-8", delete=False) as handle:
        handle.write(script)
        path = handle.name
    try:
        result = subprocess.run([str(LUAU), path], cwd=ROOT, text=True, capture_output=True, check=False)
    finally:
        Path(path).unlink(missing_ok=True)
    if result.returncode:
        raise SystemExit(result.stderr or result.stdout)
    print(result.stdout.strip())


if __name__ == "__main__":
    main()
