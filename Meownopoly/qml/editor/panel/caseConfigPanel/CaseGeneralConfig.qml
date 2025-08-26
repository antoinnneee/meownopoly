import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseRestArea
import Player

ConfigPanelElement {
    title: "Configuration Générale"
    property alias name: nameField.text

    // Fonction pour mettre à jour tous les contrôles
    function updateControls() {
        if (!targetCase) return
        updatingValues = true
        nameField.text = targetCase.name || ""
        updatingValues = false
    }

    // Mise à jour quand targetCase change
    Connections {
        target: targetCase
        ignoreUnknownSignals: true
        function onNameChanged() {
            updateControls()
        }
        function onPositionChanged() {
            updateControls()
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

    }
}
