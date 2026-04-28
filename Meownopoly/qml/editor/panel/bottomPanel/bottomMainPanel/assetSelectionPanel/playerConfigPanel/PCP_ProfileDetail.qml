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
 * Layout : 2 colonnes via RowLayout
 *  - gauche : Nom + ModelPicker + Presets
 *  - droite : Mode de sélection + onglets Simple/Expert avec sliders
 *
 * Pattern d'écriture (Phase 2b — pré-collab) : mutation directe sur le
 * profil + capture avant/après via mapInfo.toJSON() + Game.updateMapMetadata.
 * Phase 4 routera tout via EditorOpBus.makeUpdatePlayerProfileOp.
 */
Item {
    id: root

    property var profile: null
    property var mapInfo: null

    function _mutate(applyFn) {
        if (!root.profile || !root.mapInfo) return
        const before = root.mapInfo.toJSON()
        applyFn()
        Game.updateMapMetadata(before, root.mapInfo.toJSON())
    }

    // Placeholder quand aucune classe n'est sélectionnée.
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

    // Contenu d'édition.
    RowLayout {
        anchors.fill: parent
        anchors.margins: Screen.pixelDensity * 2
        spacing: Screen.pixelDensity * 3
        visible: !!root.profile

        // ============ Colonne gauche : Identité + Presets ============
        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: parent.width * 0.40
            spacing: Screen.pixelDensity * 2

            // --- Nom + Modèle 3D côte à côte ---
            RowLayout {
                Layout.fillWidth: true
                spacing: Screen.pixelDensity * 2

                // Bloc Nom
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1   // pour ratio fillWidth équilibré
                    spacing: Screen.pixelDensity * 1

                    Label {
                        text: "Nom"
                        color: "#cccccc"
                        font.pixelSize: Math.round(Screen.pixelDensity * 3)
                        font.bold: true
                    }
                    PCP_StyledTextField {
                        id: nameField
                        Layout.fillWidth: true
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
                }

                // Bloc Modèle 3D
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: Screen.pixelDensity * 1

                    Label {
                        text: "Modèle 3D"
                        color: "#cccccc"
                        font.pixelSize: Math.round(Screen.pixelDensity * 3)
                        font.bold: true
                    }
                    PCP_ModelPicker {
                        Layout.fillWidth: true
                        currentModel: root.profile ? root.profile.modelName : ""
                        onModelSelected: function(name) {
                            if (!root.profile || name === root.profile.modelName) return
                            root._mutate(() => { root.profile.modelName = name })
                        }
                    }
                }
            }

            // --- Presets ---
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Screen.pixelDensity * 1

                Label {
                    text: "Presets"
                    color: "#cccccc"
                    font.pixelSize: Math.round(Screen.pixelDensity * 3)
                    font.bold: true
                }
                PCP_PresetButtons {
                    Layout.fillWidth: true
                    onPresetChosen: function(name) {
                        if (!root.profile || !root.mapInfo) return
                        const before = root.mapInfo.toJSON()
                        root.profile.applyPreset(name)
                        Game.updateMapMetadata(before, root.mapInfo.toJSON())
                    }
                }
            }

            // Pousse le contenu vers le haut quand la zone est plus grande.
            Item { Layout.fillHeight: true }
        }

        // ============ Colonne droite : Mode + Sliders ============
        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            spacing: Screen.pixelDensity * 2

            // --- Mode de sélection ---
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

            // --- Onglets Simple / Expert ---
            PCP_StyledTabBar {
                id: physTabs
                Layout.fillWidth: true
                PCP_StyledTabButton { text: "Simple" }
                PCP_StyledTabButton { text: "Expert" }
            }

            // --- Sliders (scrollables si Expert déborde) ---
            Flickable {
                id: physFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: physStack.implicitHeight + Screen.pixelDensity * 2
                clip: true
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                StackLayout {
                    id: physStack
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
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
}
