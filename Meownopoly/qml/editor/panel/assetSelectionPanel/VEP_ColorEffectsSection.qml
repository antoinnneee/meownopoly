import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore
import "../../../ui_item"

CollapsableGroupBox {
    id: control
    title: "Color Effects"

    property alias brightnessSlider: brightnessSlider
    property alias contrastSlider: contrastSlider
    property alias saturationSlider: saturationSlider
    property alias colorizationSlider: colorizationSlider

    // Preset management properties
    property var colorPresets: []
    property int activePresetIndex: -1

    signal effectChanged()
    // signal colorPresetsChanged()

    // Settings pour la persistance des presets
    Settings {
        id: colorPresetSettings
        category: "Editor/ColorPresets"
        
        // Propriétés pour sauvegarder les presets
        property string presetsData: ""
        property int activeIndex: -1
    }

    // Initialize presets (charger depuis les settings ou utiliser les défauts)
    Component.onCompleted: {
        // Essayer de charger les presets sauvegardés
        if (!loadColorPresets()) {
            // Si pas de presets sauvegardés, utiliser les presets par défaut
            colorPresets = [
                { name: "Red", color: "#ff0000", active: false },
                { name: "Green", color: "#00ff00", active: false },
                { name: "Blue", color: "#0000ff", active: false },
                { name: "Yellow", color: "#ffff00", active: false },
                { name: "Magenta", color: "#ff00ff", active: false },
                { name: "Cyan", color: "#00ffff", active: false }
            ]
            // Sauvegarder les presets par défaut
            saveColorPresets()
        }
    }

    content : [
        
        // Brightness control
        VEP_Slider {
            id: brightnessSlider
            Layout.topMargin: 0
            Layout.fillWidth: true
            sliderText: "Brightness:"
            onEffectChanged: function(value) {
                control.effectChanged()
            }
        },

        // Contrast control
        VEP_Slider {
            id: contrastSlider
            Layout.topMargin: 1
            Layout.fillWidth: true
            sliderText: "Contrast:"
            onEffectChanged: function(value) {
                control.effectChanged()
            }
        },
        
        // Saturation control
        VEP_Slider {
            id: saturationSlider
            Layout.topMargin: 1
            Layout.fillWidth: true
            sliderText: "Saturation:"
            onEffectChanged: function(value) {
                control.effectChanged()
            }
        },
        
        // Colorization control
        VEP_Slider {
            id: colorizationSlider
            accentColor: (activePresetIndex == -1) ? "#569c58" : colorPresets[activePresetIndex].color
            from: 0
            to: 1
            Layout.topMargin: 1
            Layout.fillWidth: true
            sliderText: "Colorization:"
            onEffectChanged: function(value) {
                control.effectChanged()
            }
        },
        
        // Preset management section
        GroupBox {
            title: "Color Presets"
            Layout.fillWidth: true
            Layout.topMargin: 8
            
            background: Rectangle {
                color: "#2a2a2a"
                radius: 3
                border.color: "#444444"
                border.width: 1
                opacity: 0.1
            }
            
            label: Text {
                text: parent.title
                color: "#cccccc"
                font.pixelSize: 10
                font.bold: true
                x:4
            }
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 4
                
                // Preset controls
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    
                    Button {
                        text: "Add Preset"
                        onClicked: addNewPreset()
                        
                        background: Rectangle {
                            color: parent.enabled ? (parent.pressed ? "#666666" : "#555555") : "#444444"
                            radius: 3
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: parent.enabled ? "#cccccc" : "#888888"
                            font.pixelSize: 9
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                    
                    Button {
                        text: "Remove"
                        enabled: activePresetIndex >= 0
                        onClicked: removeActivePreset()
                        
                        background: Rectangle {
                            color: parent.enabled ? (parent.pressed ? "#cc4444" : "#aa4444") : "#444444"
                            radius: 3
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: parent.enabled ? "#ffffff" : "#888888"
                            font.pixelSize: 9
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Text {
                        text: colorPresets.length + " presets"
                        color: "#888888"
                        font.pixelSize: 9
                    }
                }
                
                // Preset grid
                GridLayout {
                    Layout.fillWidth: true
                    rowSpacing: 4
                    columnSpacing: 4
                    columns: (parent.width - parent.width/50) / 50
                    
                    Repeater {
                        model: colorPresets
                        
                        Rectangle {
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 40
                            color: modelData.color
                            border.color: modelData.active ? "#569c58" : "#666666"
                            border.width: modelData.active ? 2 : 1
                            radius: 4
                            
                            Text {
                                anchors.centerIn: parent
                                text: modelData.name
                                color: getContrastColor(modelData.color)
                                font.pixelSize: 8
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    selectPreset(index)
                                }
                                onDoubleClicked: {
                                    openPresetEditor(index)
                                }
                            }
                        }
                    }
                }
                
                // Active preset info
                RowLayout {
                    Layout.fillWidth: true
                    visible: activePresetIndex >= 0
                    
                    Text {
                        text: "Active:"
                        color: "#cccccc"
                        font.pixelSize: 9
                    }
                    
                    Rectangle {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 15
                        color: activePresetIndex >= 0 ? colorPresets[activePresetIndex].color : "#ffffff"
                        border.color: "#666666"
                        border.width: 1
                        radius: 2
                    }
                    
                    Text {
                        text: activePresetIndex >= 0 ? colorPresets[activePresetIndex].name : ""
                        color: "#cccccc"
                        font.pixelSize: 9
                        Layout.fillWidth: true
                    }
                    
                    Button {
                        id: applyButton
                        text: "Apply"
                        enabled: activePresetIndex >= 0
                        onClicked: applyActivePreset()
                        
                        background: Rectangle {
                            color: parent.enabled ? (parent.pressed ? "#569c58" : "#4a8a4a") : "#444444"
                            radius: 3
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: parent.enabled ? "#ffffff" : "#888888"
                            font.pixelSize: 9
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    ]

    
    // Functions pour la persistance des presets
    function saveColorPresets() {
        try {
            var presetsToSave = colorPresets.map(function(preset) {
                return {
                    name: preset.name,
                    color: preset.color.toString(),
                    active: preset.active
                }
            })
            
            colorPresetSettings.presetsData = JSON.stringify(presetsToSave)
            colorPresetSettings.activeIndex = activePresetIndex
            colorPresetSettings.sync() // Force la synchronisation
            
            console.log("Presets sauvegardés:", presetsToSave.length, "presets")
        } catch (error) {
            console.error("Erreur lors de la sauvegarde des presets:", error)
        }
    }
    
    function loadColorPresets() {
        try {
            if (colorPresetSettings.presetsData !== "") {
                var loadedPresets = JSON.parse(colorPresetSettings.presetsData)
                
                // Valider et nettoyer les données chargées
                var validPresets = []
                for (var i = 0; i < loadedPresets.length; i++) {
                    var preset = loadedPresets[i]
                    if (preset.name && preset.color) {
                        validPresets.push({
                            name: preset.name,
                            color: preset.color,
                            active: preset.active || false
                        })
                    }
                }
                
                if (validPresets.length > 0) {
                    colorPresets = validPresets
                    activePresetIndex = colorPresetSettings.activeIndex
                    
                    // S'assurer que l'index actif est valide
                    if (activePresetIndex >= 0 && activePresetIndex < colorPresets.length) {
                        colorPresets[activePresetIndex].active = true
                    } else {
                        activePresetIndex = -1
                    }

                    colorPresetsChanged()
                    return true
                }
            }
        } catch (error) {
            console.error("Erreur lors du chargement des presets:", error)
        }
        return false
    }
    
    // Functions
    function addNewPreset() {

        var newPreset = {
            name: "Preset " + (colorPresets.length + 1),
            color: "#ffffff",
            active: false
        }
        colorPresets.push(newPreset)
        colorPresetsChanged()
        saveColorPresets() // Sauvegarder après ajout

    }
    
    function removeActivePreset() {
        if (activePresetIndex >= 0 && activePresetIndex < colorPresets.length) {
            colorPresets.splice(activePresetIndex, 1)
            activePresetIndex = -1
            colorPresetsChanged()
            saveColorPresets() // Sauvegarder après suppression
        }
    }
    
    function selectPreset(index) {
        // Deselect previous
        if (activePresetIndex >= 0 && activePresetIndex < colorPresets.length) {
            colorPresets[activePresetIndex].active = false
        }
        
        // Select new
        if (index >= 0 && index < colorPresets.length) {
            if (index !== activePresetIndex)
            {
                activePresetIndex = index
                colorPresets[index].active = true
            }
            else
            {
                activePresetIndex = -1

            }
        } else {
            activePresetIndex = -1
        }
        
        colorPresetsChanged()
        saveColorPresets() // Sauvegarder après sélection
        applyActivePreset()
    }
    
    function applyActivePreset() {
        control.effectChanged()
    }
    
    function openPresetEditor(index) {
        if (index >= 0 && index < colorPresets.length) {
            presetEditorDialog.presetIndex = index
            presetEditorDialog.presetName = colorPresets[index].name
            presetEditorDialog.presetColor = colorPresets[index].color
            presetEditorDialog.open()
        }
    }
    
    function getContrastColor(backgroundColor) {
        // Simple contrast calculation
        var color = backgroundColor.toString()
        var r = parseInt(color.substr(1,2), 16)
        var g = parseInt(color.substr(3,2), 16)
        var b = parseInt(color.substr(5,2), 16)
        var brightness = (r * 299 + g * 587 + b * 114) / 1000
        return brightness > 128 ? "#000000" : "#ffffff"
    }
    
    // Preset Editor Dialog
    Dialog {
        id: presetEditorDialog
        title: "Edit Preset"
        modal: false

        
        property int presetIndex: -1
        property string presetName: ""
        property color presetColor: "#ffffff"
        
        width: 300
        height: 350
        y: -200
        
        background: Rectangle {
            color: "#333333"
            radius: 6
            border.color: "#555555"
            border.width: 1
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            
            Text {
                text: "Preset Name:"
                color: "#cccccc"
                font.pixelSize: 11
            }
            
            TextField {
                id: presetNameField
                text: presetEditorDialog.presetName
                Layout.fillWidth: true
                
                background: Rectangle {
                    color: "#444444"
                    radius: 3
                    border.color: "#666666"
                    border.width: 1
                }
                
                color: "#cccccc"
                font.pixelSize: 11
            }
            
            Text {
                text: "Preset Color:"
                color: "#cccccc"
                font.pixelSize: 11
            }
            
            RowLayout {
                Layout.fillWidth: true
                
                Rectangle {
                    id: presetColorField
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 30
                    color: presetEditorDialog.presetColor
                    border.color: "#666666"
                    border.width: 1
                    radius: 3
                }
                
                ColorDialog {
                    id: presetColorDialog
                    selectedColor: presetEditorDialog.presetColor
                    onAccepted: {
                        presetEditorDialog.presetColor = selectedColor
                        presetColorField.color = selectedColor
                        console.log("new color selected")
                    }
                }
                
                Button {
                    text: "Choose Color"
                    onClicked: presetColorDialog.open()
                    
                    background: Rectangle {
                        color: parent.pressed ? "#666666" : "#555555"
                        radius: 3
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "#cccccc"
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
            
            Item { Layout.fillHeight: true }
            
            RowLayout {
                Layout.fillWidth: true
                
                Item { Layout.fillWidth: true }
                
                Button {
                    text: "Cancel"
                    onClicked: presetEditorDialog.close()
                    
                    background: Rectangle {
                        color: parent.pressed ? "#666666" : "#555555"
                        radius: 3
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "#cccccc"
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
                
                Button {
                    text: "Save"
                    onClicked: {
                        if (presetEditorDialog.presetIndex >= 0 && presetEditorDialog.presetIndex < colorPresets.length) {
                            colorPresets[presetEditorDialog.presetIndex].name = presetNameField.text
                            colorPresets[presetEditorDialog.presetIndex].color = presetEditorDialog.presetColor
                            colorPresetsChanged()
                            saveColorPresets() // Sauvegarder après modification
                            applyActivePreset()
                        }
                        presetEditorDialog.close()
                    }
                    
                    background: Rectangle {
                        color: parent.pressed ? "#569c58" : "#4a8a4a"
                        radius: 3
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "#ffffff"
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
