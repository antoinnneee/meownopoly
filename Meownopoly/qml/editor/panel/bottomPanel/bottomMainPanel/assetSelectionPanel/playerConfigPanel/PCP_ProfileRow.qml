import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MapInfo

/*
 * Liste des PCP_ProfileCard + PCP_AddProfileCard en queue. Orientation
 * paramétrable : Qt.Horizontal (Flickable horizontal + Row, défaut) ou
 * Qt.Vertical (Flickable vertical + Column).
 *
 * Pas de drag & drop en v1 — réordonnancement via les boutons ←→ de
 * chaque card.
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
    property int orientation: Qt.Horizontal

    // Re-eval trigger pour la liste de profils (QQmlListProperty pas itérable
    // en JS, on s'appuie sur le signal playerProfilesChanged).
    property int _profilesTick: 0
    readonly property bool _isVertical: root.orientation === Qt.Vertical

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
        contentWidth: root._isVertical
                        ? width
                        : cardsContainer.width + Screen.pixelDensity * 3
        contentHeight: root._isVertical
                         ? cardsContainer.height + Screen.pixelDensity * 3
                         : height
        flickableDirection: root._isVertical
                              ? Flickable.VerticalFlick
                              : Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded; visible: !root._isVertical }
        ScrollBar.vertical:   ScrollBar { policy: ScrollBar.AsNeeded; visible:  root._isVertical }

        // Conteneur dynamique : Column en mode vertical, Row en mode horizontal.
        Loader {
            id: cardsContainer
            sourceComponent: root._isVertical ? colTpl : rowTpl
            // Anchors : remplit le Flickable selon l'axe non-scrollé.
            anchors.left: parent.left
            anchors.right: root._isVertical ? parent.right : undefined
            anchors.top: parent.top
            anchors.bottom: root._isVertical ? undefined : parent.bottom
            anchors.leftMargin: Screen.pixelDensity * 2
            anchors.rightMargin: root._isVertical ? Screen.pixelDensity * 2 : 0
            anchors.topMargin: Screen.pixelDensity * 1
            anchors.bottomMargin: root._isVertical ? 0 : Screen.pixelDensity * 1
        }
    }

    // Templates des deux orientations. La logique de delegate est partagée
    // via deux Repeater identiques + un AddCard final.
    Component {
        id: rowTpl
        Row {
            spacing: Screen.pixelDensity * 2

            Repeater {
                model: root._profilesTick, root.mapInfo ? root.mapInfo.playerProfileCount() : 0
                delegate: PCP_ProfileCard {
                    height: cardsContainer.height
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
                height: cardsContainer.height
                onAddRequested: root.profileAddRequested()
            }
        }
    }

    Component {
        id: colTpl
        Column {
            spacing: Screen.pixelDensity * 2

            Repeater {
                model: root._profilesTick, root.mapInfo ? root.mapInfo.playerProfileCount() : 0
                delegate: PCP_ProfileCard {
                    width: cardsContainer.width
                    // ratio 1:1.6 portrait ; on impose la largeur, la card
                    // calcule sa hauteur via implicitHeight = width * ratio.
                    height: width * 1.6
                    verticalLayout: true
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
                width: cardsContainer.width
                height: width * 1.6
                onAddRequested: root.profileAddRequested()
            }
        }
    }
}
