import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: popup
    width: Screen.pixelDensity * 150
    height: Screen.pixelDensity * 100
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    background: Rectangle {
        color: "#2E86C1"
        border.color: "#666666"
        radius: 8
        border.width: 2
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 6
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.2) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Rectangle {
            Layout.fillWidth: true
            height: Screen.pixelDensity * 30
            radius: 8
            color:  Qt.darker("#2E86C1", 1.3)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                Text {
                    text: "Adresse IP du joueur hôte"
                    font.pointSize: 10
                    font.bold: true
                    color: "white"
                }
                TextField {
                    Layout.fillWidth: true
                    placeholderText: "Veuillez écrire l'adresse ip"
                    font.pointSize: 9
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: Screen.pixelDensity * 30
            radius: 8
            color:  Qt.darker("#2E86C1", 1.3)


            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                Text {
                    text: "Port stun du joueur hôte"
                    font.pointSize: 10
                    font.bold: true
                    color: "white"
                }
                TextField {
                    Layout.fillWidth: true
                    placeholderText: "Veuillez écrire le port stun du joueur hôte"
                    font.pointSize: 9
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                Layout.fillWidth: true
                text: "Rejoindre"
                font.pointSize: 10
                onClicked: popup.close()
                background: Rectangle {
                    radius: 8
                    color: "#69F0AE"
                    border.color: Qt.darker("#69F0AE", 1.3)
                    border.width: 2
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 6
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.2) }
                            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.0) }
                        }
                    }
                }
            }

            Button {
                Layout.fillWidth: true
                text: "Annuler"
                font.pointSize: 10
                onClicked: popup.close()
                background: Rectangle {
                    radius: 8
                    color: "#FF6B6B"
                    border.color: Qt.darker("#FF6B6B", 1.3)
                    border.width: 2
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 6
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.2) }
                            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.0) }
                        }
                    }
                }
            }
        }
    }
}