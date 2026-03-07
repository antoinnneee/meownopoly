import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import GameSession 1.0

Rectangle {
    id: root
    required property var host

    property alias boardEventLog: boardEventLog

    Layout.fillWidth: true
    Layout.fillHeight: true
    color: host.cardBg
    radius: host.cardRadius
    border.color: host.cardBorder
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Text {
            text: "Board Events (reliable)"
            color: host.textPrimary
            font.bold: true
            font.pixelSize: 14
        }

        ComboBox {
            id: msgTypeCombo
            Layout.fillWidth: true
            textRole: "label"
            valueRole: "value"
            model: [
                { label: "GameStart (0x01)",   value: 0x01 },
                { label: "GameEnd (0x02)",     value: 0x02 },
                { label: "TurnStart (0x03)",   value: 0x03 },
                { label: "DiceRoll (0x04)",    value: 0x04 },
                { label: "PlayerMove (0x05)",  value: 0x05 },
                { label: "BuyProperty (0x06)", value: 0x06 },
                { label: "CardDraw (0x08)",   value: 0x08 },
                { label: "MapSync (0x0D)",     value: 0x0D }
            ]
            background: Rectangle {
                color: "#0e0e13"
                radius: 6
                border.color: host.cardBorder
                border.width: 1
            }
            contentItem: Text {
                leftPadding: 8
                text: msgTypeCombo.displayText
                color: host.textPrimary
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
            }
        }

        TextField {
            id: payloadField
            Layout.fillWidth: true
            placeholderText: "{}"
            font.pixelSize: 12
            color: host.textPrimary
            background: Rectangle {
                color: "#0e0e13"
                radius: 6
                border.color: host.cardBorder
                border.width: 1
            }
        }

        Button {
            Layout.fillWidth: true
            text: "Envoyer Event"
            implicitHeight: 30
            background: Rectangle {
                color: parent.pressed ? host.accent : "#2d2d35"
                radius: 6
                border.color: host.cardBorder
                border.width: 1
            }
            contentItem: Text {
                text: parent.text
                color: host.textPrimary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 12
            }
            onClicked: {
                try {
                    GameSession.sendEvent(msgTypeCombo.currentValue, JSON.parse(payloadField.text))
                } catch (e) {}
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            TextArea {
                id: boardEventLog
                readOnly: true
                wrapMode: Text.Wrap
                font.pixelSize: 11
                color: host.textPrimary
                background: Rectangle {
                    color: "#0e0e13"
                    radius: 4
                    border.color: host.cardBorder
                    border.width: 1
                }
            }
        }
    }
}
