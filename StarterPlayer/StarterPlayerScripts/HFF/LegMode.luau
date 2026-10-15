-- LegMode
-- "Legs without ragdoll" setting. The leg joints normally are loose ball
-- sockets that muscles (AlignOrientations) push toward the walk pose. With
-- the setting on, the hips and knees become fixed Motor6D joints that are
-- posed exactly like a normal walk animation, so the legs are part of the
-- body and nothing floppy or physical happens to them. Whenever the body goes
-- ragdoll (knocked down, falling, getting up) the sockets take over again.

local Shared = require(script.Parent.Shared)

local Config = Shared.Config

local LegMode = {}

local LEG_JOINTS = { "LeftHip", "LeftKnee", "RightHip", "RightKnee" }

local function setup(rigState)
	rigState.legMotors = {}
	for _, name in LEG_JOINTS do
		local joint = rigState.joints[name]
		if joint and joint.socket then
			local motor = Instance.new("Motor6D")
			motor.Name = "HFFLegMotor_" .. name
			motor.Part0 = joint.part0
			motor.Part1 = joint.part1
			motor.C0 = joint.a0.CFrame
			motor.C1 = joint.a1.CFrame
			motor.Enabled = false
			motor.Parent = joint.part1
			table.insert(rigState.instances, motor)
			rigState.legMotors[name] = motor
		end
	end
end

-- Call every step after the leg drives were posed. kinematic = true holds the
-- legs on their pose, false gives them back to the ragdoll sockets.
function LegMode.update(rigState, kinematic: boolean)
	if not rigState.legMotors then
		setup(rigState)
	end
	if kinematic ~= (rigState.legsKinematic or false) then
		rigState.legsKinematic = kinematic
		for name, motor in rigState.legMotors do
			local joint = rigState.joints[name]
			local drive = rigState.legDrives[name]
			if kinematic then
				joint.socket.Enabled = false
				motor.Transform = if drive and drive.rot then drive.rot else CFrame.identity
				motor.Enabled = true
			else
				motor.Enabled = false
				joint.socket.Enabled = true
			end
		end
	end
	if kinematic then
		for name, motor in rigState.legMotors do
			local drive = rigState.legDrives[name]
			if drive then
				drive.align.Enabled = false
				motor.Transform = drive.rot or CFrame.identity
			end
		end
	end
end

return LegMode
