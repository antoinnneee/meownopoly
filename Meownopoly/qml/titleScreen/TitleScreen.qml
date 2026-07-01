import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Particles
import Game
import Meownopoly.Account 1.0
import "../account/"
import theme
import ui_item

Rectangle {
    id: root
    objectName: "titleScreen"
    color: Theme.background  // Fond sombre pour un look moderne


    signal testViewRequested()  // Add this signal
    signal editorRequested();
    signal caseCreatorRequested(); // Add signal for case creator
    signal test3DRequested(); // Add signal for 3D test
    signal archiverRequested(); // Add signal for asset archiver
    signal launcherRequested(); // Add signal for launcher
    signal assetManagerTestRequested(); // Add signal for asset manager test
    signal multiplayerLobbyRequested(); // Signal for multiplayer lobby
    signal catwayTestRequested(); // Signal for Catway test interface


    // Account settings popup
    AccountSettingsPopup {
        id: accountSettingsPopup
    }

    // Fireworks system
    ParticleSystem {
        id: particleSystem
        anchors.fill: parent

        // Emitter for the initial burst
        Emitter {
            id: burstEmitter
            enabled: true
            anchors.fill: parent
            lifeSpan: 2000
            size: 10
            emitRate: 3
            velocity: AngleDirection {
                angle: 270
                angleVariation: 15
                magnitude: 200
                magnitudeVariation: 50
            }
        }

        // Particle image for the initial burst
        ImageParticle {
            id: firework
            source: "qrc:///particleresources/glowdot.png"

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
            burstEmitter.burst(1);
            firework.color = Qt.rgba(Math.random(), Math.random(), Math.random(), 1);
        }
    }

    // Title text
    Text {
        id: gameTitle
        text: "Meownopoly"
        color: Theme.textPrimary
        font.pixelSize: Theme.px(48)
        font.bold: true
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: parent.height * 0.1
        }
    }

    // Subtitle text
    Text {
        id: subtitle
        text: "The Feline Edition"
        color: Theme.textSecondary
        font.pixelSize: Theme.fontSizeDisplay
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: gameTitle.bottom
            topMargin: Theme.spacingL
        }
    }

    // Menu buttons container
    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.spacingHuge
        // Start Game Button
        Item {
            height: 20
        }

        MeowButton {
            id: startGameButton
            objectName: "startGameButton"
            text: "Start Game"
            Layout.preferredWidth: 200
            Layout.preferredHeight: 50

            baseColor: Theme.success

            onClicked: {
                root.multiplayerLobbyRequested()  // Emit the signal for multiplayer lobby
            }
        }


        // Create Server Button
        MeowButton {
            id: testUIButton
            text: "TEST UI"
            Layout.preferredWidth: 200
            Layout.preferredHeight: 50
            visible: false

            // baseColor par défaut = Theme.accent

            onClicked: {
                // TODO: Implement server creation functionality
                root.testViewRequested()
                console.log("testUIButton")
            }
        }
        // Create Server Button
        MeowButton {
            id: editorButton
            objectName: "editorButton"
            text: "EDITOR"
            Layout.preferredWidth: 200
            Layout.preferredHeight: 50

            // baseColor par défaut = Theme.accent

            onClicked: {
                root.editorRequested()
            }
        }

        // Case Creator Button
        MeowButton {
            id: caseCreatorButton
            text: "Case Creator"
            Layout.preferredWidth: 200
            Layout.preferredHeight: 50
            visible: false

            baseColor: "#9c27b0"

            onClicked: {
                root.caseCreatorRequested()
                console.log("Case Creator requested")
            }
        }

        // Gameplay Modules Test Button
        MeowButton {
            id: test3DButton
            objectName: "gameplayModulesButton"
            text: "🧩 Modules Gameplay"
            Layout.preferredWidth: 200
            Layout.preferredHeight: 50

            baseColor: "#ff5722"

            onClicked: {
                root.test3DRequested()
                console.log("Gameplay Modules requested")
            }
        }

        // Resource Launcher Button
        MeowButton {
            id: launcherButton
            objectName: "launcherButton"
            text: "🚀 Resource Launcher"
            Layout.preferredWidth: 200
            Layout.preferredHeight: 50

            baseColor: Theme.success

            onClicked: {
                root.launcherRequested()
                console.log("Resource Launcher requested")
            }
        }

        // Catway Test Button
        MeowButton {
            id: catwayTestButton
            objectName: "catwayTestButton"
            text: "📡 Test Catway"
            Layout.preferredWidth: 200
            Layout.preferredHeight: 50

            baseColor: "#00897b"

            onClicked: root.catwayTestRequested()
        }

        // Asset Manager Test Button
        MeowButton {
            id: assetManagerTestButton
            text: "🎨 Asset Manager Test"
            Layout.preferredWidth: 200
            Layout.preferredHeight: 50

            baseColor: "#9c27b0"

            onClicked: {
                root.assetManagerTestRequested()
                console.log("Asset Manager Test requested")
            }
        }
    }

    // Version text
    Text {
        text: "v0.2.0 editor edition"
        color: Theme.textMuted
        font.pixelSize: Theme.fontSizeMedium
        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: Theme.spacingL
        }
    }

    // Account info and settings button (top right corner)
    Rectangle {
        id: accountBar
        anchors {
            top: parent.top
            right: parent.right
            margins: Theme.spacingXXL
        }
        width: accountRow.width + 20
        height: 40
        color: Theme.surface
        radius: 20
        border.color: Theme.border
        border.width: 1

        RowLayout {
            id: accountRow
            anchors.centerIn: parent
            spacing: Theme.spacingL

            // Cat avatar
            Text {
                text: "🐱"
                font.pixelSize: Theme.fontSizeTitle
            }

            // Nickname
            Text {
                text: AccountManager.nickname
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeMedium
                font.bold: true
            }

            // Settings button
            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: settingsBtn.containsMouse ? Theme.border : Theme.surfaceAlt

                Behavior on color { ColorAnimation { duration: Theme.durationNormal } }

                Text {
                    text: "⚙️"
                    font.pixelSize: Theme.fontSizeMedium
                    anchors.centerIn: parent
                }

                MouseArea {
                    id: settingsBtn
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: accountSettingsPopup.open()
                }
            }
        }
    }
}
