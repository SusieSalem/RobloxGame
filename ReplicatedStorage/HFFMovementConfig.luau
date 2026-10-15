-- HFFMovementConfig
-- Every tunable for the Human Fall Flat style controller lives here.
-- Shared by the server (ragdoll + grabbing) and the client (movement).
-- Units are studs, seconds and degrees unless a name says otherwise.

local Config = {}

-- Bumped whenever the scripts change in a way that needs matching settings.
Config.Version = 22

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
	-- Shoulders are nearly free so the whole arm can reach straight up.
	LeftShoulder = { UpperAngle = 175, TwistLower = -80, TwistUpper = 80 },
	RightShoulder = { UpperAngle = 175, TwistLower = -80, TwistUpper = 80 },
	-- Elbows are tight so the forearm can't fold far away from the upper arm.
	LeftElbow = { UpperAngle = 70, TwistLower = -10, TwistUpper = 10 },
	RightElbow = { UpperAngle = 70, TwistLower = -10, TwistUpper = 10 },
	LeftHip = { UpperAngle = 80, TwistLower = -30, TwistUpper = 30 },
	RightHip = { UpperAngle = 80, TwistLower = -30, TwistUpper = 30 },
	LeftKnee = { UpperAngle = 100, TwistLower = -10, TwistUpper = 10 },
	RightKnee = { UpperAngle = 100, TwistLower = -10, TwistUpper = 10 },
}
Config.DefaultJointLimit = { UpperAngle = 45, TwistLower = -30, TwistUpper = 30 }
Config.JointFrictionTorque = 2 -- a little stiffness so limp limbs don't spin forever
-- Shoulders with no limits at all (server, applies on spawn). Looking up with the
-- arms raised, a few degrees of torso tilt pushed the arm against its twist limit
-- and the motor holding it shook the whole body. Free shoulders cannot do that.
Config.FreeShoulders = true
Config.FreeElbowTwist = true -- elbows without the +-10 degree twist limit (server, applies on spawn)

-- Physical properties of the body
Config.BodyDensity = 0.7
Config.BodyFriction = 0.5
Config.LegFriction = 0.2 -- low so dragging feet don't stop you walking
Config.BodyElasticity = 0
-- The Humanoid turns off collisions on arms/legs, so each limb gets an
-- invisible collider welded inside it. Scale is relative to the limb size.
Config.LimbColliderScale = Vector3.new(0.9, 0.85, 0.9)
-- Body parts of the same character never collide with each other (applies on spawn, server).
Config.NoSelfCollision = true

---------------------------------------------------------------------------
-- Player outline (server): a Highlight on every character
---------------------------------------------------------------------------
Config.PlayerOutline = true
Config.PlayerOutlineColor = Color3.new(0, 0, 0)
Config.PlayerOutlineFillTransparency = 1 -- 1 = outline only, lower tints the whole body black

---------------------------------------------------------------------------
-- Balance (client): soft AlignOrientation on the HumanoidRootPart
---------------------------------------------------------------------------
Config.BalanceMaxTorque = 16000 -- lower = hits and swinging limbs push the torso around more
Config.BalanceResponsiveness = 18 -- 5..200, lower = wobblier
Config.BalanceMaxAngularVelocity = 18 -- rad/s
Config.LeanAngle = 22 -- forward lean at full speed (more = feet trail behind the body, steps look alternated)

-- Weight (client, Balance module): the upright target is a spring the body's
-- motion pushes around, so the torso has momentum instead of floating.
Config.BalanceSwayFrequency = 1.4 -- how fast the torso rocks (Hz): lower = heavier, slower body
Config.BalanceSwayDamping = 0.35 -- 0..1: lower = wobbles longer after starting, stopping and landing
Config.BalanceSwayMax = 28 -- most the sway can tip the torso (degrees)
Config.ReachSwayDamping = 0.9 -- sway damping while the arms are up (higher = body stays steadier, no shaking)
Config.ReachLean = 0 -- degrees of forward lean while the arms are in use (0 = off)
Config.ReachBalanceBoost = 1 -- balance torque multiplier while the arms are in use (1 = off)
Config.BalanceAccelLean = 0.7 -- lean into speeding up, rock back when stopping (1 = physically exact)
Config.BalanceAccelSmoothing = 10 -- higher = reacts to speed changes sooner but jitterier
Config.WeightShiftAngle = 3.5 -- sideways lean over the planted foot while the other steps (waddle)
Config.GaitBob = 0.35 -- studs the hips drop when the feet are spread mid-stride
Config.HeightSpringFrequency = 2.2 -- how fast the hips settle after a dip (Hz)
Config.HeightSpringDamping = 0.45 -- 0..1: lower = bouncier knees
Config.LandingMinSpeed = 14 -- falls slower than this (studs/s) land without squashing
Config.LandingSquash = 0.22 -- how much the knees give on landing per stud/s of fall speed
Config.LandingSquashMax = 1.4 -- deepest landing crouch (studs)
Config.LandingSwayKick = 1.5 -- how much running momentum pitches the torso on landing
Config.AirBalance = 0.3 -- balance strength left during a longer fall (1 = stays bolt upright)
Config.AirBalanceFade = 0.35 -- seconds in the air before the balance fades to AirBalance
Config.BalanceRegrip = 6 -- how fast balance comes back after landing: lower = staggers upright slower

