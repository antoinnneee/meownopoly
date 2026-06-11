import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseRestArea
import Player
import theme

CCP_PanelElement {
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
        spacing: Theme.spacingL
        
        // Les trois prix côte à côte
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingXS
            
            // Prix d'achat
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingXS
                
                Label {
                    text: "💰 Prix d'achat:"
                    font.bold: true
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                }
                
                CCP_StyledSpinBox {
                    id: priceSpinBox
                    Layout.fillWidth: true
                    from: 0
                    to: 9999
                    stepSize: 10
                    suffix: "K"
                    
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
            }
            
            // Prix de vente
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingXS
                
                Label {
                    text: "💸 Prix de vente:"
                    font.bold: true
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                }
                
                CCP_StyledSpinBox {
                    id: sellPriceSpinBox
                    Layout.fillWidth: true
                    from: 0
                    to: 9999
                    stepSize: 10
                    suffix: "K"
                    
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
            }
            
            // Prix d'hypothèque
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingXS
                
                Label {
                    text: "🏦 Prix hypothèque:"
                    font.bold: true
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                }
                
                CCP_StyledSpinBox {
                    id: morgagePriceSpinBox
                    Layout.fillWidth: true
                    from: 0
                    to: 9999
                    stepSize: 5
                    suffix: "K"
                    
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
            }
        }
        
        
    } // Fin ColumnLayout
}
