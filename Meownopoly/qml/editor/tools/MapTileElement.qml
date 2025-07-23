import QtQuick 2.15
import QtQuick.Controls

SnapableElement {
    id: mapTile
    
    // Propriétés spécifiques aux tuiles de map
    property string tileType: "wall"
    property string tileName: "Mur"
    property url tileIcon: ""
    property int tileId: 0
    property var tileData: ({})
    
    // Apparence par défaut d'une tuile
    width: 40
    height: 40
    elementColor: getTileColor()
    borderColor: Qt.darker(elementColor, 1.3)
    borderWidth: 1
    
    // Signaux spécifiques
    signal tilePropertiesChanged(var properties)
    
    // Fonction pour déterminer la couleur selon le type
    function getTileColor() {
        switch(tileType) {
            case "wall": return "#8B4513"     // Marron pour les murs
            case "floor": return "#DEB887"    // Beige pour le sol
            case "door": return "#228B22"     // Vert pour les portes
            case "spawn": return "#FF6347"    // Rouge pour les points d'apparition
            case "exit": return "#4169E1"     // Bleu pour les sorties
            case "item": return "#FFD700"     // Or pour les objets
            default: return "#696969"         // Gris par défaut
        }
    }
    
    // Mise à jour de la couleur quand le type change
    onTileTypeChanged: {
        elementColor = getTileColor()
    }
    
    // Contenu visuel de la tuile
    Column {
        anchors.centerIn: parent
        spacing: 2
        
        // Icône ou texte représentant le type
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: getTileSymbol()
            color: "white"
            font.pixelSize: 12
            font.bold: true
        }
        
        // Nom de la tuile (affiché seulement si sélectionné)
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tileName
            color: "white"
            font.pixelSize: 6
            visible: isSelected
        }
    }
    
    // Fonction pour obtenir le symbole du type de tuile
    function getTileSymbol() {
        switch(tileType) {
            case "wall": return "█"
            case "floor": return "·"
            case "door": return "D"
            case "spawn": return "S"
            case "exit": return "E"
            case "item": return "♦"
            default: return "?"
        }
    }
    
    // Menu contextuel (clic droit)
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        
        onClicked: {
            if (mouse.button === Qt.RightButton) {
                contextMenu.popup()
            }
        }
    }
    
    // Menu contextuel simple
    Menu {
        id: contextMenu
        
        MenuItem {
            text: "Mur"
            onTriggered: changeTileType("wall")
        }
        MenuItem {
            text: "Sol"
            onTriggered: changeTileType("floor")
        }
        MenuItem {
            text: "Porte"
            onTriggered: changeTileType("door")
        }
        MenuItem {
            text: "Spawn"
            onTriggered: changeTileType("spawn")
        }
        MenuItem {
            text: "Sortie"
            onTriggered: changeTileType("exit")
        }
        MenuItem {
            text: "Objet"
            onTriggered: changeTileType("item")
        }
        
        MenuSeparator {}
        
        MenuItem {
            text: "Supprimer"
            onTriggered: mapTile.destroy()
        }
    }
    
    // Fonction pour changer le type de tuile
    function changeTileType(newType) {
        if (newType !== tileType) {
            tileType = newType
            tileName = getTileName(newType)
        }
    }
    
    // Fonction pour obtenir le nom français du type
    function getTileName(type) {
        switch(type) {
            case "wall": return "Mur"
            case "floor": return "Sol"
            case "door": return "Porte"
            case "spawn": return "Spawn"
            case "exit": return "Sortie"
            case "item": return "Objet"
            default: return "Inconnu"
        }
    }
    
    // Fonction pour obtenir les données de la tuile
    function getTileData() {
        return {
            id: tileId,
            type: tileType,
            name: tileName,
            x: x,
            y: y,
            width: width,
            height: height,
            data: tileData
        }
    }
} 
