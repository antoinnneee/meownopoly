import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseRestArea
import Player
import MeowStyle
import "panel"

Rectangle {
    id: root
    
    // Propriétés
    property var targetCase: null
    property bool isVisible: false
    
    // Propriétés internes pour éviter les binding loops
    property bool updatingValues: false
    
    // Signaux
    signal configurationClosed()
    signal configurationApplied(var caseData)
    
    visible: isVisible
    color: "#f8f9fa"
    border.color: "#dee2e6"
    border.width: 2
    radius: 8
    
    width: 600
    height: 700

    z: 1000  // Au-dessus de tout
    
    ScrollView {
        anchors.fill: parent
        anchors.margins: 15
        contentWidth: availableWidth
        clip: true
        
        ColumnLayout {
            width: parent.width
            spacing: 15
            
            // En-tête
            CaseConfigurationHeader {
                Layout.fillWidth: true
                onCloseClicked: {
                    root.isVisible = false
                    configurationClosed()
                }
            }
            
            // Type de case (lecture seule pour l'instant)
            GroupBox {
                title: "Type de Case"
                Layout.fillWidth: true
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 5
                    
                    Text {
                        text: targetCase ? getCaseTypeName(targetCase.type) : "Aucune case sélectionnée"
                        font.pixelSize: 14
                        color: "#495057"
                    }
                }
            }
            
            // Configuration générale
            CaseGeneralConfig {
                id: caseGeneralConfig
                targetCase: root.targetCase
                Layout.fillWidth: true
            }
            
            // Configuration spécifique RestArea
            CaseRestAreaSpecificConfig {
                id: caseRestAreaSpecificConfig
                targetCase: root.targetCase
                Layout.fillWidth: true
            }
            
            // Boutons d'action
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 10
                
                Item { Layout.fillWidth: true } // Spacer
                
                Button {
                    text: "Annuler"
                    background: Rectangle {
                        color: "#6c757d"
                        radius: 4
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        root.isVisible = false
                        configurationClosed()
                    }
                }
                
                Button {
                    text: "Appliquer"
                    background: Rectangle {
                        color: "#28a745"
                        radius: 4
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        configurationApplied(targetCase)
                        root.isVisible = false
                        configurationClosed()
                    }
                }
            }
        }
    }
    
    // Fonctions utilitaires
    function getCaseTypeName(type) {
        // Utilise la méthode helper du singleton MeowStyle
        return MeowStyle.getCaseTypeName(type)
    }
    
    function findFamilyIndex(familyValue) {
        const families = [
            CaseRestArea.FT_NONE, CaseRestArea.FT_BROWN, CaseRestArea.FT_LIGHTBLUE,
            CaseRestArea.FT_PINK, CaseRestArea.FT_ORANGE, CaseRestArea.FT_RED,
            CaseRestArea.FT_YELLOW, CaseRestArea.FT_GREEN, CaseRestArea.FT_DARKBLUE
        ]
        return families.indexOf(familyValue)
    }
    
    // Fonction pour ouvrir le panneau avec une case
    function openConfiguration(caseData) {
        targetCase = caseData
        isVisible = true
        updateControls()
    }
    
    // Fonction pour mettre à jour tous les contrôles
    function updateControls() {
        if (!targetCase) return
        
        updatingValues = true
        
        // Mise à jour des contrôles généraux
        caseGeneralConfig.updateControls()

        
        // Mise à jour des contrôles RestArea
        if (targetCase.type === Case.CS_RestArea) {
            caseRestAreaSpecificConfig.updateControls()
        }
        
        updatingValues = false
    }
}
