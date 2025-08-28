import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Case

CCP_PanelElement {
    title: "Configuration Kibble Dispenser"
    visible: targetCase && targetCase.type === Case.CS_KibbleDispenser

    // Fonction pour mettre à jour tous les contrôles
    function updateControls() {
        if (!targetCase) return
        
        // Éviter les binding loops
        updatingValues = true
        
        // Mettre à jour la valeur de récompense
        rewardSpinBox.value = targetCase.reward || 200
        
        updatingValues = false
    }

    Connections {
        target: targetCase
        ignoreUnknownSignals: true
        function onRewardChanged() {
            if (!updatingValues) {
                updatingValues = true
                rewardSpinBox.value = targetCase.reward
                updatingValues = false
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        
        // Note explicative
        Text {
            text: "🥫 Configuration du distributeur de croquettes - récompense donnée au joueur"
            font.italic: true
            font.pixelSize: 12
            color: "#6c757d"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            Layout.bottomMargin: 5
        }

        // Configuration de la récompense
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            
            Label {
                text: "Récompense (kibbles):"
                font.pixelSize: 14
                Layout.minimumWidth: 150
            }
            
            SpinBox {
                id: rewardSpinBox
                from: 0
                to: 10000
                stepSize: 50
                value: 200
                
                Layout.preferredWidth: 120
                
                onValueChanged: {
                    if (!updatingValues && targetCase) {
                        targetCase.reward = value
                    }
                }
                
                // Style personnalisé
                background: Rectangle {
                    color: "#ffffff"
                    border.color: "#ced4da"
                    border.width: 1
                    radius: 4
                }
                
                contentItem: TextInput {
                    text: rewardSpinBox.textFromValue(rewardSpinBox.value, rewardSpinBox.locale)
                    font.pixelSize: 14
                    color: "#495057"
                    horizontalAlignment: Qt.AlignHCenter
                    verticalAlignment: Qt.AlignVCenter
                    readOnly: !rewardSpinBox.editable
                    validator: rewardSpinBox.validator
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                }
            }
            
            Text {
                text: "kibbles"
                font.pixelSize: 12
                color: "#6c757d"
            }
            
            Item { Layout.fillWidth: true } // Spacer
        }
        
        // Informations supplémentaires
        Rectangle {
            Layout.fillWidth: true
            height: 60
            color: "#e9ecef"
            radius: 4
            border.color: "#dee2e6"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 5
                
                Text {
                    text: "ℹ️ Information"
                    font.bold: true
                    font.pixelSize: 12
                    color: "#495057"
                }
                
                Text {
                    text: "Quand un joueur atterrit sur cette case, il reçoit le nombre de kibbles spécifié."
                    font.pixelSize: 11
                    color: "#6c757d"
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }
        
        Item { Layout.fillHeight: true } // Spacer vertical
    }
}
