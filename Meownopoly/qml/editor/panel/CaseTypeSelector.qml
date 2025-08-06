import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Case
import MeowStyle

Rectangle {
    id: root
    
    // Propriétés
    property int currentType: Case.CS_Unknow
    property bool updatingValues: false
    
    // Signaux
    signal typeChanged(int newType)
    
    // Style
    height: 50
    color: "#ffffff"
    border.color: "#ced4da"
    border.width: 2
    radius: 8
    
    // Types de cases disponibles (excluant CS_Unknow et CS_Count)
    property var availableTypes: [
        Case.CS_KibbleDispenser,
        Case.CS_RestArea,
        Case.CS_CardBoardBox,
        Case.CS_CatNip,
        Case.CS_Jail,
        Case.CS_ToJail,
        Case.CS_CatDoor,
        Case.CS_FreeNap,
        Case.CS_Device,
        Case.CS_Taxe
    ]
    
    // Index actuel dans la liste des types
    property int currentIndex: {
        let index = availableTypes.indexOf(currentType)
        return index >= 0 ? index : 0
    }
    
    RowLayout {
        anchors.fill: parent
        anchors.margins: 5
        spacing: 0
        
        // Bouton flèche gauche
        Button {
            id: leftArrow
            Layout.preferredWidth: 40
            Layout.fillHeight: true
            
            background: Rectangle {
                color: parent.hovered ? "#e9ecef" : "transparent"
                radius: 4
                border.color: parent.hovered ? "#adb5bd" : "transparent"
                border.width: 1
                
                // Animation de couleur
                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
                Behavior on border.color {
                    ColorAnimation { duration: 150 }
                }
            }
            
            contentItem: Text {
                text: "◀"
                font.pixelSize: 16
                font.bold: true
                color: leftArrow.enabled ? "#495057" : "#adb5bd"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                
                // Animation de couleur
                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }
            
            enabled: currentIndex > 0
            
            onClicked: {
                if (currentIndex > 0) {
                    let newIndex = currentIndex - 1
                    let newType = availableTypes[newIndex]
                    if (!updatingValues) {
                        root.currentType = newType
                        typeChanged(newType)
                    }
                }
            }
            
            // Effet de survol
            hoverEnabled: true
            
            ToolTip.visible: hovered
            ToolTip.text: "Type précédent"
            ToolTip.delay: 500
        }
        
        // Zone centrale avec le nom du type
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            
            Text {
                anchors.centerIn: parent
                text: MeowStyle.getCaseTypeName(currentType)
                font.pixelSize: 14
                font.bold: true
                color: "#212529"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                
                // Animation de transition du texte
                Behavior on text {
                    SequentialAnimation {
                        PropertyAnimation {
                            target: parent
                            property: "opacity"
                            to: 0.5
                            duration: 100
                        }
                        PropertyAnimation {
                            target: parent
                            property: "opacity"
                            to: 1.0
                            duration: 100
                        }
                    }
                }
            }
            
            // Indicateur visuel subtil
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.8
                height: 2
                color: getTypeColor(currentType)
                radius: 1
                
                // Animation de couleur
                Behavior on color {
                    ColorAnimation { duration: 200 }
                }
            }
        }
        
        // Bouton flèche droite
        Button {
            id: rightArrow
            Layout.preferredWidth: 40
            Layout.fillHeight: true
            
            background: Rectangle {
                color: parent.hovered ? "#e9ecef" : "transparent"
                radius: 4
                border.color: parent.hovered ? "#adb5bd" : "transparent"
                border.width: 1
                
                // Animation de couleur
                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
                Behavior on border.color {
                    ColorAnimation { duration: 150 }
                }
            }
            
            contentItem: Text {
                text: "▶"
                font.pixelSize: 16
                font.bold: true
                color: rightArrow.enabled ? "#495057" : "#adb5bd"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                
                // Animation de couleur
                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }
            
            enabled: currentIndex < availableTypes.length - 1
            
            onClicked: {
                if (currentIndex < availableTypes.length - 1) {
                    let newIndex = currentIndex + 1
                    let newType = availableTypes[newIndex]
                    if (!updatingValues) {
                        root.currentType = newType
                        typeChanged(newType)
                    }
                }
            }
            
            // Effet de survol
            hoverEnabled: true
            
            ToolTip.visible: hovered
            ToolTip.text: "Type suivant"
            ToolTip.delay: 500
        }
    }

    
    // Fonction pour obtenir une couleur représentative du type
    function getTypeColor(type) {
        switch(type) {
            case Case.CS_KibbleDispenser: return "#28a745"  // Vert - départ
            case Case.CS_RestArea: return "#007bff"         // Bleu - propriétés
            case Case.CS_CardBoardBox: return "#ffc107"     // Jaune - caisse communauté
            case Case.CS_CatNip: return "#fd7e14"           // Orange - chance
            case Case.CS_Jail: return "#6c757d"             // Gris - prison
            case Case.CS_ToJail: return "#dc3545"           // Rouge - aller en prison
            case Case.CS_CatDoor: return "#20c997"          // Vert-bleu - gare
            case Case.CS_FreeNap: return "#e83e8c"          // Rose - parking gratuit
            case Case.CS_Device: return "#6f42c1"           // Violet - services
            case Case.CS_Taxe: return "#fd7e14"             // Orange - taxe
            default: return "#adb5bd"                       // Gris par défaut
        }
    }
    
    // Fonction publique pour mettre à jour le type depuis l'extérieur
    function setCurrentType(newType) {
        updatingValues = true
        currentType = newType
        updatingValues = false
    }
}