---------------------------------------------------------------------------
-- Standing / hovering (client): spring that holds the torso at hip height
---------------------------------------------------------------------------
Config.StandHeightScale = 1.0 -- multiplier on Humanoid.HipHeight + root half height
Config.GroundProbeExtra = 1.5 -- extra ray length below stand height that still counts as grounded
Config.HoverStiffness = 120
Config.HoverDamping = 13 -- lower = the hips bob more
Config.HoverMaxAcceleration = 420 -- caps the spring (about 2g)

---------------------------------------------------------------------------
-- Walking (client): velocity controller using a VectorForce
---------------------------------------------------------------------------
Config.WalkSpeed = 14
Config.WalkAcceleration = 5 -- how hard we chase the target velocity (1/s)
Config.WalkMaxAcceleration = 75 -- studs/s^2 cap, lower = more sluggish
Config.AirControl = 0.3 -- fraction of walk control while airborne or hanging

-- Leg IK (feet plant on the ground and step when the body moves away)
Config.LegIK = true
Config.StepDistance = 0.9 -- foot steps when it's this far from where it should be
Config.StepLead = 0.1 -- seconds of velocity to step ahead by
Config.StepDuration = 0.28 -- seconds per step at walking pace (faster when running)
Config.StepHeight = 0.8 -- how high the foot lifts mid-step (more when running)
Config.GaitMinSpeed = 2 -- moving faster than this (studs/s) walks with a steady left-right rhythm
Config.GaitStepDistance = 0.35 -- while walking, a foot steps once it is this far behind (lower = quicker rhythm)
Config.StepBalanceRecovery = 0.12 -- each catch-step while stumbling removes this fraction of the tip

-- Fallback leg swing (used when LegIK is off or in the air)
Config.StepFrequency = 1.8 -- steps per second at full speed
Config.StrideAngle = 35
Config.KneeBendAngle = 45
Config.LegMaxTorque = 8000 -- leg muscle strength: higher = legs follow the walk cycle more exactly
Config.LegResponsiveness = 60 -- higher = legs snap to the walk pose faster (applies on respawn)
Config.HeadMaxTorque = 300
Config.HeadResponsiveness = 12 -- lower = the head lags and nods with the body

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
Config.ArmMaxPitch = 62 -- highest the arms reach, in degrees above straight ahead (90 = straight up, which glitches)
-- The arm is one loose piece hanging from the shoulder (like HFF). On the
-- ground the shoulder has no muscle at all: the arm is a free pendulum that
-- swings only because the body moves. A soft elbow keeps the forearm in line
-- with the upper arm.
-- The shoulder pivot sits above the middle of the upper arm instead of its
-- inner edge, so a hanging arm rests straight down rather than leaning into
-- the torso (server, applies on spawn).
Config.CenterShoulderPivot = true
-- Air drag on the hands makes the limp arms trail behind the body: they float
-- up while you fall and stream back when you move fast.
Config.ArmAirDragVertical = 6 -- up/down drag: higher = arms rise sooner and higher when falling (0 = off)
Config.ArmAirDrag = 0.4 -- sideways drag: higher = arms trail back more when moving, and settle faster
Config.ArmAirDragMax = 3 -- cap on the drag, as a multiple of the arm's weight
-- Off the ground the arms float up. These forces push off the torso, so they do not slow the fall.
Config.ArmAirLift = 1.5 -- upward pull on the hands, as a multiple of the arm's weight (0 = off)
Config.ArmAirRaise = 0.35 -- where the hands settle, in arm lengths above the shoulder (0 = straight out, 1 = straight up)
Config.ArmAirDamping = 6 -- higher = arms settle faster in the air with less shaking
-- Nothing pushes the arms while walking. Instead the torso twists and rocks a
-- little with each step, and the boneless arms get thrown around by it.
Config.WalkTwistAngle = 12 -- shoulders turn left/right this many degrees per step (swings the arms front/back)
Config.WalkTwistFrequency = 1.7 -- twists per second at full walking speed
Config.ArmSwingResponsiveness = 20 -- how snappily the shoulder moves when the reactions pose it

