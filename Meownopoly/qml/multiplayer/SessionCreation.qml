import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Particles
import "./components"
import ui_item
import AssetManager

/**
 * Écran de création de session
 * Utilise le ChatClient mutualisé du parent
 */
Rectangle {
    id: root

    color: "#2b2220"

    // Propriété pour recevoir le ChatClient du parent
    required property var chatClient

    // Signaux pour la navigation
    signal backRequested()
    signal sessionCreateRequested(var sessionData)

    // État du formulaire — seul le nom est obligatoire
    property bool formValid: sessionNameInput.text.length >= 3

    // Mode : Edition ou Jeu
    property bool isEditionMode: false

    // ═══════════════════════════════════════
    // Patounes — Particle animation background
    // ═══════════════════════════════════════
    ParticleSystem {
        id: particleSystem
        anchors.fill: parent
        clip: true

        Emitter {
            id: burstEmitter
            enabled: true
            anchors.fill: parent
            lifeSpan: 2000
            size: 50
            emitRate: 15
            velocity: AngleDirection {
                angle: 270
                angleVariation: 15
                magnitude: 200
                magnitudeVariation: 50
            }
        }

        ImageParticle {
            id: firework
            source: AssetManager.getAssetById("ui", "particules", "pawn1").path
            color: Qt.rgba(Math.random(), Math.random(), Math.random(), 1)
            colorVariation: 0.5
            alpha: 0.75
            rotationVariation: 360
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            burstEmitter.burst(1)
            firework.color = Qt.rgba(Math.random(), Math.random(), Math.random(), 1)
        }
    }

    // ═══════════════════════════════════════
    // Layout principal — pas de scroll
    // ═══════════════════════════════════════
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 0

        // HEADER
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            BackButton {
                onBackClicked: root.backRequested()
            }

            Item {
                Layout.fillWidth: true
                Text {
                    text: "🐱 Créer une Session"
                    color: "#f5f0ff"
                    font.pixelSize: 28
                    font.bold: true
                    anchors.centerIn: parent
                }
            }

            Item { width: 40; height: 40 }
        }

        // Separator gradient orange → violet
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 12
            height: 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.15; color: "#E67E22" }
                GradientStop { position: 0.5; color: "#D4692A" }
                GradientStop { position: 0.85; color: "#E67E22" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // ═══════════════════════════════════════
        // FORMULAIRE — layout horizontal spacieux
        // ═══════════════════════════════════════
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 20

            // Conteneur central limité en largeur
            RowLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width, 820)
                height: Math.min(parent.height, 420)
                spacing: 28

                // ── COLONNE GAUCHE : Nom + Mot de passe ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#352a22"
                    radius: 16
                    border.color: "#E67E22"
                    border.width: 1

                    // Accent bar top
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 3
                        radius: 16
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#E67E22" }
                            GradientStop { position: 1.0; color: "#D4692A" }
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 0

                        // Section header
                        Row {
                            spacing: 10
                            Layout.bottomMargin: 20

                            Text {
                                text: "📝"
                                font.pixelSize: 20
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Informations"
                                color: "#f0d4a8"
                                font.pixelSize: 17
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // — Nom de la session —
                        Text {
                            text: "Nom de la session *"
                            color: "#f0d4a8"
                            font.pixelSize: 14
                            font.bold: true
                        }

                        TextField {
                            id: sessionNameInput
                            Layout.fillWidth: true
                            Layout.preferredHeight: 46
                            Layout.topMargin: 8
                            placeholderText: "ex: Partie du vendredi soir"
                            placeholderTextColor: "#7a6540"
                            color: "#f5f0ff"
                            font.pixelSize: 15
                            maximumLength: 50

                            background: Rectangle {
                                color: sessionNameInput.focus ? "#3f3025" : "#2e2418"
                                radius: 10
                                border.color: {
                                    if (sessionNameInput.focus) return "#E67E22"
                                    if (sessionNameInput.text.length > 0 && sessionNameInput.text.length < 3)
                                        return "#E74C3C"
                                    return "#6b5a40"
                                }
                                border.width: 2
                                Behavior on border.color { ColorAnimation { duration: 200 } }
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                        }

                        Text {
                            Layout.topMargin: 6
                            text: sessionNameInput.text.length + "/50" +
                                 (sessionNameInput.text.length > 0 && sessionNameInput.text.length < 3 ? "  ⚠ min. 3" : "")
                            color: sessionNameInput.text.length >= 3 ? "#8a7a60" : "#E74C3C"
                            font.pixelSize: 11
                            font.italic: true
                        }

                        // Spacer
                        Item { Layout.preferredHeight: 16 }

                        // — Mot de passe —
                        Row {
                            spacing: 8
                            Text {
                                text: "Mot de passe"
                                color: "#f0d4a8"
                                font.pixelSize: 14
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "(optionnel)"
                                color: "#8a7a60"
                                font.pixelSize: 12
                                font.italic: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        TextField {
                            id: sessionPasswordInput
                            Layout.fillWidth: true
                            Layout.preferredHeight: 46
                            Layout.topMargin: 8
                            placeholderText: "Laisser vide pour session ouverte"
                            placeholderTextColor: "#7a6540"
                            echoMode: showPasswordCheckbox.checked ? TextInput.Normal : TextInput.Password
                            color: "#f5f0ff"
                            font.pixelSize: 15
                            maximumLength: 30

                            background: Rectangle {
                                color: sessionPasswordInput.focus ? "#3f3025" : "#2e2418"
                                radius: 10
                                border.color: sessionPasswordInput.focus ? "#E67E22" : "#6b5a40"
                                border.width: 2
                                Behavior on border.color { ColorAnimation { duration: 200 } }
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                        }

                        Row {
                            Layout.topMargin: 10
                            spacing: 10

                            CheckBox {
                                id: showPasswordCheckbox
                                checked: false
                                indicator: Rectangle {
                                    width: 22; height: 22; radius: 6
                                    color: showPasswordCheckbox.checked ? "#E67E22" : "#2e2418"
                                    border.color: showPasswordCheckbox.checked ? "#F0983A" : "#6b5a40"
                                    border.width: 2
                                    Behavior on color { ColorAnimation { duration: 200 } }

                                    Text {
                                        text: "✓"; color: "#ffffff"
                                        font.pixelSize: 16; font.bold: true
                                        anchors.centerIn: parent
                                        visible: showPasswordCheckbox.checked
                                    }
                                }
                            }

                            Text {
                                text: "Afficher le mot de passe"
                                color: "#a08a6a"
                                font.pixelSize: 13
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Fill remaining space
                        Item { Layout.fillHeight: true }
                    }
                }

                // ── COLONNE DROITE : Mode + Actions ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#352a22"
                    radius: 16
                    border.color: "#E67E22"
                    border.width: 1

                    // Accent bar top
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 3
                        radius: 16
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#9B59B6" }
                            GradientStop { position: 1.0; color: "#E67E22" }
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 0

                        // Section header
                        Row {
                            spacing: 10
                            Layout.bottomMargin: 20

                            Text {
                                text: "⚙️"
                                font.pixelSize: 20
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Configuration"
                                color: "#f0d4a8"
                                font.pixelSize: 17
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // — Mode toggle —
                        Text {
                            text: "Mode de la session"
                            color: "#f0d4a8"
                            font.pixelSize: 14
                            font.bold: true
                        }

                        // Toggle switch row
                        Row {
                            Layout.topMargin: 14
                            spacing: 16

                            CheckBox {
                                id: modeCheckbox
                                checked: root.isEditionMode
                                onCheckedChanged: root.isEditionMode = checked

                                indicator: Rectangle {
                                    width: 56; height: 30; radius: 15
                                    color: modeCheckbox.checked ? "#9B59B6" : "#E67E22"
                                    border.color: modeCheckbox.checked ? "#BB77DD" : "#F0983A"
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 250 } }

                                    Rectangle {
                                        width: 24; height: 24; radius: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: modeCheckbox.checked ? parent.width - width - 3 : 3
                                        color: "#f5f0ff"
                                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                                    }
                                }
                            }

                            Row {
                                spacing: 8
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    text: root.isEditionMode ? "🛠️" : "🎮"
                                    font.pixelSize: 22
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: root.isEditionMode ? "Édition" : "Jeu"
                                    color: root.isEditionMode ? "#BB77DD" : "#F0983A"
                                    font.pixelSize: 18
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                            }
                        }

                        // Description du mode
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.topMargin: 16
                            height: modeDescText.implicitHeight + 24
                            radius: 10
                            color: root.isEditionMode ? "#352840" : "#3d2d20"
                            border.color: root.isEditionMode ? "#6b4d8a" : "#8a6530"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 250 } }
                            Behavior on border.color { ColorAnimation { duration: 250 } }

                            Text {
                                id: modeDescText
                                anchors.centerIn: parent
                                width: parent.width - 24
                                text: root.isEditionMode ?
                                     "📐 Collaborer sur l'éditeur de carte avec d'autres joueurs" :
                                     "🎲 Lancer une partie de Meownopoly classique"
                                color: root.isEditionMode ? "#c9a8e8" : "#e8c8a0"
                                font.pixelSize: 13
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        // Fill space
                        Item { Layout.fillHeight: true }

                        // ── Boutons d'action ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            // Annuler
                            Button {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 48

                                background: Rectangle {
                                    color: parent.pressed ? "#4a3520" : (parent.hovered ? "#3f3020" : "#352a22")
                                    radius: 10
                                    border.color: parent.hovered ? "#a08a6a" : "#6b5a40"
                                    border.width: 2
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                contentItem: Text {
                                    text: "Annuler"
                                    color: "#f0d4a8"
                                    font.pixelSize: 15
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: root.backRequested()
                            }

                            // Créer
                            ParticleButton {
                                text: "✨ Créer"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 48
                                enabled: root.formValid

                                particleColor: "#E67E22"
                                particleColorVariation: "#9B59B6"
                                particleCount: 30

                                background: Rectangle {
                                    color: parent.enabled ?
                                           (parent.down ? "#c0681a" : "#E67E22") : "#4a3d5a"
                                    radius: 10
                                    border.color: parent.enabled ?
                                                  (parent.hovered ? "#FFFFFF" : "#c0681a") : "#5a4d6b"
                                    border.width: 2

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        radius: 8
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.15) }
                                            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.0) }
                                        }
                                    }

                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                contentItem: Text {
                                    text: parent.text
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: parent.enabled ? "white" : "#8a7a60"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    console.log("🎉 Création de session demandée")
                                    console.log("  - Nom - Id :", sessionNameInput.text)
                                    console.log("  - Mot de passe:", sessionPasswordInput.text)
                                    console.log("  - Mode:", root.isEditionMode ? "Edition" : "Jeu")

                                    root.sessionCreateRequested({
                                        sessionId: sessionNameInput.text,
                                        password: sessionPasswordInput.text,
                                        isEditionMode: root.isEditionMode
                                    })
                                }
                            }
                        }
                    }
                }
            }
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
