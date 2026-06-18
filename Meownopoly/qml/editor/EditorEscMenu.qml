import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Particles
import QtCore
import Game
import MapFileManager
import MapTypes
import theme
import ui_item

Rectangle {
    id: escMenu
    width: (parent.width * 0.8 < Screen.pixelDensity * 180) ? parent.width * 0.8 : Screen.pixelDensity * 180
    height: (parent.height * 0.8 < Screen.pixelDensity * 150) ? parent.height * 0.8 : Screen.pixelDensity * 150
    anchors.centerIn: parent
    color: Theme.surface
    radius: Theme.radiusXL
    border.color: Theme.accent
    border.width: 2
    onVisibleChanged: isVisble(visible)

    signal isVisble(bool visible)
    signal indexSaveEvent(int index)
    ParticleSystem {
        id: particleSystem
        anchors.fill: parent
        clip: true

        // Emitter for the initial burst
        Emitter {
            id: burstEmitter
            enabled: true
            anchors.fill: parent
            lifeSpan: 2000
            size: 10
            emitRate: 3
            velocity: AngleDirection {
                angle: 270
                angleVariation: 15
                magnitude: 200
                magnitudeVariation: 50
            }
        }

        // Particle image for the initial burst
        ImageParticle {
            id: firework
            source: "qrc:///particleresources/glowdot.png"
            color: Qt.rgba(Math.random(), Math.random(), Math.random(), 1)
            colorVariation: 0.5
            alpha: 0.75
            rotationVariation: 360
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            burstEmitter.burst(1);
            firework.color = Qt.rgba(Math.random(), Math.random(), Math.random(), 1);
        }
    }

    property bool isVisible: false
    
    // Propriétés pour la navigation
    property string currentView: "main"
    
    // Signal pour retourner au menu principal
    signal returnToMainMenu()

    // ── Composants inline du panneau Paramètres ──────────────────
    // Libellé d'une ligne de réglage : titre + sous-titre optionnel.
    // Prend toute la largeur disponible pour repousser le contrôle à droite.
    component SettingLabel: ColumnLayout {
        id: _settingLabel
        property string title: ""
        property string hint: ""
        Layout.fillWidth: true
        spacing: Theme.px(2)
        Text {
            text: _settingLabel.title
            color: Theme.textSoft
            font.pixelSize: Theme.fontSizeMedium
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
        Text {
            visible: _settingLabel.hint !== ""
            text: _settingLabel.hint
            color: Theme.textHint
            font.pixelSize: Theme.fontSizeSmall
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
    }
    // Fin séparateur horizontal entre deux lignes de réglage.
    component SettingDivider: Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.surfaceHover
    }

    // Fonction pour afficher/masquer le menu
    function show() {
        isVisible = true
        currentView = "main"
        forceActiveFocus()  // Assurer que le menu reçoit le focus
    }
    
    function hide() {
        isVisible = false
        currentView = "main"
        // Redonner le focus à l'éditeur parent
        var editor = parent
        while (editor && !editor.hasOwnProperty('regainFocus')) {
            editor = editor.parent
        }
        if (editor) {
            editor.forceActiveFocus()
        }
    }
    
    // Fonction pour rafraîchir la liste des cartes
    function refreshMapList() {
        mapsList.model = MapFileManager.getAvailableMaps()
    }
    
    visible: isVisible
    
    // Fond semi-transparent pour laisser voir les particules
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.3
        radius: Theme.radiusXL
        z: 0  // Au-dessus des particules mais sous le contenu
    }
    
    // MouseArea pour s'assurer que le menu peut recevoir le focus
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton  // Ne pas interférer avec les clics
        onPressed: {
            forceActiveFocus()
        }
    }
    
    // Contenu principal
    Item {
        anchors.fill: parent
        anchors.margins: Theme.spacingHuge

        // Vue principale avec les options
        Item {
            id: mainView
            anchors.fill: parent
            visible: currentView === "main"

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingHuge

                Text {
                    text: "Menu d'échappement"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeDisplay
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                // Bouton Retour au menu principal
                MeowButton {
                    width: 300
                    height: 50
                    text: "Retour au menu principal"
                    anchors.horizontalCenter: parent.horizontalCenter
                    variant: "primary"
                    onClicked: {
                        escMenu.returnToMainMenu()
                        escMenu.hide()
                    }
                }
                
                // Bouton Charger carte
                MeowButton {
                    width: 300
                    height: 50
                    text: "Charger carte"
                    anchors.horizontalCenter: parent.horizontalCenter
                    variant: "primary"
                    onClicked: {
                        currentView = "loadMap"
                        refreshMapList()
                    }
                }
                
                // Bouton Paramètres
                MeowButton {
                    width: 300
                    height: 50
                    text: "Paramètres"
                    anchors.horizontalCenter: parent.horizontalCenter
                    variant: "primary"
                    onClicked: {
                        currentView = "settings"
                    }
                }
                
                // Bouton About
                MeowButton {
                    width: 300
                    height: 50
                    text: "About"
                    anchors.horizontalCenter: parent.horizontalCenter
                    variant: "primary"
                    onClicked: {
                        currentView = "about"
                    }
                }
                
                // Bouton Fermer
                MeowButton {
                    width: 300
                    height: 50
                    text: "Fermer"
                    anchors.horizontalCenter: parent.horizontalCenter
                    variant: "secondary"
                    baseColor: Theme.textMuted
                    onClicked: {
                        escMenu.hide()
                    }
                }
            }
        }
        
        // Vue de chargement de carte
        Item {
            id: loadMapView
            anchors.fill: parent
            visible: currentView === "loadMap"
            
            Column {
                anchors.fill: parent
                spacing: Theme.spacingXXL
                
                // Header avec bouton retour
                Row {
                    width: parent.width
                    height: 40
                    spacing: Theme.spacingXXL
                    
                    MeowButton {
                        width: 40
                        height: 40
                        text: "←"
                        anchors.verticalCenter: parent.verticalCenter
                        variant: "primary"
                        fontSize: Theme.fontSizeTitle
                        hoverZoom: false
                        onClicked: {
                            currentView = "main"
                        }
                    }
                    
                    Text {
                        text: "Charger une carte"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeHeading
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                // Liste des cartes
                Rectangle {
                    width: parent.width
                    height: parent.height - 60
                    color: Theme.surfaceAlt
                    radius: Theme.radiusL
                    border.color: Theme.accent
                    border.width: 1

                    ListView {
                        id: mapsList
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        model: []
                        spacing: Theme.spacingXS
                        clip: true
                        
                        ScrollBar.vertical: ScrollBar {
                            id: scrollBar
                            active: mapsList.contentHeight > mapsList.height
                            policy: ScrollBar.AsNeeded
                            visible: mapsList.contentHeight > mapsList.height
                            
                            contentItem: Rectangle {
                                implicitWidth: 8
                                radius: width / 2
                                color: "#999999"
                                opacity: scrollBar.pressed ? 0.8 : 0.5
                            }
                        }
                        
                        delegate: MeowButton {
                            width: mapsList.width
                            height: 40
                            text: modelData
                            baseColor: Theme.border
                            fontSize: Theme.fontSizeMedium
                            hoverZoom: false
                            glossy: false

                            onClicked: {
                                console.log("Chargement de la carte:", modelData)
                                if (typeof logic !== 'undefined') {
                                    // Level 4 — plus besoin d'appeler
                                    // logic.removeCurrentMap() : Game.loadMap
                                    // émet clearCurrentMap en entrée et
                                    // Editor.qml le convertit en wipe.
                                    var normalizedMapName = MapFileManager.findMapFileByName(modelData)
                                    if (normalizedMapName !== "") {
                                        Game.loadMap(normalizedMapName, MapTypes.CUSTOM)
                                    } else {
                                        console.error("Could not find map file for: " + modelData)
                                    }
                                }
                                escMenu.hide()
                            }
                        }
                    }
                }
            }
        }
        
        // Vue des paramètres
        Item {
            id: settingsView
            anchors.fill: parent
            visible: currentView === "settings"
            
            Settings {
                id: stBackGroundEditor
                property bool selectBackgroundAtStart: value("selectBackgroundAtStart", "true") === "true" || value("selectBackgroundAtStart", "true") === true
                category: "Editor"
                // Applique l'échelle d'interface persistée (Theme.uiScale) dès
                // le chargement de l'éditeur — le settingsView est instancié
                // même masqué, donc ce handler s'exécute au démarrage. Lecture
                // directe via value() (pas une propriété déclarée trackée) pour
                // rester cohérent avec les autres réglages scalaires du panneau.
                Component.onCompleted: {
                    Theme.uiScale = parseFloat(value("uiScale", "1.0"))
                }
            }
            Settings {
                id: stEnableAutoSave
                category: "Editor/SaveConfig"
            }
            Settings {
                id: stVideoConfig
                category: "Video"
            }
            Settings {
                id: stControlsConfig
                category: "Controls"
            }
            
            ColumnLayout {
                id: settingsBody
                anchors.fill: parent
                spacing: Theme.spacingL

                // Catégorie active de la sidebar (mémorisée d'une ouverture à
                // l'autre). Pilote la sidebar ET le StackLayout de contenu.
                property string category: "editor"

                // ── En-tête : titre + bouton retour ─────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingL

                    Text {
                        text: "Paramètres"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeHeading
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    MeowButton {
                        text: "Retour"
                        iconText: "←"
                        variant: "secondary"
                        fontSize: Theme.fontSizeMedium
                        hoverZoom: false
                        glossy: false
                        onClicked: currentView = "main"
                    }
                }

                // ── Corps : sidebar de catégories + volet de contenu ────
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Theme.spacingL

                    // --- Sidebar de navigation ---
                    Rectangle {
                        Layout.preferredWidth: Theme.px(190)
                        Layout.fillHeight: true
                        color: Theme.surface
                        radius: Theme.radiusL
                        border.color: Theme.surfaceHover
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingXS

                            Repeater {
                                model: [
                                    { key: "editor",   icon: "✎", label: "Éditeur" },
                                    { key: "graphics", icon: "▦", label: "Graphiques" },
                                    { key: "audio",    icon: "♪", label: "Audio" },
                                    { key: "controls", icon: "⌨", label: "Contrôles" }
                                ]
                                delegate: Rectangle {
                                    id: navItem
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Theme.px(42)
                                    radius: Theme.radiusM
                                    readonly property bool active: settingsBody.category === modelData.key
                                    color: navItem.active ? Theme.accent
                                                          : (navMouse.containsMouse ? Theme.surfaceHover : "transparent")
                                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Theme.spacingL
                                        anchors.rightMargin: Theme.spacingM
                                        spacing: Theme.spacingM

                                        Text {
                                            text: modelData.icon
                                            font.pixelSize: Theme.fontSizeLarge
                                            color: navItem.active ? Theme.textPrimary : Theme.textHint
                                        }
                                        Text {
                                            text: modelData.label
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.bold: navItem.active
                                            color: navItem.active ? Theme.textPrimary : Theme.textSecondary
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                    }
                                    MouseArea {
                                        id: navMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: settingsBody.category = modelData.key
                                    }
                                }
                            }
                            Item { Layout.fillWidth: true; Layout.fillHeight: true }
                        }
                    }

                    // --- Volet de contenu (une page par catégorie) ---
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Theme.surface
                        radius: Theme.radiusL
                        border.color: Theme.surfaceHover
                        border.width: 1

                        StackLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingXXL
                            currentIndex: ["editor", "graphics", "audio", "controls"].indexOf(settingsBody.category)

                            // ===================== ÉDITEUR =====================
                            ScrollView {
                                clip: true
                                contentWidth: availableWidth
                                ColumnLayout {
                                    width: parent.width
                                    spacing: Theme.spacingL

                                    Text { text: "Éditeur"; color: Theme.accent; font.pixelSize: Theme.fontSizeLarge; font.bold: true; Layout.fillWidth: true }
                                    SettingDivider {}

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.spacingXL
                                        SettingLabel { title: "Sélection de carte au lancement"; hint: "Propose le choix d'une carte à l'ouverture de l'éditeur." }
                                        MeowSwitch {
                                            Layout.alignment: Qt.AlignVCenter
                                            checked: stBackGroundEditor.selectBackgroundAtStart
                                            onToggled: { stBackGroundEditor.setValue("selectBackgroundAtStart", checked); stBackGroundEditor.sync() }
                                        }
                                    }
                                    SettingDivider {}

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.spacingXL
                                        SettingLabel { title: "Mode de sauvegarde"; hint: "Quand la carte est écrite sur le disque." }
                                        MeowComboBox {
                                            id: autoSaveCombo
                                            Layout.preferredWidth: Theme.px(220)
                                            Layout.alignment: Qt.AlignVCenter
                                            model: ["Manuelle", "Intervalle de temps", "Sur modification"]
                                            currentIndex: { let val = parseInt(stEnableAutoSave.value("saveEvent", "1")); return val > 0 && val <= 3 ? val - 1 : 0 }
                                            onActivated: {
                                                stEnableAutoSave.setValue("saveEvent", currentIndex + 1)
                                                stEnableAutoSave.sync()
                                                escMenu.indexSaveEvent(currentIndex + 1)
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.spacingXL
                                        visible: autoSaveCombo.currentIndex === 1
                                        SettingLabel { title: "Intervalle de sauvegarde" }
                                        MeowSpinBox {
                                            Layout.alignment: Qt.AlignVCenter
                                            Layout.preferredWidth: Theme.px(150)
                                            from: 1; to: 60; suffix: " min"
                                            value: parseInt(stEnableAutoSave.value("saveInterval", "1"))
                                            onValueChanged: { stEnableAutoSave.setValue("saveInterval", value); stEnableAutoSave.sync() }
                                        }
                                    }
                                    SettingDivider {}

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.spacingXL
                                        SettingLabel { title: "Échelle de l'interface"; hint: "Redimensionne toute l'UI. Appliqué au relâchement du curseur." }
                                        MeowSlider {
                                            id: uiScaleSlider
                                            Layout.preferredWidth: Theme.px(200)
                                            Layout.alignment: Qt.AlignVCenter
                                            from: 0.5; to: 2.0; stepSize: 0.05
                                            value: Theme.uiScale
                                            accentColor: Theme.accent
                                            showValue: false
                                            // Aperçu non-destructif : on n'applique pas pendant le
                                            // glissement souris (sinon le panneau se redimensionne et
                                            // le slider fuit sous le curseur), seulement au relâchement.
                                            property bool _dragging: false
                                            function _applyScale() {
                                                Theme.uiScale = uiScaleSlider.value
                                                stBackGroundEditor.setValue("uiScale", uiScaleSlider.value)
                                                stBackGroundEditor.sync()
                                            }
                                            onGestureBegan: uiScaleSlider._dragging = true
                                            onGestureCommitted: { uiScaleSlider._dragging = false; uiScaleSlider._applyScale() }
                                            onMoved: (v) => { if (!uiScaleSlider._dragging) uiScaleSlider._applyScale() }
                                        }
                                        Text {
                                            text: "×" + uiScaleSlider.value.toFixed(2)
                                            color: Theme.textSoft
                                            font.pixelSize: Theme.fontSizeMedium
                                            Layout.preferredWidth: Theme.px(50)
                                            Layout.alignment: Qt.AlignVCenter
                                            horizontalAlignment: Text.AlignRight
                                        }
                                    }
                                }
                            }

                            // ===================== GRAPHIQUES =====================
                            ScrollView {
                                clip: true
                                contentWidth: availableWidth
                                ColumnLayout {
                                    width: parent.width
                                    spacing: Theme.spacingL

                                    Text { text: "Graphiques"; color: Theme.accent; font.pixelSize: Theme.fontSizeLarge; font.bold: true; Layout.fillWidth: true }
                                    SettingDivider {}

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.spacingXL
                                        SettingLabel { title: "Résolution"; hint: "Taille de la fenêtre (mode fenêtré)." }
                                        MeowComboBox {
                                            Layout.preferredWidth: Theme.px(200)
                                            Layout.alignment: Qt.AlignVCenter
                                            model: ["1920x1080", "1366x768", "1280x720", "1024x768"]
                                            currentIndex: { let savedRes = stVideoConfig.value("resolution", "1280x720"); let idx = model.indexOf(savedRes); return idx >= 0 ? idx : 2 }
                                            onActivated: {
                                                let res = currentText
                                                stVideoConfig.setValue("resolution", res)
                                                stVideoConfig.sync()
                                                let parts = res.split("x")
                                                if (parts.length === 2 && Window.window) {
                                                    Window.window.width = parseInt(parts[0])
                                                    Window.window.height = parseInt(parts[1])
                                                    Window.window.x = (Screen.desktopAvailableWidth - Window.window.width) / 2
                                                    Window.window.y = (Screen.desktopAvailableHeight - Window.window.height) / 2
                                                }
                                            }
                                        }
                                    }
                                    SettingDivider {}

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.spacingXL
                                        SettingLabel { title: "Plein écran sans bordure" }
                                        MeowSwitch {
                                            Layout.alignment: Qt.AlignVCenter
                                            checked: stVideoConfig.value("fullscreen", false) === "true" || stVideoConfig.value("fullscreen", false) === true
                                            onToggled: {
                                                stVideoConfig.setValue("fullscreen", checked)
                                                stVideoConfig.sync()
                                                if (Window.window)
                                                    Window.window.visibility = checked ? Window.FullScreen : Window.Windowed
                                            }
                                        }
                                    }
                                }
                            }

                            // ===================== AUDIO =====================
                            ScrollView {
                                clip: true
                                contentWidth: availableWidth
                                ColumnLayout {
                                    width: parent.width
                                    spacing: Theme.spacingL

                                    Text { text: "Audio"; color: Theme.accent; font.pixelSize: Theme.fontSizeLarge; font.bold: true; Layout.fillWidth: true }
                                    SettingDivider {}

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.spacingXL
                                        SettingLabel { title: "Volume général" }
                                        MeowSlider {
                                            id: volumeSlider
                                            Layout.preferredWidth: Theme.px(200)
                                            Layout.alignment: Qt.AlignVCenter
                                            from: 0; to: 100; stepSize: 1; value: 50
                                            accentColor: Theme.accent
                                            showValue: false
                                        }
                                        Text {
                                            text: Math.round(volumeSlider.value) + "%"
                                            color: Theme.textSoft
                                            font.pixelSize: Theme.fontSizeMedium
                                            Layout.preferredWidth: Theme.px(50)
                                            Layout.alignment: Qt.AlignVCenter
                                            horizontalAlignment: Text.AlignRight
                                        }
                                    }
                                    SettingDivider {}

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.spacingXL
                                        SettingLabel { title: "Activer la musique" }
                                        MeowSwitch {
                                            Layout.alignment: Qt.AlignVCenter
                                            checked: true
                                        }
                                    }
                                }
                            }

                            // ===================== CONTRÔLES =====================
                            ScrollView {
                                clip: true
                                contentWidth: availableWidth
                                ColumnLayout {
                                    width: parent.width
                                    spacing: Theme.spacingL

                                    Text { text: "Contrôles"; color: Theme.accent; font.pixelSize: Theme.fontSizeLarge; font.bold: true; Layout.fillWidth: true }
                                    SettingDivider {}

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.spacingXL
                                        SettingLabel { title: "Sensibilité de la souris" }
                                        MeowSlider {
                                            id: sensitivitySlider
                                            Layout.preferredWidth: Theme.px(200)
                                            Layout.alignment: Qt.AlignVCenter
                                            from: 0.8; to: 4.0
                                            value: parseFloat(stControlsConfig.value("mouseSensitivity", "1.0"))
                                            accentColor: Theme.accent
                                            showValue: false
                                            onMoved: (v) => { stControlsConfig.setValue("mouseSensitivity", v); stControlsConfig.sync() }
                                        }
                                        Text {
                                            text: (Math.round(sensitivitySlider.value * 100) / 100).toFixed(2)
                                            color: Theme.textSoft
                                            font.pixelSize: Theme.fontSizeMedium
                                            Layout.preferredWidth: Theme.px(50)
                                            Layout.alignment: Qt.AlignVCenter
                                            horizontalAlignment: Text.AlignRight
                                        }
                                    }
                                    SettingDivider {}

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.spacingXL
                                        SettingLabel { title: "Inverser l'axe Y" }
                                        MeowSwitch {
                                            Layout.alignment: Qt.AlignVCenter
                                            checked: stControlsConfig.value("invertMouseY", false) === "true" || stControlsConfig.value("invertMouseY", false) === true
                                            onToggled: { stControlsConfig.setValue("invertMouseY", checked); stControlsConfig.sync() }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        // Vue About
        Item {
            id: aboutView
            anchors.fill: parent
            visible: currentView === "about"
            
            Column {
                anchors.fill: parent
                spacing: Theme.spacingXXL
                
                // Header avec bouton retour
                Row {
                    width: parent.width
                    height: 40
                    spacing: Theme.spacingXXL
                    
                    MeowButton {
                        width: 40
                        height: 40
                        text: "←"
                        anchors.verticalCenter: parent.verticalCenter
                        variant: "primary"
                        fontSize: Theme.fontSizeTitle
                        hoverZoom: false
                        onClicked: {
                            currentView = "main"
                        }
                    }
                    
                    Text {
                        text: "À propos"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeHeading
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                // Contenu About
                Rectangle {
                    width: parent.width
                    height: parent.height - 60
                    color: Theme.surfaceAlt
                    radius: Theme.radiusL
                    border.color: Theme.accent
                    border.width: 1

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingXXL
                        
                        Text {
                            width: parent.width
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeMedium
                            wrapMode: Text.WordWrap
                            text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt.

Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur? Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur, vel illum qui dolorem eum fugiat quo voluptas nulla pariatur?

At vero eos et accusamus et iusto odio dignissimos ducimus qui blanditiis praesentium voluptatum deleniti atque corrupti quos dolores et quas molestias excepturi sint occaecati cupiditate non provident, similique sunt in culpa qui officia deserunt mollitia animi, id est laborum et dolorum fuga. Et harum quidem rerum facilis est et expedita distinctio.

Nam libero tempore, cum soluta nobis est eligendi optio cumque nihil impedit quo minus id quod maxime placeat facere possimus, omnis voluptas assumenda est, omnis dolor repellendus. Temporibus autem quibusdam et aut officiis debitis aut rerum necessitatibus saepe eveniet ut et voluptates repudiandae sint et molestiae non recusandae. Itaque earum rerum hic tenetur a sapiente delectus, ut aut reiciendis voluptatibus maiores alias consequatur aut perferendis doloribus asperiores repellat."
                        }
                    }
                }
            }
        }
    }
    
    // Gestion des touches
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            if (currentView === "main") {
                hide()
            } else {
                currentView = "main"
            }
            event.accepted = true
        }
    }
    
    // Assurer que le menu peut recevoir le focus pour les raccourcis clavier
    focus: true
}

