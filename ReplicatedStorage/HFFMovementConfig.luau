-- HFFMovementConfig
-- Every tunable for the Human Fall Flat style controller lives here.
-- Shared by the server (ragdoll + grabbing) and the client (movement).
-- Units are studs, seconds and degrees unless a name says otherwise.

local Config = {}

-- Bumped whenever the scripts change in a way that needs matching settings.
Config.Version = 2

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

-- Leg IK (feet plant on the ground and step when the body moves away)
Config.LegIK = true
Config.StepDistance = 0.9 -- foot steps when it's this far from where it should be
Config.StepLead = 0.18 -- seconds of velocity to step ahead by
Config.StepDuration = 0.3 -- seconds per step at walking pace (faster when running)
Config.StepHeight = 0.7 -- how high the foot lifts mid-step
Config.StepBalanceRecovery = 0.12 -- each catch-step while stumbling removes this fraction of the tip

-- Fallback leg swing (used when LegIK is off or in the air)
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
Config.ArmRaiseAngle = 15 -- arms point this many degrees above where the camera looks
Config.ArmSwingScale = 0.8 -- arm swing while walking, as a fraction of StrideAngle
Config.ArmSwingMaxTorque = 800
Config.ArmMaxTorque = 6000
Config.ArmResponsiveness = 40
Config.ArmMaxAngularVelocity = 25

Config.GrabRadius = 1.8 -- how close the hand must be to a part to grip it
Config.GrabRetryDelay = 0.35 -- wait between grab requests per hand
Config.ServerGrabTolerance = 4 -- slack for latency when the server validates a grab
Config.GripBreakDistance = 6 -- grip snaps if hand and grip point drift this far apart

---------------------------------------------------------------------------
-- Knockdown and recovery (client)
---------------------------------------------------------------------------
Config.ImpactKnockdownSpeed = 65 -- sudden velocity change (studs/s) that knocks you out
Config.FallTiltAngle = 75 -- tipped further than this from upright...
Config.FallTiltTime = 0.8 -- ...for this long counts as falling over
Config.KnockdownTime = 2.0 -- limp time before getting up
Config.RecoverTime = 0.8 -- balance ramps back up over this long
Config.RecoverGrace = 1.0 -- no new knockdowns this long after getting up

---------------------------------------------------------------------------
-- Euphoria-style reactions (client): active ragdoll instead of going limp
---------------------------------------------------------------------------
Config.EuphoriaEnabled = true
Config.RagdollKey = Enum.KeyCode.R -- toggle ragdoll on/off (testing and for fun)
Config.RagdollGamepadButton = Enum.KeyCode.ButtonY
Config.StaggerSpeed = 28 -- a hit smaller than ImpactKnockdownSpeed but above this makes you stumble
Config.StaggerTime = 2.0 -- a stumble from a hit ends after this long if you didn't trip
Config.StaggerTilt = 15 -- how far (degrees) a hit tips you to start the stumble
Config.StaggerRecovery = 1.8 -- how fast a hit-stumble settles by itself (R-ragdoll never settles)
Config.StaggerBalance = 0.6 -- balance strength while stumbling (1 = normal)
Config.TeeterStartTilt = 5 -- R: starting tip in degrees
Config.StaggerTravel = 1.2 -- how much a stumble moves you (lower = steps more in place)
Config.TeeterInstability = 1.4 -- how fast the tip grows by itself (higher = trips sooner)
Config.TeeterWobble = 0.25 -- random sway while stumbling
Config.TeeterPlayerControl = 0.6 -- how strongly WASD / stick pushes back against the tip
Config.TeeterFallAngle = 40 -- tip past this many degrees and you trip and fall
Config.FallPanicSpeed = 35 -- falling faster than this makes the arms and legs flail
Config.EuphoriaBraceSpeed = 8 -- while knocked, moving faster than this = hands out to brace
Config.EuphoriaGroundProbe = 4 -- how close to the ground counts as "landed" while knocked
Config.EuphoriaFlailTorque = 2500
Config.EuphoriaBraceTorque = 3500
Config.EuphoriaWritheTorque = 400 -- weak squirming while dazed on the ground
Config.PushUpTorque = 5000

---------------------------------------------------------------------------
-- Camera (client): normal Roblox camera with a smoothed focus point
---------------------------------------------------------------------------
Config.CameraLockMouse = true -- mouse turns the camera without holding right click
Config.MouseUnlockKey = Enum.KeyCode.LeftAlt -- toggles a free cursor (for menus)
Config.CameraHeightOffset = 1.5 -- focus point above the upper torso
Config.CameraFollowSharpness = 10 -- higher = follows tighter, lower = smoother

---------------------------------------------------------------------------
-- Gamepad and mobile
---------------------------------------------------------------------------
-- Gamepad: left stick moves, right stick turns the camera, A jumps,
-- L2/L1 = left arm, R2/R1 = right arm.
-- Mobile: Roblox thumbstick and jump button, plus two hold buttons (L / R) for the arms.
Config.MobileButtonSize = 70 -- pixels (legacy, the HUD now scales with MobileButtonScale)
Config.MobileButtonScale = 0.15 -- touch button size as a fraction of screen height (clamped 56-110 px)

---------------------------------------------------------------------------
-- HUD
---------------------------------------------------------------------------
Config.SettingsKey = Enum.KeyCode.M -- opens the settings menu (gamepad: Select)
Config.HintsKey = Enum.KeyCode.H -- shows/hides the control hints
Config.ShowControlHints = true

---------------------------------------------------------------------------
-- Testing
---------------------------------------------------------------------------
Config.SpawnPlayground = true -- builds a small test area (crates, climb wall) on the server
Config.Debug = false -- prints the client's balance/ground state once a second

return Config
