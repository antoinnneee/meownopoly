import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import theme
import ui_item

/*
 * NCP_DialogueSection — éditeur de la séquence de lignes de dialogue.
 *
 * Édite DIRECTEMENT le NPCParameter cible via ses Q_INVOKABLE
 * (addLine/setLineAt/removeLineAt/moveLine) — la mutation en place d'une
 * QStringList exposée en Q_PROPERTY ne serait pas observée par QML.
 * Chaque mutation émet linesEdited() pour que le parent propage
 * (op SetNpcParameter + Game.updateMap débouncé).
 */
ColumnLayout {
    id: root

    // NPCParameter C++ cible (null si aucun PNJ sélectionné).
    property var targetNpc: null

    signal linesEdited()
    signal focusReleased()

    spacing: Theme.spacingS

    readonly property var _lines: targetNpc ? targetNpc.dialogueLines : []

    Text {
        text: root._lines.length === 0
              ? "Aucune ligne — le PNJ restera muet."
              : root._lines.length + " ligne(s), affichées dans l'ordre."
        color: Theme.textMuted
        font.pixelSize: Theme.fontSizeSmall
        font.italic: true
    }

    Repeater {
        model: root._lines

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingXS

            Text {
                text: (index + 1) + "."
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeSmall
                Layout.preferredWidth: Theme.px(20)
            }

            MeowTextField {
                Layout.fillWidth: true
                text: modelData
                onEditingFinished: {
                    if (!root.targetNpc) return
                    if (text === root.targetNpc.lineAt(index)) return
                    root.targetNpc.setLineAt(index, text)
                    root.linesEdited()
                }
                Keys.onReturnPressed: {
                    focus = false
                    root.focusReleased()
                }
            }

            MeowButton {
                Layout.preferredWidth: Theme.px(28)
                Layout.preferredHeight: Theme.px(28)
                text: "▲"
                variant: "secondary"
                fontSize: Theme.fontSizeSmall
                hoverZoom: false
                glossy: false
                enabled: index > 0
                onClicked: {
                    if (!root.targetNpc) return
                    root.targetNpc.moveLine(index, index - 1)
                    root.linesEdited()
                }
            }
            MeowButton {
                Layout.preferredWidth: Theme.px(28)
                Layout.preferredHeight: Theme.px(28)
                text: "▼"
                variant: "secondary"
                fontSize: Theme.fontSizeSmall
                hoverZoom: false
                glossy: false
                enabled: index < root._lines.length - 1
                onClicked: {
                    if (!root.targetNpc) return
                    root.targetNpc.moveLine(index, index + 1)
                    root.linesEdited()
                }
            }
            MeowButton {
                Layout.preferredWidth: Theme.px(28)
                Layout.preferredHeight: Theme.px(28)
                text: "✕"
                variant: "danger"
                fontSize: Theme.fontSizeSmall
                hoverZoom: false
                glossy: false
                onClicked: {
                    if (!root.targetNpc) return
                    root.targetNpc.removeLineAt(index)
                    root.linesEdited()
                }
            }
        }
    }

    MeowButton {
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.px(30)
        iconText: "➕"
        text: "Ajouter une ligne"
        variant: "secondary"
        fontSize: Theme.fontSizeSmall
        hoverZoom: false
        glossy: false
        enabled: root.targetNpc !== null
        onClicked: {
            root.targetNpc.addLine("")
            root.linesEdited()
        }
    }
}
