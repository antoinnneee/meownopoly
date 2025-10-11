import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

pragma ComponentBehavior: Bound

Rectangle {
    id: root
    
    // Properties
    property var targetSnapableElement: null
    property bool updatingValues: false
    
    // Visual properties
    color: "#2a2a2a"
    radius: 8
    border.color: "#444444"
    border.width: 1
    
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
            
            // Title
            Text {
                id: titleText
                text: "Configuration des Connexions"
                color: "#ffffff"
                font.pixelSize: 16
                font.bold: true
                width: parent.width
            }
            
            // Section des éléments précédents
            Rectangle {
                width: parent.width
                height: 200
                color: "#333333"
                radius: 8
                border.color: "#555555"
                border.width: 1
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    
                    // En-tête de section
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        color: "#74b9ff"
                        radius: 6
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6
                            
                            Text {
                                text: "⬅️"
                                font.pixelSize: 14
                                color: "#ffffff"
                            }
                            
                            Label {
                                text: "Éléments Précédents"
                                font.pixelSize: 14
                                font.bold: true
                                color: "#ffffff"
                                Layout.fillWidth: true
                            }
                            
                            Rectangle {
                                implicitWidth: 20
                                implicitHeight: 18
                                radius: 9
                                color: "#ffffff"
                                opacity: 0.3
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: prevList.count
                                    color: "#ffffff"
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }
                        }
                    }
                    
                    // Placeholder quand vide
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: prevList.count === 0
                        color: "#2a2a2a"
                        radius: 6
                        border.color: "#555555"
                        border.width: 1
                        
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            
                            Text {
                                text: "📭"
                                font.pixelSize: 24
                                Layout.alignment: Qt.AlignHCenter
                            }
                            
                            Label {
                                text: "Aucun élément précédent"
                                color: "#888888"
                                font.pixelSize: 12
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                    
                    // Liste des éléments précédents
                    ListView {
                        id: prevList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        visible: count > 0
                        model: root.targetSnapableElement && root.targetSnapableElement.connectionManager ? root.targetSnapableElement.connectionManager.previousElements : []
                        boundsBehavior: Flickable.StopAtBounds
                        spacing: 2
                        
                        delegate: Rectangle {
                            required property int index
                            width: ListView.view.width
                            height: 36
                            color: prevMouseArea.containsMouse ? "#444444" : "#333333"
                            radius: 4
                            border.color: "#555555"
                            border.width: 1
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                            
                            MouseArea {
                                id: prevMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                            }
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8
                                
                                // Badge d'index
                                Rectangle {
                                    implicitWidth: 24
                                    implicitHeight: 20
                                    radius: 10
                                    color: "#74b9ff"
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: index + 1
                                        color: "#ffffff"
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                }
                                
                                Label {
                                    Layout.fillWidth: true
                                    text: "Élément " + (index + 1)
                                    color: "#cccccc"
                                    font.pixelSize: 12
                                    elide: Label.ElideRight
                                }
                                
                                // Bouton retirer
                                Rectangle {
                                    implicitWidth: 60
                                    implicitHeight: 20
                                    radius: 10
                                    color: removeBtn.containsMouse ? "#ff7675" : "#fd79a8"
                                    
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    
                                    MouseArea {
                                        id: removeBtn
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            if (root.targetSnapableElement && root.targetSnapableElement.connectionManager) {
                                                root.targetSnapableElement.connectionManager.removePreviousElement(modelData)
                                            }
                                        }
                                    }
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "Retirer"
                                        color: "#ffffff"
                                        font.pixelSize: 9
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Section des éléments suivants
            Rectangle {
                width: parent.width
                height: 200
                color: "#333333"
                radius: 8
                border.color: "#555555"
                border.width: 1
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    
                    // En-tête de section
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        color: "#00b894"
                        radius: 6
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6
                            
                            Text {
                                text: "➡️"
                                font.pixelSize: 14
                                color: "#ffffff"
                            }
                            
                            Label {
                                text: "Éléments Suivants"
                                font.pixelSize: 14
                                font.bold: true
                                color: "#ffffff"
                                Layout.fillWidth: true
                            }
                            
                            Rectangle {
                                implicitWidth: 20
                                implicitHeight: 18
                                radius: 9
                                color: "#ffffff"
                                opacity: 0.3
                                
                                Label {
                                    anchors.centerIn: parent
                                    text: nextList.count
                                    color: "#ffffff"
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }
                        }
                    }
                    
                    // Placeholder quand vide
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: nextList.count === 0
                        color: "#2a2a2a"
                        radius: 6
                        border.color: "#555555"
                        border.width: 1
                        
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            
                            Text {
                                text: "📪"
                                font.pixelSize: 24
                                Layout.alignment: Qt.AlignHCenter
                            }
                            
                            Label {
                                text: "Aucun élément suivant"
                                color: "#888888"
                                font.pixelSize: 12
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                    
                    // Liste des éléments suivants
                    ListView {
                        id: nextList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        visible: count > 0
                        model: root.targetSnapableElement && root.targetSnapableElement.connectionManager ? root.targetSnapableElement.connectionManager.nextElements : []
                        boundsBehavior: Flickable.StopAtBounds
                        spacing: 2
                        
                        delegate: Rectangle {
                            required property int index
                            width: ListView.view.width
                            height: 36
                            color: nextMouseArea.containsMouse ? "#444444" : "#333333"
                            radius: 4
                            border.color: "#555555"
                            border.width: 1
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                            
                            MouseArea {
                                id: nextMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                            }
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8
                                
                                // Badge d'index
                                Rectangle {
                                    implicitWidth: 24
                                    implicitHeight: 20
                                    radius: 10
                                    color: "#00b894"
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: index + 1
                                        color: "#ffffff"
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                }
                                
                                Label {
                                    Layout.fillWidth: true
                                    text: "Élément " + (index + 1)
                                    color: "#cccccc"
                                    font.pixelSize: 12
                                    elide: Label.ElideRight
                                }
                                
                                // Bouton retirer
                                Rectangle {
                                    implicitWidth: 60
                                    implicitHeight: 20
                                    radius: 10
                                    color: removeNextBtn.containsMouse ? "#ff7675" : "#fd79a8"
                                    
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    
                                    MouseArea {
                                        id: removeNextBtn
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            if (root.targetSnapableElement && root.targetSnapableElement.connectionManager) {
                                                root.targetSnapableElement.connectionManager.removeNextElement(nextList.model[index])
                                            }
                                        }
                                    }
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: "Retirer"
                                        color: "#ffffff"
                                        font.pixelSize: 9
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
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
                        color: addPrevBtn.containsMouse ? "#5a67d8" : "#667eea"
                        
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: addPrevBtn.containsMouse ? "#667eea" : "#74b9ff" }
                            GradientStop { position: 1.0; color: addPrevBtn.containsMouse ? "#5a67d8" : "#6c5ce7" }
                        }
                        
                        Behavior on color { ColorAnimation { duration: 200 } }
                        
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
                        color: addNextBtn.containsMouse ? "#00a085" : "#00b894"
                        
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: addNextBtn.containsMouse ? "#00b894" : "#55efc4" }
                            GradientStop { position: 1.0; color: addNextBtn.containsMouse ? "#00a085" : "#00b894" }
                        }
                        
                        Behavior on color { ColorAnimation { duration: 200 } }
                        
                        MouseArea {
                            id: addNextBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (root.targetSnapableElement) {
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
