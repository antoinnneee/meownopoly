import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Case
import CaseRestArea
import CaseCatPerks
import MeowStyle

Rectangle {
    id: root
    color: mouseArea.containsMouse ? "#454545" : "#373737"
    border.color: isSelected ? "#4A90E2" : "#555555" 
    border.width: isSelected ? 2 : 1
    radius: 6
    
    // Properties
    required property var caseData
    property string categoryName: ""
    property string typeName: ""
    property bool isSelected: false
    
    // Colors for different family types - utilise le singleton MeowStyle
    property var familyColors: MeowStyle.familyColors
    
    // Signals
    signal caseClicked(string category, string type, string id)
    
    // Determine if the case is purchasable
    property bool isPurchasable: {
        if (caseData && caseData.type === Case.CS_RestArea || 
            caseData && caseData.type === Case.CS_CatDoor || 
            caseData && caseData.type === Case.CS_Device) {
            return caseData.price > 0;
        }
        return false;
    }
    
    // Color header based on case type
    Rectangle {
        id: headerBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 16
        radius: parent.radius
        color: {
            if (caseData) {
                if (caseData.type === Case.CS_RestArea && caseData.family) {
                    return familyColors[caseData.family];
                } else {
                    // Colors based on case type
                    switch (caseData.type) {
                        case Case.CS_KibbleDispenser: return "#FFC107"; // Yellow
                        case Case.CS_CardBoardBox: return "#FF9800";    // Orange
                        case Case.CS_CatNip: return "#4CAF50";          // Green
                        case Case.CS_Jail: return "#9C27B0";            // Purple
                        case Case.CS_ToJail: return "#673AB7";          // Deep Purple
                        case Case.CS_CatDoor: return "#2196F3";         // Blue
                        case Case.CS_FreeNap: return "#03A9F4";         // Light Blue
                        case Case.CS_Device: return "#00BCD4";          // Cyan
                        default: return "#607D8B";                       // Blue Grey
                    }
                }
            }
            return "#607D8B"; // Default color
        }
    }
    
    // Main content area
    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: headerBar.height
        anchors.margins: 3
        spacing: 1
        
        // Case icon
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            
            Text {
                anchors.centerIn: parent
                text: {
                    if (caseData) {
                        switch (caseData.type) {
                            case Case.CS_KibbleDispenser: return "🥣";  // Bowl
                            case Case.CS_RestArea: return "🛌";         // Bed
                            case Case.CS_CardBoardBox: return "📦";     // Box
                            case Case.CS_CatNip: return "🌿";           // Plant
                            case Case.CS_Jail: return "🔒";             // Lock
                            case Case.CS_ToJail: return "⛓️";           // Chain
                            case Case.CS_CatDoor: return "🚪";          // Door
                            case Case.CS_FreeNap: return "😴";          // Sleeping
                            case Case.CS_Device: return "💡";           // Light
                            default: return "❓";                       // Unknown
                        }
                    }
                    return "❓";
                }
                font.pixelSize: 16
            }
        }
        
        // Case name
        Text {
            id: nameText
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: caseData ? caseData.name : "Unknown"
            color: "white"
            font.pixelSize: 9
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
            maximumLineCount: 2
            wrapMode: Text.Wrap
        }
        
        // Case price (if applicable)
        Text {
            id: priceText
            Layout.alignment: Qt.AlignHCenter
            visible: isPurchasable
            text: isPurchasable ? caseData.price + " K" : ""
            color: "#4CAF50"  // Green for price
            font.pixelSize: 9
            font.bold: true
        }
    }
    
    // Case category badge
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 3
        width: categoryText.width + 6
        height: 12
        radius: 6
        color: isPurchasable ? "#4CAF50" : "#FF9800"  // Green for purchasable, orange for temporary
        
        Text {
            id: categoryText
            anchors.centerIn: parent
            text: isPurchasable ? "P" : "S"  // P for Propriété, S for Spéciale
            color: "white"
            font.pixelSize: 7
            font.bold: true
        }
    }
    
    // Mouse interactions
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onClicked: {
            root.caseClicked(
                root.categoryName, 
                root.typeName, 
                caseData ? caseData.uniqueId.toString() : ""
            );
        }
    }
    
    // Selection indicator
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: "#4A90E2"
        border.width: root.isSelected ? 2 : 0
        radius: parent.radius
        
        Behavior on border.width {
            NumberAnimation { duration: 150 }
        }
    }
}