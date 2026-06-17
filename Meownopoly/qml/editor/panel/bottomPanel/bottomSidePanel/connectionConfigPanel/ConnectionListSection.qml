import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import theme

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
    
    color: Theme.surfaceAlt
    radius: Theme.radiusL
    border.color: Theme.borderLight
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingXS

        
        // Placeholder quand vide
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: connectionList.count === 0
            color: Theme.surface
            radius: Theme.radiusM
            border.color: Theme.borderLight
            border.width: 1

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Theme.spacingS

                Text {
                    text: root.emptyIcon
                    font.pixelSize: Theme.fontSizeDisplay
                    Layout.alignment: Qt.AlignHCenter
                }

                Label {
                    text: root.emptyMessage
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSizeBody
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
            spacing: Theme.spacingXXS
            
            delegate: Rectangle {
                required property int index
                required property var modelData
                width: ListView.view.width
                height: 36
                color: itemMouseArea.containsMouse ? Theme.border : Theme.surfaceAlt
                radius: Theme.radiusS
                border.color: Theme.borderLight
                border.width: 1

                Behavior on color { ColorAnimation { duration: Theme.durationNormal } }
                
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
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingM
                    
                    // Badge d'index
                    Rectangle {
                        implicitWidth: 24
                        implicitHeight: 20
                        radius: Theme.radiusXL
                        color: root.badgeColor

                        Label {
                            anchors.centerIn: parent
                            text: index + 1
                            color: "#ffffff"
                            font.pixelSize: Theme.fontSizeCaption
                            font.bold: true
                        }
                    }
                    
                    Label {
                        Layout.fillWidth: true
                        text: "Élément " + (index + 1)
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeBody
                        elide: Label.ElideRight
                    }
                    
                    // Bouton retirer
                    Rectangle {
                        implicitWidth: 60
                        implicitHeight: 20
                        radius: Theme.radiusXL
                        color: removeBtn.containsMouse ? Theme.dangerSoft : "#fd79a8"

                        Behavior on color { ColorAnimation { duration: Theme.durationNormal } }
                        
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
                            font.pixelSize: Theme.fontSizeTiny
                            font.bold: true
                        }
                    }
                }
            }
        }
    }
}

