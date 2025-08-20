import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: window
    color: "#1e1e1e"
    
    signal backRequested()
    
    // Back button
    Button {
        id: backButton
        text: "← Back"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 10
        z: 100
        
        onClicked: window.backRequested()
    }
    
    Text {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 15
        text: "Asset Manager Test"
        color: "white"
        font.pixelSize: 20
        font.bold: true
    }

    ScrollView {
        anchors {
            left: parent.left
            right: parent.right
            top: backButton.bottom
            bottom: parent.bottom
            margins: 20
        }

        ColumnLayout {
            width: window.width - 40
            spacing: 20

            Text {
                text: "Asset Manager Test"
                font.pixelSize: 24
                font.bold: true
                color: "white"
            }

            // Test decoration model
            GroupBox {
                title: "All Decorations"
                Layout.fillWidth: true
                Layout.preferredHeight: 200
                label: Label{
                    text: parent.title
                    color: "white"
                }

                ListView {
                    id: lv
                    anchors.fill: parent
                    model: AssetManager.decorationModel
                    delegate: Rectangle {
                        width: lv.width
                        height: 60
                        border.color: "gray"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10

                            Image {
                                source: model.path
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                fillMode: Image.PreserveAspectFit
                                
                                Rectangle {
                                    anchors.fill: parent
                                    color: "lightgray"
                                    visible: parent.status !== Image.Ready
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "IMG"
                                        color: "gray"
                                    }
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                Text { text: "Type: " + model.type; color: "black" }
                                Text { text: "ID: " + model.id; color: "black" }
                                Text { text: "Size: " + model.width + "x" + model.height; color: "black" }
                                Text { text: "Ratio: " + model.ratio.toFixed(2); color: "black" }
                            }
                        }
                    }
                }
            }

            // Test filtered model for grass
            GroupBox {
                title: "Grass Decorations Only"
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                label: Label{
                    text: parent.title
                    color: "white"
                }


                ListView {
                    id: lvGrass
                    anchors.fill: parent
                    model: AssetManager.getTypeModel("decoration", "grass")
                    delegate: Rectangle {
                        width: lvGrass.width
                        height: 40
                        border.color: "green"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 5

                            Image {
                                source: model.path
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                fillMode: Image.PreserveAspectFit
                                
                                Rectangle {
                                    anchors.fill: parent
                                    color: "lightgreen"
                                    visible: parent.status !== Image.Ready
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "🌱"
                                        font.pixelSize: 16
                                    }
                                }
                            }

                            Text {
                                text: "Grass " + model.id + " (" + model.filename + ")"
                                Layout.fillWidth: true
                                color: "black"
                            }
                        }
                    }
                }
            }

            // Test player icons
            GroupBox {
                title: "Player Icons"
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                label: Label{
                    text: parent.title
                    color: "white"
                }


                ListView {
                    anchors.fill: parent
                    model: AssetManager.playerIconModel
                    delegate: Rectangle {
                        width: parent.width
                        height: 40
                        border.color: "blue"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 5

                            Image {
                                source: model.path
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                fillMode: Image.PreserveAspectFit
                                
                                Rectangle {
                                    anchors.fill: parent
                                    color: "lightblue"
                                    visible: parent.status !== Image.Ready
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: "👤"
                                        font.pixelSize: 16
                                    }
                                }
                            }

                            Text {
                                text: "Player " + model.id + " (" + model.filename + ")"
                                Layout.fillWidth: true
                                color: "white"
                            }
                        }
                    }
                }
            }

            // Test direct path access
            GroupBox {
                title: "Direct Path Access Test"
                Layout.fillWidth: true
                label: Label{
                    text: parent.title
                    color: "white"
                }


                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Text {
                        text: "Grass decoration 1: " + AssetManager.getDecorationPath("grass", "1")
                        wrapMode: Text.Wrap
                        width: parent.width
                        color: "white"
                    }

                    Text {
                        text: "Tree decoration 2: " + AssetManager.getDecorationPath("tree", "2")
                        wrapMode: Text.Wrap
                        width: parent.width
                        color: "white"
                    }

                    Text {
                        text: "Player icon 3: " + AssetManager.getPlayerIconPath("3")
                        wrapMode: Text.Wrap
                        width: parent.width
                        color: "white"
                    }

                    Button {
                        text: "Reload Assets"
                        onClicked: AssetManager.loadAssets()
                    }
                }
            }

            // Metadata Generation Panel
            GroupBox {
                title: "Metadata Generation"
                Layout.fillWidth: true
                label: Label{
                    text: parent.title
                    color: "white"
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 15

                    Text {
                        text: "Generate metadata.json files automatically from image files"
                        color: "white"
                        wrapMode: Text.Wrap
                        width: parent.width
                    }

                    // Available assets scan
                    Rectangle {
                        width: parent.width
                        height: 120
                        color: "#333333"
                        border.color: "#555555"
                        radius: 4

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10

                            Text {
                                text: "Available Assets:"
                                color: "white"
                                font.bold: true
                            }

                            ScrollView {
                                width: parent.width
                                height: 80

                                ListView {
                                    id: availableAssetsList
                                    model: AssetManager.scanAvailableAssets()
                                    delegate: Text {
                                        text: "• " + modelData
                                        color: "#cccccc"
                                        font.pixelSize: 12
                                    }
                                }
                            }
                        }
                    }

                    // Generation buttons
                    Row {
                        spacing: 10

                        Button {
                            text: "🔄 Scan Assets"
                            onClicked: {
                                availableAssetsList.model = AssetManager.scanAvailableAssets()
                            }
                        }

                        Button {
                            text: "📝 Generate All Metadata"
                            onClicked: {
                                var success = AssetManager.generateAllMetadata()
                                if (success) {
                                    generationStatus.text = "✅ Metadata generated successfully!"
                                    generationStatus.color = "#4CAF50"
                                } else {
                                    generationStatus.text = "❌ Failed to generate metadata"
                                    generationStatus.color = "#F44336"
                                }
                                statusTimer.start()
                            }
                        }
                    }

                    Text {
                        id: generationStatus
                        text: ""
                        color: "white"
                        font.bold: true
                        
                        Timer {
                            id: statusTimer
                            interval: 3000
                            onTriggered: generationStatus.text = ""
                        }
                    }

                    Text {
                        text: "Note: This will overwrite existing metadata.json files"
                        color: "#FFC107"
                        font.pixelSize: 11
                        font.italic: true
                    }
                }
            }
        }
    }
}
