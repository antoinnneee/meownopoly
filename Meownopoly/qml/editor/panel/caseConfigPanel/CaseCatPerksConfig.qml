import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseRestArea
import Player

ConfigPanelElement {
    title: "Prix et Finances"
    property alias buyPrice: priceSpinBox.value
    property alias sellPrice: sellPriceSpinBox.value
    property alias morgagePrice: morgagePriceSpinBox.value

    visible: targetCase && (targetCase.type === Case.CS_RestArea || 
                            targetCase.type === Case.CS_CatDoor || 
                            targetCase.type === Case.CS_Device)

    // Fonction pour mettre à jour tous les contrôles
    function updateControls() {
        if (!targetCase) return
        updatingValues = true
        priceSpinBox.value = targetCase.price || 0
        sellPriceSpinBox.value = targetCase.sellPrice || 0
        morgagePriceSpinBox.value = targetCase.morgagePrice || 0
        updatingValues = false
    }

    // Mise à jour quand targetCase change
    Connections {
        target: targetCase
        ignoreUnknownSignals: true
        function onPriceChanged() {
            updateControls()
        }
        function onSellPriceChanged() {
            updateControls()
        }
        function onMorgagePriceChanged() {
            updateControls()
        }
    }
    
    ColumnLayout {
        width: parent.width
        spacing: 10
        
        // Note explicative
        Text {
            text: "💡 Configuration des prix pour les propriétés achetables"
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
            
            // Prix d'achat
            Label {
                text: "💰 Prix d'achat:"
                font.bold: true
                Layout.preferredWidth: 120
            }
            
            SpinBox {
                id: priceSpinBox
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
                        value = targetCase.price
                    }
                }
                
                onValueChanged: {
                    if (!updatingValues && targetCase) {
                        targetCase.price = value
                    }
                }

            }
            
            // Prix de vente
            Label {
                text: "💸 Prix de vente:"
                font.bold: true
                Layout.preferredWidth: 120
            }
            
            SpinBox {
                id: sellPriceSpinBox
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
                        value = targetCase.sellPrice
                    }
                }
                
                onValueChanged: {
                    if (!updatingValues && targetCase) {
                        targetCase.sellPrice = value
                    }
                }

            }
            
            // Prix d'hypothèque
            Label {
                text: "🏦 Prix hypothèque:"
                font.bold: true
                Layout.preferredWidth: 120
            }
            
            SpinBox {
                id: morgagePriceSpinBox
                Layout.fillWidth: true
                from: 0
                to: 9999
                stepSize: 5
                
                textFromValue: function(value, locale) {
                    return value + "K"
                }
                
                valueFromText: function(text, locale) {
                    return parseInt(text.replace("K", ""))
                }
                
                Component.onCompleted: {
                    if (targetCase) {
                        value = targetCase.morgagePrice
                    }
                }
                
                onValueChanged: {
                    if (!updatingValues && targetCase) {
                        targetCase.morgagePrice = value
                    }
                }

            }
        } // Fin GridLayout
        
        
    } // Fin ColumnLayout
}
