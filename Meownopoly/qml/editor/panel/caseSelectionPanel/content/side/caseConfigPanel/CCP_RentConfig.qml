import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseRestArea
import Player

CCP_PanelElement {
    title: "Prix de Location"
    
    visible: targetCase && targetCase.type === Case.CS_RestArea

    // Fonction pour mettre à jour tous les contrôles
    function updateControls() {
        if (!targetCase || !targetCase.rentPrice) return
        updatingValues = true
        
        // Mettre à jour chaque SpinBox individuellement
        if (terrainNuSpinBox && targetCase.rentPrice.length > 0) {
            terrainNuSpinBox.value = targetCase.rentPrice[0]
        }
        if (star1SpinBox && targetCase.rentPrice.length > 1) {
            star1SpinBox.value = targetCase.rentPrice[1]
        }
        if (star2SpinBox && targetCase.rentPrice.length > 2) {
            star2SpinBox.value = targetCase.rentPrice[2]
        }
        if (star3SpinBox && targetCase.rentPrice.length > 3) {
            star3SpinBox.value = targetCase.rentPrice[3]
        }
        if (hotelSpinBox && targetCase.rentPrice.length > 4) {
            hotelSpinBox.value = targetCase.rentPrice[4]
        }
        
        updatingValues = false
    }

    ColumnLayout{
        anchors.fill: parent
        spacing: 8
        // Note explicative
        Text {
            text: "💡 Définissez les prix de location selon le niveau d'amélioration de la propriété"
            font.italic: true
            font.pixelSize: 12
            color: "#888888"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            Layout.bottomMargin: 5
        }

        // Prix de location organisés en 2 colonnes
        RowLayout {
            Layout.fillWidth: true
            spacing: 15
            
            // Colonne gauche (Terrain nu, 2 étoiles)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10
                
                // Terrain nu
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    
                    Label {
                        text: "🏞️ Terrain nu"
                        font.bold: true
                        color: "#cccccc"
                        font.pixelSize: 11
                    }
                    
                    CCP_StyledSpinBox {
                        id: terrainNuSpinBox
                        Layout.fillWidth: true
                        from: 0
                        to: 10000
                        stepSize: 5
                        suffix: "K"
                        
                        property int rentIndex: 0
                        
                        Component.onCompleted: {
                            if (targetCase && targetCase.rentPrice && targetCase.rentPrice.length > rentIndex) {
                                value = targetCase.rentPrice[rentIndex]
                            }
                        }
                        
                        onValueChanged: {
                            if (!updatingValues && targetCase && targetCase.rentPrice && targetCase.rentPrice.length > rentIndex) {
                                targetCase.rentPrice[rentIndex] = value
                            }
                        }
                    }
                }
                
                // 2 étoiles
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    
                    Label {
                        text: "⭐⭐ 2 étoiles"
                        font.bold: true
                        color: "#cccccc"
                        font.pixelSize: 11
                    }
                    
                    CCP_StyledSpinBox {
                        id: star2SpinBox
                        Layout.fillWidth: true
                        from: 0
                        to: 10000
                        stepSize: 5
                        suffix: "K"
                        
                        property int rentIndex: 2
                        
                        Component.onCompleted: {
                            if (targetCase && targetCase.rentPrice && targetCase.rentPrice.length > rentIndex) {
                                value = targetCase.rentPrice[rentIndex]
                            }
                        }
                        
                        onValueChanged: {
                            if (!updatingValues && targetCase && targetCase.rentPrice && targetCase.rentPrice.length > rentIndex) {
                                targetCase.rentPrice[rentIndex] = value
                            }
                        }
                    }
                }
            }
            
            // Colonne droite (1 étoile, 3 étoiles)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10
                
                // 1 étoile
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    
                    Label {
                        text: "⭐ 1 étoile"
                        font.bold: true
                        color: "#cccccc"
                        font.pixelSize: 11
                    }
                    
                    CCP_StyledSpinBox {
                        id: star1SpinBox
                        Layout.fillWidth: true
                        from: 0
                        to: 10000
                        stepSize: 5
                        suffix: "K"
                        
                        property int rentIndex: 1
                        
                        Component.onCompleted: {
                            if (targetCase && targetCase.rentPrice && targetCase.rentPrice.length > rentIndex) {
                                value = targetCase.rentPrice[rentIndex]
                            }
                        }
                        
                        onValueChanged: {
                            if (!updatingValues && targetCase && targetCase.rentPrice && targetCase.rentPrice.length > rentIndex) {
                                targetCase.rentPrice[rentIndex] = value
                            }
                        }
                    }
                }
                
                // 3 étoiles
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    
                    Label {
                        text: "⭐⭐⭐ 3 étoiles"
                        font.bold: true
                        color: "#cccccc"
                        font.pixelSize: 11
                    }
                    
                    CCP_StyledSpinBox {
                        id: star3SpinBox
                        Layout.fillWidth: true
                        from: 0
                        to: 10000
                        stepSize: 5
                        suffix: "K"
                        
                        property int rentIndex: 3
                        
                        Component.onCompleted: {
                            if (targetCase && targetCase.rentPrice && targetCase.rentPrice.length > rentIndex) {
                                value = targetCase.rentPrice[rentIndex]
                            }
                        }
                        
                        onValueChanged: {
                            if (!updatingValues && targetCase && targetCase.rentPrice && targetCase.rentPrice.length > rentIndex) {
                                targetCase.rentPrice[rentIndex] = value
                            }
                        }
                    }
                }
            }
        }
        
        // Séparateur visuel
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#555555"
            Layout.topMargin: 5
            Layout.bottomMargin: 5
        }
        
        // Hôtel (séparé en dessous)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 8
            
            Label {
                text: "🏨 Hôtel"
                font.bold: true
                color: "#ff6b6b"
                font.pixelSize: 14
                Layout.alignment: Qt.AlignHCenter
            }
            
            CCP_StyledSpinBox {
                id: hotelSpinBox
                Layout.preferredWidth: 200
                Layout.alignment: Qt.AlignHCenter
                from: 0
                to: 10000
                stepSize: 10
                suffix: "K"
                
                Component.onCompleted: {
                    if (targetCase && targetCase.rentPrice && targetCase.rentPrice.length > 4) {
                        value = targetCase.rentPrice[4]
                    }
                }
                
                onValueChanged: {
                    if (!updatingValues && targetCase && targetCase.rentPrice && targetCase.rentPrice.length > 4) {
                        targetCase.rentPrice[4] = value
                    }
                }
            }
        }
    }
}
