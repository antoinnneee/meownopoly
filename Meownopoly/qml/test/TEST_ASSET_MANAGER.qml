import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import AssetManager
import theme

Rectangle {
    id: window
    color: Theme.background
    
    signal backRequested()
    
    // Back button
    Button {
        id: backButton
        text: "← Back"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: Theme.spacingL
        z: 100
        
        onClicked: window.backRequested()
    }
    
    Text {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Theme.spacingXXL
        text: "Asset Manager Test"
        color: Theme.textPrimary
        font.pixelSize: Theme.fontSizeHeading
        font.bold: true
    }

    ColumnLayout {
        anchors {
            left: parent.left
            right: parent.right
            top: backButton.bottom
            bottom: parent.bottom
            margins: Theme.spacingHuge
        }
        spacing: Theme.spacingXXL

        Text {
            text: "Generate metadata.json files automatically from image files"
            color: Theme.textPrimary
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        // Available assets scan
        Text {
            text: "Available Assets:"
            color: Theme.textPrimary
            font.bold: true
        }

        ListView {
            id: availableAssetsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 200

            model: AssetManager.scanAvailableAssets()
            delegate: Text {
                text: "• " + modelData
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeBody
                width: availableAssetsList.width
            }

            ScrollBar.vertical: ScrollBar {
                active: true
                policy: ScrollBar.AsNeeded
            }
        }
        // Generation buttons
        Row {
            spacing: Theme.spacingL

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
                        generationStatus.color = Theme.success
                    } else {
                        generationStatus.text = "❌ Failed to generate metadata"
                        generationStatus.color = Theme.danger
                    }
                    statusTimer.start()
                }
            }
        }

        Text {
            id: generationStatus
            text: ""
            Layout.fillWidth: true
        }

        Text {
            text: "Note: This will overwrite existing metadata.json files"
            color: Theme.warning
            font.pixelSize: Theme.fontSizeSmall
            font.italic: true
        }

        Timer {
            id: statusTimer
            interval: 3000
            onTriggered: generationStatus.text = ""
        }
    }
}
