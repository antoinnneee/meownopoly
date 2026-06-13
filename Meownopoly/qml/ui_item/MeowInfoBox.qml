import QtQuick
import QtQuick.Layouts
import theme

/*
 * MeowInfoBox — note explicative ou encadré d'information des panneaux.
 *
 * Deux modes :
 *  - note (défaut, variant: "") : texte italique discret, sans cadre.
 *      MeowInfoBox { Layout.fillWidth: true; text: "💡 …" }
 *  - encadré coloré (variant: "info" | "warning" | "tip") : cadre + titre + corps.
 *      MeowInfoBox { Layout.fillWidth: true; variant: "tip"; title: "💡 Conseils"; text: "• …" }
 *
 * Inséré dans un Layout : penser à `Layout.fillWidth: true` côté appelant.
 */
Item {
    id: root

    property string variant: ""           // "" = note ; info | warning | tip = encadré
    property string title: ""
    property string text: ""
    property int fontSize: Theme.fontSizeBody   // taille du texte en mode note

    readonly property bool _callout: root.variant !== ""
    readonly property color _bg: root.variant === "warning" ? Theme.warningBg
                               : root.variant === "tip" ? Theme.tipBg
                               : Theme.infoBg
    readonly property color _border: root.variant === "warning" ? Theme.warningBorder
                                   : root.variant === "tip" ? Theme.tipBorder
                                   : Theme.infoBorder
    readonly property color _titleColor: root.variant === "warning" ? Theme.warningTitle
                                       : root.variant === "tip" ? Theme.tipTitle
                                       : Theme.infoTitle
    readonly property color _bodyColor: root.variant === "warning" ? Theme.warningText
                                      : root.variant === "tip" ? Theme.tipText
                                      : Theme.infoText

    implicitWidth: 100
    implicitHeight: root._callout ? calloutBox.implicitHeight : note.implicitHeight

    // ── Mode note ────────────────────────────────────────────────
    Text {
        id: note
        visible: !root._callout
        width: root.width
        text: root.text
        font.italic: true
        font.pixelSize: root.fontSize
        color: Theme.textMuted
        wrapMode: Text.WordWrap
    }

    // ── Mode encadré coloré ──────────────────────────────────────
    Rectangle {
        id: calloutBox
        visible: root._callout
        width: root.width
        implicitHeight: calloutCol.implicitHeight + 2 * Theme.spacingL
        height: implicitHeight
        color: root._bg
        radius: Theme.radiusS
        border.color: root._border
        border.width: 1

        ColumnLayout {
            id: calloutCol
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingS

            Text {
                visible: root.title !== ""
                text: root.title
                font.bold: true
                font.pixelSize: Theme.fontSizeSmall
                color: root._titleColor
            }
            Text {
                text: root.text
                font.pixelSize: Theme.fontSizeTiny
                color: root._bodyColor
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }
    }
}
