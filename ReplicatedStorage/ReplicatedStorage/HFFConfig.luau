-- HFFConfig
-- Every tunable for the Human Fall Flat style controller lives here.
-- Shared by the server (ragdoll + grabbing) and the client (movement).
-- Units are studs, seconds and degrees unless a name says otherwise.

local Config = {}

---------------------------------------------------------------------------
-- Rig / joints (server)
---------------------------------------------------------------------------

-- R15 Motor6Ds that stay rigid. Everything else becomes a BallSocketConstraint.
Config.RigidJoints = {
	Root = true, -- HumanoidRootPart -> LowerTorso
	Waist = true, -- one solid torso, like HFF's bean body
	LeftWrist = true,
	RightWrist = true,
	LeftAnkle = true,
	RightAnkle = true,
}

-- UpperAngle: how far (cone, degrees) the limb can swing away from its rest pose.
-- TwistLower/TwistUpper: how far it can twist along its own length.
Config.JointLimits = {
	Neck = { UpperAngle = 40, TwistLower = -50, TwistUpper = 50 },
	LeftShoulder = { UpperAngle = 165, TwistLower = -70, TwistUpper = 70 },
	RightShoulder = { UpperAngle = 165, TwistLower = -70, TwistUpper = 70 },
	LeftElbow = { UpperAngle = 110, TwistLower = -20, TwistUpper = 20 },
	RightElbow = { UpperAngle = 110, TwistLower = -20, TwistUpper = 20 },
	LeftHip = { UpperAngle = 80, TwistLower = -30, TwistUpper = 30 },
	RightHip = { UpperAngle = 80, TwistLower = -30, TwistUpper = 30 },
	LeftKnee = { UpperAngle = 100, TwistLower = -10, TwistUpper = 10 },
	RightKnee = { UpperAngle = 100, TwistLower = -10, TwistUpper = 10 },
}
Config.DefaultJointLimit = { UpperAngle = 45, TwistLower = -30, TwistUpper = 30 }
Config.JointFrictionTorque = 2 -- a little stiffness so limp limbs don't spin forever

-- Physical properties of the body
Config.BodyDensity = 0.7
Config.BodyFriction = 0.5
Config.LegFriction = 0.2 -- low so dragging feet don't stop you walking
Config.BodyElasticity = 0
-- The Humanoid turns off collisions on arms/legs, so each limb gets an
-- invisible collider welded inside it. Scale is relative to the limb size.
Config.LimbColliderScale = Vector3.new(0.9, 0.85, 0.9)

---------------------------------------------------------------------------
-- Balance (client): soft AlignOrientation on the HumanoidRootPart
---------------------------------------------------------------------------
Config.BalanceMaxTorque = 25000
Config.BalanceResponsiveness = 25 -- 5..200, lower = wobblier
Config.BalanceMaxAngularVelocity = 18 -- rad/s
Config.LeanAngle = 12 -- forward lean at full speed

---------------------------------------------------------------------------
-- Standing / hovering (client): spring that holds the torso at hip height
---------------------------------------------------------------------------
Config.StandHeightScale = 1.0 -- multiplier on Humanoid.HipHeight + root half height
Config.GroundProbeExtra = 1.5 -- extra ray length below stand height that still counts as grounded
Config.HoverStiffness = 120
Config.HoverDamping = 16
Config.HoverMaxAcceleration = 420 -- caps the spring (about 2g)

---------------------------------------------------------------------------
-- Walking (client): velocity controller using a VectorForce
---------------------------------------------------------------------------
Config.WalkSpeed = 14
Config.WalkAcceleration = 6 -- how hard we chase the target velocity (1/s)
Config.WalkMaxAcceleration = 110 -- studs/s^2 cap, lower = more sluggish
Config.AirControl = 0.3 -- fraction of walk control while airborne or hanging

-- Procedural leg swing
Config.StepFrequency = 1.8 -- steps per second at full speed
Config.StrideAngle = 35
Config.KneeBendAngle = 45
Config.LegMaxTorque = 2500
Config.LegResponsiveness = 35
Config.HeadMaxTorque = 300
Config.HeadResponsiveness = 20

---------------------------------------------------------------------------
-- Jumping (client)
---------------------------------------------------------------------------
Config.JumpVelocity = 42
Config.JumpCooldown = 0.5
Config.CoyoteTime = 0.15 -- can still jump this long after leaving the ground
Config.JumpHoverGrace = 0.3 -- stand spring is off this long after a jump

---------------------------------------------------------------------------
-- Arms and grabbing
---------------------------------------------------------------------------
Config.ArmMaxTorque = 6000
Config.ArmResponsiveness = 40
Config.ArmMaxAngularVelocity = 25

Config.GrabRadius = 1.3 -- how close the hand must be to a part to grip it
Config.GrabRetryDelay = 0.35 -- wait between grab requests per hand
Config.ServerGrabTolerance = 4 -- slack for latency when the server validates a grab
Config.GripBreakDistance = 6 -- grip snaps if hand and grip point drift this far apart

---------------------------------------------------------------------------
-- Knockdown and recovery (client)
---------------------------------------------------------------------------
Config.ImpactKnockdownSpeed = 55 -- sudden velocity change (studs/s) that knocks you out
Config.FallTiltAngle = 65 -- tipped further than this from upright...
Config.FallTiltTime = 0.6 -- ...for this long counts as falling over
Config.KnockdownTime = 2.0 -- limp time before getting up
Config.RecoverTime = 0.8 -- balance ramps back up over this long
Config.RecoverGrace = 1.0 -- no new knockdowns this long after getting up

---------------------------------------------------------------------------
-- Testing
---------------------------------------------------------------------------
Config.SpawnPlayground = true -- builds a small test area (crates, climb wall) on the server
Config.Debug = false -- prints the client's balance/ground state once a second

return Config
