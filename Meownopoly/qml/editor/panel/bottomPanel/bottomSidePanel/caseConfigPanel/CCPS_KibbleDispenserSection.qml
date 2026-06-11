import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Case
import MapTypes
import ui_item
import theme

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
            font.pixelSize: Theme.fontSizeCaption
            color: Theme.textMuted
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        },
        
        // Configuration de la récompense
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingM
            
            Text {
                text: "Récompense (kibbles):"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeSmall
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
                    color: Theme.surface
                    border.color: Theme.borderLight
                    border.width: 1
                    radius: Theme.radiusXS
                }
                
                contentItem: TextInput {
                    text: rewardSpinBox.textFromValue(rewardSpinBox.value, rewardSpinBox.locale)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textPrimary
                    horizontalAlignment: Qt.AlignHCenter
                    verticalAlignment: Qt.AlignVCenter
                    readOnly: !rewardSpinBox.editable
                    validator: rewardSpinBox.validator
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                }
            }
            
            Text {
                text: "kibbles"
                font.pixelSize: Theme.fontSizeCaption
                color: Theme.textMuted
            }
        }

    ]
    
    // Functions
    function updateControls() {
        if (!targetCase) return
        rewardSpinBox.value = targetCase.reward || 200
    }
}

