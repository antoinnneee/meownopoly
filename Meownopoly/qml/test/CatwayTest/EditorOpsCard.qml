import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EditorOpBus 1.0

Rectangle {
    id: root
    required property var host

    color: host.cardBg
    radius: host.cardRadius
    border.color: host.cardBorder
    border.width: 1

    property alias log: opsLog

    function append(direction, op) {
        const now = new Date().toLocaleTimeString(Qt.locale(), "HH:mm:ss")
        const typeStr = _typeName(op.op)
        const compact = JSON.stringify(op).substring(0, 120)
        opsLog.text += "[" + now + "] " + direction + " " + typeStr + " " + compact + "\n"
    }

    function _typeName(t) {
        switch (t) {
        case EditorOpType.CreateItem:              return "CreateItem"
        case EditorOpType.DeleteItem:              return "DeleteItem"
        case EditorOpType.MoveItem:                return "MoveItem"
        case EditorOpType.ResizeItem:              return "ResizeItem"
        case EditorOpType.SetDisplayParameter:     return "SetDisplay"
        case EditorOpType.SetCaseData:             return "SetCaseData"
        case EditorOpType.SetDecorationParameter:  return "SetDecoration"
        case EditorOpType.SetZoneParameter:        return "SetZone"
        case EditorOpType.LinkItems:               return "LinkItems"
        case EditorOpType.UnlinkItems:             return "UnlinkItems"
        default:                                   return "op=" + t
        }
    }

    Connections {
        target: EditorOpBus
        function onOpRecorded(op)       { root.append("→", op) }
        function onRemoteOpReceived(op) { root.append("←", op) }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Log d'ops"
                color: host.textPrimary
                font.bold: true
                font.pixelSize: 14
                Layout.fillWidth: true
            }
            Button {
                text: "Clear"
                onClicked: opsLog.text = ""
                background: Rectangle {
                    color: parent.pressed ? host.accent : "#2d2d35"
                    radius: 6
                    border.color: host.cardBorder
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: host.textPrimary
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Text {
            text: "→ soumission locale / ← op distante reçue"
            color: host.textSecondary
            font.pixelSize: 10
            font.italic: true
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            TextArea {
                id: opsLog
                readOnly: true
                wrapMode: Text.NoWrap
                font.family: "Consolas"
                font.pixelSize: 11
                color: host.textPrimary
                background: Rectangle {
                    color: "#0e0e13"
                    radius: 6
                    border.color: host.cardBorder
                    border.width: 1
                }
            }
        }
    }
}
