import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "./components"

import ui_item

/**
 * Écran de création de session
 * Front-end uniquement - Les inputs sont validés mais non fonctionnels
 */
Rectangle {
    id: root

    color: "#1a1a1a"

    // Signaux pour la navigation
    signal backRequested()
    signal sessionCreateRequested(var sessionData)

    // État du formulaire
    property bool formValid: sessionNameInput.text.length >= 3 &&
                            sessionPasswordInput.text.length >= 3

    property int maxPlayersSelection: 4
    property bool isPublicSession: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 24

        // HEADER
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            // Bouton retour
            BackButton {
                onBackClicked: root.backRequested()
            }

            // Titre centré
            Item {
                Layout.fillWidth: true

                Text {
                    text: "🐱 Créer une Session"
                    color: "#ffffff"
                    font.pixelSize: 28
                    font.bold: true
                    anchors.centerIn: parent
                }
            }

            // Spacer pour équilibrer le layout
            Item {
                width: 40
                height: 40
            }
        }

        // Separator
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#444444"
        }

        // FORMULAIRE PRINCIPAL
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: 20

                // Section: Informations générales
                GroupBox {
                    Layout.fillWidth: true
                    Layout.preferredWidth: Math.min(600, parent.width * 0.8)
                    Layout.alignment: Qt.AlignHCenter

                    background: Rectangle {
                        color: "#2a2a2a"
                        radius: 12
                        border.color: "#444444"
                        border.width: 2
                    }

                    label: Text {
                        text: "📝 Informations de la session"
                        color: "#ffffff"
                        font.pixelSize: 18
                        font.bold: true
                        padding: 10
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 16

                        // Nom de la session
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Nom de la session *"
                                color: "#cccccc"
                                font.pixelSize: 14
                                font.bold: true
                            }

                            TextField {
                                id: sessionNameInput
                                Layout.fillWidth: true
                                Layout.preferredHeight: 45

                                placeholderText: "ex: Partie du vendredi soir"

                                color: "#ffffff"
                                font.pixelSize: 16

                                background: Rectangle {
                                    color: sessionNameInput.focus ? "#333333" : "#1a1a1a"
                                    radius: 8
                                    border.color: {
                                        if (sessionNameInput.focus) return "#4caf50"
                                        if (sessionNameInput.text.length > 0 && sessionNameInput.text.length < 3)
                                            return "#ff9800"
                                        return "#555555"
                                    }
                                    border.width: 2

                                    Behavior on border.color {
                                        ColorAnimation { duration: 200 }
                                    }
                                }

                                maximumLength: 50
                            }

                            // Compteur de caractères
                            Text {
                                text: sessionNameInput.text.length + "/50 caractères" +
                                     (sessionNameInput.text.length < 3 ? " (minimum 3)" : "")
                                color: sessionNameInput.text.length >= 3 ? "#888888" : "#ff9800"
                                font.pixelSize: 12
                                font.italic: true
                            }
                        }

                        // Mot de passe
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Mot de passe *"
                                color: "#cccccc"
                                font.pixelSize: 14
                                font.bold: true
                            }

                            TextField {
                                id: sessionPasswordInput
                                Layout.fillWidth: true
                                Layout.preferredHeight: 45

                                placeholderText: "Minimum 3 caractères"
                                echoMode: showPasswordCheckbox.checked ? TextInput.Normal : TextInput.Password

                                color: "#ffffff"
                                font.pixelSize: 16

                                background: Rectangle {
                                    color: sessionPasswordInput.focus ? "#333333" : "#1a1a1a"
                                    radius: 8
                                    border.color: {
                                        if (sessionPasswordInput.focus) return "#4caf50"
                                        if (sessionPasswordInput.text.length > 0 && sessionPasswordInput.text.length < 3)
                                            return "#ff9800"
                                        return "#555555"
                                    }
                                    border.width: 2

                                    Behavior on border.color {
                                        ColorAnimation { duration: 200 }
                                    }
                                }

                                maximumLength: 30
                            }

                            // Checkbox pour afficher le mot de passe
                            Row {
                                spacing: 8

                                CheckBox {
                                    id: showPasswordCheckbox
                                    checked: false

                                    indicator: Rectangle {
                                        width: 20
                                        height: 20
                                        radius: 4
                                        color: "#1a1a1a"
                                        border.color: showPasswordCheckbox.checked ? "#4caf50" : "#555555"
                                        border.width: 2

                                        Text {
                                            text: "✓"
                                            color: "#4caf50"
                                            font.pixelSize: 16
                                            font.bold: true
                                            anchors.centerIn: parent
                                            visible: showPasswordCheckbox.checked
                                        }
                                    }
                                }

                                Text {
                                    text: "Afficher le mot de passe"
                                    color: "#888888"
                                    font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }

                // Section: Configuration de la partie
                GroupBox {
                    Layout.fillWidth: true
                    Layout.preferredWidth: Math.min(600, parent.width * 0.8)
                    Layout.alignment: Qt.AlignHCenter

                    background: Rectangle {
                        color: "#2a2a2a"
                        radius: 12
                        border.color: "#444444"
                        border.width: 2
                    }

                    label: Text {
                        text: "⚙️ Configuration"
                        color: "#ffffff"
                        font.pixelSize: 18
                        font.bold: true
                        padding: 10
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 16

                        // Nombre de joueurs maximum
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Nombre de joueurs maximum"
                                color: "#cccccc"
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Row {
                                spacing: 12

                                Repeater {
                                    model: [2, 3, 4, 5, 6]

                                    delegate: Rectangle {
                                        width: 60
                                        height: 60
                                        radius: 30
                                        color: maxPlayersButtonMouseArea.containsMouse ?
                                               (maxPlayersSelection === modelData ? "#4caf50" : "#444444") :
                                               (maxPlayersSelection === modelData ? "#4caf50" : "#333333")
                                        border.color: maxPlayersSelection === modelData ? "#ffffff" : "#555555"
                                        border.width: 2

                                        property int playersCount: modelData

                                        Behavior on color {
                                            ColorAnimation { duration: 200 }
                                        }

                                        Text {
                                            text: modelData
                                            color: "#ffffff"
                                            font.pixelSize: 24
                                            font.bold: true
                                            anchors.centerIn: parent
                                        }

                                        MouseArea {
                                            id: maxPlayersButtonMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            onClicked: {
                                                root.maxPlayersSelection = modelData
                                            }
                                        }

                                        // Animation hover
                                        scale: maxPlayersButtonMouseArea.containsMouse ? 1.1 : 1.0
                                        Behavior on scale {
                                            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                                        }
                                    }
                                }
                            }

                            Text {
                                text: "💡 " + (maxPlayersSelection === 2 ? "Duel intense" :
                                             maxPlayersSelection === 3 ? "Trio stratégique" :
                                             maxPlayersSelection === 4 ? "Partie classique (recommandé)" :
                                             maxPlayersSelection === 5 ? "Partie étendue" :
                                             "Chaos total !")
                                color: "#888888"
                                font.pixelSize: 12
                                font.italic: true
                            }
                        }

                        // Visibilité de la session
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Visibilité"
                                color: "#cccccc"
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Row {
                                spacing: 12

                                // Publique
                                Rectangle {
                                    width: 140
                                    height: 50
                                    radius: 8
                                    color: visibilityMouseArea1.containsMouse ?
                                           (isPublicSession ? "#4caf50" : "#444444") :
                                           (isPublicSession ? "#4caf50" : "#333333")
                                    border.color: isPublicSession ? "#ffffff" : "#555555"
                                    border.width: 2

                                    Behavior on color {
                                        ColorAnimation { duration: 200 }
                                    }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 8

                                        Text {
                                            text: "🌐"
                                            font.pixelSize: 18
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: "Publique"
                                            color: "#ffffff"
                                            font.pixelSize: 14
                                            font.bold: true
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: visibilityMouseArea1
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.isPublicSession = true
                                    }
                                }

                                // Privée
                                Rectangle {
                                    width: 140
                                    height: 50
                                    radius: 8
                                    color: visibilityMouseArea2.containsMouse ?
                                           (!isPublicSession ? "#ff9800" : "#444444") :
                                           (!isPublicSession ? "#ff9800" : "#333333")
                                    border.color: !isPublicSession ? "#ffffff" : "#555555"
                                    border.width: 2

                                    Behavior on color {
                                        ColorAnimation { duration: 200 }
                                    }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 8

                                        Text {
                                            text: "🔒"
                                            font.pixelSize: 18
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: "Privée"
                                            color: "#ffffff"
                                            font.pixelSize: 14
                                            font.bold: true
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: visibilityMouseArea2
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.isPublicSession = false
                                    }
                                }
                            }

                            Text {
                                text: isPublicSession ?
                                     "📢 Votre session apparaîtra dans la liste publique" :
                                     "🔐 Seuls les joueurs avec le mot de passe pourront rejoindre"
                                color: "#888888"
                                font.pixelSize: 12
                                font.italic: true
                            }
                        }
                    }
                }

                // Spacer
                Item {
                    Layout.fillHeight: true
                    Layout.minimumHeight: 20
                }
            }
        }

        // Separator
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#444444"
        }

        // FOOTER AVEC BOUTONS
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 16

            // Bouton Annuler
            Button {
                Layout.preferredWidth: 150
                Layout.preferredHeight: 50

                text: "Annuler"

                background: Rectangle {
                    color: parent.pressed ? "#555555" : (parent.hovered ? "#444444" : "#333333")
                    radius: 8
                    border.color: "#666666"
                    border.width: 2

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }

                contentItem: Text {
                    text: parent.text
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: root.backRequested()
            }

            // Bouton Créer la session
            ParticleButton {
                text: "✨ Créer la session"
                Layout.preferredWidth: 200
                Layout.preferredHeight: 50

                enabled: root.formValid

                particleColor: "#4caf50"
                particleColorVariation: "#8bc34a"
                particleCount: 30

                background: Rectangle {
                    color: parent.enabled ?
                           (parent.down ? "#388e3c" : "#4caf50") : "#555555"
                    radius: 8
                    border.color: parent.enabled ?
                                  (parent.hovered ? "#FFFFFF" : "#388e3c") : "#666666"
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

                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 16
                    font.bold: true
                    color: parent.enabled ? "white" : "#888888"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    console.log("🎉 Session créée (front-end uniquement)")
                    console.log("  - Nom:", sessionNameInput.text)
                    console.log("  - Mot de passe:", sessionPasswordInput.text)
                    console.log("  - Max joueurs:", maxPlayersSelection)
                    console.log("  - Publique:", isPublicSession)

                    // Émettre le signal avec les données
                    root.sessionCreateRequested({
                        name: sessionNameInput.text,
                        password: sessionPasswordInput.text,
                        maxPlayers: maxPlayersSelection,
                        isPublic: isPublicSession
                    })
                }
            }
        }

        // Note pour développeurs
        Text {
            text: "⚠️ Interface front-end uniquement - Logique de création non implémentée"
            color: "#666666"
            font.pixelSize: 11
            font.italic: true
            Layout.alignment: Qt.AlignHCenter
        }
    }

    // Animation d'entrée
    opacity: 0
    Component.onCompleted: fadeInAnimation.start()

    NumberAnimation {
        id: fadeInAnimation
        target: root
        property: "opacity"
        from: 0
        to: 1
        duration: 300
        easing.type: Easing.OutQuad
    }
}
