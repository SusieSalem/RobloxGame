-- ChangeLog
-- Every update to the game, newest first. The in-game update log (U key or
-- the button next to the gear) shows this list top to bottom.
-- To log a change: add a new entry at the TOP of the list.

return {
	{
		date = "2026-10-14 18:20",
		title = "Brazos correctos en cualquier avatar",
		changes = {
			"Los brazos se apuntan según cómo está armado cada avatar, no solo el personaje de bloques.",
			"Así el brazo y el antebrazo ya no se empujan entre sí con avatares de otras formas.",
			"La unión del hombro queda bien alineada en todos los avatares desde que apareces.",
		},
	},
	{
		date = "2026-10-14 18:05",
		title = "Sin bamboleo con los brazos arriba",
		changes = {
			"Los brazos levantados pesan menos, así el cuerpo ya no se bambolea con los dos brazos arriba.",
			"La fuerza para agarrar y levantar es la misma; al bajarlos recuperan su peso normal.",
		},
	},
	{
		date = "2026-10-14 18:00",
		title = "Gorros antiguos sin choques",
		changes = {
			"También los gorros de tipo antiguo dejan de chocar y de pesar.",
			"Tu propio juego lo aplica además del servidor, aunque el accesorio cargue tarde.",
		},
	},
	{
		date = "2026-10-14 17:55",
		title = "Accesorios sin peso",
		changes = {
			"Los accesorios (gorros, pelo, bolsos, mascotas, alas) ya no pesan ni chocan con nada.",
			"Así los brazos suben igual con cualquier avatar, no solo con el personaje por defecto.",
		},
	},
	{
		date = "2026-10-11 06:40",
		title = "Vuelta a la versión de las 06:08",
		changes = {
			"Se quitaron los cambios de las 06:20 (antebrazo que sigue al brazo) y 06:25 (giro limitado del brazo y ArmRoll).",
			"Se mantiene la versión de las 06:08: los codos siguen sin límite de giro.",
		},
	},
	{
		date = "2026-10-11 06:08",
		title = "Codos sin límite de giro",
		changes = {
			"El antebrazo tenía un límite de giro de solo 10° respecto al brazo, y al subir los brazos podía chocar con él y sacudir el cuerpo.",
			"Ahora los codos conservan su límite de doblado pero ya no limitan el giro.",
		},
	},
	{
		date = "2026-10-11 05:58",
		title = "Sin temblor al mirar arriba con los brazos",
		changes = {
			"Los hombros tenían topes de giro: con los brazos arriba bastaban unos grados de inclinación del cuerpo para chocar con ellos y sacudir todo el torso.",
			"Ahora los hombros giran libres, sin topes, y los brazos ya no pueden empujar el cuerpo.",
			"Se quitó la inclinación extra hacia adelante y la fuerza extra del balance al usar los brazos: no ayudaban.",
		},
	},
	{
		date = "2026-10-11 05:43",
		title = "Quieto en el suelo",
		changes = {
			"Una vez en el suelo el cuerpo se queda flojo: ya no mueve brazos y piernas ni gira.",
			"Los brazos y piernas solo se mueven mientras caes en el aire.",
		},
	},
	{
		date = "2026-10-11 05:39",
		title = "Te balanceas más tiempo",
		changes = {
			"Cuando te tambaleas por un golpe, ahora te balanceas el doble de tiempo antes de recuperarte (StaggerTime 4, StaggerRecovery 0.8).",
		},
	},
	{
		date = "2026-10-11 05:36",
		title = "Menos temblor con los brazos arriba",
		changes = {
			"Con los brazos arriba el torso se inclinaba entre 25° y 37° y el balance no alcanzaba a corregirlo.",
			"Ahora el balance tiene más fuerza mientras usas los brazos y el cuerpo se inclina un poco hacia adelante para compensar.",
		},
	},
	{
		date = "2026-10-11 05:35",
		title = "Cuerpo más firme con los brazos arriba",
		changes = {
			"Mientras usas los brazos, el balance ya no reacciona al empuje de los brazos y el cuerpo se mece mucho menos.",
			"El cuello deja de compensar el torso con los brazos arriba, para que no se dispare un temblor.",
		},
	},
	{
		date = "2026-10-11 05:25",
		title = "Sin temblor al mirar arriba",
		changes = {
			"Al mirar casi vertical con los brazos activos el cuerpo temblaba: la dirección hacia donde mira el personaje se volvía inestable.",
			"Ahora esa dirección se calcula con la parte de arriba de la cámara y se mantiene estable al mirar arriba o abajo.",
			"Mientras usas los brazos no se activan los tropiezos automáticos.",
		},
	},
	{
		date = "2026-10-11 05:30",
		title = "Brazos sin choques con accesorios",
		changes = {
			"Los accesorios (gorros, bolsos, mascotas de hombro) ya no chocan con los brazos.",
			"Los brazos sostienen la puntería con aún más firmeza.",
			"Se quitó el recuadro negro de diagnóstico.",
		},
	},
	{
		date = "2026-10-11 05:25",
		title = "Brazos firmes al apuntar",
		changes = {
			"Los brazos sostienen su posición con firmeza en vez de colgar 35 grados por debajo y rebotar.",
		},
	},
	{
		date = "2026-10-11 05:20",
		title = "Lectura de diagnóstico (temporal)",
		changes = {
			"Al mantener un clic aparece un recuadro negro con números de la física, para encontrar el fallo de los brazos.",
			"Los brazos ya no dependen del balanceo del torso para apuntar.",
		},
	},
	{
		date = "2026-10-11 05:15",
		title = "Inclinación al caminar",
		changes = {
			"Al caminar te inclinas bastante más hacia adelante (de 8° a 22°), así los pies quedan detrás del cuerpo y los pasos se alternan.",
			"Los pies apuntan menos adelante del cuerpo.",
			"Se quitó la opción \"Piernas sin ragdoll\" de Ajustes.",
		},
	},
	{
		date = "2026-10-11 05:10",
		title = "Cargar cajas",
		changes = {
			"Lo que sostienes pesa solo una quinta parte mientras lo agarras, así que ya puedes levantar las cajas.",
			"Al soltarlo recupera todo su peso.",
		},
	},
	{
		date = "2026-10-11 05:05",
		title = "Sin choques con tu propio cuerpo",
		changes = {
			"Las partes de tu cuerpo ya no chocan entre sí: brazos, piernas y torso se atraviesan.",
			"Sigues chocando con el suelo, los objetos y otros jugadores.",
			"Se aplica al reaparecer. Se puede apagar con Config.NoSelfCollision.",
		},
	},
	{
		date = "2026-10-11 05:05",
		title = "Brazos levantados más suaves",
		changes = {
			"Con la mano vacía los brazos usan poca fuerza: solo la necesaria para levantarse.",
			"La fuerza completa se guarda para cuando la mano está agarrando algo.",
		},
	},
	{
		date = "2026-10-11 05:00",
		title = "Menos caidas locas",
		changes = {
			"Con \"Piernas sin ragdoll\" el balance tiene 2.5 veces más fuerza, porque las piernas fijas pesan más.",
			"Los tropiezos por empujones son menos sensibles: hace falta inclinarse más y por más tiempo.",
		},
	},
	{
		date = "2026-10-11 04:58",
		title = "Piernas sin ragdoll",
		changes = {
			"Nuevo interruptor en Ajustes (M): \"Piernas sin ragdoll\".",
			"Activado: las piernas son articulaciones fijas que siguen el paso como una animación normal, sin física suelta.",
			"Al caer, quedar noqueado o levantarte, las piernas vuelven a ser ragdoll solas.",
		},
	},
	{
		date = "2026-10-11 04:50",
		title = "Agarre más fácil y giro al agarrar",
		changes = {
			"Agarrar ya no exige un punto exacto: la mano agarra con un pequeño margen.",
			"Los objetos redondos o con forma rara se agarran aunque la mano esté metida en ellos.",
			"Al agarrar, el personaje gira con la cámara y arrastra lo que sostiene.",
			"Los brazos suben más suave, para no empujar el propio cuerpo y agacharlo.",
		},
	},
	{
		date = "2026-10-11 04:45",
		title = "Piernas como la animación normal",
		changes = {
			"Las piernas tienen más del triple de fuerza y siguen el paso casi exacto.",
			"Al caminar los pies alternan izquierda-derecha con ritmo constante, sin arrastrarse.",
			"Cada paso levanta el pie rápido y lo baja hacia adelante, como la animación de caminar.",
			"Al correr los pasos son más rápidos y el pie sube más.",
		},
	},
	{
		date = "2026-10-11 04:40",
		title = "Agarrar y levantar",
		changes = {
			"Los brazos siempre apuntan al frente del cuerpo; la cámara solo los sube y baja.",
			"Girar la cámara con los dos clics ya no dobla el cuerpo de lado.",
			"La mano tiene que tocar de verdad para agarrar, y solo agarra cosas que están al frente.",
			"Más fuerza al levantar; si algo pesa demasiado los brazos aflojan en vez de fallar.",
			"Los brazos ya no suben completamente rectos hacia arriba, que causaba fallos.",
			"Reaparecer funciona siempre, también al caer al vacío.",
			"Las caídas van a velocidad normal y los brazos ya no tiemblan en el aire.",
		},
	},
	{
		date = "2026-10-11 04:35",
		title = "Registro de actualizaciones",
		changes = {
			"Nuevo panel de actualizaciones: tecla U o el botón junto al engrane.",
			"Al entrar aparece un aviso con la última actualización.",
		},
	},
	{
		date = "2026-10-11 04:28",
		title = "Ragdoll activo estilo Euphoria",
		changes = {
			"Pierdes el balance de verdad: si te empujan y no lo aguantas, tropiezas hacia donde te empujaron.",
			"Al caer o chocar fuerte, el cuerpo se suelta un momento y cae como peso muerto.",
			"Te levantas desde agachado poco a poco, sin flotar hacia arriba.",
			"Aterrizar rápido te hace tropezar; caer de muy alto te deja tirado.",
			"El cuello mantiene la cabeza nivelada; al tropezar mira al suelo.",
		},
	},
	{
		date = "2026-10-11 04:21",
		title = "Brazos sueltos",
		changes = {
			"Los brazos cuelgan sin fuerza y flotan hacia arriba al saltar o caer.",
			"Al caminar el torso gira un poco y los brazos se balancean solos.",
			"Codos más flojos y brazos más fuertes al agarrar cosas.",
		},
	},
	{
		date = "2026-10-11 04:05",
		title = "Balance con peso",
		changes = {
			"El torso se mece como un resorte: se inclina al acelerar y se mece al frenar.",
			"El peso pasa al pie apoyado y las caderas bajan en cada paso.",
			"Las rodillas ceden al aterrizar y el balance se afloja en caídas largas.",
		},
	},
}
