import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Particles
import QtCore
import Game
import MapFileManager
import MapTypes

Rectangle {
    id: escMenu
    width: (parent.width * 0.8 < Screen.pixelDensity * 180) ? parent.width * 0.8 : Screen.pixelDensity * 180
    height: (parent.height * 0.8 < Screen.pixelDensity * 150) ? parent.height * 0.8 : Screen.pixelDensity * 150
    anchors.centerIn: parent
    color: "#2C2C2C"
    radius: 10
    border.color: "#4A90E2"
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
        radius: 10
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
        anchors.margins: 20
        
        // Vue principale avec les options
        Item {
            id: mainView
            anchors.fill: parent
            visible: currentView === "main"
            
            Column {
                anchors.centerIn: parent
                spacing: 20
                
                Text {
                    text: "Menu d'échappement"
                    color: "white"
                    font.pixelSize: 24
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                // Bouton Retour au menu principal
                Button {
                    width: 300
                    height: 50
                    text: "Retour au menu principal"
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    background: Rectangle {
                        color: parent.pressed ? "#3A7BD5" : "#4A90E2"
                        radius: 8
                        border.color: "#2E5BBA"
                        border.width: 1
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        escMenu.returnToMainMenu()
                        escMenu.hide()
                    }
                }
                
                // Bouton Charger carte
                Button {
                    width: 300
                    height: 50
                    text: "Charger carte"
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    background: Rectangle {
                        color: parent.pressed ? "#3A7BD5" : "#4A90E2"
                        radius: 8
                        border.color: "#2E5BBA"
                        border.width: 1
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        currentView = "loadMap"
                        refreshMapList()
                    }
                }
                
                // Bouton Paramètres
                Button {
                    width: 300
                    height: 50
                    text: "Paramètres"
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    background: Rectangle {
                        color: parent.pressed ? "#3A7BD5" : "#4A90E2"
                        radius: 8
                        border.color: "#2E5BBA"
                        border.width: 1
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        currentView = "settings"
                    }
                }
                
                // Bouton About
                Button {
                    width: 300
                    height: 50
                    text: "About"
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    background: Rectangle {
                        color: parent.pressed ? "#3A7BD5" : "#4A90E2"
                        radius: 8
                        border.color: "#2E5BBA"
                        border.width: 1
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        currentView = "about"
                    }
                }
                
                // Bouton Fermer
                Button {
                    width: 300
                    height: 50
                    text: "Fermer"
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    background: Rectangle {
                        color: parent.pressed ? "#666666" : "#888888"
                        radius: 8
                        border.color: "#555555"
                        border.width: 1
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
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
                spacing: 15
                
                // Header avec bouton retour
                Row {
                    width: parent.width
                    height: 40
                    spacing: 15
                    
                    Button {
                        width: 40
                        height: 40
                        text: "←"
                        anchors.verticalCenter: parent.verticalCenter
                        
                        background: Rectangle {
                            color: parent.pressed ? "#3A7BD5" : "#4A90E2"
                            radius: 6
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: 18
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            currentView = "main"
                        }
                    }
                    
                    Text {
                        text: "Charger une carte"
                        color: "white"
                        font.pixelSize: 20
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                // Liste des cartes
                Rectangle {
                    width: parent.width
                    height: parent.height - 60
                    color: "#333333"
                    radius: 8
                    border.color: "#4A90E2"
                    border.width: 1
                    
                    ListView {
                        id: mapsList
                        anchors.fill: parent
                        anchors.margins: 10
                        model: []
                        spacing: 5
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
                        
                        delegate: Button {
                            width: mapsList.width
                            height: 40
                            
                            background: Rectangle {
                                color: "#444444"
                                radius: 6
                                border.color: "#4A90E2"
                                border.width: 1
                            }
                            
                            contentItem: Text {
                                text: modelData
                                color: "white"
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
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
                anchors.fill: parent
                spacing: 15
                
                // Header avec bouton retour
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    spacing: 15
                    
                    Button {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        text: "←"
                        
                        background: Rectangle {
                            color: parent.pressed ? "#3A7BD5" : "#4A90E2"
                            radius: 8
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: 18
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            currentView = "main"
                        }
                    }
                    
                    Text {
                        text: "Paramètres"
                        color: "white"
                        font.pixelSize: 22
                        font.bold: true
                        Layout.fillWidth: true
                    }
                }
                
                // Contenu des paramètres
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#1E1E1E"
                    radius: 12
                    border.color: "#333333"
                    border.width: 1
                    
                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 15
                        contentWidth: availableWidth
                        clip: true
                        
                        ColumnLayout {
                            width: parent.width
                            spacing: 15
                            
                            // --- SECTION ÉDITEUR ---
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: editorLayout.implicitHeight + 30
                                color: "#252525"
                                radius: 8
                                border.color: "#3A3A3A"
                                border.width: 1
                                
                                ColumnLayout {
                                    id: editorLayout
                                    anchors.fill: parent
                                    anchors.margins: 15
                                    spacing: 15
                                    
                                    Text {
                                        text: "Éditeur"
                                        color: "#4A90E2"
                                        font.pixelSize: 16
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }

                                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#3A3A3A" }
                                    
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 15
                                        Text { text: "Afficher la sélection de carte au lancement"; color: "#E0E0E0"; font.pixelSize: 14; Layout.fillWidth: true }
                                        Switch {
                                            id: launchSwitch
                                            checked: stBackGroundEditor.selectBackgroundAtStart
                                            onCheckedChanged: {
                                                stBackGroundEditor.setValue("selectBackgroundAtStart", checked)
                                                stBackGroundEditor.sync()
                                            }
                                            indicator: Rectangle {
                                                implicitWidth: 46; implicitHeight: 24
                                                x: parent.leftPadding
                                                y: parent.height / 2 - height / 2
                                                radius: 12
                                                color: parent.checked ? "#4A90E2" : "#444444"
                                                Rectangle {
                                                    x: parent.parent.checked ? parent.width - width - 2 : 2
                                                    y: 2; width: 20; height: 20; radius: 10; color: "white"
                                                    Behavior on x { NumberAnimation { duration: 150 } }
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 15
                                        Text { text: "Mode de sauvegarde"; color: "#E0E0E0"; font.pixelSize: 14; Layout.fillWidth: true }
                                        ComboBox {
                                            id: autoSaveCombo
                                            Layout.preferredWidth: 220
                                            model: ["Manuelle", "Intervalle de temps", "Sur modification"]
                                            currentIndex: {
                                                let val = parseInt(stEnableAutoSave.value("saveEvent", "1"))
                                                return val > 0 && val <= 3 ? val - 1 : 0
                                            }
                                            onActivated: {
                                                stEnableAutoSave.setValue("saveEvent", currentIndex + 1)
                                                stEnableAutoSave.sync()
                                                escMenu.indexSaveEvent(currentIndex + 1)
                                            }
                                            background: Rectangle { color: "#333333"; radius: 6; border.color: autoSaveCombo.pressed ? "#4A90E2" : "#555555"; border.width: 1 }
                                            contentItem: Text { text: parent.currentText; color: "white"; verticalAlignment: Text.AlignVCenter; leftPadding: 10; font.pixelSize: 14 }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 15
                                        visible: autoSaveCombo.currentIndex === 1
                                        Text { text: "Intervalle (minutes)"; color: "#E0E0E0"; font.pixelSize: 14; Layout.fillWidth: true }
                                        SpinBox {
                                            id: saveIntervalSpinBox
                                            Layout.preferredWidth: 120
                                            from: 1; to: 60
                                            value: parseInt(stEnableAutoSave.value("saveInterval", "1"))
                                            onValueChanged: { stEnableAutoSave.setValue("saveInterval", value); stEnableAutoSave.sync() }
                                            background: Rectangle { color: "#333333"; radius: 6; border.color: "#555555"; border.width: 1 }
                                            contentItem: TextInput {
                                                text: parent.textFromValue(parent.value, parent.locale)
                                                font.pixelSize: 14; color: "white"
                                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; readOnly: true
                                            }
                                            up.indicator: Rectangle { x: parent.width - width; height: parent.height; implicitWidth: 30; color: parent.up.pressed ? "#4A90E2" : "#404040"; radius: 6; Text { text: "+"; color: "white"; anchors.centerIn: parent } }
                                            down.indicator: Rectangle { x: 0; height: parent.height; implicitWidth: 30; color: parent.down.pressed ? "#4A90E2" : "#404040"; radius: 6; Text { text: "-"; color: "white"; anchors.centerIn: parent } }
                                        }
                                    }
                                }
                            }

                            // --- SECTION GRAPHIQUES ---
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: graphicsLayout.implicitHeight + 30
                                color: "#252525"
                                radius: 8
                                border.color: "#3A3A3A"
                                border.width: 1
                                
                                ColumnLayout {
                                    id: graphicsLayout
                                    anchors.fill: parent
                                    anchors.margins: 15
                                    spacing: 15
                                    
                                    Text {
                                        text: "Graphiques"
                                        color: "#4A90E2"
                                        font.pixelSize: 16
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }
                                    
                                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#3A3A3A" }
                                    
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Résolution"; color: "#E0E0E0"; font.pixelSize: 14; Layout.fillWidth: true }
                                        ComboBox {
                                            id: resolutionCombo
                                            Layout.preferredWidth: 200; 
                                            model: ["1920x1080", "1366x768", "1280x720", "1024x768"]
                                            currentIndex: {
                                                let savedRes = stVideoConfig.value("resolution", "1280x720")
                                                let idx = model.indexOf(savedRes)
                                                return idx >= 0 ? idx : 2 // default to 1280x720
                                            }
                                            onActivated: {
                                                let res = currentText
                                                stVideoConfig.setValue("resolution", res)
                                                stVideoConfig.sync()
                                                
                                                let parts = res.split("x")
                                                if(parts.length === 2 && Window.window) {
                                                    Window.window.width = parseInt(parts[0])
                                                    Window.window.height = parseInt(parts[1])
                                                    
                                                    // Centrer la fenêtre
                                                    Window.window.x = (Screen.desktopAvailableWidth - Window.window.width) / 2
                                                    Window.window.y = (Screen.desktopAvailableHeight - Window.window.height) / 2
                                                }
                                            }
                                            background: Rectangle { color: "#333333"; radius: 6; border.color: parent.pressed ? "#4A90E2" : "#555555"; border.width: 1 }
                                            contentItem: Text { text: parent.currentText; color: "white"; verticalAlignment: Text.AlignVCenter; leftPadding: 10; font.pixelSize: 14 }
                                        }
                                    }
                                    
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Mode plein écran sans bordure"; color: "#E0E0E0"; font.pixelSize: 14; Layout.fillWidth: true }
                                        Switch {
                                            id: fullscreenSwitch; 
                                            checked: stVideoConfig.value("fullscreen", false) === "true" || stVideoConfig.value("fullscreen", false) === true
                                            onCheckedChanged: {
                                                stVideoConfig.setValue("fullscreen", checked)
                                                stVideoConfig.sync()
                                                
                                                if(Window.window) {
                                                    if(checked) {
                                                        Window.window.visibility = Window.FullScreen
                                                    } else {
                                                        Window.window.visibility = Window.Windowed
                                                    }
                                                }
                                            }
                                            indicator: Rectangle { implicitWidth: 46; implicitHeight: 24; x: parent.leftPadding; y: parent.height/2 - height/2; radius: 12; color: parent.checked ? "#4A90E2" : "#444444"
                                                Rectangle { x: parent.parent.checked ? parent.width - width - 2 : 2; y: 2; width: 20; height: 20; radius: 10; color: "white"; Behavior on x { NumberAnimation { duration: 150 } } } }
                                        }
                                    }
                                }
                            }

                            // --- SECTION AUDIO ---
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: audioLayout.implicitHeight + 30
                                color: "#252525"
                                radius: 8
                                border.color: "#3A3A3A"
                                border.width: 1
                                
                                ColumnLayout {
                                    id: audioLayout
                                    anchors.fill: parent
                                    anchors.margins: 15
                                    spacing: 15
                                    
                                    Text {
                                        text: "Audio"
                                        color: "#4A90E2"
                                        font.pixelSize: 16
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }
                                    
                                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#3A3A3A" }
                                    
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Volume général"; color: "#E0E0E0"; font.pixelSize: 14; Layout.fillWidth: true }
                                        Slider {
                                            id: volumeSlider
                                            Layout.preferredWidth: 200; from: 0; to: 100; value: 50
                                            background: Rectangle { x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - height / 2; implicitWidth: 150; implicitHeight: 4; width: parent.availableWidth; height: implicitHeight; radius: 2; color: "#444444"; Rectangle { width: parent.parent.visualPosition * parent.width; height: parent.height; color: "#4A90E2"; radius: 2 } }
                                            handle: Rectangle { x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width); y: parent.topPadding + parent.availableHeight / 2 - height / 2; implicitWidth: 16; implicitHeight: 16; radius: 8; color: parent.pressed ? "#f0f0f0" : "white"; border.color: "#4A90E2"; border.width: 1 }
                                        }
                                        Text { text: Math.round(volumeSlider.value) + "%"; color: "#E0E0E0"; font.pixelSize: 14; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight }
                                    }
                                    
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Activer la musique"; color: "#E0E0E0"; font.pixelSize: 14; Layout.fillWidth: true }
                                        Switch {
                                            id: musicSwitch; checked: true
                                            indicator: Rectangle { implicitWidth: 46; implicitHeight: 24; x: parent.leftPadding; y: parent.height/2 - height/2; radius: 12; color: parent.checked ? "#4A90E2" : "#444444"
                                                Rectangle { x: parent.parent.checked ? parent.width - width - 2 : 2; y: 2; width: 20; height: 20; radius: 10; color: "white"; Behavior on x { NumberAnimation { duration: 150 } } } }
                                        }
                                    }
                                }
                            }

                            // --- SECTION CONTRÔLES ---
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: controlsLayout.implicitHeight + 30
                                color: "#252525"
                                radius: 8
                                border.color: "#3A3A3A"
                                border.width: 1
                                
                                ColumnLayout {
                                    id: controlsLayout
                                    anchors.fill: parent
                                    anchors.margins: 15
                                    spacing: 15
                                    
                                    Text {
                                        text: "Contrôles"
                                        color: "#4A90E2"
                                        font.pixelSize: 16
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }
                                    
                                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#3A3A3A" }
                                    
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Sensibilité de la souris"; color: "#E0E0E0"; font.pixelSize: 14; Layout.fillWidth: true }
                                        Slider {
                                            id: sensitivitySlider
                                            Layout.preferredWidth: 200; from: 0.8; to: 4.0; 
                                            value: parseFloat(stControlsConfig.value("mouseSensitivity", "1.0"))
                                            onValueChanged: {
                                                stControlsConfig.setValue("mouseSensitivity", value)
                                                stControlsConfig.sync()
                                            }
                                            background: Rectangle { x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - height / 2; implicitWidth: 150; implicitHeight: 4; width: parent.availableWidth; height: implicitHeight; radius: 2; color: "#444444"; Rectangle { width: parent.parent.visualPosition * parent.width; height: parent.height; color: "#4A90E2"; radius: 2 } }
                                            handle: Rectangle { x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width); y: parent.topPadding + parent.availableHeight / 2 - height / 2; implicitWidth: 16; implicitHeight: 16; radius: 8; color: parent.pressed ? "#f0f0f0" : "white"; border.color: "#4A90E2"; border.width: 1 }
                                        }
                                        Text { text: (Math.round(sensitivitySlider.value * 100) / 100).toFixed(2); color: "#E0E0E0"; font.pixelSize: 14; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight }
                                    }
                                    
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Inverser l'axe Y"; color: "#E0E0E0"; font.pixelSize: 14; Layout.fillWidth: true }
                                        Switch {
                                            id: invertMouseSwitch; 
                                            checked: stControlsConfig.value("invertMouseY", false) === "true" || stControlsConfig.value("invertMouseY", false) === true
                                            onCheckedChanged: {
                                                stControlsConfig.setValue("invertMouseY", checked)
                                                stControlsConfig.sync()
                                            }
                                            indicator: Rectangle { implicitWidth: 46; implicitHeight: 24; x: parent.leftPadding; y: parent.height/2 - height/2; radius: 12; color: parent.checked ? "#4A90E2" : "#444444"
                                                Rectangle { x: parent.parent.checked ? parent.width - width - 2 : 2; y: 2; width: 20; height: 20; radius: 10; color: "white"; Behavior on x { NumberAnimation { duration: 150 } } } }
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
                spacing: 15
                
                // Header avec bouton retour
                Row {
                    width: parent.width
                    height: 40
                    spacing: 15
                    
                    Button {
                        width: 40
                        height: 40
                        text: "←"
                        anchors.verticalCenter: parent.verticalCenter
                        
                        background: Rectangle {
                            color: parent.pressed ? "#3A7BD5" : "#4A90E2"
                            radius: 6
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.pixelSize: 18
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            currentView = "main"
                        }
                    }
                    
                    Text {
                        text: "À propos"
                        color: "white"
                        font.pixelSize: 20
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                // Contenu About
                Rectangle {
                    width: parent.width
                    height: parent.height - 60
                    color: "#333333"
                    radius: 8
                    border.color: "#4A90E2"
                    border.width: 1
                    
                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 15
                        
                        Text {
                            width: parent.width
                            color: "white"
                            font.pixelSize: 14
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

