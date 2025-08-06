import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseRestArea
import Player

ConfigPanelElement {
    title: "Configuration Générale"
    property alias name: nameField.text
    property alias position: positionSpinBox.value

    // Fonction pour mettre à jour tous les contrôles
    function updateControls() {
        if (!targetCase) return
        updatingValues = true
        nameField.text = targetCase.name || ""
        positionSpinBox.value = targetCase.position || 0
        updatingValues = false
    }

    // Mise à jour quand targetCase change
    Connections {
        target: targetCase
        function onNameChanged() {
            if (!updatingValues) {
                updatingValues = true
                nameField.text = targetCase.name
                updatingValues = false
            }
        }
        function onPositionChanged() {
            if (!updatingValues) {
                updatingValues = true
                positionSpinBox.value = targetCase.position
                updatingValues = false
            }
        }
    }

    GridLayout {
        anchors.fill: parent
        columns: 2
        rowSpacing: 10
        columnSpacing: 10
        
        Label {
            text: "Nom:"
            font.bold: true
        }
        
        TextField {
            id: nameField
            Layout.fillWidth: true
            placeholderText: "Nom de la case"
            
            Component.onCompleted: {
                if (targetCase) {
                    text = targetCase.name
                }
            }
            
            onEditingFinished: {
                if (!updatingValues && targetCase) {
                    targetCase.name = text
                }
            }
        }
        
        Label {
            text: "Position:"
            font.bold: true
        }
        
        SpinBox {
            id: positionSpinBox
            Layout.fillWidth: true
            from: 0
            to: 39
            
            Component.onCompleted: {
                if (targetCase) {
                    value = targetCase.position
                }
            }
            
            onValueChanged: {
                if (!updatingValues && targetCase) {
                    targetCase.position = value
                }
            }
        }
    }
}