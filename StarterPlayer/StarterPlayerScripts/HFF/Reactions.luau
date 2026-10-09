-- Reactions
-- Euphoria-style active ragdoll: instead of going limp the body keeps
-- "muscles" and reacts. It flails while falling, braces toward the impact,
-- squirms on the ground, pushes itself up, and windmills its arms while
-- stumbling.

local Workspace = game:GetService("Workspace")

local Shared = require(script.Parent.Shared)
local Util = require(script.Parent.Util)
local Drives = require(script.Parent.Drives)

local Config = Shared.Config
local poseDrive = Drives.pose

local Reactions = {}


local function outward(side: string): number
	return if side == "Left" then -1 else 1
end

local noise = Util.noise

-- World-space frame for a one-attachment arm align pointing along aim.
local function armFrame(core: BasePart, aim: Vector3): CFrame
	local right = core.CFrame.RightVector
	local up = right - aim * aim:Dot(right)
	if up.Magnitude < 1e-3 then
		up = core.CFrame.UpVector
	end
	return CFrame.fromMatrix(Vector3.zero, aim, up.Unit)
end

local function setArmReach(arm, frame: CFrame?, torque: number)
	for _, align in { arm.upper, arm.lower } do
		if align then
			align.Enabled = frame ~= nil
			align.MaxTorque = torque
			if frame then
				align.CFrame = frame
			end
		end
	end
end

local function chooseReaction(rigState, velocity: Vector3, grounded: boolean, reaching: boolean): string?
	local state = rigState.state
	if state == "Knocked" then
		local nearGround = Workspace:Raycast(
			rigState.core.Position,
			Vector3.new(0, -Config.EuphoriaGroundProbe, 0),
			rigState.raycastParams
		)
		if not nearGround and velocity.Y < -Config.FallPanicSpeed * 0.5 then
			return "Flail"
		elseif velocity.Magnitude > Config.EuphoriaBraceSpeed then
			return "Brace"
		end
		return "Writhe"
	elseif state == "Stagger" then
		return "Stagger"
	elseif state == "Recovering" and rigState.stateTime < Config.RecoverTime * 0.6 then
		return "PushUp"
	elseif not grounded and velocity.Y < -Config.FallPanicSpeed and not reaching then
		return "Flail" -- long fall while still on your feet
	end
	return nil
end

