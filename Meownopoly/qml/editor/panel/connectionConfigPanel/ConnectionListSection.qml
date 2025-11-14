import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

pragma ComponentBehavior: Bound

// Composant réutilisable pour afficher une liste de connexions (précédentes ou suivantes)
Rectangle {
    id: root
    
    // Properties
    property string title: "Éléments"
    property string emptyMessage: "Aucun élément"
    property string emptyIcon: "📭"
    property string directionIcon: "⬅️"
    property color headerColor: "#74b9ff"
    property color badgeColor: "#74b9ff"
    property var listModel: []
    property var targetElement: null
    property string connectionType: "previous" // "previous" or "next"
    
    // Signals
    signal removeElement(var element, int index)
    signal elementHovered(var element)
    signal elementUnhovered()
    
    color: "#333333"
    radius: 8
    border.color: "#555555"
    border.width: 1
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 5

        
        // Placeholder quand vide
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: connectionList.count === 0
            color: "#2a2a2a"
            radius: 6
            border.color: "#555555"
            border.width: 1
            
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 6
                
                Text {
                    text: root.emptyIcon
                    font.pixelSize: 24
                    Layout.alignment: Qt.AlignHCenter
                }
                
                Label {
                    text: root.emptyMessage
                    color: "#888888"
                    font.pixelSize: 12
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
        
        // Liste des éléments
        ListView {
            id: connectionList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: count > 0
            model: root.listModel
            boundsBehavior: Flickable.StopAtBounds
            spacing: 2
            
            delegate: Rectangle {
                required property int index
                required property var modelData
                width: ListView.view.width
                height: 36
                color: itemMouseArea.containsMouse ? "#444444" : "#333333"
                radius: 4
                border.color: "#555555"
                border.width: 1
                
                Behavior on color { ColorAnimation { duration: 150 } }
                
                MouseArea {
                    id: itemMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                        root.elementHovered(modelData)
                    }
                    onExited: {
                        root.elementUnhovered()
                    }
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
                        color: root.badgeColor
                        
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
                                root.removeElement(modelData, index)
                                //root.listModel = connectionList.model
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

