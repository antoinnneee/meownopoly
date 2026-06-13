import ui_item
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import AssetManager 1.0
import theme

CollapsableGroupBox {
    id: root
    title: "🧸 3D Models"
    isCollapsed: true

    signal modelSelected(string name)

    property string currentModel: ""

    content: [
        Flow {
            Layout.fillWidth: true
            spacing: Theme.spacingM
            padding: Theme.spacingXS

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
        color: isSelected ? Theme.hover(Theme.surfaceHover) : (mouseArea.containsMouse ? Theme.surfaceHover : Theme.surfaceAlt)
        radius: Theme.radiusM
        border.color: isSelected ? Theme.accent : Theme.borderLight
        border.width: isSelected ? 2 : 1

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Theme.spacingXXS
            Text {
                text: btn.icon
                font.pixelSize: Theme.fontSizeHeading
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: btn.text
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeCaption
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
