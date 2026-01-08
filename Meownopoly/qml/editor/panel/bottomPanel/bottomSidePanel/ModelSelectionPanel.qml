import ui_item
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import AssetManager 1.0

CollapsableGroupBox {
    id: root
    title: "🧸 3D Models"
    isCollapsed: true

    signal modelSelected(string name)

    property string currentModel: ""

    content: [
        Flow {
            Layout.fillWidth: true
            spacing: 8
            padding: 5

            // --- Primitives ---
            ModelButton {
                text: "Cube"
                icon: "📦"
                isSelected: root.currentModel === "Cube"
                onClicked: root.modelSelected("Cube")
            }

            ModelButton {
                text: "Sphere"
                icon: "🔮"
                isSelected: root.currentModel === "Sphere"
                onClicked: root.modelSelected("Sphere")
            }

            // --- Downloaded Models ---
            Repeater {
                model: AssetManager.getAvailableModels()
                delegate: ModelButton {
                    text: modelData
                    icon: "👤"
                    isSelected: root.currentModel === modelData
                    onClicked: root.modelSelected(modelData)
                }
            }
        }
    ]

    // Helper component for buttons
    component ModelButton: Rectangle {
        id: btn
        property string text: ""
        property string icon: ""
        property bool isSelected: false
        signal clicked()

        width: 80
        height: 60
        color: isSelected ? "#4a4a4a" : (mouseArea.containsMouse ? "#3d3d3d" : "#333333")
        radius: 6
        border.color: isSelected ? "#0078d7" : "#555555"
        border.width: isSelected ? 2 : 1

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2
            Text {
                text: btn.icon
                font.pixelSize: 20
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: btn.text
                color: "white"
                font.pixelSize: 10
                Layout.alignment: Qt.AlignHCenter
                elide: Text.ElideRight
                Layout.maximumWidth: btn.width - 8
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: btn.clicked()
        }
    }
}
