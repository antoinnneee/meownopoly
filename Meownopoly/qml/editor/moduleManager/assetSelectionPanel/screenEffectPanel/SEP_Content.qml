import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Game
import theme
import ui_item
import world3d 1.0

import "../"
import editorBottomPanel
import screenEffectPanel

/*
 * Onglet "Effets" du AssetSelectionPanel — éditeur de la bibliothèque d'effets
 * visuels plein écran (MapInfo.screenEffects).
 *
 * Master / détail :
 *   - Gauche  : liste des effets + bouton "Ajouter" (menu de presets), avec
 *               duplication / suppression par item.
 *   - Droite  : éditeur de l'effet sélectionné (nom, type, couleur, intensité,
 *               vignette, flou, désaturation, pulsation, fondus) + aperçu live.
 *
 * Persistance + collaboration : chaque mutation passe par
 * Game.updateMapMetadata(before, after) — même chemin que la config joueurs.
 * Cela sauvegarde la carte (save-on-edit) ET diffuse aux pairs via l'ApplyState
 * (delta MetadataChanged). Pas d'op dédié nécessaire : les effets voyagent avec
 * le reste de MapInfo. NB : updateMapMetadata recrée l'instance MapInfo, donc on
 * garde la sélection par `id` et tout se re-résout via les bindings.
 */
