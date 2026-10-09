-- Knockdown
-- Falling over, stumbling (stagger) and the manual ragdoll toggle.

local Shared = require(script.Parent.Shared)
local Util = require(script.Parent.Util)

local Config = Shared.Config

local Knockdown = {}

function Knockdown.knockDown(rigState, duration: number?)
	if rigState.state == "Dead" then
		return
	end
	rigState.state = "Knocked"
	rigState.stateTime = 0
	rigState.knockDuration = duration or Config.KnockdownTime
	rigState.tiltTimer = 0
end

-- Manual ragdoll toggle (R / gamepad Y / mobile button): you lose balance and
-- fight to stay up until you trip; then you stay down until toggled again.
function Knockdown.toggleRagdoll(rigState)
	if not rigState or rigState.state == "Dead" then
		return
	end
	if rigState.state == "Knocked" then
		if rigState.manualRagdoll then
			rigState.manualRagdoll = false
			rigState.knockDuration = 0 -- get up on the next step
		else
			rigState.manualRagdoll = true
			rigState.knockDuration = math.huge -- stay down until R again
		end
	elseif rigState.state == "Stagger" and rigState.teeterManual then
		rigState.state = "Active" -- caught yourself
		rigState.stateTime = 0
	else
		-- Lose balance: wobble and fight to stay up until you trip.
		local angle = math.random() * math.pi * 2
		rigState.state = "Stagger"
		rigState.stateTime = 0
		rigState.teeterManual = true
		rigState.teeterDrift = Vector3.new(math.cos(angle), 0, math.sin(angle)) * math.rad(Config.TeeterStartTilt)
	end
end

-- Impacts and tipping over.
function Knockdown.update(rigState, dt: number, now: number)
	local velocity = rigState.core.AssemblyLinearVelocity
	local velocityChange = (velocity - rigState.lastVelocity).Magnitude
	rigState.lastVelocity = velocity
	if rigState.skipImpactCheck then
		rigState.skipImpactCheck = false
		velocityChange = 0
	end

	if rigState.state == "Knocked" then
		if rigState.stateTime >= rigState.knockDuration then
			rigState.state = "Recovering"
			rigState.stateTime = 0
			rigState.graceUntil = now + Config.RecoverGrace
		end
		return
	end
	if now < rigState.graceUntil then
		rigState.tiltTimer = 0
		return
	end

	if velocityChange > Config.ImpactKnockdownSpeed then
		Knockdown.knockDown(rigState)
		return
	end
	-- A smaller hit makes you stumble: weaker balance and catch-steps in the
	-- direction you were shoved.
	if Config.EuphoriaEnabled and velocityChange > Config.StaggerSpeed and rigState.state == "Active" then
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		rigState.state = "Stagger"
		rigState.stateTime = 0
		rigState.teeterManual = false
		rigState.teeterDrift = if flat.Magnitude > 0.1 then flat.Unit * math.rad(Config.StaggerTilt) else Vector3.zero
	end

	local upright = rigState.core.CFrame.UpVector.Y
	if upright < math.cos(math.rad(Config.FallTiltAngle)) then
		rigState.tiltTimer += dt
		if rigState.tiltTimer > Config.FallTiltTime then
			Knockdown.knockDown(rigState)
		end
	else
		rigState.tiltTimer = 0
	end
end

-- Staggering: the body tips along teeterDrift. The tip grows on its own
-- (unstable, like balancing on a ball), wobbles randomly, and the player can
-- fight it with the movement keys. Tip too far and you trip.
-- Returns the balance strength multiplier.
function Knockdown.updateStagger(rigState, dt: number, now: number, moveDirection: Vector3): number
	if rigState.state ~= "Stagger" then
		return 1
	end
	local manual = rigState.teeterManual
	local drift = rigState.teeterDrift
	local wobble = Vector3.new(Util.noise(now * 1.3, 31), 0, Util.noise(now * 1.3, 32)) * Config.TeeterWobble
	local growth = drift * (Config.TeeterInstability - (if manual then 0 else Config.StaggerRecovery))
	drift += (growth + wobble - moveDirection * Config.TeeterPlayerControl) * dt
	rigState.teeterDrift = drift
	if drift.Magnitude > math.rad(Config.TeeterFallAngle) then
		Knockdown.knockDown(rigState, if manual then math.huge else nil)
		rigState.manualRagdoll = manual
	elseif not manual and (rigState.stateTime > Config.StaggerTime or (rigState.stateTime > 0.4 and drift.Magnitude < math.rad(3))) then
		rigState.state = "Active"
		rigState.stateTime = 0
	end
	return Config.StaggerBalance
end

return Knockdown
