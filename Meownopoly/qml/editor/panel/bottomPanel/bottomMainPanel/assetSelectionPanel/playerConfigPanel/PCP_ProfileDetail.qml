import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PlayerProfile
import Game
import MapInfo

/*
 * Panneau d'édition d'un PlayerProfile. Visible quand un profil est
 * sélectionné dans PCP_ProfileRow.
 *
 * Pattern d'écriture (Phase 2b — pré-collab) : mutation directe sur le
 * profil + capture avant/après via mapInfo.toJSON() + Game.updateMapMetadata.
 * Phase 4 routera tout via EditorOpBus.makeUpdatePlayerProfileOp.
 */
Item {
    id: root

    property var profile: null
    property var mapInfo: null

    // Helpers de mutation : capture avant, mute, capture après, déclare
    function _mutate(applyFn) {
        if (!root.profile || !root.mapInfo) return
        const before = root.mapInfo.toJSON()
        applyFn()
        Game.updateMapMetadata(before, root.mapInfo.toJSON())
    }

    Rectangle {
        anchors.fill: parent
        color: "#1a1a1a"
        radius: 6
        border.color: "#3a3a3a"
        border.width: 1
        visible: !root.profile

        Label {
            anchors.centerIn: parent
            text: "Sélectionnez une classe ou ajoutez-en une"
            color: "#777777"
            font.pixelSize: Math.round(Screen.pixelDensity * 3.2)
            font.italic: true
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: contentCol.implicitHeight + Screen.pixelDensity * 4
        clip: true
        visible: !!root.profile
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: contentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Screen.pixelDensity * 2
            spacing: Screen.pixelDensity * 2

            // ----- Ligne haut : Nom + ModelPicker -----
            RowLayout {
                Layout.fillWidth: true
                spacing: Screen.pixelDensity * 3

                Label {
                    text: "Nom"
                    color: "#cccccc"
                    font.pixelSize: Math.round(Screen.pixelDensity * 3)
                }
                TextField {
                    id: nameField
                    Layout.preferredWidth: Screen.pixelDensity * 50
                    text: root.profile ? root.profile.name : ""
                    Connections {
                        target: root.profile
                        function onNameChanged() {
                            if (nameField.text !== root.profile.name)
                                nameField.text = root.profile.name
                        }
                    }
                    onEditingFinished: {
                        if (!root.profile) return
                        const v = text.trim()
                        if (!v || v === root.profile.name) return
                        root._mutate(() => { root.profile.name = v })
                    }
                }

                Item { Layout.fillWidth: true }

                PCP_ModelPicker {
                    Layout.preferredWidth: Screen.pixelDensity * 60
                    currentModel: root.profile ? root.profile.modelName : ""
                    onModelSelected: function(name) {
                        if (!root.profile || name === root.profile.modelName) return
                        root._mutate(() => { root.profile.modelName = name })
                    }
                }
            }

            // ----- PickMode + minOccurrences -----
            PCP_PickModeSelector {
                Layout.fillWidth: true
                pickMode: root.profile ? root.profile.pickMode : PlayerProfile.Unique
                minOccurrences: root.profile ? root.profile.minOccurrences : 1
                onPickModeRequested: function(mode) {
                    if (!root.profile || mode === root.profile.pickMode) return
                    root._mutate(() => { root.profile.pickMode = mode })
                }
                onMinOccurrencesRequested: function(n) {
                    if (!root.profile || n === root.profile.minOccurrences) return
                    root._mutate(() => { root.profile.minOccurrences = n })
                }
            }

            // ----- Onglets Simple / Expert -----
            TabBar {
                id: physTabs
                Layout.fillWidth: true
                TabButton { text: "Simple" }
                TabButton { text: "Expert" }
            }

            StackLayout {
                Layout.fillWidth: true
                currentIndex: physTabs.currentIndex

                PCP_PhysicsSimpleSection {
                    profile: root.profile
                    mapInfo: root.mapInfo
                }

                PCP_PhysicsExpertSection {
                    profile: root.profile
                    mapInfo: root.mapInfo
                }
            }
        }
    }
}