EBP_Content {
    id: root

    required property var logic
    sidePanelRatio: 0   // pas de side panel ; tout est dans mainContent

    readonly property var mapInfo: logic ? logic.mapInfo : null

    property string selectedId: ""
    readonly property var selectedEffect: (mapInfo && selectedId)
                                           ? mapInfo.screenEffectById(selectedId)
                                           : null

    // Snapshot avant édition (pour les drags de slider : capturé au press,
    // commité au release → un seul delta par geste).
    property string _beforeJson: ""

    // Liste réactive des effets. Accéder à `mapInfo.screenEffects` capture la
    // dépendance de binding (NOTIFY screenEffectsChanged) ; l'itération réelle
    // passe par les helpers (QQmlListProperty pas indexable en JS).
    readonly property var _effects: {
        const arr = []
        if (mapInfo) {
            const dep = mapInfo.screenEffects
            const n = mapInfo.screenEffectCount()
            for (let i = 0; i < n; ++i) {
                const e = mapInfo.screenEffectAt(i)
                if (e) arr.push(e)
            }
        }
        return arr
    }

    readonly property var _presets: ["Givré", "Toxique", "Chaleur", "Ténèbres", "Flou", "Teinte"]
    readonly property var _typeLabels: ["Teinte", "Givré", "Toxique", "Chaleur", "Vignette", "Flou"]
    readonly property var _palette: ["#BFE9FF", "#6BFF6B", "#FF7A2A", "#000000",
                                     "#FFFFFF", "#3366FF", "#FF4D6D", "#B266FF"]

    // -- Helpers de mutation --
    function _commit(before) {
        if (!mapInfo) return
        Game.updateMapMetadata(before, mapInfo.toJSON())
    }
    function _mutate(fn) {                 // changement discret : capture → mute → commit
        if (!mapInfo) return
        const before = mapInfo.toJSON()
        fn()
        _commit(before)
    }
    function _addPreset(presetName) {
        if (!mapInfo) return
        const before = mapInfo.toJSON()
        const e = mapInfo.addScreenEffectFromPreset(presetName)
        _commit(before)
        if (e) root.selectedId = e.id
    }
    function _remove(id) {
        if (!mapInfo) return
        const before = mapInfo.toJSON()
        mapInfo.removeScreenEffect(id)
        _commit(before)
        if (root.selectedId === id) root.selectedId = ""
    }
    function _duplicate(id) {
        if (!mapInfo) return
        const before = mapInfo.toJSON()
        const e = mapInfo.duplicateScreenEffect(id)
        _commit(before)
        if (e) root.selectedId = e.id
    }

    Item {
        anchors.fill: parent
        anchors.margins: Theme.spacingM

        RowLayout {
            anchors.fill: parent
            spacing: Theme.spacingM

            // ======================== Liste (gauche) ========================
            Rectangle {
                Layout.preferredWidth: 240
                Layout.fillHeight: true
                color: Theme.surface
                radius: Theme.radiusS
                border.color: Theme.border
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    spacing: Theme.spacingS

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: "Bibliothèque"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeBody
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        Button {
                            text: "＋ Ajouter"
                            font.pixelSize: Theme.fontSizeSmall
                            onClicked: presetMenu.open()

                            Menu {
                                id: presetMenu
                                Repeater {
                                    model: root._presets
                                    MenuItem {
                                        text: modelData
                                        onTriggered: root._addPreset(modelData)
                                    }
                                }
                            }
                        }
                    }

                    ListView {
                        id: effectList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: Theme.spacingXS
                        model: root._effects

                        delegate: Rectangle {
                            required property var modelData
                            width: ListView.view.width
                            height: 40
                            radius: Theme.radiusXS
                            color: modelData.id === root.selectedId
                                   ? Theme.surfaceHover : Theme.background
                            border.color: modelData.id === root.selectedId
                                          ? Theme.accent : Theme.border
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingS
                                anchors.rightMargin: Theme.spacingXS
                                spacing: Theme.spacingS

                                Rectangle {
                                    width: 18; height: 18; radius: 4
                                    color: modelData.tintColor
                                    border.color: Theme.border
                                    border.width: 1
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: Theme.textPrimary
                                    font.pixelSize: Theme.fontSizeSmall
                                    elide: Text.ElideRight
                                }
                                ToolButton {
                                    text: "⧉"
                                    font.pixelSize: Theme.fontSizeSmall
                                    implicitWidth: 26; implicitHeight: 26
                                    onClicked: root._duplicate(modelData.id)
                                }
                                ToolButton {
                                    text: "🗑"
                                    font.pixelSize: Theme.fontSizeSmall
                                    implicitWidth: 26; implicitHeight: 26
                                    onClicked: root._remove(modelData.id)
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                z: -1
                                onClicked: root.selectedId = modelData.id
                            }
                        }

                        Label {
                            anchors.centerIn: parent
                            width: parent.width - Theme.spacingL
                            visible: root._effects.length === 0
                            text: "Aucun effet.\nUtilise « ＋ Ajouter » pour partir d'un preset."
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSizeSmall
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            // ======================== Éditeur (droite) ========================
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.surface
                radius: Theme.radiusS
                border.color: Theme.border
                border.width: 1

                Label {
                    anchors.centerIn: parent
                    visible: root.selectedEffect === null
                    text: "Sélectionne un effet pour l'éditer."
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSizeBody
                }

                // Le formulaire est rechargé à chaque changement de sélection
                // (toggle de `active` via Connections) : updateMapMetadata recrée
                // l'instance MapInfo et les contrôles interactifs cassent leurs
                // bindings une fois édités — un form neuf rétablit des bindings
                // propres pour le nouvel effet.
                Loader {
                    id: detailLoader
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    active: root.selectedEffect !== null
                    sourceComponent: detailForm
                }
                Connections {
                    target: root
                    function onSelectedIdChanged() {
                        detailLoader.active = false
                        detailLoader.active = (root.selectedEffect !== null)
                    }
                }

                Component {
                    id: detailForm
                    ScrollView {
                    clip: true
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: parent.width
                        spacing: Theme.spacingM

                        // ---- Aperçu live ----
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 120
                            radius: Theme.radiusS
                            clip: true
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#3a4a5a" }
                                GradientStop { position: 1.0; color: "#1a2230" }
                            }
                            // Damier léger pour juger la transparence.
                            Row {
                                anchors.centerIn: parent
                                spacing: 24
                                Repeater {
                                    model: 5
                                    Rectangle { width: 18; height: 18; radius: 4; color: "#ffffff"; opacity: 0.25 }
                                }
                            }
                            ScreenEffectOverlay {
                                anchors.fill: parent
                                effect: root.selectedEffect
                                amount: 1.0
                            }
                            Label {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: Theme.spacingXS
                                text: "Aperçu"
                                color: "#ffffff"
                                opacity: 0.6
                                font.pixelSize: Theme.fontSizeTiny
                            }
                        }

                        // ---- Nom + Type ----
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: Theme.spacingM
                            rowSpacing: Theme.spacingS

                            Label { text: "Nom :"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.bold: true }
                            MeowTextField {
                                id: nameField
                                Layout.fillWidth: true
                                text: root.selectedEffect ? root.selectedEffect.name : ""
                                onActiveFocusChanged: { if (activeFocus && root.mapInfo) root._beforeJson = root.mapInfo.toJSON() }
                                onEditingFinished: {
                                    if (root.selectedEffect && root.selectedEffect.name !== text) {
                                        root.selectedEffect.name = text
                                        root._commit(root._beforeJson)
                                    }
                                }
                            }

                            Label { text: "Type :"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.bold: true }
                            MeowComboBox {
                                id: typeCombo
                                Layout.fillWidth: true
                                model: root._typeLabels
                                currentIndex: root.selectedEffect ? root.selectedEffect.type : 0
                                onActivated: function(index) {
                                    if (root.selectedEffect && root.selectedEffect.type !== index)
                                        root._mutate(function() { root.selectedEffect.type = index })
                                }
                            }

                            Label { text: "Preset :"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.bold: true }
                            MeowComboBox {
                                id: presetCombo
                                Layout.fillWidth: true
                                model: root._presets
                                displayText: "Appliquer un preset…"
                                onActivated: function(index) {
                                    const name = root._presets[index]
                                    if (root.selectedEffect)
                                        root._mutate(function() { root.selectedEffect.applyPreset(name) })
                                }
                            }
                        }

                        // ---- Couleur ----
                        Label { text: "Couleur de teinte :"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.bold: true }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingS
                            Rectangle {
                                width: 28; height: 28; radius: Theme.radiusXS
                                color: root.selectedEffect ? root.selectedEffect.tintColor : "transparent"
                                border.color: Theme.border; border.width: 1
                            }
                            MeowTextField {
                                id: colorField
                                Layout.preferredWidth: 90
                                text: root.selectedEffect ? root.selectedEffect.tintColor : ""
                                onEditingFinished: {
                                    if (root.selectedEffect && root.selectedEffect.tintColor !== text)
                                        root._mutate(function() { root.selectedEffect.tintColor = text })
                                }
                            }
                            Repeater {
                                model: root._palette
                                Rectangle {
                                    required property string modelData
                                    width: 22; height: 22; radius: Theme.radiusXS
                                    color: modelData
                                    border.color: Theme.border; border.width: 1
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (root.selectedEffect)
                                                root._mutate(function() { root.selectedEffect.tintColor = modelData })
                                        }
                                    }
                                }
                            }
                        }

                        // ---- Sliders ----
                        SEP_Slider {
                            Layout.fillWidth: true
                            label: "Intensité"; from: 0; to: 1; decimals: 2
                            value: root.selectedEffect ? root.selectedEffect.intensity : 0
                            onMovedValue: function(v) { if (root.selectedEffect) root.selectedEffect.intensity = v }
                            onBegin: { if (root.mapInfo) root._beforeJson = root.mapInfo.toJSON() }
                            onCommit: root._commit(root._beforeJson)
                        }
                        SEP_Slider {
                            Layout.fillWidth: true
                            label: "Vignette"; from: 0; to: 1; decimals: 2
                            value: root.selectedEffect ? root.selectedEffect.vignette : 0
                            onMovedValue: function(v) { if (root.selectedEffect) root.selectedEffect.vignette = v }
                            onBegin: { if (root.mapInfo) root._beforeJson = root.mapInfo.toJSON() }
                            onCommit: root._commit(root._beforeJson)
                        }
                        SEP_Slider {
                            Layout.fillWidth: true
                            label: "Flou (scène)"; from: 0; to: 1; decimals: 2
                            value: root.selectedEffect ? root.selectedEffect.blur : 0
                            onMovedValue: function(v) { if (root.selectedEffect) root.selectedEffect.blur = v }
                            onBegin: { if (root.mapInfo) root._beforeJson = root.mapInfo.toJSON() }
                            onCommit: root._commit(root._beforeJson)
                        }
                        SEP_Slider {
                            Layout.fillWidth: true
                            label: "Saturation"; from: -1; to: 1; decimals: 2
                            value: root.selectedEffect ? root.selectedEffect.saturation : 0
                            onMovedValue: function(v) { if (root.selectedEffect) root.selectedEffect.saturation = v }
                            onBegin: { if (root.mapInfo) root._beforeJson = root.mapInfo.toJSON() }
                            onCommit: root._commit(root._beforeJson)
                        }
                        SEP_Slider {
                            Layout.fillWidth: true
                            label: "Pulsation"; from: 0; to: 5; decimals: 1
                            value: root.selectedEffect ? root.selectedEffect.pulseSpeed : 0
                            onMovedValue: function(v) { if (root.selectedEffect) root.selectedEffect.pulseSpeed = v }
                            onBegin: { if (root.mapInfo) root._beforeJson = root.mapInfo.toJSON() }
                            onCommit: root._commit(root._beforeJson)
                        }

                        // ---- Fondus ----
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: Theme.spacingM
                            rowSpacing: Theme.spacingS

                            Label { text: "Fondu entrée (ms) :"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.bold: true }
                            SpinBox {
                                Layout.fillWidth: true
                                from: 0; to: 5000; stepSize: 50
                                value: root.selectedEffect ? root.selectedEffect.fadeInMs : 0
                                onValueModified: {
                                    if (root.selectedEffect && root.selectedEffect.fadeInMs !== value)
                                        root._mutate(function() { root.selectedEffect.fadeInMs = value })
                                }
                            }

                            Label { text: "Fondu sortie (ms) :"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.bold: true }
                            SpinBox {
                                Layout.fillWidth: true
                                from: 0; to: 5000; stepSize: 50
                                value: root.selectedEffect ? root.selectedEffect.fadeOutMs : 0
                                onValueModified: {
                                    if (root.selectedEffect && root.selectedEffect.fadeOutMs !== value)
                                        root._mutate(function() { root.selectedEffect.fadeOutMs = value })
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                    }
                }
            }
        }
    }
}
