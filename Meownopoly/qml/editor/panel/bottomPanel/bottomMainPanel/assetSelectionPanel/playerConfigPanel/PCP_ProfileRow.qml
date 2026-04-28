import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MapInfo

/*
 * Rangée horizontale (Flickable) des PCP_ProfileCard + PCP_AddProfileCard
 * en queue. Pas de drag & drop en v1 — réordonnancement via les boutons
 * ←→ de chaque card.
 *
 * Le parent (PCP_Content) fournit le `mapInfo` et la sélection courante via
 * `selectedProfileId` (string). Émet `profileSelected(id)` au clic d'une
 * card. Les actions (add/remove/duplicate/move/rename) sont propagées
 * verbatim au parent.
 */
Item {
    id: root

    property var mapInfo: null
    property string selectedProfileId: ""

    // Re-eval trigger pour la liste de profils (QQmlListProperty pas itérable
    // en JS, on s'appuie sur le signal playerProfilesChanged).
    property int _profilesTick: 0

    signal profileSelected(string id)
    signal profileAddRequested()
    signal profileRemoveRequested(string id)
    signal profileDuplicateRequested(string id)
    signal profileMoveRequested(string id, int newIndex)
    signal profileRenameRequested(string id, string newName)

    Connections {
        target: root.mapInfo
        function onPlayerProfilesChanged() { root._profilesTick++ }
    }

    clip: true

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: cardsRow.width + Screen.pixelDensity * 3
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

        Row {
            id: cardsRow
            anchors.left: parent.left
            anchors.leftMargin: Screen.pixelDensity * 2
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: Screen.pixelDensity * 1
            anchors.bottomMargin: Screen.pixelDensity * 1
            spacing: Screen.pixelDensity * 2

            Repeater {
                id: rep
                model: root._profilesTick, root.mapInfo ? root.mapInfo.playerProfileCount() : 0

                delegate: PCP_ProfileCard {
                    id: card
                    height: cardsRow.height
                    profile: root.mapInfo ? root.mapInfo.playerProfileAt(index) : null
                    isSelected: profile && profile.id === root.selectedProfileId

                    onSelected: if (profile) root.profileSelected(profile.id)
                    onDuplicateRequested: if (profile) root.profileDuplicateRequested(profile.id)
                    onRemoveRequested: if (profile) root.profileRemoveRequested(profile.id)
                    onMoveLeftRequested: if (profile && index > 0)
                                              root.profileMoveRequested(profile.id, index - 1)
                    onMoveRightRequested: {
                        if (!profile || !root.mapInfo) return
                        const last = root.mapInfo.playerProfileCount() - 1
                        if (index < last)
                            root.profileMoveRequested(profile.id, index + 1)
                    }
                    onNameEditRequested: function(newName) {
                        if (profile) root.profileRenameRequested(profile.id, newName)
                    }
                }
            }

            PCP_AddProfileCard {
                height: cardsRow.height
                onAddRequested: root.profileAddRequested()
            }
        }
    }
}
