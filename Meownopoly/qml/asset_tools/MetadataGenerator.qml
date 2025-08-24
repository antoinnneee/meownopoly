import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs

Rectangle {
    id: root
    color: "#2e2e2e"
    border.color: "#555555"
    border.width: 1
    radius: 8

    property string targetDirectory: ""
    
    signal metadataGenerated(bool success, string message)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        // Header
        Text {
            text: "Metadata Generator"
            color: "white"
            font.pixelSize: 18
            font.bold: true
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            text: "Generate metadata.json files from image directories"
            color: "#cccccc"
            font.pixelSize: 12
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }

        // Current assets base path
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: "#333333"
            radius: 4
            border.color: "#555555"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10

                Text {
                    text: "Assets Path:"
                    color: "white"
                    font.bold: true
                }

                Text {
                    text: AssetManager ? AssetManager.assetsBasePath || "Not set" : "AssetManager not available"
                    color: "#4CAF50"
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                }
            }
        }

        // Available assets scan
        GroupBox {
            title: "Available Image Directories"
            Layout.fillWidth: true
            Layout.fillHeight: true

            label: Label {
                text: parent.title
                color: "white"
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 10

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: assetsList
                        model: ListModel {
                            id: assetsListModel
                        }

                        delegate: Rectangle {
                            width: assetsList.width
                            height: 60
                            color: mouseArea.containsMouse ? "#404040" : "#333333"
                            border.color: "#555555"
                            radius: 4

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10

                                Column {
                                    Layout.fillWidth: true

                                    Text {
                                        text: model.directory
                                        color: "white"
                                        font.bold: true
                                    }

                                    Text {
                                        text: model.imageCount + " images found"
                                        color: "#cccccc"
                                        font.pixelSize: 11
                                    }
                                }

                                Button {
                                    text: model.hasMetadata ? "🔄 Regenerate" : "📝 Generate"
                                    enabled: model.imageCount > 0

                                    onClicked: {
                                        var success = AssetManager.generateMetadataForDirectory(model.fullPath)
                                        if (success) {
                                            statusText.text = "✅ Generated metadata for " + model.directory
                                            statusText.color = "#4CAF50"
                                            model.hasMetadata = true
                                        } else {
                                            statusText.text = "❌ Failed to generate metadata for " + model.directory
                                            statusText.color = "#F44336"
                                        }
                                        statusTimer.start()
                                        refreshAssetsList()
                                    }
                                }
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                            }
                        }
                    }
                }

                // Action buttons
                RowLayout {
                    Layout.fillWidth: true

                    Button {
                        text: "🔄 Refresh Scan"
                        onClicked: refreshAssetsList()
                    }

                    Button {
                        text: "📝 Generate All"
                        enabled: assetsListModel.count > 0

                        onClicked: {
                            var success = AssetManager.generateAllMetadata()
                            if (success) {
                                statusText.text = "✅ Generated all metadata files successfully!"
                                statusText.color = "#4CAF50"
                            } else {
                                statusText.text = "❌ Failed to generate some metadata files"
                                statusText.color = "#F44336"
                            }
                            statusTimer.start()
                            refreshAssetsList()
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "🔄 Reload Assets"
                        onClicked: AssetManager.loadAssets()
                    }
                }
            }
        }

        // Status message
        Text {
            id: statusText
            text: ""
            color: "white"
            font.bold: true
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap

            Timer {
                id: statusTimer
                interval: 4000
                onTriggered: statusText.text = ""
            }
        }
    }

    Component.onCompleted: {
        refreshAssetsList()
    }

    function refreshAssetsList() {
        assetsListModel.clear()
        
        if (!AssetManager) {
            return
        }

        // Scan for asset directories
        var availableAssets = AssetManager.scanAvailableAssets()
        
        for (var i = 0; i < availableAssets.length; i++) {
            var assetInfo = availableAssets[i]
            
            // Parse the format "decoration/grass (5 images)"
            var parts = assetInfo.split(" (")
            var directory = parts[0]
            var imageCountStr = parts[1] ? parts[1].replace(" images)", "") : "0"
            var imageCount = parseInt(imageCountStr)
            
            // Build full path
            var fullPath = ""
            if (directory.includes("/")) {
                // decoration/grass -> assets/decoration/grass
                fullPath = AssetManager.assetsBasePath + directory
            } else {
                // player_icons -> assets/player_icons
                fullPath = AssetManager.assetsBasePath + directory
            }
            
            // Check if metadata.json already exists
            var metadataExists = Qt.resolvedUrl(fullPath + "/metadata.json").toString().length > 0
            
            assetsListModel.append({
                directory: directory,
                fullPath: fullPath,
                imageCount: imageCount,
                hasMetadata: metadataExists
            })
        }
    }
}
