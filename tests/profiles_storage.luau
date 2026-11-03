-- DataStore contract tests with an in-memory atomic UpdateAsync double.
local passed = 0
local function check(condition, message)
	passed += 1
	if not condition then error("FAIL: " .. message, 2) end
end
local Profiles = Require(ServerScriptService.Server.Services.Profiles)
local realWait = task.wait
task.wait = function() return 0 end
RunService.IsStudio = function() return false end

local records, failMode, writes = {}, false, 0
local store = {}
function store:UpdateAsync(key, transform)
	writes += 1
	if failMode then error("simulated outage") end
	local old = records[key]
	local new = transform(old and table.clone(old) or nil)
	if new ~= nil then records[key] = new end
	return new and table.clone(new) or nil
end
Profiles.store = store

local alice = Instance.new("Player"); alice.UserId = 101; alice.Name = "Alice"
local bob = Instance.new("Player"); bob.UserId = 202; bob.Name = "Bob"
local session = Profiles:Load(alice)
check(session.canSave and session.status == "saved", "successful load is writable")
check(records.u_101.lock.id == session.lockId, "load acquires session lock")
Profiles:Add(alice, { xp = 275, kills = 4 })
Profiles:Best(alice, 7)
check(Profiles:Save(alice, false), "autosave succeeds")
check(records.u_101.xp == 275 and records.u_101.bestWave == 7, "autosave writes progress")
check(records.u_101.lock.id == session.lockId, "autosave keeps ownership")

local other = Profiles:Load(bob)
check(other.status ~= "locked", "different user can load")
-- Simulate Alice hopping to a second server while her first lock is alive.
local aliceKey = "u_101"
local savedLock = records[aliceKey].lock
local second = { data = {}, canSave = false, status = "loading", closed = false, lost = false, lockId = "second-server" }
local kicked
alice.Kick = function(_, message) kicked = message end
local realSessions = Profiles.Sessions
Profiles.Sessions = { [alice] = second }
local locked = Profiles:Load(alice)
check(locked.status == "locked" and not locked.canSave, "live foreign lock blocks load")
check(kicked ~= nil, "locked player is told to retry")
check(records[aliceKey].lock.id == savedLock.id, "blocked load does not steal lock")
Profiles.Sessions = realSessions

check(Profiles:Save(alice, true), "final save succeeds")
check(records.u_101.lock == nil, "final save releases lock")
check(Profiles.Sessions[alice] == nil, "released session is removed")

-- A failed load must never overwrite an existing cloud record with defaults.
records.u_303 = { schema = 1, xp = 999, wins = 3, bestWave = 12, kills = 40, matches = 5 }
local carol = Instance.new("Player"); carol.UserId = 303; carol.Name = "Carol"
failMode = true
local beforeWrites = writes
local failed = Profiles:Load(carol)
check(failed.status == "unavailable" and not failed.canSave, "outage produces read-only temporary profile")
Profiles:Add(carol, { xp = 500 })
check(not Profiles:Save(carol, true), "temporary profile cannot write")
check(records.u_303.xp == 999 and records.u_303.wins == 3, "outage does not erase cloud progress")
failMode = false

-- Disconnect during initial load must not leave a fresh lock behind.
local dave = Instance.new("Player"); dave.UserId = 404; dave.Name = "Dave"
local realUpdate = store.UpdateAsync
store.UpdateAsync = function(self, key, transform)
	local result = realUpdate(self, key, transform)
	local pending = Profiles.Sessions[dave]
	if pending then pending.closed = true; Profiles.Sessions[dave] = nil end
	return result
end
local abandoned = Profiles:Load(dave)
check(abandoned.closed, "disconnect races with load")
check(records.u_404 == nil or records.u_404.lock == nil, "abandoned load releases its own lock")
store.UpdateAsync = realUpdate

task.wait = realWait
print(string.format("profiles_storage: %d assertions passed", passed))
