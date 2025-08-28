import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt.labs.folderlistmodel 2.15
import MapLoader

pragma ComponentBehavior: Bound

Item {
    id: root

    // Propriétés
    property bool isVisible: false
    
    // Signaux
    signal configurationClosed()
    signal mapSelected(string mapName)

    visible: isVisible
    width: 600
    height: 500
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
                color: "#e17055"
                radius: 12
                
                // Gradient pour l'en-tête
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#e17055" }
                    GradientStop { position: 1.0; color: "#d63031" }
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
                            text: "🗺️"
                            font.pixelSize: 18
                        }
                    }

                    Label {
                        text: "Sélecteur de Maps"
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

            // Section d'information
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                color: "#ffffff"
                radius: 12
                border.color: "#e9ecef"
                border.width: 1
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    
                    Text {
                        text: "📁"
                        font.pixelSize: 16
                    }
                    
                    Label {
                        text: "Maps disponibles dans le dossier map/"
                        font.pixelSize: 14
                        color: "#6c757d"
                        Layout.fillWidth: true
                    }
                    
                    Rectangle {
                        implicitWidth: 40
                        implicitHeight: 24
                        radius: 12
                        color: "#74b9ff"
                        opacity: 0.8
                        
                        Label {
                            anchors.centerIn: parent
                            text: mapListView.count
                            color: "#ffffff"
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }
                }
            }

            // Liste des maps avec style moderne
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
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

                    // Placeholder moderne quand vide
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: mapListView.count === 0
                        color: "#f8f9fa"
                        radius: 8
                        border.color: "#e9ecef"
                        border.width: 1
                        
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            
                            Text {
                                text: "🗂️"
                                font.pixelSize: 48
                                Layout.alignment: Qt.AlignHCenter
                            }
                            
                            Label {
                                text: "Aucune map trouvée"
                                color: "#6c757d"
                                font.pixelSize: 16
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                            
                            Label {
                                text: "Vérifiez que le dossier map/ contient des fichiers .json"
                                color: "#6c757d"
                                font.pixelSize: 12
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    // Liste des maps
                    ListView {
                        id: mapListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        visible: count > 0
                        model: ListModel {
                            id: mapModel
                            
                            Component.onCompleted: {
                                refreshMapList()
                            }
                            
                            function refreshMapList() {
                                // Vider le modèle existant
                                mapModel.clear()
                                
                                // Récupérer la liste des maps depuis MapLoader
                                var availableMaps = MapLoader.getAvailableMaps()
                                console.log("Available maps from MapLoader:", availableMaps)
                                
                                // Ajouter chaque map au modèle
                                for (var i = 0; i < availableMaps.length; i++) {
                                    var mapName = availableMaps[i]
                                    mapModel.append({
                                        "mapName": mapName,
                                        "fileName": mapName + "_map.json",
                                        "description": "Map " + mapName,
                                        "lastModified": "N/A"
                                    })
                                }
                            }
                        }
                        boundsBehavior: Flickable.StopAtBounds
                        spacing: 8

                        delegate: Rectangle {
                            required property string mapName
                            required property string fileName
                            required property string description
                            required property string lastModified
                            required property int index
                            
                            width: ListView.view.width
                            height: 80
                            color: mapMouseArea.containsMouse ? "#f1f3f4" : "#ffffff"
                            radius: 12
                            border.color: "#e9ecef"
                            border.width: 1
                            
                            // Animation hover
                            Behavior on color { ColorAnimation { duration: 150 } }
                            
                            // Effet de surbrillance au survol
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "#74b9ff"
                                opacity: mapMouseArea.containsMouse ? 0.1 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: mapMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    console.log("Sélection de la map:", mapName)
                                    root.mapSelected(mapName)
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 16

                                // Icône de map stylisée
                                Rectangle {
                                    implicitWidth: 48
                                    implicitHeight: 48
                                    radius: 24
                                    color: "#74b9ff"
                                    
                                    // Gradient pour l'icône
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: "#74b9ff" }
                                        GradientStop { position: 1.0; color: "#6c5ce7" }
                                    }
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "🗺️"
                                        font.pixelSize: 20
                                    }
                                }

                                // Informations de la map
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Label {
                                        text: mapName
                                        color: "#2d3436"
                                        font.pixelSize: 16
                                        font.bold: true
                                        elide: Label.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Label {
                                        text: description
                                        color: "#636e72"
                                        font.pixelSize: 12
                                        elide: Label.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    
                                    Label {
                                        text: "Fichier: " + fileName
                                        color: "#b2bec3"
                                        font.pixelSize: 10
                                        elide: Label.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                // Bouton de chargement stylisé
                                Rectangle {
                                    implicitWidth: 100
                                    implicitHeight: 36
                                    radius: 18
                                    color: loadBtn.containsMouse ? "#00b894" : "#55efc4"
                                    
                                    // Animation hover
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    
                                    MouseArea {
                                        id: loadBtn
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            console.log("Chargement de la map:", mapName)
                                            MapLoader.loadMap(mapName)
                                            root.isVisible = false
                                            configurationClosed()
                                        }
                                    }
                                    
                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        
                                        Text {
                                            text: "📥"
                                            font.pixelSize: 12
                                        }
                                        
                                        Label {
                                            text: "Charger"
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
            }

            // Boutons d'action en bas
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: "#ffffff"
                radius: 12
                border.color: "#e9ecef"
                border.width: 1
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 16
                    
                    // Bouton Actualiser
                    Rectangle {
                        Layout.preferredWidth: 120
                        Layout.preferredHeight: 40
                        radius: 20
                        color: refreshBtn.containsMouse ? "#636e72" : "#74b9ff"
                        
                        // Animation hover
                        Behavior on color { ColorAnimation { duration: 150 } }
                        
                        MouseArea {
                            id: refreshBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                console.log("Actualisation de la liste des maps")
                                mapModel.refreshMapList()
                            }
                        }
                        
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            
                            Text {
                                text: "🔄"
                                font.pixelSize: 14
                            }
                            
                            Label {
                                text: "Actualiser"
                                color: "#ffffff"
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }
                    }
                    
                    Item { Layout.fillWidth: true } // Spacer
                    
                    // Bouton Annuler
                    Rectangle {
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 40
                        radius: 20
                        color: cancelBtn.containsMouse ? "#636e72" : "#b2bec3"
                        
                        // Animation hover
                        Behavior on color { ColorAnimation { duration: 150 } }
                        
                        MouseArea {
                            id: cancelBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.isVisible = false
                                configurationClosed()
                            }
                        }
                        
                        Label {
                            anchors.centerIn: parent
                            text: "Annuler"
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
