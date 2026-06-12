import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseRestArea
import Player
import theme
import ui_item

CCP_PanelElement {
    title: "Prix d'Achat des Améliorations"
    
    visible: targetCase && targetCase.type === Case.CS_RestArea

    // Fonction pour mettre à jour tous les contrôles
    function updateControls() {
        if (!targetCase) return
        updatingValues = true
        housePriceSpinBox.value = targetCase.housePrice || 0
        hotelPriceSpinBox.value = targetCase.hotelPrice || 0
        updatingValues = false
    }

    // Mise à jour quand targetCase change
    Connections {
        target: targetCase
        ignoreUnknownSignals: true
        function onHousePriceChanged() {
            updateControls()
        }
        function onHotelPriceChanged() {
            updateControls()
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingL
        
        // Note explicative
        Text {
            text: "🏗️ Définissez les prix d'achat pour construire des améliorations sur cette propriété"
            font.italic: true
            font.pixelSize: Theme.fontSizeBody
            color: Theme.textMuted
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            Layout.bottomMargin: Theme.spacingXS
        }
        
        // Les deux prix côte à côte
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingL
            
            // Prix d'achat d'une étoile
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingXS
                
                Label {
                    text: "⭐ Prix d'une étoile:"
                    font.bold: true
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeBody
                }
                
                MeowSpinBox {
                    id: housePriceSpinBox
                    Layout.fillWidth: true
                    from: 0
                    to: 9999
                    stepSize: 10
                    suffix: "K"
                    
                    Component.onCompleted: {
                        if (targetCase) {
                            value = targetCase.housePrice || 0
                        }
                    }
                    
                    onValueChanged: {
                        if (!updatingValues && targetCase) {
                            targetCase.housePrice = value
                        }
                    }
                }
            }
            
            // Prix d'achat d'un hôtel
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingXS
                
                Label {
                    text: "🏨 Prix d'un hôtel:"
                    font.bold: true
                    color: Theme.dangerSoft
                    font.pixelSize: Theme.fontSizeBody
                }
                
                MeowSpinBox {
                    id: hotelPriceSpinBox
                    Layout.fillWidth: true
                    from: 0
                    to: 9999
                    stepSize: 25
                    suffix: "K"
                    
                    Component.onCompleted: {
                        if (targetCase) {
                            value = targetCase.hotelPrice || 0
                        }
                    }
                    
                    onValueChanged: {
                        if (!updatingValues && targetCase) {
                            targetCase.hotelPrice = value
                        }
                    }
                }
            }
        }
        
        // Information supplémentaire
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: infoText.implicitHeight + 16
            color: "#2a3a4a"
            radius: Theme.radiusM
            border.color: "#4a6a8a"
            border.width: 1
            
            Text {
                id: infoText
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                text: "💡 Les étoiles se construisent une par une (1⭐ → 2⭐ → 3⭐ → 4⭐). L'hôtel remplace les 4 étoiles."
                font.pixelSize: Theme.fontSizeSmall
                color: "#99ccff"
                wrapMode: Text.WordWrap
                verticalAlignment: Text.AlignVCenter
            }
        }
        
    } // Fin ColumnLayout
}
