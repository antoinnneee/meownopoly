import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Game
import "../style"

Rectangle {
    id: root
    color: "#1a1a1a"  // Dark background for modern look

    signal startGameRequested()  // Add this signal

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
