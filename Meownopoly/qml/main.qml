import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "titleScreen/"
import QtQuick.Window
import Game

import Qt.labs.platform

ApplicationWindow {
    id: root
    width: 1280
    height: 720
    visible: true
    title: "Meownopoly"
    
    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: titleScreen
    }

    Component {
        id: titleScreen
        TitleScreen {
            onStartGameRequested: playerSetup.open()
        }
    }

    Component {
        id: gameBoard
        GameBoard {}
    }

    PlayerSetup {
        id: playerSetup
        anchors.centerIn: parent
        width: Math.max(parent.width * 0.4, Screen.pixelDensity * 150)
        onAccepted: {
            stackView.push(gameBoard)
        }
    }

    // Connect to Game signals
    Connections {
        target: Game
        function onGameStarted() {
            stackView.push(gameBoard)
        }
    }
}
