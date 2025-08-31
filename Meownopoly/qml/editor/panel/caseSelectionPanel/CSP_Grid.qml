import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Case
import Game

ScrollView {
    id: root

    // Properties
    property string categoryName: ""
    property string typeName: ""
    property string searchText: ""
    property var caseList: []

    // Selection state

    property string currentSelectedCategory: ""
    property string currentSelectedType: ""
    property string currentSelectedId: ""

    // Signal for case selection
    signal caseSelected(string category, string type, string id)

    // Content
    contentWidth: gridLayout.implicitWidth
    contentHeight: gridLayout.implicitHeight

    // Get filtered cases based on search text
    function getFilteredCases() {
        if (searchText.trim() === "") {
            return caseList;
        }

        var searchLower = searchText.toLowerCase();
        return caseList.filter(function(caseData) {
            return caseData.name.toLowerCase().includes(searchLower);
        });
    }

    GridLayout {
        id: gridLayout
        anchors.fill: parent
        columns: Math.max(1, Math.floor(root.width / 90)) // Responsive columns for 80px items + spacing
        columnSpacing: 10
        rowSpacing: 10

        // Populate the grid with filtered cases
        Repeater {
            model: getFilteredCases()

            CSP_Item {
                Layout.preferredWidth: 80
                Layout.preferredHeight: 80

                caseData: modelData
                categoryName: root.categoryName
                typeName: root.typeName

                // Selection state
                isSelected: root.currentSelectedCategory === root.categoryName &&
                           root.currentSelectedType === root.typeName &&
                           root.currentSelectedId === (modelData.uniqueId ? modelData.uniqueId.toString() : "")

                onCaseClicked: function(category, type, id) {
                    root.caseSelected(category, type, id)
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
        visible: caseList === null

        Column {
            anchors.centerIn: parent
            spacing: 15

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: parent.parent.visible
            }

            Text {
                text: "Chargement des cases..."
                color: "#CCCCCC"
                font.pixelSize: 14
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // Empty state when no cases found
    Rectangle {
        anchors.centerIn: parent
        width: 250
        height: 120
        color: "transparent"
        visible: caseList && caseList.length === 0

        Column {
            anchors.centerIn: parent
            spacing: 10

            Text {
                text: "📁"
                font.pixelSize: 32
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Aucune case trouvée"
                color: "#CCCCCC"
                font.pixelSize: 14
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Catégorie: " + (root.categoryName === "proprietes" ? "Propriétés" : "Spéciales")
                color: "#999999"
                font.pixelSize: 11
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // No search results state
    Rectangle {
        anchors.centerIn: parent
        width: 200
        height: 100
        color: "transparent"
        visible: caseList && caseList.length > 0 && getFilteredCases().length === 0

        Column {
            anchors.centerIn: parent
            spacing: 10

            Text {
                text: "🔍"
                font.pixelSize: 32
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Aucune case correspondante"
                color: "#CCCCCC"
                font.pixelSize: 14
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Essayez d'autres termes de recherche"
                color: "#999999"
                font.pixelSize: 11
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
