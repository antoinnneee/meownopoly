import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

GroupBox {
    id: control
    title: "Configuration Générale"
    
    // Properties
    property var targetCase: null
    property bool updatingValues: false
    
    // Signals
    signal configurationChanged()
    
    // Visual styling
    background: Rectangle {
        color: "#333333"
        radius: 4
        border.color: "#555555"
        border.width: 1
    }
    
    label: Text {
        x: control.leftPadding
        width: control.availableWidth
        text: control.title
        color: "#cccccc"
        elide: Text.ElideRight
    }
    
    // Mise à jour quand targetCase change
    Connections {
        target: targetCase
        ignoreUnknownSignals: true
        function onNameChanged() {
            updateControls()
        }
    }
    
    GridLayout {
        anchors.fill: parent
        columns: 2
        rowSpacing: 8
        columnSpacing: 10
        
        Text {
            text: "Nom:"
            color: "#cccccc"
            font.pixelSize: 11
            font.bold: true
        }
        
        TextField {
            id: nameField
            Layout.fillWidth: true
            placeholderText: "Nom de la case"
            
            background: Rectangle {
                color: "#2a2a2a"
                radius: 3
                border.color: nameField.activeFocus ? "#569c58" : "#555555"
                border.width: 1
                
                Behavior on border.color { ColorAnimation { duration: 150 } }
            }
            
            color: "#ffffff"
            font.pixelSize: 11
            padding: 6
            
            Component.onCompleted: {
                if (targetCase) {
                    text = targetCase.name
                }
            }
            
            onEditingFinished: {
                if (!updatingValues && targetCase) {
                    targetCase.name = text
                    configurationChanged()
                }
            }
        }
    }
    
    // Functions
    function updateControls() {
        if (!targetCase) return
        nameField.text = targetCase.name || ""
    }
}

