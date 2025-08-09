import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    // Propriétés
    property var targetElement: null
    property bool isVisible: false

    // Signaux
    signal configurationClosed()

    visible: isVisible
    width: 520
    height: 460
    z: 1100

    // Panneau visuel
    Rectangle {
        id: panel
        anchors.fill: parent
        color: "#ffffff"
        radius: 10
        border.color: "#e9ecef"
        border.width: 1

        // Contenu
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // En-tête moderne
            ToolBar {
                Layout.fillWidth: true
                height: 40

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    Label {
                        text: "Connexions de l'élément"
                        font.pixelSize: 18
                        font.bold: true
                        color: "#212529"
                        Layout.fillWidth: true
                        elide: Label.ElideRight
                    }

                    ToolButton {
                        text: "✕"
                        onClicked: {
                            root.isVisible = false
                            configurationClosed()
                        }
                    }
                }
            }

            // Contenu scrollable
            ScrollView {
                id: scroller
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    id: contentCol
                    width: scroller.availableWidth
                    spacing: 12

                    // Liste des éléments précédents
                    GroupBox {
                        title: "Éléments précédents"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180

                        // Placeholder quand vide (remplace PlaceholderMessage)
                        Item {
                            anchors.fill: parent
                            visible: prevList.count === 0
                            Label {
                                anchors.centerIn: parent
                                text: "Aucun élément précédent"
                                color: "#6c757d"
                                font.pixelSize: 14
                            }
                        }

                        ListView {
                            id: prevList
                            anchors.fill: parent
                            clip: true
                            model: targetElement && targetElement.connectionManager ? targetElement.connectionManager.previousElements : []
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: SwipeDelegate {
                                id: prevSwipe
                                width: ListView.view.width
                                height: 44
                                padding: 10

                                contentItem: Item {
                                    width: parent.width
                                    height: parent.height
                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 8

                                        Rectangle {
                                            width: 28
                                            height: 24
                                            radius: 6
                                            color: "#e9ecef"
                                            Label {
                                                anchors.centerIn: parent
                                                text: index
                                                color: "#495057"
                                                font.pixelSize: 12
                                            }
                                        }

                                        Label {
                                            Layout.fillWidth: true
                                            text: "Élément " + index
                                            color: "#212529"
                                            elide: Label.ElideRight
                                        }

                                        ToolButton {
                                            text: "Retirer"
                                            onClicked: targetElement && targetElement.connectionManager && targetElement.connectionManager.removePreviousElement(modelData)
                                        }
                                    }
                                }

                                // Action swipe vers la droite pour retirer
                                swipe.right: Item {
                                    width: parent.width
                                    height: parent.height

                                    Rectangle { anchors.fill: parent; color: "#dc3545" }
                                    Label {
                                        text: "Retirer"
                                        color: "white"
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.right: parent.right
                                        anchors.rightMargin: 16
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (targetElement && targetElement.connectionManager)
                                                targetElement.connectionManager.removePreviousElement(modelData)
                                            prevSwipe.swipe.close()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Liste des éléments suivants
                    GroupBox {
                        title: "Éléments suivants"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180

                        // Placeholder quand vide (remplace PlaceholderMessage)
                        Item {
                            anchors.fill: parent
                            visible: nextList.count === 0
                            Label {
                                anchors.centerIn: parent
                                text: "Aucun élément suivant"
                                color: "#6c757d"
                                font.pixelSize: 14
                            }
                        }

                        ListView {
                            id: nextList
                            anchors.fill: parent
                            clip: true
                            model: targetElement && targetElement.connectionManager ? targetElement.connectionManager.nextElements : []
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: SwipeDelegate {
                                id: nextSwipe
                                width: ListView.view.width
                                height: 44
                                padding: 10

                                contentItem: Item {
                                    width: parent.width
                                    height: parent.height
                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 8

                                        Rectangle {
                                            width: 28
                                            height: 24
                                            radius: 6
                                            color: "#e9ecef"
                                            Label {
                                                anchors.centerIn: parent
                                                text: index
                                                color: "#495057"
                                                font.pixelSize: 12
                                            }
                                        }

                                        Label {
                                            Layout.fillWidth: true
                                            text: "Élément " + index
                                            color: "#212529"
                                            elide: Label.ElideRight
                                        }

                                        ToolButton {
                                            text: "Retirer"
                                            onClicked: targetElement && targetElement.connectionManager && targetElement.connectionManager.removeNextElement(modelData)
                                        }
                                    }
                                }

                                // Action swipe vers la droite pour retirer
                                swipe.right: Item {
                                    width: parent.width
                                    height: parent.height

                                    Rectangle { anchors.fill: parent; color: "#dc3545" }
                                    Label {
                                        text: "Retirer"
                                        color: "white"
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.right: parent.right
                                        anchors.rightMargin: 16
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (targetElement && targetElement.connectionManager)
                                                targetElement.connectionManager.removeNextElement(modelData)
                                            nextSwipe.swipe.close()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Actions
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Button {
                            text: "Ajouter précédent (sélection)"
                            onClicked: {
                                if (targetElement && root.selectElementToConnect)
                                    root.selectElementToConnect("previous")
                            }
                        }

                        Button {
                            text: "Ajouter suivant (sélection)"
                            onClicked: {
                                if (targetElement && root.selectElementToConnect)
                                    root.selectElementToConnect("next")
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


