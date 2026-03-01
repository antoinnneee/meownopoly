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

    // Animation fluide sur le fond
    Behavior on color { ColorAnimation { duration: 300 } }

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
    // Palette Dynamique (Orange 🎮 <-> Violet 🛠️)
    // ═══════════════════════════════════════
    readonly property color cOrangePrimary: "#E67E22"
    readonly property color cOrangeSecondary: "#D4692A"
    readonly property color cOrangeDark: "#c0681a"
    readonly property color cVioletPrimary: "#9B59B6"
    readonly property color cVioletSecondary: "#BB77DD"
    readonly property color cVioletDark: "#6b4d8a"

    readonly property color bgRoot: isEditionMode ? "#2a2035" : "#2b2220"
    readonly property color bgPanel: isEditionMode ? "#352a42" : "#352a22"

    readonly property color cPrimary: isEditionMode ? cVioletPrimary : cOrangePrimary
    readonly property color cSecondary: isEditionMode ? cVioletSecondary : cOrangeSecondary
    readonly property color cDark: isEditionMode ? cVioletDark : cOrangeDark

    readonly property color bgInput: isEditionMode ? "#2e2440" : "#2e2418"
    readonly property color bgInputFocus: isEditionMode ? "#3f3350" : "#3f3025"
    readonly property color borderInput: isEditionMode ? "#5a4d6b" : "#6b5a40"

    readonly property color textHighlight: isEditionMode ? "#d4b8e8" : "#f0d4a8"
    readonly property color textMuted: isEditionMode ? "#7a6b8e" : "#8a7a60"
    readonly property color textDim: isEditionMode ? "#6b5a7a" : "#7a6540"

    readonly property color bgBtnHover: isEditionMode ? "#3f3350" : "#3f3020"
    readonly property color bgBtnPress: isEditionMode ? "#4a3d5a" : "#4a3520"
    readonly property color borderBtn: isEditionMode ? "#5a4d6b" : "#6b5a40"
    readonly property color borderBtnHover: isEditionMode ? "#9a8aae" : "#a08a6a"

    color: bgRoot

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

        // Separator dynamique central
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 12
            height: 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.15; color: root.cPrimary }
                GradientStop { position: 0.5; color: root.cSecondary }
                GradientStop { position: 0.85; color: root.cPrimary }
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
                    color: root.bgPanel
                    radius: 16
                    border.color: root.cPrimary
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 300 } }
                    Behavior on border.color { ColorAnimation { duration: 300 } }

                    // Accent bar top
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 3
                        radius: 16
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: root.cPrimary }
                            GradientStop { position: 1.0; color: root.cSecondary }
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
                                color: root.textHighlight
                                font.pixelSize: 17
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 300 } }
                            }
                        }

                        // — Nom de la session —
                        Text {
                            text: "Nom de la session *"
                            color: root.textHighlight
                            font.pixelSize: 14
                            font.bold: true
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }

                        TextField {
                            id: sessionNameInput
                            Layout.fillWidth: true
                            Layout.preferredHeight: 46
                            Layout.topMargin: 8
                            placeholderTextColor: root.textDim
                            color: "#f5f0ff"
                            font.pixelSize: 15
                            maximumLength: 50

                            background: Rectangle {
                                color: sessionNameInput.focus ? root.bgInputFocus : root.bgInput
                                radius: 10
                                border.color: {
                                    if (sessionNameInput.focus) return root.cPrimary
                                    if (sessionNameInput.text.length > 0 && sessionNameInput.text.length < 3)
                                        return "#E74C3C"
                                    return root.borderInput
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
                            color: sessionNameInput.text.length >= 3 ? root.textMuted : "#E74C3C"
                            font.pixelSize: 11
                            font.italic: true
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }

                        // Spacer
                        Item { Layout.preferredHeight: 16 }

                        // — Mot de passe —
                        Row {
                            spacing: 8
                            Text {
                                text: "Mot de passe"
                                color: root.textHighlight
                                font.pixelSize: 14
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 300 } }
                            }
                            Text {
                                text: "(optionnel)"
                                color: root.textMuted
                                font.pixelSize: 12
                                font.italic: true
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 300 } }
                            }
                        }

                        TextField {
                            id: sessionPasswordInput
                            Layout.fillWidth: true
                            Layout.preferredHeight: 46
                            Layout.topMargin: 8
                            placeholderText: "Laisser vide pour session ouverte"
                            placeholderTextColor: root.textDim
                            echoMode: showPasswordCheckbox.checked ? TextInput.Normal : TextInput.Password
                            color: "#f5f0ff"
                            font.pixelSize: 15
                            maximumLength: 30

                            background: Rectangle {
                                color: sessionPasswordInput.focus ? root.bgInputFocus : root.bgInput
                                radius: 10
                                border.color: sessionPasswordInput.focus ? root.cPrimary : root.borderInput
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
                                    color: showPasswordCheckbox.checked ? root.cPrimary : root.bgInput
                                    border.color: showPasswordCheckbox.checked ? root.cSecondary : root.borderInput
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
                                color: root.textMuted
                                font.pixelSize: 13
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 300 } }
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
                    color: root.bgPanel
                    radius: 16
                    border.color: root.cPrimary
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 300 } }
                    Behavior on border.color { ColorAnimation { duration: 300 } }

                    // Accent bar top
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 3
                        radius: 16
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: root.cPrimary }
                            GradientStop { position: 1.0; color: root.cSecondary }
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
                                color: root.textHighlight
                                font.pixelSize: 17
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 300 } }
                            }
                        }

                        // — Mode toggle —
                        Text {
                            text: "Mode de la session"
                            color: root.textHighlight
                            font.pixelSize: 14
                            font.bold: true
                            Behavior on color { ColorAnimation { duration: 300 } }
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
                                    color: modeCheckbox.checked ? root.cVioletPrimary : root.cOrangePrimary
                                    border.color: modeCheckbox.checked ? root.cVioletSecondary : root.cOrangeSecondary
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
                                    color: root.isEditionMode ? root.cVioletSecondary : root.cOrangeSecondary
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

                            // Cette description de mode utilise toujours du contraste par rapport au mode actif
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
                                Behavior on color { ColorAnimation { duration: 250 } }
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
                                    color: parent.pressed ? root.bgBtnPress : (parent.hovered ? root.bgBtnHover : root.bgPanel)
                                    radius: 10
                                    border.color: parent.hovered ? root.borderBtnHover : root.borderBtn
                                    border.width: 2
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                contentItem: Text {
                                    text: "Annuler"
                                    color: root.textHighlight
                                    font.pixelSize: 15
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                }

                                onClicked: root.backRequested()
                            }

                            // Créer
                            ParticleButton {
                                text: "✨ Créer"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 48
                                enabled: root.formValid

                                particleColor: root.cPrimary
                                particleColorVariation: root.cSecondary
                                particleCount: 30

                                background: Rectangle {
                                    color: parent.enabled ?
                                               (parent.down ? root.cDark : root.cPrimary) : root.bgBtnPress
                                    radius: 10
                                    border.color: parent.enabled ?
                                                      (parent.hovered ? "#FFFFFF" : root.cDark) : root.borderBtn
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
                                    color: parent.enabled ? "white" : root.textMuted
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                }

                                onClicked: {
                                    console.log("🎉 Création de session demandée")
                                    console.log("  - ID:", sessionId)
                                    console.log("  - Nom:", sessionNameInput.text)
                                    console.log("  - Mot de passe:", sessionPasswordInput.text)
                                    console.log("  - Mode:", root.isEditionMode ? "Edition" : "Jeu")

                                    root.sessionCreateRequested({
                                                                    sessionId: sessionId,
                                                                    name: sessionNameInput.text,
                                                                    password: sessionPasswordInput.text,
                                                                    isEditionMode: root.isEditionMode
                                                                })
                                    /*
                                    console.log("  - Id/Nom:", sessionNameInput.text)
                                    console.log("  - Mot de passe:", sessionPasswordInput.text)
                                    console.log("  - Mode:", root.isEditionMode ? "Edition" : "Jeu")

                                    root.sessionCreateRequested({
                                        sessionId: sessionNameInput.text,
                                        password: sessionPasswordInput.text,
                                        isEditionMode: root.isEditionMode
                                    })
                                    */
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
