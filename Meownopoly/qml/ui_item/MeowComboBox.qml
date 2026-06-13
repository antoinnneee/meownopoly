import QtQuick
import QtQuick.Controls
import theme

/*
 * MeowComboBox — liste déroulante canonique des panneaux de l'éditeur.
 *
 * Promu depuis PCP_StyledComboBox.
 * Palette : fond Theme.surface, border Theme.borderLight (focus Theme.accentAlt), texte clair.
 * Popup : fond #222222, item survolé Theme.hover(surface), item sélectionné Theme.accentAlt.
 */
ComboBox {
    id: control

    implicitHeight: 32
    leftPadding: Theme.spacingL
    rightPadding: 28

    font.pixelSize: Theme.fontSizeBody

    contentItem: Text {
        leftPadding: control.leftPadding
        rightPadding: control.rightPadding
        text: control.displayText
        color: control.enabled ? Theme.textPrimary : Theme.textDisabled
        font: control.font
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignLeft
        elide: Text.ElideRight
    }

    indicator: Text {
        x: control.width - width - 8
        y: control.topPadding + (control.availableHeight - height) / 2
        text: "▾"
        color: control.popup.visible ? Theme.hover(Theme.accentAlt) : "#aaaaaa"
        font.pixelSize: Theme.fontSizeMedium
    }

    background: Rectangle {
        color: control.pressed ? Theme.pressed(Theme.surface) : Theme.surface
        radius: Theme.radiusXS
        border.color: control.activeFocus ? Theme.accentAlt : Theme.borderLight
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    delegate: ItemDelegate {
        id: itemDel
        width: control.width
        contentItem: Text {
            // Respecte textRole pour les modèles d'objets ({name, id}…),
            // tout en restant compatible avec les modèles de chaînes.
            text: (control.textRole && modelData
                     && modelData[control.textRole] !== undefined)
                    ? modelData[control.textRole]
                    : modelData
            color: itemDel.highlighted ? Theme.textPrimary : Theme.textSecondary
            font: control.font
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            color: itemDel.highlighted
                     ? Theme.accentAlt
                     : (itemDel.hovered ? Theme.hover(Theme.surface) : "transparent")
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
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
            border.color: Theme.border
            border.width: 1
            radius: Theme.radiusXS
        }
    }
}
