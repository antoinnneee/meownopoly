import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

pragma ComponentBehavior: Bound

Item {
    id: root

    // Propriétés
    property var targetElement: null
    property bool isVisible: false
    
    // Fonction à implémenter par l'hôte pour la sélection d'éléments
    function selectElementToConnect(kind) {
        console.warn("selectElementToConnect not implemented for kind:", kind)
    }

    // Signaux
    signal configurationClosed()

    visible: isVisible
    width: 580
    height: 520
    z: 1100

    // Overlay semi-transparent
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.isVisible = false
                configurationClosed()
            }
        }
    }

    // Panneau principal avec effet d'ombre
    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: parent.width - 40
        height: parent.height - 40
        color: "#f8f9fa"
        radius: 16
        
        // Ombre portée simulée avec des rectangles
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 8
            anchors.leftMargin: 4
            anchors.rightMargin: -4
            anchors.bottomMargin: -4
            color: "#20000000"
            radius: parent.radius
            z: -1
        }

        // Gradient subtil pour le fond
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#ffffff" }
                GradientStop { position: 1.0; color: "#f8f9fa" }
            }
        }

        // Contenu
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            // En-tête avec style moderne
                                        Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 60
                color: "#6c5ce7"
                radius: 12
                
                // Gradient pour l'en-tête
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#6c5ce7" }
                    GradientStop { position: 1.0; color: "#5f3dc4" }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    // Icône
                                                        Rectangle {
                                    implicitWidth: 32
                                    implicitHeight: 32
                        radius: 16
                        color: "#ffffff"
                        opacity: 0.2
                        
                        Text {
                            anchors.centerIn: parent
                            text: "🔗"
                            font.pixelSize: 18
                        }
                    }

                    Label {
                        text: "Gestionnaire de Connexions"
                        font.pixelSize: 20
                        font.bold: true
                        color: "#ffffff"
                        Layout.fillWidth: true
                        elide: Label.ElideRight
                    }

                    // Bouton fermer stylisé
                    Rectangle {
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: 16
                        color: "#ffffff"
                                                                opacity: closeButton.containsMouse ? 0.3 : 0.2
                        
                        MouseArea {
                            id: closeButton
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.isVisible = false
                                configurationClosed()
                            }
                        }
                        
                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: "#ffffff"
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }
                }
            }

            // Contenu scrollable avec style moderne
            ScrollView {
                id: scroller
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                
                // Style personnalisé pour la scrollbar
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 8
                        radius: 4
                        color: "#c6c6c6"
                        opacity: 0.6
                    }
                    background: Rectangle {
                        implicitWidth: 8
                        color: "transparent"
                    }
                }

                ColumnLayout {
                    id: contentCol
                    width: scroller.availableWidth
                    spacing: 20

                    // Section des éléments précédents
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 200
                        color: "#ffffff"
                        radius: 12
                        border.color: "#e9ecef"
                        border.width: 1
                        
                        // Ombre subtile simulée
                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: 2
                            anchors.leftMargin: 1
                            anchors.rightMargin: -1
                            anchors.bottomMargin: -1
                            color: "#15000000"
                            radius: parent.radius
                            z: -1
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            // En-tête de section
                                                            Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                color: "#74b9ff"
                                radius: 8
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8
                                    
                                    Text {
                                        text: "⬅️"
                                        font.pixelSize: 16
                                    }
                                    
                                    Label {
                                        text: "Éléments Précédents"
                                        font.pixelSize: 16
                                        font.bold: true
                                        color: "#ffffff"
                                        Layout.fillWidth: true
                                    }
                                    
                                                                            Rectangle {
                                            implicitWidth: 24
                                            implicitHeight: 20
                                        radius: 10
                                        color: "#ffffff"
                                        opacity: 0.3
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: prevList.count
                                            color: "#ffffff"
                                            font.pixelSize: 12
                                            font.bold: true
                                        }
                                    }
                                }
                            }

                            // Placeholder moderne quand vide
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                visible: prevList.count === 0
                                color: "#f8f9fa"
                                radius: 8
                                border.color: "#e9ecef"
                                border.width: 1
                                
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    
                                    Text {
                                        text: "📭"
                                        font.pixelSize: 32
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    
                                    Label {
                                        text: "Aucun élément précédent"
                                        color: "#6c757d"
                                        font.pixelSize: 14
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }
                            }

                            // Liste moderne des éléments précédents
                            ListView {
                                id: prevList
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                visible: count > 0
                                model: root.targetElement && root.targetElement.connectionManager ? root.targetElement.connectionManager.previousElements : []
                                boundsBehavior: Flickable.StopAtBounds
                                spacing: 4

                                delegate: Rectangle {
                                    width: ListView.view.width
                                    height: 48
                                    color: prevMouseArea.containsMouse ? "#f1f3f4" : "#ffffff"
                                    radius: 8
                                    border.color: "#e9ecef"
                                    border.width: 1
                                    
                                    // Animation hover
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    MouseArea {
                                        id: prevMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 12

                                        // Badge d'index stylisé
                                        Rectangle {
                                            implicitWidth: 32
                                            implicitHeight: 28
                                            radius: 14
                                            color: "#74b9ff"
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: index + 1
                                                color: "#ffffff"
                                                font.pixelSize: 12
                                                font.bold: true
                                            }
                                        }

                                        Label {
                                            Layout.fillWidth: true
                                            text: "Élément " + (index + 1)
                                            color: "#2d3436"
                                            font.pixelSize: 14
                                            elide: Label.ElideRight
                                        }

                                        // Bouton retirer stylisé
                                        Rectangle {
                                            implicitWidth: 80
                                            implicitHeight: 28
                                            radius: 14
                                            color: removeBtn.containsMouse ? "#ff7675" : "#fd79a8"
                                            
                                            // Animation hover
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            
                                            MouseArea {
                                                id: removeBtn
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: root.targetElement && root.targetElement.connectionManager && root.targetElement.connectionManager.removePreviousElement(modelData)
                                            }
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: "Retirer"
                                                color: "#ffffff"
                                                font.pixelSize: 11
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
                        Layout.fillWidth: true
                        Layout.preferredHeight: 200
                        color: "#ffffff"
                        radius: 12
                        border.color: "#e9ecef"
                        border.width: 1
                        
                        // Ombre subtile simulée
                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: 2
                            anchors.leftMargin: 1
                            anchors.rightMargin: -1
                            anchors.bottomMargin: -1
                            color: "#15000000"
                            radius: parent.radius
                            z: -1
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            // En-tête de section
                                                            Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                color: "#00b894"
                                radius: 8
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8
                                    
                                    Text {
                                        text: "➡️"
                                        font.pixelSize: 16
                                    }
                                    
                                    Label {
                                        text: "Éléments Suivants"
                                        font.pixelSize: 16
                                        font.bold: true
                                        color: "#ffffff"
                                        Layout.fillWidth: true
                                    }
                                    
                                                                            Rectangle {
                                            implicitWidth: 24
                                            implicitHeight: 20
                                        radius: 10
                                        color: "#ffffff"
                                        opacity: 0.3
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: nextList.count
                                            color: "#ffffff"
                                            font.pixelSize: 12
                                            font.bold: true
                                        }
                                    }
                                }
                            }

                            // Placeholder moderne quand vide
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                visible: nextList.count === 0
                                color: "#f8f9fa"
                                radius: 8
                                border.color: "#e9ecef"
                                border.width: 1
                                
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    
                                    Text {
                                        text: "📪"
                                        font.pixelSize: 32
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    
                                    Label {
                                        text: "Aucun élément suivant"
                                        color: "#6c757d"
                                        font.pixelSize: 14
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }
                            }

                            // Liste moderne des éléments suivants
                            ListView {
                                id: nextList
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                visible: count > 0
                                model: root.targetElement && root.targetElement.connectionManager ? root.targetElement.connectionManager.nextElements : []
                                boundsBehavior: Flickable.StopAtBounds
                                spacing: 4

                                delegate: Rectangle {
                                    required property int index
                                    Component.onCompleted: {
                                        console.log("model", nextList.model[index])
                                    }

                                    width: ListView.view.width
                                    height: 48
                                    color: nextMouseArea.containsMouse ? "#f1f3f4" : "#ffffff"
                                    radius: 8
                                    border.color: "#e9ecef"
                                    border.width: 1
                                    
                                    // Animation hover
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    MouseArea {
                                        id: nextMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 12

                                        // Badge d'index stylisé
                                        Rectangle {
                                            implicitWidth: 32
                                            implicitHeight: 28
                                            radius: 14
                                            color: "#00b894"
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: index + 1
                                                color: "#ffffff"
                                                font.pixelSize: 12
                                                font.bold: true
                                            }
                                        }

                                        Label {
                                            Layout.fillWidth: true
                                            text: "Élément " + (index + 1)
                                            color: "#2d3436"
                                            font.pixelSize: 14
                                            elide: Label.ElideRight
                                        }

                                        // Bouton retirer stylisé
                                        Rectangle {
                                            implicitWidth: 80
                                            implicitHeight: 28
                                            radius: 14
                                            color: removeNextBtn.containsMouse ? "#ff7675" : "#fd79a8"
                                            
                                            // Animation hover
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            
                                            MouseArea {
                                                id: removeNextBtn
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: root.targetElement && root.targetElement.connectionManager && root.targetElement.connectionManager.removeNextElement( nextList.model[index])
                                            }
                                            
                                            Label {
                                                anchors.centerIn: parent
                                                text: "Retirer"
                                                color: "#ffffff"
                                                font.pixelSize: 11
                                                font.bold: true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Section des actions avec style moderne
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 80
                        color: "#ffffff"
                        radius: 12
                        border.color: "#e9ecef"
                        border.width: 1
                        
                        // Ombre subtile simulée
                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: 2
                            anchors.leftMargin: 1
                            anchors.rightMargin: -1
                            anchors.bottomMargin: -1
                            color: "#15000000"
                            radius: parent.radius
                            z: -1
                        }
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 16

                            // Bouton ajouter précédent
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 48
                                radius: 12
                                color: addPrevBtn.containsMouse ? "#5a67d8" : "#667eea"
                                
                                // Gradient
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: addPrevBtn.containsMouse ? "#667eea" : "#74b9ff" }
                                    GradientStop { position: 1.0; color: addPrevBtn.containsMouse ? "#5a67d8" : "#6c5ce7" }
                                }
                                
                                // Animation hover
                                Behavior on color { ColorAnimation { duration: 200 } }
                                
                                MouseArea {
                                    id: addPrevBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (root.targetElement)
                                            root.selectElementToConnect("previous")
                                    }
                                }
                                
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    
                                    Text {
                                        text: "⬅️"
                                        font.pixelSize: 16
                                    }
                                    
                                    Label {
                                        text: "Ajouter Précédent"
                                        color: "#ffffff"
                                        font.pixelSize: 14
                                        font.bold: true
                                    }
                                }
                            }

                            // Bouton ajouter suivant
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 48
                                radius: 12
                                color: addNextBtn.containsMouse ? "#00a085" : "#00b894"
                                
                                // Gradient
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: addNextBtn.containsMouse ? "#00b894" : "#55efc4" }
                                    GradientStop { position: 1.0; color: addNextBtn.containsMouse ? "#00a085" : "#00b894" }
                                }
                                
                                // Animation hover
                                Behavior on color { ColorAnimation { duration: 200 } }
                                
                                MouseArea {
                                    id: addNextBtn
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (root.targetElement)
                                            root.selectElementToConnect("next")
                                    }
                                }
                                
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    
                                    Text {
                                        text: "➡️"
                                        font.pixelSize: 16
                                    }
                                    
                                    Label {
                                        text: "Ajouter Suivant"
                                        color: "#ffffff"
                                        font.pixelSize: 14
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }


    // Hook que l'hôte doit implémenter pour fournir un élément sélectionné
    // function selectElementToConnect(kind) { /* 'previous' | 'next' */ }
}


