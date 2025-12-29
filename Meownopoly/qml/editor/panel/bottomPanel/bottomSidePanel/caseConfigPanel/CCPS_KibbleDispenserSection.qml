import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Case
import MapTypes
import ui_item

CollapsableGroupBox {
    id: control
    title: "Configuration Kibble Dispenser"
    
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
        function onRewardChanged() {
            if (!updatingValues) {
                updateControls()
            }
        }
    }
    
    content: [
        // Note explicative
        Text {
            text: "🥫 Configuration du distributeur de croquettes - récompense donnée au joueur"
            font.italic: true
            font.pixelSize: 10
            color: "#888888"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        },
        
        // Configuration de la récompense
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            
            Text {
                text: "Récompense (kibbles):"
                color: "#cccccc"
                font.pixelSize: 11
                Layout.minimumWidth: 140
            }
            
            SpinBox {
                id: rewardSpinBox
                from: 0
                to: 10000
                stepSize: 50
                value: 200
                
                Layout.preferredWidth: 110
                
                onValueChanged: {
                    if (!updatingValues && targetCase) {
                        targetCase.reward = value
                        configurationChanged()
                    }
                }
                
                background: Rectangle {
                    color: "#2a2a2a"
                    border.color: "#555555"
                    border.width: 1
                    radius: 3
                }
                
                contentItem: TextInput {
                    text: rewardSpinBox.textFromValue(rewardSpinBox.value, rewardSpinBox.locale)
                    font.pixelSize: 11
                    color: "#ffffff"
                    horizontalAlignment: Qt.AlignHCenter
                    verticalAlignment: Qt.AlignVCenter
                    readOnly: !rewardSpinBox.editable
                    validator: rewardSpinBox.validator
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                }
            }
            
            Text {
                text: "kibbles"
                font.pixelSize: 10
                color: "#888888"
            }
        }

    ]
    
    // Functions
    function updateControls() {
        if (!targetCase) return
        rewardSpinBox.value = targetCase.reward || 200
    }
}

