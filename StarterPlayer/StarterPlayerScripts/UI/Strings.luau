-- Strings
-- HUD text. Spanish for Spanish locales, English otherwise.

local Players = game:GetService("Players")

local STRINGS = {
	es = {
		Move = "Moverse",
		Jump = "Saltar",
		LeftArm = "Brazo izq.",
		RightArm = "Brazo der.",
		Ragdoll = "Ragdoll",
		Camera = "Cámara",
		FreeMouse = "Soltar mouse",
		Settings = "Ajustes",
		HideHints = "Ocultar",
		Teetering = "Perdiendo el equilibrio",
		TeeteringHint = "Muévete en contra para no caer",
		Stumbling = "¡Tambaleando!",
		Ragdolled = "Ragdoll",
		RagdolledHint = "%s para levantarte",
		KnockedOut = "¡Noqueado!",
		GettingUp = "Levantándote…",
		SettingMouseLock = "Girar cámara con el mouse",
		SettingEuphoria = "Reacciones Euphoria",
		SettingLegIK = "Pasos con IK",
		SettingHints = "Mostrar controles",
		Close = "Cerrar",
		Updates = "Actualizaciones",
		LatestUpdate = "Nuevo: %s (U para ver más)",
	},
	en = {
		Move = "Move",
		Jump = "Jump",
		LeftArm = "Left arm",
		RightArm = "Right arm",
		Ragdoll = "Ragdoll",
		Camera = "Camera",
		FreeMouse = "Free mouse",
		Settings = "Settings",
		HideHints = "Hide",
		Teetering = "Losing balance",
		TeeteringHint = "Move against the lean to stay up",
		Stumbling = "Stumbling!",
		Ragdolled = "Ragdoll",
		RagdolledHint = "%s to get up",
		KnockedOut = "Knocked out!",
		GettingUp = "Getting up…",
		SettingMouseLock = "Turn camera with mouse",
		SettingEuphoria = "Euphoria reactions",
		SettingLegIK = "IK footsteps",
		SettingHints = "Show controls",
		Close = "Close",
		Updates = "Updates",
		LatestUpdate = "New: %s (U for more)",
	},
}

local locale = Players.LocalPlayer.LocaleId:sub(1, 2)
return STRINGS[locale] or STRINGS.en
