import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#2e2e2e"
    border.color: "#555555"
    border.width: 1

    property string selectedAssetPath: ""
    property string selectedAssetType: ""
    property string selectedAssetId: ""
    
    signal assetSelected(string path, string type, string id)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // Header with tools
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Asset Manager"
                color: "white"
                font.pixelSize: 16
                font.bold: true
                Layout.fillWidth: true
            }

            Button {
                text: "🔄"
                ToolTip.text: "Reload assets"
                ToolTip.visible: hovered
                
                onClicked: AssetManager.loadAssets()
            }

            Button {
                text: "📝"
                ToolTip.text: "Generate metadata"
                ToolTip.visible: hovered
                
                onClicked: {
                    var success = AssetManager.generateAllMetadata()
                    if (success) {
                        statusText.text = "Metadata generated!"
                        statusText.color = "#4CAF50"
                    } else {
                        statusText.text = "Generation failed"
                        statusText.color = "#F44336"
                    }
                    statusTimer.start()
                }
            }
        }

    }
}
