import QtQuick
import QtQuick.Controls.Material
ComboBox {
    id:control
    height: 40
    background: Rectangle {
        id: rectangle
        implicitWidth: 120
        implicitHeight: 40
        opacity: control.enabled ? 1 : 0.3
        color: (control.checked) ? Qt.darker(AppStyle.backgroundButLight, 1.2) : (!control.down) ? AppStyle.backgroundButLight : Qt.darker(AppStyle.backgroundButLight, 1.1)

        border.color: AppStyle.primary
        border.width: 1
        radius: 1
    }
    delegate: ItemDelegate {
        id:delegItem
        width: control.width
        contentItem: Text {
            text: modelData
            verticalAlignment: Text.AlignVCenter
            font: control.font
            color: (highlighted)? AppStyle.globalInvertPrimaryAccent : AppStyle.globalPrimaryAccent
        }

        highlighted: control.highlightedIndex === index
    }

    contentItem: Text {
        id: text1
        text: control.displayText
        font: control.font
        opacity: control.enabled ? 1.0 : 0.3
        color: AppStyle.primary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
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

            ScrollIndicator.vertical: ScrollIndicator { }
        }
        background: Rectangle {
            opacity: control.enabled ? 1 : 0.3
            color: (control.highlightedIndex != currentIndex) ? Qt.darker(AppStyle.backgroundButLight, 1.2) : (!control.down) ? AppStyle.backgroundButLight : Qt.darker(AppStyle.backgroundButLight, 1.1)

            border.color: AppStyle.primary
            border.width: 1
            radius: 1
        }
    }


}

/*##^##
Designer {
    D{i:0;autoSize:true;formeditorZoom:0.25;height:480;width:640}
}
##^##*/
