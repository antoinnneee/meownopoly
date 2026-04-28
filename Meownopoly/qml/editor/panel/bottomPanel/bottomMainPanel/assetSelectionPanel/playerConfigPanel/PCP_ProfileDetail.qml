import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PlayerProfile
import Game
import MapInfo
import EditorOpBus

/*
 * Panneau d'édition d'un PlayerProfile. Visible quand un profil est
 * sélectionné dans PCP_ProfileRow.
 *
 * Layout : RowLayout 2 colonnes
 *  - gauche : Mode de sélection + Nom + ModelPicker + Presets
 *  - droite : onglets Simple/Expert avec sliders (scrollables)
 *
 * Pattern d'écriture (Phase 4) : mutation locale immédiate + autosave
 * via Game.updateMapMetadata + EditorOpBus.submitOp(UpdatePlayerProfile)
 * pour broadcast collab. Le payload `fields` ne contient que les champs
 * effectivement changés (delta minimal sur la wire).
 */
Item {
    id: root

    property var profile: null
    property var mapInfo: null

    /// Mute un champ du profil, déclenche autosave et broadcast l'op
    /// UpdatePlayerProfile correspondante. `fields` est un objet partiel
    /// {name: value, ...} qui sera appliqué côté peer via applyJson.
    function _mutateFields(fields, applyFn) {
        if (!root.profile || !root.mapInfo) return
        const before = root.mapInfo.toJSON()
        applyFn()
        Game.updateMapMetadata(before, root.mapInfo.toJSON())
        EditorOpBus.submitOp(EditorOpBus.makeUpdatePlayerProfileOp(
                                root.profile.id, fields))
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

        // ============ Colonne gauche : Mode + Identité + Presets ============
        ColumnLayout {
            id: leftCol
            Layout.fillHeight: true
            Layout.fillWidth: true
            // Ratio 8:12 cm = 40:60 entre les deux colonnes. RowLayout
            // distribue l'espace selon les preferredWidth quand fillWidth
            // est true sur les deux. Valeurs en mm via Screen.pixelDensity.
            Layout.preferredWidth: Screen.pixelDensity * 80    // 8 cm
            Layout.minimumWidth:   Screen.pixelDensity * 60    // 6 cm
            spacing: Screen.pixelDensity * 2

            // --- Mode de sélection (en haut de la colonne gauche) ---
            PCP_PickModeSelector {
                Layout.fillWidth: true
                pickMode: root.profile ? root.profile.pickMode : PlayerProfile.Unique
                minOccurrences: root.profile ? root.profile.minOccurrences : 1
                onPickModeRequested: function(mode) {
                    if (!root.profile || mode === root.profile.pickMode) return
                    root._mutateFields({ "pickMode": mode },
                                       () => { root.profile.pickMode = mode })
                }
                onMinOccurrencesRequested: function(n) {
                    if (!root.profile || n === root.profile.minOccurrences) return
                    root._mutateFields({ "minOccurrences": n },
                                       () => { root.profile.minOccurrences = n })
                }
            }

            // --- Nom + Modèle 3D côte à côte ---
            RowLayout {
                Layout.fillWidth: true
                spacing: Screen.pixelDensity * 2

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
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
                            root._mutateFields({ "name": v },
                                               () => { root.profile.name = v })
                        }
                    }
                }

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
                            root._mutateFields({ "modelName": name },
                                               () => { root.profile.modelName = name })
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
                        // Le preset touche 8 champs physiques d'un coup ; on
                        // les capture après application et on broadcast via
                        // UpdatePlayerProfile avec tous les champs.
                        const fields = {
                            "radius":          root.profile.radius,
                            "mass":            root.profile.mass,
                            "acceleration":    root.profile.acceleration,
                            "maxSpeed":        root.profile.maxSpeed,
                            "linearDamping":   root.profile.linearDamping,
                            "staticFriction":  root.profile.staticFriction,
                            "dynamicFriction": root.profile.dynamicFriction,
                            "bounceFactor":    root.profile.bounceFactor
                        }
                        EditorOpBus.submitOp(EditorOpBus.makeUpdatePlayerProfileOp(
                                                root.profile.id, fields))
                    }
                }
            }

            // Pousse le contenu vers le haut quand la zone est plus grande.
            Item { Layout.fillHeight: true }
        }

        // ============ Colonne droite : Tabs + Sliders ============
        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.preferredWidth: Screen.pixelDensity * 120   // 12 cm
            Layout.minimumWidth:   Screen.pixelDensity * 80    // 8 cm
            spacing: Screen.pixelDensity * 2

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
