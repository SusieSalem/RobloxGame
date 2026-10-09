-- Drives
-- Helpers that bend the ragdoll's ball-socket joints with AlignOrientations.

local Shared = require(script.Parent.Shared)

local Config = Shared.Config

local Drives = {}

-- A drive bends a ball-socket joint toward an angle relative to its parent
-- part by moving a target attachment that the child's attachment chases.
function Drives.make(rigState, jointName: string, maxTorque: number, responsiveness: number)
	local joint = rigState.joints[jointName]
	if not joint then
		return nil
	end
	local target = Instance.new("Attachment")
	target.Name = "HFFDriveTarget_" .. jointName
	target.CFrame = joint.a0.CFrame
	target.Parent = joint.part0

	local align = Instance.new("AlignOrientation")
	align.Name = "HFFDrive_" .. jointName
	align.Mode = Enum.OrientationAlignmentMode.TwoAttachment
	align.Attachment0 = joint.a1
	align.Attachment1 = target
	align.MaxTorque = maxTorque
	align.Responsiveness = responsiveness
	align.Parent = joint.part1

	table.insert(rigState.instances, target)
	table.insert(rigState.instances, align)
	return { align = align, target = target, base = joint.a0.CFrame, maxTorque = maxTorque }
end

-- Joint frames have X along the limb and Y along the body's right axis, so a
-- positive angle about Y swings the limb forward.
function Drives.set(drive, angle: number, strength: number, enabled: boolean)
	if not drive then
		return
	end
	drive.align.Enabled = enabled and strength > 0
	drive.align.MaxTorque = drive.maxTorque * strength
	drive.target.CFrame = drive.base * CFrame.Angles(0, angle, 0)
end

-- Like setDrive, but with a sideways angle too and an explicit torque. Used by
-- the Euphoria-style reactions. Positive side swings the limb toward +X (the
-- character's right).
function Drives.pose(drive, forward: number, side: number, torque: number)
	if not drive then
		return
	end
	drive.align.Enabled = torque > 0
	drive.align.MaxTorque = torque
	drive.target.CFrame = drive.base * CFrame.Angles(0, forward, side)
end

-- Arms aim in world space, so they use one-attachment AlignOrientations.
function Drives.makeArmAlign(rigState, jointName: string)
	local joint = rigState.joints[jointName]
	if not joint then
		return nil
	end
	local align = Instance.new("AlignOrientation")
	align.Name = "HFFReach_" .. jointName
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = joint.a1
	align.MaxTorque = Config.ArmMaxTorque
	align.Responsiveness = Config.ArmResponsiveness
	align.MaxAngularVelocity = Config.ArmMaxAngularVelocity
	align.Enabled = false
	align.Parent = joint.part1
	table.insert(rigState.instances, align)
	return align
end

return Drives
