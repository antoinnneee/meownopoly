import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MapTypes
import ui_item
import EditorOpBus 1.0

pragma ComponentBehavior: Bound

CollapsableGroupBox {
    id: root
    title: "Connexions"
    
    // Properties
    property var targetSnapableElement: null
    property bool updatingValues: false
    property var hoveredConnectionElement: null
    property var logic: null  // Référence au logic pour sauvegarder
    property bool showConnections: false
    onShowConnectionsChanged: {
        logic.tileLogic.displayLinkEnable = showConnections
    }
    
    // Signals
    signal requestAddConnection(string kind)
    signal configurationChanged()
    
    // Main scrollable content
    content:  [
            
            // Checkbox afficher les connexions
            Rectangle {
                Layout.fillWidth: true
                height: 50
                color: "#2a2a2a"
                radius: 8
                border.color: "#555555"
                border.width: 1
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10
                    
                    CheckBox {
                        id: showConnectionsCheckbox
                        checked: root.showConnections

                        text: "Afficher les connexions"
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        
                        onCheckedChanged: {
                            root.showConnections = checked
                        }
                        contentItem: Text {
                            text: showConnectionsCheckbox.text
                            anchors.verticalCenter: parent.verticalCenter
                        font: showConnectionsCheckbox.font
                        opacity: showConnectionsCheckbox.enabled ? 1.0 : 0.3
                        color: showConnectionsCheckbox.checked ? "#ffffff" : "#cccccc"
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: showConnectionsCheckbox.indicator.width + showConnectionsCheckbox.spacing
                        }
                        indicator: Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            radius: 4
                            border.color: showConnectionsCheckbox.checked ? "#667eea" : "#888888"
                            border.width: 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: showConnectionsCheckbox.checked ? "#667eea" : "#3a3a3a"
                            
                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: "white"
                                font.pixelSize: 14
                                font.bold: true
                                visible: showConnectionsCheckbox.checked
                            }
                        }
                    }

                }
            },
            
            // Section des actions
            Rectangle {
                Layout.fillWidth: true
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
                                if (!showConnections)
                                    showConnections = true
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
                                if (!showConnections)
                                    showConnections = true
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
            ,
            // Sections des éléments côte à côte
            RowLayout {
                Layout.fillWidth: true
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
                            // Phase 2: UnlinkItems (log-only) avant la mutation.
                            if (root.targetSnapableElement.snapableParameters && element && element.snapableParameters) {
                                EditorOpBus.recordOp(EditorOpBus.makeUnlinkOp(
                                    String(root.targetSnapableElement.snapableParameters.uniqueId),
                                    String(element.snapableParameters.uniqueId),
                                    "previous"))
                            }
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
                            // Phase 2: UnlinkItems (log-only) avant la mutation.
                            if (root.targetSnapableElement.snapableParameters && element && element.snapableParameters) {
                                EditorOpBus.recordOp(EditorOpBus.makeUnlinkOp(
                                    String(root.targetSnapableElement.snapableParameters.uniqueId),
                                    String(element.snapableParameters.uniqueId),
                                    "next"))
                            }
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
        ]

    
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
