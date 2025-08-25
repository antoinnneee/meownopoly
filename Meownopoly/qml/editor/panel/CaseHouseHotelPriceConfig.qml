import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseRestArea
import Player

ConfigPanelElement {
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
        spacing: 10
        
        // Note explicative
        Text {
            text: "🏗️ Définissez les prix d'achat pour construire des améliorations sur cette propriété"
            font.italic: true
            font.pixelSize: 12
            color: "#6c757d"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            Layout.bottomMargin: 5
        }
        
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 10
            columnSpacing: 10
            
            // Prix d'achat d'une maison (étoile)
            Label {
                text: "⭐ Prix d'une étoile:"
                font.bold: true
                Layout.preferredWidth: 140
                color: "#495057"
            }
            
            SpinBox {
                id: housePriceSpinBox
                Layout.fillWidth: true
                from: 0
                to: 9999
                stepSize: 10
                
                textFromValue: function(value, locale) {
                    return value + "K"
                }
                
                valueFromText: function(text, locale) {
                    return parseInt(text.replace("K", ""))
                }
                
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
            
            // Prix d'achat d'un hôtel
            Label {
                text: "🏨 Prix d'un hôtel:"
                font.bold: true
                Layout.preferredWidth: 140
                color: "#dc3545"
            }
            
            SpinBox {
                id: hotelPriceSpinBox
                Layout.fillWidth: true
                from: 0
                to: 9999
                stepSize: 25
                
                textFromValue: function(value, locale) {
                    return value + "K"
                }
                
                valueFromText: function(text, locale) {
                    return parseInt(text.replace("K", ""))
                }
                
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
        } // Fin GridLayout
        
        // Information supplémentaire
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: infoText.implicitHeight + 16
            color: "#e3f2fd"
            radius: 6
            border.color: "#2196f3"
            border.width: 1
            
            Text {
                id: infoText
                anchors.fill: parent
                anchors.margins: 8
                text: "💡 Les étoiles se construisent une par une (1⭐ → 2⭐ → 3⭐ → 4⭐). L'hôtel remplace les 4 étoiles."
                font.pixelSize: 11
                color: "#1976d2"
                wrapMode: Text.WordWrap
                verticalAlignment: Text.AlignVCenter
            }
        }
        
    } // Fin ColumnLayout
}
