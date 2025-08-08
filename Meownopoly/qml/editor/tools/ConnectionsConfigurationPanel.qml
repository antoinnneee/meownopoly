import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    // Propriétés
    property var targetElement: null
    property bool isVisible: false
    onTargetElementChanged: {
        console.log("targer changed", targetElement.connectionManager.previousElements )
    }

    // Signaux
    signal configurationClosed()

    visible: isVisible
    color: "#f8f9fa"
    border.color: "#dee2e6"
    border.width: 2
    radius: 8

    width: 500
    height: 400
    z: 1100

    ScrollView {
        anchors.fill: parent
        anchors.margins: 15
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 12

            // En-tête
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Connexions de l'élément"
                    font.pixelSize: 18
                    font.bold: true
                    color: "#343a40"
                    Layout.fillWidth: true
                }

                Button {
                    text: "Fermer"
                    onClicked: {
                        root.isVisible = false
                        configurationClosed()
                    }
                }
            }
            // Debug temporaire désactivé

            // Listes des connexions
            GroupBox {
                title: "Éléments précédents"
                Layout.fillWidth: true
                Layout.preferredHeight: 180
                Component.onCompleted: {
                    console.log("size groupbox previous : ", width, height)
                }

                ListView {
                    id: prevList
                    anchors.fill: parent
                    clip: true
                    model: targetElement && targetElement.connectionManager ? targetElement.connectionManager.previousElements : []

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 36
                        color: index % 2 ? "#ffffff" : "#f1f3f5"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Text { text: "El." + index; color: "#212529"; Layout.fillWidth: true }

                            Button {
                                text: "Retirer"
                                onClicked: targetElement.connectionManager.removePreviousElement(modelData)
                            }
                        }
                    }
                }
            }

            GroupBox {
                title: "Éléments suivants"
                Layout.fillWidth: true
                Layout.preferredHeight: 180

                ListView {
                    id: nextList
                    anchors.fill: parent
                    clip: true
                    model: targetElement && targetElement.connectionManager ? targetElement.connectionManager.nextElements : []

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 36
                        color: index % 2 ? "#ffffff" : "#f1f3f5"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Text { text: "El." + index; color: "#212529"; Layout.fillWidth: true }

                            Button {
                                text: "Retirer"
                                onClicked: targetElement.connectionManager.removeNextElement(modelData)
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

    // Hook que l'hôte doit implémenter pour fournir un élément sélectionné
    // function selectElementToConnect(kind) { /* 'previous' | 'next' */ }
}


