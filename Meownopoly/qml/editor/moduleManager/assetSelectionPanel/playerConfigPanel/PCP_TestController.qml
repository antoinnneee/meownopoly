/*
 * Singleton QML — bus entre PCP_ProfileDetail (qui demande à tester un
 * profil) et Editor.qml (qui injecte les params + modèle dans le player
 * principal).
 *
 * Stocke un `profileId` (string) plutôt qu'un pointeur QObject, parce que
 * `Game::updateMapMetadata` recrée tout le `MapInfo` à chaque commit
 * (cf. game_loader.cpp:343 — `map->setMapInfo(new MapInfo(delta.after))`),
 * ce qui détruit les `PlayerProfile*` existants. Un pointeur QML deviendrait
 * null à chaque slider release ; un string id reste stable et l'éditeur
 * retrouve l'instance courante via `mapInfo.playerProfileById(id)`.
 *
 * Usage côté caller (PCP_ProfileDetail) :
 *   PCP_TestController.startTesting(profile)   // ou stopTesting()
 *
 * Usage côté Editor.qml :
 *   readonly property var _testedProfile:
 *       PCP_TestController.profileId && MapFileManager.currentMap
 *           ? MapFileManager.currentMap.mapInfo.playerProfileById(
 *                 PCP_TestController.profileId)
 *           : null
 */
pragma Singleton
import QtQuick

QtObject {
    id: ctl

    // "" = pas de test en cours.
    property string profileId: ""

    function startTesting(p) { ctl.profileId = (p && p.id) ? p.id : "" }
    function stopTesting()   { ctl.profileId = "" }
    function isTesting()     { return ctl.profileId !== "" }
    function isTestingId(id) { return ctl.profileId !== "" && ctl.profileId === id }
}
