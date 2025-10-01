import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Particles
import Game

Rectangle {
    id: root
    color: "#1a1a1a"  // Dark background for modern look

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

    signal startGameRequested()  // Add this signal
    signal testViewRequested()  // Add this signal
    signal editorRequested();
    signal caseCreatorRequested(); // Add signal for case creator
    signal test3DRequested(); // Add signal for 3D test
    signal archiverRequested(); // Add signal for asset archiver
    signal launcherRequested(); // Add signal for launcher
    signal assetManagerTestRequested(); // Add signal for asset manager test
    // Title text
    Text {
        id: gameTitle
        text: "Meownopoly"
        color: "#ffffff"
        font.pixelSize: 48
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
        color: "#cccccc"
        font.pixelSize: 24
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: gameTitle.bottom
            topMargin: 10
        }
    }

    // Menu buttons container
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 20
        // Start Game Button
        Item {
            height: 20
        }

        Button {
            id: startGameButton
            text: "Start Game"
            Layout.preferredWidth: 200
            Layout.preferredHeight: 50
            
            background: Rectangle {
                color: startGameButton.pressed ? "#2e7d32" : "#4caf50"
                radius: 8
            }
            
            contentItem: Text {
                text: startGameButton.text
                color: "white"
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                root.startGameRequested()  // Emit the signal
            }
        }

        // Create Server Button
        Button {
            id: createServerButton
            text: "Create Server"
            Layout.preferredWidth: 200
            Layout.preferredHeight: 50

            background: Rectangle {
                color: createServerButton.pressed ? "#1565c0" : "#2196f3"
                radius: 8
            }

            contentItem: Text {
                text: createServerButton.text
                color: "white"
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                // TODO: Implement server creation functionality
                console.log("Create server clicked")
            }
        }

        // Create Server Button
        Button {
            id: testUIButton
            text: "TEST UI"
            Layout.preferredWidth: 200
            Layout.preferredHeight: 50
            visible: false

            background: Rectangle {
                color: testUIButton.pressed ? "#1565c0" : "#2196f3"
                radius: 8
            }

            contentItem: Text {
                text: testUIButton.text
                color: "white"
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                // TODO: Implement server creation functionality
                root.testViewRequested()
                console.log("testUIButton")
            }
        }
        // Create Server Button
        Button {
            id: editorButton
            text: "EDITOR"
            Layout.preferredWidth: 200
            Layout.preferredHeight: 50

            background: Rectangle {
                color: editorButton.pressed ? "#1565c0" : "#2196f3"
                radius: 8
            }

            contentItem: Text {
                text: editorButton.text
                color: "white"
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                // TODO: Implement server creation functionality
                root.editorRequested()
                console.log("show editor")
            }
        }

        // Case Creator Button
        Button {
            id: caseCreatorButton
            text: "Case Creator"
            Layout.preferredWidth: 200
            Layout.preferredHeight: 50
            visible: false

            background: Rectangle {
                color: caseCreatorButton.pressed ? "#6a1b9a" : "#9c27b0"
                radius: 8
            }

            contentItem: Text {
                text: caseCreatorButton.text
                color: "white"
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                root.caseCreatorRequested()
                console.log("Case Creator requested")
            }
        }

        // Test 3D Button
        Button {
            id: test3DButton
            text: "🐱 Test Component"
            Layout.preferredWidth: 200
            Layout.preferredHeight: 50

            background: Rectangle {
                color: test3DButton.pressed ? "#d84315" : "#ff5722"
                radius: 8
            }

            contentItem: Text {
                text: test3DButton.text
                color: "white"
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                root.test3DRequested()
                console.log("Test Component requested")
            }
        }
        
        // Resource Launcher Button
        Button {
            id: launcherButton
            text: "🚀 Resource Launcher"
            Layout.preferredWidth: 200
            Layout.preferredHeight: 50

            background: Rectangle {
                color: launcherButton.pressed ? "#388e3c" : "#4caf50"
                radius: 8
            }

            contentItem: Text {
                text: launcherButton.text
                color: "white"
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                root.launcherRequested()
                console.log("Resource Launcher requested")
            }
        }
        
        // Asset Manager Test Button
        Button {
            id: assetManagerTestButton
            text: "🎨 Asset Manager Test"
            Layout.preferredWidth: 200
            Layout.preferredHeight: 50

            background: Rectangle {
                color: assetManagerTestButton.pressed ? "#7b1fa2" : "#9c27b0"
                radius: 8
            }

            contentItem: Text {
                text: assetManagerTestButton.text
                color: "white"
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                root.assetManagerTestRequested()
                console.log("Asset Manager Test requested")
            }
        }
    }

    // Version text
    Text {
        text: "v0.2.0 editor edition"
        color: "#808080"
        font.pixelSize: 14
        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: 10
        }
    }
}
