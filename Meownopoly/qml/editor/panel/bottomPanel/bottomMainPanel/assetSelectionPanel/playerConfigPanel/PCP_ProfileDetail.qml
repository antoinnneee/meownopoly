import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PlayerProfile
import Game
import MapInfo
import EditorOpBus
import playerConfigPanel 1.0

/*
 * Panneau d'édition d'un PlayerProfile. Visible quand un profil est
 * sélectionné dans PCP_ProfileRow.
 *
 * Layout : RowLayout 2 colonnes
 *  - gauche  : Nom + Preview 3D (≤ 3 cm) + ModelPicker + Mode + bouton Test
 *  - droite  : Presets + CheckBox "Mode expert" + Sliders (Simple ou Expert)
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

    // True ssi PCP_TestController teste actuellement CE profil. La
    // comparaison se fait par id (string stable), pas par pointeur :
    // Game.updateMapMetadata recrée le PlayerProfile à chaque commit donc
    // un pointeur deviendrait null après la 1re modif (cf. PCP_TestController).
    readonly property bool _isTestingThisProfile:
        !!root.profile && PCP_TestController.isTestingId(root.profile.id)

    function _toggleTest() {
        if (!root.profile) return
        if (_isTestingThisProfile) PCP_TestController.stopTesting()
        else                       PCP_TestController.startTesting(root.profile)
    }

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

        // ============ Colonne gauche : Identité + Preview + Mode + Test ============
        ColumnLayout {
            id: leftCol
            Layout.fillHeight: true
            Layout.preferredWidth: Screen.pixelDensity * 70    // 7 cm
            Layout.minimumWidth:   Screen.pixelDensity * 55    // 5.5 cm
            spacing: Screen.pixelDensity * 1.5

            // --- Nom de la classe (gros titre éditable) ---
            PCP_StyledTextField {
                id: nameField
                Layout.fillWidth: true
                text: root.profile ? root.profile.name : ""
                horizontalAlignment: TextInput.AlignHCenter
                font.pixelSize: Math.round(Screen.pixelDensity * 4.5)
                font.bold: true
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

            // --- Preview 3D : capé à 3 cm de hauteur, centré horizontalement.
            // Le pane reste carré-ish ; la container Item gère le centrage
            // horizontal (Layout.alignment ne suffit pas avec un fillWidth).
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Screen.pixelDensity * 30   // 3 cm

                PCP_ProfilePreviewPane {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, Screen.pixelDensity * 30)
                    height: parent.height
                    profile: root.profile
                }
            }

            // --- ModelPicker ---
            ColumnLayout {
                Layout.fillWidth: true
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

                // --- Skin / Variante (Color ID Map) ---
                PCP_SkinPicker {
                    Layout.fillWidth: true
                    modelName: root.profile ? root.profile.modelName : ""
                    colorVariant: root.profile ? root.profile.colorVariant : ""
                    onColorVariantPicked: function(json) {
                        if (!root.profile || json === root.profile.colorVariant) return
                        root._mutateFields({ "colorVariant": json },
                                           () => { root.profile.colorVariant = json })
                    }
                }
            }

            // --- Mode de sélection (Unique / Shared / Mandatory) ---
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

            // --- Bouton Tester en 3D (en bas de colonne) ---
            PCP_StyledButton {
                Layout.fillWidth: true
                accent: true
                text: root._isTestingThisProfile ? "Arrêter le test"
                                                 : "Tester en 3D"
                enabled: !!root.profile
                onClicked: root._toggleTest()
            }

            // Pousse le contenu vers le haut quand la zone est plus grande.
            Item { Layout.fillHeight: true }
        }

        // ============ Colonne droite : Presets + Mode expert + Sliders ============
        ColumnLayout {
            id: rightCol
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.preferredWidth: Screen.pixelDensity * 130   // 13 cm
            Layout.minimumWidth:   Screen.pixelDensity * 90    // 9 cm
            spacing: Screen.pixelDensity * 2

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

            // --- Mode expert (CheckBox remplace les onglets Simple/Expert) ---
            CheckBox {
                id: expertCheck
                Layout.fillWidth: true
                text: "Mode expert (afficher tous les paramètres physiques)"
                checked: false
                contentItem: Label {
                    text: expertCheck.text
                    color: "#cccccc"
                    font.pixelSize: Math.round(Screen.pixelDensity * 3)
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: expertCheck.indicator.width + expertCheck.spacing
                }
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
                    currentIndex: expertCheck.checked ? 1 : 0

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
