import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MapTypes

pragma ComponentBehavior: Bound

Rectangle {
    id: root
    
    // Properties
    property var targetSnapableElement: null
    property bool updatingValues: false
    property var hoveredConnectionElement: null
    property var logic: null  // Référence au logic pour sauvegarder
    
    // Visual properties
    color: "#2a2a2a"
    radius: 8
    border.color: "#444444"
    border.width: 1

    topLeftRadius: 0
    topRightRadius: 0
    // Signals
    signal requestAddConnection(string kind)
    signal configurationChanged()
    
    // Main scrollable content
    ScrollView {
        anchors.fill: parent
        anchors.margins: 10
        contentWidth: availableWidth
        clip: true
        
        Column {
            id: mainLayout
            width: parent.width
            spacing: 10
            
            // Section des actions
            Rectangle {
                width: parent.width
                height: 60
                color: "#333333"
                radius: 8
                border.color: "#555555"
                border.width: 1
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12
                    
                    // Bouton ajouter précédent
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 8
                        color: addPrevBtn.pressed ? "#4a5ac8" : (addPrevBtn.containsMouse ? "#5a67d8" : "#667eea")
                        
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: addPrevBtn.pressed ? "#5a67d8" : (addPrevBtn.containsMouse ? "#667eea" : "#74b9ff") }
                            GradientStop { position: 1.0; color: addPrevBtn.pressed ? "#4a5ac8" : (addPrevBtn.containsMouse ? "#5a67d8" : "#6c5ce7") }
                        }
                        
                        scale: addPrevBtn.pressed ? 0.95 : 1.0
                        opacity: addPrevBtn.pressed ? 0.8 : 1.0
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on scale { NumberAnimation { duration: 40 } }
                        Behavior on opacity { NumberAnimation { duration: 80 } }
                        
                        MouseArea {
                            id: addPrevBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (root.targetSnapableElement) {
                                    root.requestAddConnection("previous")
                                }
                            }
                        }
                        
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            
                            Text {
                                text: "⬅️"
                                font.pixelSize: 12
                            }
                            
                            Label {
                                text: "Ajouter Précédent"
                                color: "#ffffff"
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }
                    }
                    
                    // Bouton ajouter suivant
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 8
                        color: addNextBtn.pressed ? "#009075" : (addNextBtn.containsMouse ? "#00a085" : "#00b894")
                        
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: addNextBtn.pressed ? "#00a085" : (addNextBtn.containsMouse ? "#00b894" : "#55efc4") }
                            GradientStop { position: 1.0; color: addNextBtn.pressed ? "#009075" : (addNextBtn.containsMouse ? "#00a085" : "#00b894") }
                        }
                        
                        scale: addNextBtn.pressed ? 0.95 : 1.0
                        opacity: addNextBtn.pressed ? 0.8 : 1.0


                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on scale { NumberAnimation { duration: 40 } }
                        Behavior on opacity { NumberAnimation { duration: 80 } }
                        
                        MouseArea {
                            id: addNextBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                console.log("next button clicked")
                                if (root.targetSnapableElement) {
                                    console.log("add next request")
                                    root.requestAddConnection("next")
                                }
                            }
                        }
                        
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            
                            Text {
                                text: "➡️"
                                font.pixelSize: 12
                            }
                            
                            Label {
                                text: "Ajouter Suivant"
                                color: "#ffffff"
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }
                    }
                }
            }
            
            // Sections des éléments côte à côte
            RowLayout {
                width: parent.width
                height: 300
                spacing: 10
                
                // Section des éléments précédents
                ConnectionListSection {
                    id: previousSection
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    title: "Éléments Précédents"
                    emptyMessage: "Aucun élément précédent"
                    emptyIcon: "📭"
                    directionIcon: "⬅️"
                    headerColor: "#74b9ff"
                    badgeColor: "#74b9ff"
                    connectionType: "previous"
                    
                    listModel: root.targetSnapableElement && root.targetSnapableElement.connectionManager 
                        ? root.targetSnapableElement.connectionManager.previousElements 
                        : []
                    
                    onRemoveElement: function(element, index) {
                        if (root.targetSnapableElement && root.targetSnapableElement.connectionManager) {
                            root.targetSnapableElement.connectionManager.removePreviousElement(element)
                            if (logic) {
                                logic.saveMap(MapTypes.UNDOREDO)
                            }
                        }
                    }
                    
                    onElementHovered: function(element) {
                        root.hoveredConnectionElement = element
                        // Pour les éléments précédents, c'est leur connectionManager qui crée l'overlay
                        if (element && element.connectionManager) {
                            element.connectionManager.hoveredElement = root.targetSnapableElement
                        }
                    }
                    
                    onElementUnhovered: {
                        // Réinitialiser tous les hoveredElement
                        if (root.hoveredConnectionElement && root.hoveredConnectionElement.connectionManager) {
                            root.hoveredConnectionElement.connectionManager.hoveredElement = null
                        }
                        root.hoveredConnectionElement = null
                    }
                }
                
                // Section des éléments suivants
                ConnectionListSection {
                    id: nextSection
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    title: "Éléments Suivants"
                    emptyMessage: "Aucun élément suivant"
                    emptyIcon: "📪"
                    directionIcon: "➡️"
                    headerColor: "#00b894"
                    badgeColor: "#00b894"
                    connectionType: "next"
                    
                    listModel: root.targetSnapableElement && root.targetSnapableElement.connectionManager 
                        ? root.targetSnapableElement.connectionManager.nextElements 
                        : []
                    
                    onRemoveElement: function(element, index) {
                        if (root.targetSnapableElement && root.targetSnapableElement.connectionManager) {
                            root.targetSnapableElement.connectionManager.removeNextElement(element)
                            if (logic) {
                                logic.saveMap(MapTypes.UNDOREDO)
                            }
                        }
                    }
                    
                    onElementHovered: function(element) {
                        root.hoveredConnectionElement = element
                        // Pour les éléments suivants, c'est le targetSnapableElement.connectionManager qui crée l'overlay
                        if (root.targetSnapableElement && root.targetSnapableElement.connectionManager) {
                            root.targetSnapableElement.connectionManager.hoveredElement = element
                        }
                    }
                    
                    onElementUnhovered: {
                        // Réinitialiser tous les hoveredElement
                        if (root.targetSnapableElement && root.targetSnapableElement.connectionManager) {
                            root.targetSnapableElement.connectionManager.hoveredElement = null
                        }
                        root.hoveredConnectionElement = null
                    }
                }
            }
        }
    }
    
    // Functions
    function setTargetElement(snapableElement) {
        if (snapableElement) {
            targetSnapableElement = snapableElement
            updateControls()
        }
    }

    function updateControls() {
        if (!targetSnapableElement) return
        
        updatingValues = true
        // Les ListView se mettront à jour automatiquement via les bindings
        updatingValues = false
    }
    
    function clearTarget() {
        targetSnapableElement = null
    }
}
