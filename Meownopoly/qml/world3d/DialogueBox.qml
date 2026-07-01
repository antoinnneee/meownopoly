import QtQuick
import theme

/*
 * DialogueBox — bulle de dialogue 2D d'un PNJ.
 *
 * Positionnée par l'appelant (NPCDialogueOverlay) au-dessus de la tile PNJ
 * dans le référentiel workArea : suivre tile.x/tile.y suit pan/zoom
 * gratuitement (pas de projection 3D→écran). Affiche le nom, la ligne
 * courante et un indicateur de progression ; clic = avance (si interactive).
 */
Item {
    id: root

    /// Nom affiché en en-tête (vide = pas d'en-tête).
    property string npcName: ""
    /// Ligne de dialogue courante.
    property string text: ""
    /// Progression dans la séquence (affichée si total > 1).
    property int index: 0
    property int total: 0
    /// Si vrai, un clic sur la bulle avance la séquence.
    property bool interactive: true

    signal advanceRequested()

    implicitWidth: bubble.width
    implicitHeight: bubble.height + tail.height

    Rectangle {
        id: bubble
        width: Math.min(Theme.px(260),
                        Math.max(Theme.px(120), contentColumn.implicitWidth + 2 * Theme.spacingM))
        height: contentColumn.implicitHeight + 2 * Theme.spacingM
        radius: Theme.radiusL
        color: Theme.surface
        border.color: Theme.accent
        border.width: 1

        Column {
            id: contentColumn
            x: Theme.spacingM
            y: Theme.spacingM
            width: bubble.width - 2 * Theme.spacingM
            spacing: Theme.spacingXS

            Text {
                visible: root.npcName !== ""
                text: root.npcName
                color: Theme.accent
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                text: root.text
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeBody
                wrapMode: Text.WordWrap
                width: parent.width
            }

            Text {
                visible: root.total > 1
                text: (root.index + 1) + " / " + root.total
                      + (root.interactive ? "  ▸" : "")
                color: Theme.textMuted
                font.pixelSize: Theme.fontSizeTiny
                width: parent.width
                horizontalAlignment: Text.AlignRight
            }
        }

        TapHandler {
            enabled: root.interactive
            onTapped: root.advanceRequested()
        }
    }

    // Queue de la bulle, centrée sous le corps.
    Canvas {
        id: tail
        anchors.top: bubble.bottom
        anchors.horizontalCenter: bubble.horizontalCenter
        width: 16
        height: 10
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = Theme.surface
            ctx.strokeStyle = Theme.accent
            ctx.lineWidth = 1
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.lineTo(width, 0)
            ctx.lineTo(width / 2, height)
            ctx.closePath()
            ctx.fill()
            ctx.stroke()
        }
    }
}