Config.ArmElbowTorque = 120 -- elbow: higher = forearm more rigid with the upper arm
Config.ArmElbowResponsiveness = 10 -- lower = forearm lags and wobbles more
Config.ArmElbowBend = 8 -- resting elbow bend
Config.ArmMaxTorque = 10000 -- arm strength while reaching: higher = lifts heavier things
-- Lifting presses the body down as hard as it pulls the load up, so strength
-- is limited by the legs. When a load is too heavy the arms ease off instead
-- of crushing the body into the floor.
Config.RaisedArmWeight = 0.2 -- raised arms weigh this fraction of normal (stops two raised arms making the body wobble)
Config.ArmFreeTorque = 1500 -- arm strength with an empty hand: enough to raise the arm, too little to shove the body
Config.CarryWeightScale = 0.2 -- a held prop weighs this fraction of its real weight (server). Lower = you lift heavier things
Config.CarryLegBoost = 1.8-- legs push this much harder while gripping something (carry heavier loads)
Config.CarryMaxCrouch = 0.6 -- pressed down further than this (studs) counts as overloaded
Config.ArmGiveRate = 4 -- how fast the arms ease off when overloaded (per second)
Config.ArmRecoverRate = 1.5 -- how fast they get their strength back
Config.ArmMinPower = 0.15 -- weakest the arms get, as a fraction of ArmMaxTorque
-- The arms raise smoothly. Snapping them up shoves the torso and can knock
-- your own balance over (the weird crouch).
-- Responsiveness is how firmly the arm holds its aim. Too low and the arm sags
-- under its own weight and wobbles like a soft spring (at 18 it hung 35 degrees
-- below the aim). The speed cap is what keeps the raise smooth.
Config.ArmResponsiveness = 120
Config.ArmMaxAngularVelocity = 9 -- rad/s: top speed the arms swing up at
Config.ArmMaxYawLead = 35 -- degrees the arms may point left/right of the torso while it turns to the camera

Config.GrabRadius = 0.4-- largest gap (studs) between the hand and a surface that still grips; 0 = must overlap
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
Config.RecoverTime = 1.4 -- getting up takes this long (rises out of a crouch)
Config.RecoverGrace = 1.0 -- no new knockdowns this long after getting up

---------------------------------------------------------------------------
-- Euphoria-style reactions (client): active ragdoll instead of going limp
---------------------------------------------------------------------------
Config.EuphoriaEnabled = true
Config.RagdollKey = Enum.KeyCode.R -- toggle ragdoll on/off (testing and for fun)
Config.RagdollGamepadButton = Enum.KeyCode.ButtonY
Config.StaggerSpeed = 28 -- a hit smaller than ImpactKnockdownSpeed but above this makes you stumble
Config.StaggerTime = 4.0 -- a stumble from a hit ends after this long if you didn't trip
Config.StaggerTilt = 15 -- how far (degrees) a hit tips you to start the stumble
Config.StaggerRecovery = 0.8 -- how fast a hit-stumble settles by itself (R-ragdoll never settles)
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
-- Active ragdoll: the body reacts to real physics instead of being held upright.
Config.BalanceLossAngle = 40 -- shoved or tripped this many degrees past where balance wants you...
Config.BalanceLossTime = 0.3 -- ...for this long (seconds) and you stumble the way you were pushed
Config.BalanceLossCarry = 0.6 -- how much of that push carries into the stumble
Config.HardLandingSpeed = 48 -- landing faster than this (studs/s) while moving makes you stumble
Config.HardLandingTilt = 12 -- how far (degrees) a hard landing tips you
Config.HardLandingKnockSpeed = 85 -- landing faster than this knocks you flat
Config.ImpactLimpTime = 0.35 -- after a knockdown or a slam while down, every muscle lets go this long
Config.ImpactLimpSpeed = 30 -- a slam this hard (sudden speed change) while down goes limp again
Config.GetUpCrouch = 0.55 -- start getting up crouched this low (fraction of stand height)
Config.GetUpTurnSpeed = 2.5 -- rad/s the torso can turn upright at the start of getting up (lower = slower, heavier)
Config.HeadStabilize = 0.6 -- 0..1: how much the neck keeps the head level while the torso sways

---------------------------------------------------------------------------
-- Camera (client): normal Roblox camera with a smoothed focus point
---------------------------------------------------------------------------
Config.CameraLockMouse = true -- mouse turns the camera without holding right click
Config.MouseUnlockKey = Enum.KeyCode.LeftAlt -- toggles a free cursor (for menus)
Config.CameraHeightOffset = 1.5 -- focus point above the upper torso
Config.CameraFollowSharpness = 10 -- higher = follows tighter, lower = smoother

---------------------------------------------------------------------------
-- Other players (client): smooth local copy of every other player's body
---------------------------------------------------------------------------
-- Other players' ragdolls arrive over the network in uneven steps. Each client
-- hides them and shows a smoothed copy instead; physics still uses the real body.
Config.RemoteSmoothing = true -- false = show the raw replicated bodies
Config.RemoteSmoothingSharpness = 18 -- how tightly the copy's torso follows; lower = smoother but later
Config.RemoteSmoothingJointSharpness = 22 -- same for arm/leg/head rotation
Config.RemoteSmoothingVelocityLead = 0.8 -- 0..1, cancels the trailing behind while moving (1 = none, can overshoot on stops)
Config.RemoteSmoothingSnapDistance = 15 -- further off than this (respawn, teleport) jumps instead of easing

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
Config.SpawnPlayground = false -- builds a small test area (crates, climb wall) on the server
Config.Debug = false -- prints the client's balance/ground state once a second
Config.DebugOverlay = false -- true shows a box of physics numbers on screen while an arm is held (for bug hunting)

return Config
