import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#2e2e2e"
    border.color: "#555555"
    border.width: 1
    radius: 8

    property string selectedCategory: "decoration"
    property string selectedType: "grass"
    property string selectedAssetId: "1"
    
    signal assetSelected(string category, string type, string assetId)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // Header
        Text {
            text: "Asset Selector"
            color: "white"
            font.pixelSize: 16
            font.bold: true
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        // Category selection
        RowLayout {
            Layout.fillWidth: true
            
            Text {
                text: "Category:"
                color: "white"
                Layout.preferredWidth: 80
            }
            
            ComboBox {
                id: categoryCombo
                Layout.fillWidth: true
                model: ["decoration", "player_icons"]
                currentIndex: selectedCategory === "decoration" ? 0 : 1
                
                onCurrentTextChanged: {
                    root.selectedCategory = currentText
                    // Reset type selection when category changes
                    if (currentText === "decoration") {
                        typeCombo.model = ["grass", "tree"]
                        typeCombo.currentIndex = 0
                    } else {
                        typeCombo.model = [""]
                        typeCombo.currentIndex = 0
                    }
                }
            }
        }

        // Type selection (only for categories that have types)
        RowLayout {
            Layout.fillWidth: true
            visible: root.selectedCategory === "decoration"
            
            Text {
                text: "Type:"
                color: "white"
                Layout.preferredWidth: 80
            }
            
            ComboBox {
                id: typeCombo
                Layout.fillWidth: true
                model: ["grass", "tree"]
                
                onCurrentTextChanged: {
                    root.selectedType = currentText
                }
            }
        }

        // Asset grid
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            GridView {
                id: assetGrid
                cellWidth: 80
                cellHeight: 80
                model: {
                    if (root.selectedCategory === "decoration") {
                        return AssetManager.getTypeModel("decoration", root.selectedType)
                    } else {
                        return AssetManager.playerIconModel
                    }
                }
                
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
                        
                        // Placeholder if image fails to load
                        Rectangle {
                            anchors.fill: parent
                            color: "#555555"
                            visible: parent.status !== Image.Ready
                            
                            Text {
                                anchors.centerIn: parent
                                text: model.id
                                color: "white"
                                font.pixelSize: 12
                            }
                        }
                    }
                    
                    Text {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: model.id
                        color: "white"
                        font.pixelSize: 10
                        background: Rectangle {
                            color: "#80000000"
                            radius: 2
                        }
                    }
                    
                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        
                        onClicked: {
                            root.selectedAssetId = model.id
                            root.assetSelected(root.selectedCategory, root.selectedType, model.id)
                        }
                    }
                }
            }
        }

        // Selected asset info
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: "#333333"
            radius: 4
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                
                Text {
                    text: "Selected:"
                    color: "white"
                    font.bold: true
                }
                
                Text {
                    text: root.selectedCategory + "/" + root.selectedType + "/" + root.selectedAssetId
                    color: "#4CAF50"
                    Layout.fillWidth: true
                }
                
                Button {
                    text: "Use Asset"
                    enabled: root.selectedAssetId !== ""
                    
                    onClicked: {
                        root.assetSelected(root.selectedCategory, root.selectedType, root.selectedAssetId)
                    }
                }
            }
        }
    }
}
