import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Game
import "../style"

Rectangle {
    id: root
    color: "#1a1a1a"  // Dark background for modern look

    signal startGameRequested()  // Add this signal
    signal testViewRequested()  // Add this signal
    signal editorRequested();
    signal caseCreatorRequested(); // Add signal for case creator

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
            topMargin: parent.height * 0.2
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
                testViewRequested()
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
                editorRequested()
                console.log("show editor")
            }
        }

        // Case Creator Button
        Button {
            id: caseCreatorButton
            text: "Case Creator"
            Layout.preferredWidth: 200
            Layout.preferredHeight: 50

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
                caseCreatorRequested()
                console.log("Case Creator requested")
            }
        }
    }

    // Version text
    Text {
        text: "v1.0.0"
        color: "#808080"
        font.pixelSize: 14
        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: 10
        }
    }
}
