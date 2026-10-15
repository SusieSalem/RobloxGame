--[[
	README (sincronizado por Rojo)

	Si ves este script, Rojo esta conectado y sincronizando.
	Viene de ServerScriptService/README.server.luau. Solo tiene comentarios, no ejecuta nada.

	Juego: movimiento ragdoll estilo Human Fall Flat.
	- Scripts del jugador: StarterPlayer/StarterPlayerScripts/HFF
	- Servidor: ServerScriptService/HFFServer
	- Ajustes (balance, peso, brazos, salto): ReplicatedStorage/HFFMovementConfig

	==================================================================
	ULTIMA ACTUALIZACION: 2026-10-11 06:40 UTC
	Vuelta a la version de las 06:08
	==================================================================
	- Revertidos 06:20 (antebrazo al mismo marco que el brazo) y 06:25 (limitRollError y ArmRoll).
	- Se mantiene 06:08: FreeElbowTwist en true (codos sin limite de giro).
	- Se mantienen elbowJoint/elbowRest en Rig y las lineas de DebugOverlay (no afectan al juego).
	Archivos: ReplicatedStorage/HFFMovementConfig, UI/ChangeLog

	------------------------------------------------------------------
	HISTORIAL
	------------------------------------------------------------------
	2026-10-11 06:08 UTC - Codos sin limite de giro (FreeElbowTwist).
	(Revertidos el 06:40: 06:25 giro limitado + ArmRoll y 06:20 antebrazo sigue al brazo.)
	2026-10-11 05:58 UTC - Hombros sin topes (FreeShoulders); ReachLean 0, ReachBalanceBoost 1.
	2026-10-11 05:43 UTC - Quieto en el suelo: cuerpo flojo, sin girar; Brace solo en el aire.
	2026-10-11 05:39 UTC - Te balanceas mas tiempo: StaggerTime 4, StaggerRecovery 0.8.
	2026-10-11 05:36 UTC - Menos temblor con los brazos arriba (ReachBalanceBoost 1.6, ReachLean 8).
	2026-10-11 05:35 UTC - Cuerpo mas firme con los brazos arriba (ReachSwayDamping 0.9).
	2026-10-11 05:25 UTC - Sin temblor al mirar arriba: giro estable (Util.getCameraYaw).
	2026-10-11 05:15 UTC - Inclinacion al caminar (LeanAngle 22); se quito "Piernas sin ragdoll".
	2026-10-11 05:05 UTC - Sin choques con tu propio cuerpo (NoSelfCollision).
	2026-10-11 05:00 UTC - Menos caidas locas: balance 2.5x con piernas fijas, tropiezos menos sensibles.
	2026-10-11 04:58 UTC - Piernas sin ragdoll (Ajustes > Piernas sin ragdoll): Motor6D fijos.
	2026-10-11 04:52 UTC - Primer intento de piernas rigidas (5x fuerza); reemplazado por piernas sin ragdoll.
	2026-10-11 04:50 UTC - Agarre mas facil y giro al agarrar (otro hilo).
	2026-10-11 04:45 UTC - Piernas como la animacion normal: 3x fuerza, ritmo izquierda-derecha constante.
	2026-10-11 04:40 UTC - Agarrar y levantar (otro hilo): brazos al frente, agarre real, mas fuerza.
	2026-10-11 04:35 UTC - Registro de actualizaciones en el juego (tecla U, UI/ChangeLog).
	2026-10-11 04:28 UTC - Ragdoll activo estilo Euphoria: perdida de balance real al ser
	  empujado, cuerpo flojo al golpe, levantarse desde agachado, tropiezo/caida al
	  aterrizar fuerte, cabeza estable. (HFF/Controller, Knockdown, Reactions, Balance, config)
	2026-10-11 04:21 UTC - Brazos sueltos (otro hilo): flotan al saltar, se balancean al caminar.
	2026-10-11 04:05 UTC - Balance con peso (HFF/Balance nuevo): el torso se mece
	  como resorte, se inclina al acelerar, se mece al frenar, cambia el peso al pie
	  apoyado, las caderas bajan en cada paso, las rodillas ceden al aterrizar y el
	  balance se afloja en caidas largas. Ajustes en la seccion "Weight" del config.
]]
