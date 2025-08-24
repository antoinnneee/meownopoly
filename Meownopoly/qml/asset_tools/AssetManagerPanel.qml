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

        // Status text
        Text {
            id: statusText
            text: ""
            color: "white"
            font.pixelSize: 12
            Layout.fillWidth: true
            
            Timer {
                id: statusTimer
                interval: 2000
                onTriggered: statusText.text = ""
            }
        }

        // Category tabs
        TabBar {
            id: categoryTabs
            Layout.fillWidth: true
            
            TabButton {
                text: "Decorations"
            }
            TabButton {
                text: "Player Icons"
            }
        }

        // Content area
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: categoryTabs.currentIndex

            // Decorations tab
            ColumnLayout {
                spacing: 10

                // Type selector for decorations
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: "Type:"
                        color: "white"
                    }
                    
                    ComboBox {
                        id: decorationTypeCombo
                        Layout.fillWidth: true
                        model: ["grass", "tree"]
                        
                        onCurrentTextChanged: {
                            decorationGrid.model = AssetManager.getTypeModel("decoration", currentText)
                        }
                    }
                }

                // Decoration grid
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    GridView {
                        id: decorationGrid
                        cellWidth: 80
                        cellHeight: 80
                        model: AssetManager.getTypeModel("decoration", "grass")
                        
                        delegate: Rectangle {
                            width: 70
                            height: 70
                            color: mouseArea.containsMouse ? "#404040" : "#333333"
                            border.color: root.selectedAssetId === model.id ? "#4CAF50" : "#666666"
                            border.width: 2
                            radius: 4
                            
                            Image {
                                anchors.fill: parent
                                anchors.margins: 5
                                source: model.path
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                
                                Rectangle {
                                    anchors.fill: parent
                                    color: "#555555"
                                    visible: parent.status !== Image.Ready
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: model.id
                                        color: "white"
                                        font.pixelSize: 10
                                    }
                                }
                            }
                            
                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                
                                onClicked: {
                                    root.selectedAssetPath = model.path
                                    root.selectedAssetType = decorationTypeCombo.currentText
                                    root.selectedAssetId = model.id
                                    root.assetSelected(model.path, decorationTypeCombo.currentText, model.id)
                                }
                            }
                        }
                    }
                }
            }

            // Player Icons tab
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                GridView {
                    id: playerIconGrid
                    cellWidth: 80
                    cellHeight: 80
                    model: AssetManager.playerIconModel
                    
                    delegate: Rectangle {
                        width: 70
                        height: 70
                        color: mouseArea2.containsMouse ? "#404040" : "#333333"
                        border.color: root.selectedAssetId === model.id ? "#4CAF50" : "#666666"
                        border.width: 2
                        radius: 4
                        
                        Image {
                            anchors.fill: parent
                            anchors.margins: 5
                            source: model.path
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            
                            Rectangle {
                                anchors.fill: parent
                                color: "#555555"
                                visible: parent.status !== Image.Ready
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: model.id
                                    color: "white"
                                    font.pixelSize: 10
                                }
                            }
                        }
                        
                        MouseArea {
                            id: mouseArea2
                            anchors.fill: parent
                            hoverEnabled: true
                            
                            onClicked: {
                                root.selectedAssetPath = model.path
                                root.selectedAssetType = "player_icon"
                                root.selectedAssetId = model.id
                                root.assetSelected(model.path, "player_icon", model.id)
                            }
                        }
                    }
                }
            }
        }

        // Selected asset info
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: "#333333"
            radius: 4
            visible: root.selectedAssetPath !== ""
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                
                Text {
                    text: "Selected:"
                    color: "white"
                    font.bold: true
                }
                
                Text {
                    text: root.selectedAssetType + "/" + root.selectedAssetId
                    color: "#4CAF50"
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                }
            }
        }
    }
}
