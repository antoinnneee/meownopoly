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
    width: Screen.pixelDensity * 150
    height: Screen.pixelDensity * 125
    anchors.centerIn: parent
    color: "#2C2C2C"
    radius: 10
    border.color: "#4A90E2"
    border.width: 2
    onVisibleChanged: isVisble(visible)

    signal isVisble(bool visible)
    
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
        if (editor && editor.regainFocus) {
            editor.regainFocus()
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
                                    logic.removeCurrentMap()
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
                        text: "Paramètres"
                        color: "white"
                        font.pixelSize: 20
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                // Contenu des paramètres
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

                        Column {
                            width: parent.width
                            // anchors.top: displayMenuBtn.bottom
                            anchors.topMargin: 10
                            spacing: 20

                            Button {
                                id: displayMenuBtn
                                height: 50
                                width: escMenu.width * 0.82
                                background: Rectangle {
                                    color: displayMenuBtn.checked ? "#4A90E2" : "#333333"
                                    radius: 8
                                    border.width: 1
                                    border.color: displayMenuBtn.checked ? "#FFFFFF" : "#555555"
                                }
                                contentItem: Text {
                                    id: txt
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: displayMenuBtn.checked ? "Afficher la modification de carte au lancement de l'éditeur ?" :
                                                                   "Ne pas afficher la modification de carte au lancement de l'éditeur ?"
                                    wrapMode: Text.WordWrap
                                    color: "white"
                                    font.pixelSize: 13
                                }
                                onVisibleChanged: {
                                    state = stBackGroundEditor.value("selectBackgroundAtStart", "true")
                                }
                                onClicked:{
                                    checked = !checked
                                    stBackGroundEditor.setValue("selectBackgroundAtStart", checked)
                                    stBackGroundEditor.sync()
                                }
                                Settings {
                                    id: stBackGroundEditor
                                    property bool selectBackgroundAtStart: value("selectBackgroundAtStart", "true")
                                    category: "Editor"
                                }
                            }
                            Row {
                                id: rowSave
                                height: 50
                                width: escMenu.width
                                spacing: 10
                                Button {
                                    id: enableAutoSaveBtn
                                    height: 50
                                    width: escMenu.width * 0.5
                                    property int indexBt : stEnableAutoSave.value("saveEvent", "0")
                                    background: Rectangle {
                                        color: {
                                            switch (enableAutoSaveBtn.indexBt){
                                            case 1 :
                                            default: "#333333"; break;
                                            case 2 : "#4A90E2"; break;
                                            case 3 : "#63C76F"; break;
                                            }
                                        }
                                        border.color: {
                                            switch (enableAutoSaveBtn.indexBt){
                                            case 1 :
                                            default: "#555555"; break;
                                            case 2 :
                                            case 3 : "#FFFFFF"; break;
                                            }
                                        }

                                        border.width: 1
                                        radius: 8
                                    }
                                    contentItem: Text {
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        text:switch (enableAutoSaveBtn.indexBt){
                                             case 1 :
                                             default: "Pas de sauvegarde automatique"; break;
                                             case 2 : "Sauvegarde toute les "; break;
                                             case 3 : "Sauvegarde sur modification"; break;
                                             }
                                        wrapMode: Text.WordWrap
                                        color: "white"
                                        font.pixelSize: 13
                                    }
                                    onVisibleChanged: {
                                        enableAutoSaveBtn.indexBt = parseInt(stEnableAutoSave.value("saveEvent", "0"))
                                        if (enableAutoSaveBtn.indexBt == 2) {
                                            saveIntervalSpinBox.value = parseInt(stEnableAutoSave.value("saveInterval", "1"))
                                        }
                                    }
                                    onClicked:{
                                        enableAutoSaveBtn.indexBt % 3 ? enableAutoSaveBtn.indexBt += 1 : enableAutoSaveBtn.indexBt = 1
                                        stEnableAutoSave.setValue("saveEvent", enableAutoSaveBtn.indexBt)
                                        stEnableAutoSave.sync()
                                        if (enableAutoSaveBtn.indexBt == 2) {
                                            saveIntervalSpinBox.value = parseInt(stEnableAutoSave.value("saveInterval", "1"))
                                        }
                                    }
                                    Settings {
                                        id: stEnableAutoSave
                                        category: "Editor/SaveConfig"
                                    }
                                }
                                
                                // Conteneur discret pour l'intervalle de sauvegarde
                                Row {
                                    id: intervalRow
                                    height: 50
                                    visible: enableAutoSaveBtn.indexBt == 2
                                    spacing: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    // SpinBox discret
                                    SpinBox {
                                        id: saveIntervalSpinBox
                                        height: 35
                                        width: 50
                                        from: 1
                                        to: 5
                                        value: parseInt(stEnableAutoSave.value("saveInterval", "1"))
                                        
                                        contentItem: TextInput {
                                            text: saveIntervalSpinBox.textFromValue(saveIntervalSpinBox.value, saveIntervalSpinBox.locale)
                                            font.pixelSize: 12
                                            color: "#CCCCCC"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            readOnly: true
                                            selectByMouse: false
                                        }
                                        
                                        background: Rectangle {
                                            color: "#2A2A2A"
                                            radius: 4
                                            border.color: "#555555"
                                            border.width: 1
                                        }
                                        
                                        up.indicator: Rectangle {
                                            x: saveIntervalSpinBox.mirrored ? 0 : parent.width - width
                                            height: parent.height / 2
                                            implicitWidth: 18
                                            color: saveIntervalSpinBox.up.pressed ? "#3A3A3A" : "#2A2A2A"
                                            border.color: "#555555"
                                            border.width: 1
                                            radius: 4
                                            Text {
                                                text: "+"
                                                color: "#CCCCCC"
                                                font.pixelSize: 11
                                                anchors.centerIn: parent
                                            }
                                        }
                                        
                                        down.indicator: Rectangle {
                                            x: saveIntervalSpinBox.mirrored ? 0 : parent.width - width
                                            y: parent.height / 2
                                            height: parent.height / 2
                                            implicitWidth: 18
                                            color: saveIntervalSpinBox.down.pressed ? "#3A3A3A" : "#2A2A2A"
                                            border.color: "#555555"
                                            border.width: 1
                                            radius: 4
                                            Text {
                                                text: "−"
                                                color: "#CCCCCC"
                                                font.pixelSize: 11
                                                anchors.centerIn: parent
                                            }
                                        }
                                        
                                        onValueChanged: {
                                            if (visible) {
                                                stEnableAutoSave.setValue("saveInterval", value.toString())
                                                stEnableAutoSave.sync()
                                            }
                                        }
                                    }
                                    
                                    // Texte "minutes"
                                    Text {
                                        text: "minutes"
                                        color: "#CCCCCC"
                                        font.pixelSize: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            // Section Graphiques
                            Column {
                                width: parent.width
                                spacing: 10
                                
                                Text {
                                    text: "Graphiques"
                                    color: "#4A90E2"
                                    font.pixelSize: 16
                                    font.bold: true
                                }
                                
                                Row {
                                    width: parent.width
                                    height: 30
                                    spacing: 10
                                    
                                    Text {
                                        text: "Qualité graphique:"
                                        color: "white"
                                        font.pixelSize: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    
                                    ComboBox {
                                        width: 150
                                        model: ["Faible", "Moyenne", "Élevée", "Ultra"]
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                
                                Row {
                                    width: parent.width
                                    height: 30
                                    spacing: 10
                                    
                                    Text {
                                        text: "Résolution:"
                                        color: "white"
                                        font.pixelSize: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    
                                    ComboBox {
                                        width: 150
                                        model: ["1920x1080", "1366x768", "1280x720", "1024x768"]
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                
                                Row {
                                    width: parent.width
                                    height: 30
                                    spacing: 10
                                    
                                    CheckBox {
                                        id: fullscreenCheckbox
                                        checked: false
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    
                                    Text {
                                        text: "Mode plein écran"
                                        color: "white"
                                        font.pixelSize: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                            
                            // Section Audio
                            Column {
                                width: parent.width
                                spacing: 10
                                
                                Text {
                                    text: "Audio"
                                    color: "#4A90E2"
                                    font.pixelSize: 16
                                    font.bold: true
                                }
                                
                                Row {
                                    width: parent.width
                                    height: 30
                                    spacing: 10
                                    
                                    Text {
                                        text: "Volume général:"
                                        color: "white"
                                        font.pixelSize: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    
                                    Slider {
                                        width: 200
                                        from: 0
                                        to: 100
                                        value: 50
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    
                                    Text {
                                        text: Math.round(parent.value) + "%"
                                        color: "white"
                                        font.pixelSize: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                
                                Row {
                                    width: parent.width
                                    height: 30
                                    spacing: 10
                                    
                                    CheckBox {
                                        id: musicCheckbox
                                        checked: true
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    
                                    Text {
                                        text: "Activer la musique"
                                        color: "white"
                                        font.pixelSize: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                            
                            // Section Contrôles
                            Column {
                                width: parent.width
                                spacing: 10
                                
                                Text {
                                    text: "Contrôles"
                                    color: "#4A90E2"
                                    font.pixelSize: 16
                                    font.bold: true
                                }
                                
                                Row {
                                    width: parent.width
                                    height: 30
                                    spacing: 10
                                    
                                    Text {
                                        text: "Sensibilité de la souris:"
                                        color: "white"
                                        font.pixelSize: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    
                                    Slider {
                                        width: 200
                                        from: 0.1
                                        to: 2.0
                                        value: 1.0
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    
                                    Text {
                                        text: Math.round(parent.value * 100) / 100
                                        color: "white"
                                        font.pixelSize: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                
                                Row {
                                    width: parent.width
                                    height: 30
                                    spacing: 10
                                    
                                    CheckBox {
                                        id: invertMouseCheckbox
                                        checked: false
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    
                                    Text {
                                        text: "Inverser l'axe Y de la souris"
                                        color: "white"
                                        font.pixelSize: 14
                                        anchors.verticalCenter: parent.verticalCenter
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

