import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import AiSupervisor 1.0
import theme

// Harness V3 — passerelle MCP du canal IA (C1-C4, D2/D20/D21).
//
// La passerelle `AiGatewayServer` est instanciée opt-in dans main.cpp
// (--ai-gateway-port <N> ou MEOW_AI_GATEWAY_PORT) et n'est pas un singleton QML.
// Son état de diagnostic est lu via AiProcessSupervisor (gatewayPresent/…),
// stable après le démarrage → lecture au chargement + bouton « Rafraîchir ».
Rectangle {
    id: root
    required property var host

    color: host.cardBg
    radius: host.cardRadius
    border.color: host.cardBorder
    border.width: 1
    implicitHeight: content.implicitHeight + Theme.spacingXXL * 2

    // Snapshot des valeurs (pas de NOTIFY côté C++ : on relit à la demande).
    property bool _present: false
    property bool _listening: false
    property int _port: 0
    property bool _httpAvailable: false
    property string _proposerToken: ""
    property string _arbiterToken: ""
    property bool _revealTokens: false

    function _refresh() {
        root._present = AiProcessSupervisor.gatewayPresent()
        root._listening = AiProcessSupervisor.gatewayListening()
        root._port = AiProcessSupervisor.gatewayPort()
        root._httpAvailable = AiProcessSupervisor.gatewayHttpAvailable()
        root._proposerToken = AiProcessSupervisor.gatewayProposerToken()
        root._arbiterToken = AiProcessSupervisor.gatewayArbiterToken()
    }
    function _mask(tok) {
        if (!tok || tok.length === 0)
            return "—"
        if (root._revealTokens)
            return tok
        return tok.length <= 8 ? "••••••••"
                               : tok.substring(0, 4) + "…" + tok.substring(tok.length - 4)
    }

    Component.onCompleted: root._refresh()

    component FieldLabel: Text {
        color: root.host.textSecondary
        font.pixelSize: Theme.fontSizeSmall
    }
    component ValueText: Text {
        color: root.host.textPrimary
        font.pixelSize: Theme.fontSizeSmall
        font.family: "Consolas"
    }
    component StyledButton: Button {
        id: btn
        property color tint: root.host.accent
        implicitHeight: Theme.px(26)
        padding: Theme.spacingM
        font.pixelSize: Theme.fontSizeSmall
        contentItem: Text {
            text: btn.text; color: Theme.textPrimary; font: btn.font
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: Theme.radiusS
            color: btn.down ? Qt.darker(btn.tint, 1.3)
                 : btn.hovered ? Qt.lighter(btn.tint, 1.15) : btn.tint
            border.color: root.host.cardBorder; border.width: 1
        }
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.spacingXXL
        spacing: Theme.spacingM

        Text {
            text: "Passerelle MCP (canal IA)"
            color: root.host.textPrimary
            font.bold: true
            font.pixelSize: Theme.fontSizeMedium
            Layout.fillWidth: true
        }
        Text {
            text: "AiGatewayServer · loopback HTTP JSON-RPC — opt-in --ai-gateway-port"
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeCaption
            font.italic: true
            Layout.fillWidth: true
        }

        // — Bannière d'état (présente / absente) —
        Rectangle {
            objectName: "gwStatusBanner"
            Layout.fillWidth: true
            Layout.preferredHeight: bannerText.implicitHeight + Theme.spacingM * 2
            radius: Theme.radiusS
            readonly property color _c: root._listening ? Theme.success
                                      : root._present ? Theme.warning : Theme.danger
            color: Qt.rgba(_c.r, _c.g, _c.b, 0.15)
            border.color: _c
            border.width: 1
            Text {
                id: bannerText
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                text: root._listening
                        ? "Passerelle démarrée et à l'écoute sur 127.0.0.1:" + root._port
                        : root._present
                          ? "Passerelle instanciée mais pas à l'écoute (add-on HTTP absent ?)"
                          : "Passerelle non démarrée — lancez avec --ai-gateway-port <N>"
                color: parent._c
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                wrapMode: Text.WordWrap
                verticalAlignment: Text.AlignVCenter
            }
        }

        // — Détails —
        GridLayout {
            columns: 2
            columnSpacing: Theme.spacingXL
            rowSpacing: Theme.spacingXS
            Layout.fillWidth: true

            FieldLabel { text: "présente" }
            ValueText {
                objectName: "gwPresent"
                text: "" + root._present
                color: root._present ? Theme.success : Theme.danger
            }
            FieldLabel { text: "à l'écoute" }
            ValueText {
                objectName: "gwListening"
                text: "" + root._listening
                color: root._listening ? Theme.success : root.host.textSecondary
            }
            FieldLabel { text: "port" }
            ValueText { objectName: "gwPort"; text: root._port > 0 ? "" + root._port : "—" }

            FieldLabel { text: "MEOW_HAS_HTTP_SERVER" }
            ValueText {
                objectName: "gwHttpAvailable"
                text: "" + root._httpAvailable
                color: root._httpAvailable ? Theme.success : Theme.warning
            }

            FieldLabel { text: "token proposante (D20)" }
            ValueText { objectName: "gwProposerToken"; text: root._mask(root._proposerToken); Layout.fillWidth: true }
            FieldLabel { text: "token arbitre (D20)" }
            ValueText { objectName: "gwArbiterToken"; text: root._mask(root._arbiterToken); Layout.fillWidth: true }
        }

        Text {
            visible: root._present
            text: "Secrets loopback (D20) — jamais journalisés. Affichés ici pour diagnostic uniquement."
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeCaption
            font.italic: true
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        // — Actions —
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS
            StyledButton {
                objectName: "gwRefreshBtn"
                text: "Rafraîchir"
                onClicked: root._refresh()
            }
            StyledButton {
                objectName: "gwRevealBtn"
                text: root._revealTokens ? "Masquer tokens" : "Révéler tokens"
                enabled: root._present
                tint: Theme.surfaceAlt
                onClicked: root._revealTokens = !root._revealTokens
            }
            Item { Layout.fillWidth: true }
        }
    }
}
