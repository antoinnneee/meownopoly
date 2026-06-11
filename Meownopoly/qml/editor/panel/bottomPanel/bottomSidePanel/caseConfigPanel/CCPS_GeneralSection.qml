import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import MapTypes
import ui_item
import theme


CollapsableGroupBox  {
    id: control
    title: "Configuration Générale"
    
    // Properties
    property var targetCase: null
    property bool updatingValues: false
    property var logic: null  // Référence au logic pour sauvegarder
    
    // Signals
    signal configurationChanged()
    
    onConfigurationChanged: {
        if (logic) {
            logic.saveMap(MapTypes.UNDOREDO)
        }
    }
    // Mise à jour quand targetCase change
    Connections {
        target: targetCase
        ignoreUnknownSignals: true
        function onNameChanged() {
            updateControls()
        }
    }
    
    content : GridLayout {
        Layout.fillHeight: true
        Layout.fillWidth: true
        columns: 2
        rowSpacing: Theme.spacingM
        columnSpacing: Theme.spacingL
        
        Text {
            text: "Nom:"
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
        }
        
        TextField {
            id: nameField
            Layout.fillWidth: true
            placeholderText: "Nom de la case"
            
            background: Rectangle {
                color: Theme.surface
                radius: Theme.radiusXS
                border.color: nameField.activeFocus ? Theme.accentAlt : Theme.borderLight
                border.width: 1

                Behavior on border.color { ColorAnimation { duration: Theme.durationNormal } }
            }

            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeSmall
            padding: Theme.spacingS
            
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

