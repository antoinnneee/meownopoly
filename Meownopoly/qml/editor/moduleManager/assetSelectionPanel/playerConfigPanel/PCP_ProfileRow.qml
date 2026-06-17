import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MapInfo

/*
 * Liste des PCP_ProfileCard + PCP_AddProfileCard en queue. Orientation
 * paramétrable : Qt.Horizontal (Flickable horizontal + Row, défaut) ou
 * Qt.Vertical (Flickable vertical + Column).
 *
 * Pas de drag & drop en v1 — réordonnancement via les boutons ←→ (ou ↑↓
 * en vertical) de chaque card.
 */
Item {
    id: root

    property var mapInfo: null
    property string selectedProfileId: ""
    property int orientation: Qt.Horizontal

    property int _profilesTick: 0
    readonly property bool _isVertical: root.orientation === Qt.Vertical

    signal profileSelected(string id)
    signal profileEditRequested(string id)
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
                        : (cardsRow.visible ? cardsRow.width + Screen.pixelDensity * 3 : width)
        contentHeight: root._isVertical
                         ? (cardsCol.visible ? cardsCol.height + Screen.pixelDensity * 3 : height)
                         : height
        flickableDirection: root._isVertical
                              ? Flickable.VerticalFlick
                              : Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded; visible: !root._isVertical }
        ScrollBar.vertical:   ScrollBar { policy: ScrollBar.AsNeeded; visible:  root._isVertical }

        // ----- Mode horizontal -----
        Row {
            id: cardsRow
            visible: !root._isVertical
            anchors.left: parent.left
            anchors.leftMargin: Screen.pixelDensity * 2
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: Screen.pixelDensity * 1
            anchors.bottomMargin: Screen.pixelDensity * 1
            spacing: Screen.pixelDensity * 2

            Repeater {
                model: !root._isVertical
                         ? (root._profilesTick, root.mapInfo ? root.mapInfo.playerProfileCount() : 0)
                         : 0
                delegate: PCP_ProfileCard {
                    height: cardsRow.height
                    width: Math.max(Screen.pixelDensity * 30, height / 1.6)
                    profile: root.mapInfo ? root.mapInfo.playerProfileAt(index) : null
                    isSelected: profile && profile.id === root.selectedProfileId

                    onSelected: if (profile) root.profileSelected(profile.id)
                    onEditRequested: if (profile) root.profileEditRequested(profile.id)
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
                visible: !root._isVertical
                height: cardsRow.height
                width: Math.max(Screen.pixelDensity * 30, height / 1.6)
                onAddRequested: root.profileAddRequested()
            }
        }

        // ----- Mode vertical -----
        Column {
            id: cardsCol
            visible: root._isVertical
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Screen.pixelDensity * 4
            anchors.rightMargin: Screen.pixelDensity * 4
            anchors.topMargin: Screen.pixelDensity * 1
            spacing: Screen.pixelDensity * 2

            // Largeur stable : on borne par le Column (anchored sur le Flickable),
            // les cards lisent cardsCol.width — pas de circularité car le Column
            // tire sa largeur des anchors (hard-set), pas de ses enfants.
            Repeater {
                model: root._isVertical
                         ? (root._profilesTick, root.mapInfo ? root.mapInfo.playerProfileCount() : 0)
                         : 0
                delegate: PCP_ProfileCard {
                    width: cardsCol.width
                    height: width * 1.6
                    verticalLayout: true
                    profile: root.mapInfo ? root.mapInfo.playerProfileAt(index) : null
                    isSelected: profile && profile.id === root.selectedProfileId

                    onSelected: if (profile) root.profileSelected(profile.id)
                    onEditRequested: if (profile) root.profileEditRequested(profile.id)
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
                visible: root._isVertical
                width: cardsCol.width
                height: width * 1.6
                onAddRequested: root.profileAddRequested()
            }
        }
    }
}