function Reactions.apply(rigState, dt: number, velocity: Vector3, grounded: boolean, reaching: boolean)
	rigState.reactionTime += dt
	local t = rigState.reactionTime
	local mode = if Config.EuphoriaEnabled then chooseReaction(rigState, velocity, grounded, reaching) else nil
	rigState.reactionMode = mode
	local legs = rigState.legDrives
	local core = rigState.core
	-- The player keeps their arms while stumbling or getting up if they're reaching.
	local armsFree = rigState.state == "Knocked" or not reaching

	if not mode then
		for _, drive in rigState.elbowDrives do
			if drive then
				drive.align.Enabled = false
			end
		end
		for _, arm in rigState.arms do
			if arm.upper then
				arm.upper.MaxTorque = Config.ArmMaxTorque
			end
			if arm.lower then
				arm.lower.MaxTorque = Config.ArmMaxTorque
			end
		end
		return
	end

	if mode == "Flail" then
		-- Windmilling arms and pedalling legs.
		local torque = Config.EuphoriaFlailTorque
		for side, arm in rigState.arms do
			if armsFree then
				setArmReach(arm, nil, 0)
				local phase = if side == "Left" then 0 else math.pi
				poseDrive(rigState.armSwingDrives[side], math.sin(t * 9 + phase) * 1.5, outward(side) * (0.9 + 0.4 * math.sin(t * 7)), torque)
				poseDrive(rigState.elbowDrives[side], 0.6 + 0.5 * math.sin(t * 11 + phase), 0, torque)
			end
		end
		poseDrive(legs.LeftHip, math.sin(t * 8) * 0.9, -0.2, torque)
		poseDrive(legs.RightHip, -math.sin(t * 8) * 0.9, 0.2, torque)
		poseDrive(legs.LeftKnee, -0.7 - 0.5 * math.cos(t * 8), 0, torque)
		poseDrive(legs.RightKnee, -0.7 + 0.5 * math.cos(t * 8), 0, torque)
		poseDrive(rigState.headDrive, 0.3, 0, Config.HeadMaxTorque)
	elseif mode == "Brace" then
		-- Protective reflex: hands out toward where you're tumbling, chin tucked.
		local travel = if velocity.Magnitude > 0.1 then velocity.Unit else Vector3.zero
		local aim = (travel * 0.7 + Vector3.new(0, -1, 0)).Unit
		local frame = armFrame(core, aim)
		for side, arm in rigState.arms do
			setArmReach(arm, frame, Config.EuphoriaBraceTorque)
			poseDrive(rigState.elbowDrives[side], 0.25, 0, Config.EuphoriaBraceTorque)
		end
		poseDrive(legs.LeftHip, 0.5, -0.15, Config.EuphoriaFlailTorque)
		poseDrive(legs.RightHip, 0.5, 0.15, Config.EuphoriaFlailTorque)
		poseDrive(legs.LeftKnee, -0.8, 0, Config.EuphoriaFlailTorque)
		poseDrive(legs.RightKnee, -0.8, 0, Config.EuphoriaFlailTorque)
		poseDrive(rigState.headDrive, 0.6, 0, Config.HeadMaxTorque * 2)
	elseif mode == "Writhe" then
		-- Weak, slow squirming on the ground (dazed).
		local torque = Config.EuphoriaWritheTorque
		local speed = 0.9
		for side, arm in rigState.arms do
			setArmReach(arm, nil, 0)
			local seed = if side == "Left" then 1 else 2
			poseDrive(rigState.armSwingDrives[side], noise(t * speed, seed) * 1.4, outward(side) * (0.4 + 0.4 * noise(t * speed, seed + 10)), torque)
			poseDrive(rigState.elbowDrives[side], 0.5 + 0.6 * noise(t * speed, seed + 20), 0, torque)
		end
		poseDrive(legs.LeftHip, 0.3 + noise(t * speed, 3) * 0.8, -0.1, torque)
		poseDrive(legs.RightHip, 0.3 + noise(t * speed, 4) * 0.8, 0.1, torque)
		poseDrive(legs.LeftKnee, -0.6 + noise(t * speed, 5) * 0.6, 0, torque)
		poseDrive(legs.RightKnee, -0.6 + noise(t * speed, 6) * 0.6, 0, torque)
		poseDrive(rigState.headDrive, noise(t * 0.5, 7) * 0.5, noise(t * 0.5, 8) * 0.4, Config.HeadMaxTorque)
	elseif mode == "PushUp" then
		-- Hands to the floor, knees tucked, then the balance ramp stands you up.
		local aim = (Vector3.new(0, -1, 0) + core.CFrame.LookVector * 0.4).Unit
		local frame = armFrame(core, aim)
		for side, arm in rigState.arms do
			if armsFree then
				setArmReach(arm, frame, Config.PushUpTorque)
				poseDrive(rigState.elbowDrives[side], 0.2, 0, Config.PushUpTorque)
			end
		end
		poseDrive(legs.LeftHip, 1.0, -0.1, Config.EuphoriaBraceTorque)
		poseDrive(legs.RightHip, 1.0, 0.1, Config.EuphoriaBraceTorque)
		poseDrive(legs.LeftKnee, -1.3, 0, Config.EuphoriaBraceTorque)
		poseDrive(legs.RightKnee, -1.3, 0, Config.EuphoriaBraceTorque)
	elseif mode == "Stagger" then
		-- Arms thrown out and windmilling harder the closer you are to tripping.
		local panic = math.clamp(rigState.teeterDrift.Magnitude / math.rad(Config.TeeterFallAngle), 0, 1)
		for side, arm in rigState.arms do
			if armsFree then
				setArmReach(arm, nil, 0)
				local phase = if side == "Left" then 0 else math.pi
				local swingAmount = 0.3 + 1.0 * panic
				poseDrive(
					rigState.armSwingDrives[side],
					math.sin(t * (6 + 6 * panic) + phase) * swingAmount,
					outward(side) * (0.8 + 0.6 * panic),
					Config.EuphoriaFlailTorque
				)
				poseDrive(rigState.elbowDrives[side], 0.4, 0, Config.EuphoriaFlailTorque)
			end
		end
	end
end


return Reactions
