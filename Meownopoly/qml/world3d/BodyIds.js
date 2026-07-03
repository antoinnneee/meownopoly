// BodyIds — source unique des préfixes de bodyId physiques.
//
// Avant : "crate:" dupliqué dans CrateSpawner et GrabController, "enemy:"
// dans CombatController, et un substring(6) magique dans TriggerController —
// divergence garantie au premier renommage.
.pragma library

const CRATE_PREFIX = "crate:"
const ENEMY_PREFIX = "enemy:"

function crate(uuid) { return CRATE_PREFIX + uuid }
function enemy(uuid) { return ENEMY_PREFIX + uuid }

function isCrate(bodyId) { return String(bodyId).indexOf(CRATE_PREFIX) === 0 }
function isEnemy(bodyId) { return String(bodyId).indexOf(ENEMY_PREFIX) === 0 }

function crateUuid(bodyId) { return String(bodyId).substring(CRATE_PREFIX.length) }
function enemyUuid(bodyId) { return String(bodyId).substring(ENEMY_PREFIX.length) }
