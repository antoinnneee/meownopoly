import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import AssetManager

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
            height: parent.height
            spacing: 20




            // Metadata Generation Panel
            GroupBox {
                title: "Metadata Generation"
                Layout.fillWidth: true
                Layout.fillHeight: true
                label: Label{
                    text: parent.title
                    color: "white"
                }

                ColumnLayout {
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
                        Layout.fillHeight: true
                        color: "#333333"
                        border.color: "#555555"
                        radius: 4

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            anchors.margins: 10

                            Text {
                                text: "Available Assets:"
                                color: "white"
                                font.bold: true
                            }

                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

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
