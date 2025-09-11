import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import AssetManager

ScrollView {
    id: root
    
    // Properties
    property string category: ""
    property string type: ""
    property string searchText: ""
    property var assetModel: null
    property bool isLoading: false
    
    // Selection state
    property string currentSelectedCategory: ""
    property string currentSelectedType: ""
    property string currentSelectedId: ""
    
    // Signals
    signal assetSelected(string id)
    
    // Update model when category/type changes
    onCategoryChanged: updateModel()
    onTypeChanged: updateModel()
    
    
    function updateModel() {
        if (category && type) {
            console.log("loading model", category, type)
            isLoading = true
            
            var model = AssetManager.getAssetModel(category, type)
            if (model) {
                assetModel = model
                console.log("Model loaded successfully:", model.rowCount(), "items")
            } else {
                console.warn("Failed to load model for", category, type)
                assetModel = null
            }
            
            isLoading = false
        } else {
            assetModel = null
            isLoading = false
        }
    }
    
    Component.onCompleted: updateModel()
    
    // Content
    contentWidth: gridLayout.implicitWidth
    contentHeight: gridLayout.implicitHeight
    
    GridLayout {
        id: gridLayout
        anchors.fill: parent
        columns: Math.max(1, Math.floor(root.width / 90))
        columnSpacing: 10
        rowSpacing: 10
        
        Repeater {
            model: root.assetModel
            
            ASP_Item {
                Layout.preferredWidth: 80
                Layout.preferredHeight: 80
                
                // Asset data
                assetPath: model.path || ""
                assetId: model.id || ""
                assetFilename: model.filename || ""
                assetWidth: model.width || 0
                assetHeight: model.height || 0
                assetRatioWidth: model.ratioWidth || 1
                assetRatioHeight: model.ratioHeight || 1
                
                // Selection state
                isSelected: root.currentSelectedCategory === root.category && 
                           root.currentSelectedType === root.type && 
                           root.currentSelectedId === (model.id || "").toString()
                
                // Filter by search text
                visible: {
                    if (root.searchText === "") return true
                    
                    var searchLower = root.searchText.toLowerCase()
                    var idMatch = (model.id || "").toString().toLowerCase().includes(searchLower)
                    var filenameMatch = (model.filename || "").toLowerCase().includes(searchLower)
                    
                    return idMatch || filenameMatch
                }
                
                onAssetClicked: function(id) {
                    //console.log(assetPath, assetId, assetFilename)
                    root.assetSelected(id)
                }

            }
        }
        
        // Spacer item to fill remaining space
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: gridLayout.children.length === 1 // Only spacer visible
        }
    }
    
    // Loading state
    Rectangle {
        anchors.centerIn: parent
        width: 200
        height: 100
        color: "transparent"
        visible: (root.isLoading || (!root.assetModel && root.category && root.type))
        
        Column {
            anchors.centerIn: parent
            spacing: 15
            
            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: parent.parent.visible
            }
            
            Text {
                text: "Loading assets..."
                color: "#CCCCCC"
                font.pixelSize: 14
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
    
    // Empty state when no assets found
    Rectangle {
        anchors.centerIn: parent
        width: 250
        height: 120
        color: "transparent"
        visible: root.assetModel && root.assetModel.rowCount() === 0
        
        Column {
            anchors.centerIn: parent
            spacing: 10
            
            Text {
                text: "📁"
                font.pixelSize: 32
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Text {
                text: "No assets found"
                color: "#CCCCCC"
                font.pixelSize: 14
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Text {
                text: "Category: " + root.category + " > " + root.type
                color: "#999999"
                font.pixelSize: 11
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Text {
                text: "Make sure assets are properly loaded in AssetManager"
                color: "#999999"
                font.pixelSize: 10
                font.italic: true
                anchors.horizontalCenter: parent.horizontalCenter
                wrapMode: Text.Wrap
                width: 220
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
