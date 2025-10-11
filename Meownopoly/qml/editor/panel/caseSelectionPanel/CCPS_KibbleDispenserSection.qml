import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Case

GroupBox {
    id: control
    title: "Configuration Kibble Dispenser"
    
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
        function onRewardChanged() {
            if (!updatingValues) {
                updateControls()
            }
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 8
        
        // Note explicative
        Text {
            text: "🥫 Configuration du distributeur de croquettes - récompense donnée au joueur"
            font.italic: true
            font.pixelSize: 10
            color: "#888888"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
        
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
            
            Item { Layout.fillWidth: true }
        }
        
        // Informations supplémentaires
        Rectangle {
            Layout.fillWidth: true
            height: 55
            color: "#2a2a2a"
            radius: 3
            border.color: "#444444"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4
                
                Text {
                    text: "ℹ️ Information"
                    font.bold: true
                    font.pixelSize: 10
                    color: "#cccccc"
                }
                
                Text {
                    text: "Quand un joueur atterrit sur cette case, il reçoit le nombre de kibbles spécifié."
                    font.pixelSize: 9
                    color: "#888888"
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
    
    // Functions
    function updateControls() {
        if (!targetCase) return
        rewardSpinBox.value = targetCase.reward || 200
    }
}

