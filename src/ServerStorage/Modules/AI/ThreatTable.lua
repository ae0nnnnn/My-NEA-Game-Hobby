local ThreatTable = {}

local RECENCY_DECAY_RATE = 0.5 -- threat points lost per second since last hit

function ThreatTable.Init(Object)
	Object.Threats = {
		entries = {},
		currentTarget = nil,
		maxRange = (Object.AggroRange or 30),
	}
end

local function getEntry(Object, char)
	local entries = Object.Threats.entries
	if not entries[char] then
		entries[char] = { damage = 0, lastHit = 0, healing = 0 }
	end
	return entries[char]
end

function ThreatTable.RegisterHit(Object, targetChar, damage)
	if not Object.Threats then
		return
	end
	local entry = getEntry(Object, targetChar)
	entry.damage += damage
	entry.lastHit = os.clock()
end

function ThreatTable.RegisterDamage(Object, attackerChar, damage)
	if not Object.Threats then
		return
	end
	local entry = getEntry(Object, attackerChar)
	entry.damage += damage
	entry.lastHit = os.clock()
end

function ThreatTable.RegisterHealing(Object, targetChar, amount)
	if not Object.Threats then
		return
	end
	local entry = getEntry(Object, targetChar)
	entry.healing += amount
	entry.lastHit = os.clock()
end

local function threatScore(entry)
	local now = os.clock()
	local recency = math.max(0, 1 - (now - entry.lastHit) * RECENCY_DECAY_RATE)
	return entry.damage * 1.0 + (entry.healing > 0 and 0.5 or 0) + recency
end

function ThreatTable.GetTopThreat(Object)
	if not Object.Threats then
		return nil
	end
	local best, bestScore = nil, -math.huge

	for char, entry in pairs(Object.Threats.entries) do
		if char and char.Parent and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
			local score = threatScore(entry)
			if score > bestScore then
				best, bestScore = char, score
			end
		end
	end

	Object.Threats.currentTarget = best
	if best then
		Object.Target = best
	end
	return best
end

function ThreatTable.ClearDead(Object)
	if not Object.Threats then
		return
	end
	for char in pairs(Object.Threats.entries) do
		local dead = (not char) or not char.Parent or (char:FindFirstChild("Humanoid") and char.Humanoid.Health <= 0)
		if dead then
			Object.Threats.entries[char] = nil
			if Object.Threats.currentTarget == char then
				Object.Threats.currentTarget = nil
			end
		end
	end
end

function ThreatTable.Reset(Object)
	if not Object.Threats then
		return
	end
	Object.Threats.entries = {}
	Object.Threats.currentTarget = nil
end

return ThreatTable
