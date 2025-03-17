import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "./style"
import Game

Dialog {
    id: root
    title: "Player Setup"
    modal: true
    standardButtons: Dialog.Ok | Dialog.Cancel
    width: 400
    height: 500

    property var availableColors: [
        { name: "Red Cat", color: "#e74c3c" },
        { name: "Blue Cat", color: "#3498db" },
        { name: "Green Cat", color: "#2ecc71" },
        { name: "Purple Cat", color: "#9b59b6" },
        { name: "Orange Cat", color: "#e67e22" },
        { name: "Yellow Cat", color: "#f1c40f" }
    ]
    
    // Lists for generating random cat-themed names
    property var catPrefixes: [
        "Whisker", "Paws", "Fluffy", "Mittens", "Shadow", "Tiger", "Luna", "Leo", 
        "Milo", "Bella", "Oliver", "Simba", "Nala", "Felix", "Cleo", "Max", "Lily",
        "Oscar", "Daisy", "Charlie", "Willow", "Jasper", "Coco", "Smokey", "Kitty"
    ]
    
    property var catSuffixes: [
        "Purr", "Meow", "Scratch", "Pounce", "Nap", "Cuddle", "Prowl", "Hiss",
        "Snuggle", "Hunter", "Climber", "Jumper", "Whisper", "Racer", "Dreamer",
        "Stalker", "Fluff", "Trouble", "Explorer", "Snoozer", "Nibbler"
    ]
    
    // Generate a random cat name
    function generateRandomName() {
        const prefix = catPrefixes[Math.floor(Math.random() * catPrefixes.length)];
        const suffix = catSuffixes[Math.floor(Math.random() * catSuffixes.length)];
        return prefix + " " + suffix;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 20

        ListView {
            id: playerList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: 4  // Maximum 4 players
            spacing: 10
            clip: true

            delegate: Rectangle {
                width: playerList.width
                height: 80
                color: "#f5f6fa"
                radius: 8

                RowLayout {
                    anchors {
                        fill: parent
                        margins: 10
                    }
                    spacing: 10

                    TextField {
                        id: nameField
                        Layout.fillWidth: true
                        placeholderText: "Player " + (index + 1)
                        text: ""
                    }

                    ComboBox {
                        id: colorCombo
                        model: availableColors
                        textRole: "name"
                        Layout.preferredWidth: 120
                        currentIndex: index
                        delegate: ItemDelegate {
                            width: colorCombo.width
                            contentItem: Rectangle {
                                color: availableColors[index].color
                                implicitHeight: 30
                                radius: 4
                                Text {
                                    anchors.centerIn: parent
                                    text: availableColors[index].name
                                    color: "white"
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        color: availableColors[colorCombo.currentIndex].color
                    }
                    
                    // Random name button
                    Button {
                        width: 30
                        height: 30
                        icon.source: "qrc:/asset/dice.png"  // We'll add this icon later
                        icon.color: "#7f8c8d"
                        
                        background: Rectangle {
                            color: "transparent"
                            border.color: "#bdc3c7"
                            border.width: 1
                            radius: 4
                        }
                        
                        ToolTip.visible: hovered
                        ToolTip.text: "Generate random name"
                        
                        Text {
                            anchors.centerIn: parent
                            text: "🎲"
                            font.pixelSize: 16
                        }
                        
                        onClicked: {
                            nameField.text = generateRandomName();
                        }
                    }
                }
            }
        }
    }

    // Generate random names for all players on dialog opening
    Component.onCompleted: {
        // Short delay to ensure ListView items are created
        generateNamesTimer.start();
    }
    
    Timer {
        id: generateNamesTimer
        interval: 100
        repeat: false
        onTriggered: {
            // Generate random names for all players
            for (var i = 0; i < playerList.count; i++) {
                var item = playerList.itemAtIndex(i);
                if (item) {
                    item.children[0].children[0].text = generateRandomName();
                }
            }
        }
    }

    onAccepted: {
        var players = [];
        for (var i = 0; i < playerList.count; i++) {
            var item = playerList.itemAtIndex(i);
            if (item) {
                var name = item.children[0].children[0].text || "Player " + (i + 1);
                var color = availableColors[item.children[0].children[1].currentIndex].color;
                players.push({ name: name, color: color });
            }
        }
        Game.setupPlayers(players);
    }
} 
