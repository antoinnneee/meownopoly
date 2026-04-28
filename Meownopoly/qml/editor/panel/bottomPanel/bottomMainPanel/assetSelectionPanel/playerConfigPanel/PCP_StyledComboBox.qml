import QtQuick
import QtQuick.Controls
import QtQuick.Templates as T

/*
 * ComboBox stylée cohérente avec le reste de l'éditeur.
 * Palette : fond #2a2a2a, border #555555 (focus #569c58), texte blanc.
 * Popup : fond #222222, item hovered #2f2f2f, item sélectionné #569c58.
 */
ComboBox {
    id: control

    implicitHeight: 32
    leftPadding: 10
    rightPadding: 28

    font.pixelSize: 12

    contentItem: Text {
        leftPadding: control.leftPadding
        rightPadding: control.rightPadding
        text: control.displayText
        color: control.enabled ? "#ffffff" : "#666666"
        font: control.font
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignLeft
        elide: Text.ElideRight
    }

    indicator: Text {
        x: control.width - width - 8
        y: control.topPadding + (control.availableHeight - height) / 2
        text: "▾"
        color: control.popup.visible ? "#6fb872" : "#aaaaaa"
        font.pixelSize: 14
    }

    background: Rectangle {
        color: control.pressed ? "#1f1f1f" : "#2a2a2a"
        radius: 3
        border.color: control.activeFocus ? "#569c58" : "#555555"
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    delegate: ItemDelegate {
        id: itemDel
        width: control.width
        contentItem: Text {
            text: modelData
            color: itemDel.highlighted ? "#ffffff" : "#cccccc"
            font: control.font
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            color: itemDel.highlighted
                     ? "#569c58"
                     : (itemDel.hovered ? "#2f2f2f" : "transparent")
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        highlighted: control.highlightedIndex === index
    }

    popup: Popup {
        y: control.height - 1
        width: control.width
        implicitHeight: contentItem.implicitHeight
        padding: 1

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex

            ScrollIndicator.vertical: ScrollIndicator {}
        }

        background: Rectangle {
            color: "#222222"
            border.color: "#444444"
            border.width: 1
            radius: 3
        }
    }
}
