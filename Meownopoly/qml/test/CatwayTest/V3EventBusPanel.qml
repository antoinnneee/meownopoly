import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MeowEvents 1.0
import theme
import ui_item

// Panneau de test interactif — bus d'événements métier (M5, D1-D4).
//   - journal live scrollable (eventPublished → ListModel : seq/type/actor/résumé) ;
//   - injection d'événements de test (publish) ;
//   - events_poll(cursor) : réponse brute {entries, nextCursor, truncated, oldestSeq} ;
//   - aperçu du résumé injecté (canalSummary) avec audience proposer/arbiter ;
//   - compteurs (eventCount, logicalClock, auditCount, rejectedCount).
Rectangle {
    id: root
    required property var host

    property string _pollResult: ""
    property string _summaryText: ""

    color: host.cardBg
    radius: host.cardRadius
    border.color: host.cardBorder
    border.width: 1
    implicitHeight: content.implicitHeight + Theme.spacingXXL * 2

    // Aligné sur meow::EventType (event_types.h). Sous-ensemble courant pour les
    // tests ; publish() accepte n'importe quel entier valide de l'enum.
    readonly property var _eventTypes: [
        { label: "TileCreated (300)", type: 300 },
        { label: "EditorOpLocal (200)", type: 200 },
        { label: "MapLoaded (101)", type: 101 },
        { label: "TileMoved (302)", type: 302 }
    ]

    function _audience() {
        // 0 = proposer, 1 = arbiter (GameplayEventBus::CanalAudience).
        return audienceCombo.currentIndex;
    }

    function _publish() {
        const spec = root._eventTypes[typeCombo.currentIndex];
        // source 1 = Game (event_types.h EventSource). Le payload est opaque.
        GameplayEventBus.publish(spec.type, 1, actorField.text || "tester",
                                 { summary: summaryField.text, target: "tile-test" });
    }

    function _poll() {
        const cur = parseInt(cursorField.text) || 0;
        const r = GameplayEventBus.canalPoll(cur, root._audience(), 32);
        root._pollResult = JSON.stringify({
            count: r.count,
            nextCursor: r.nextCursor,
            truncated: r.truncated,
            oldestSeq: r.oldestSeq,
            entries: r.entries
        }, null, 1);
    }

    function _summary() {
        const cur = parseInt(cursorField.text) || 0;
        const r = GameplayEventBus.canalSummary(cur, root._audience(), 20);
        root._summaryText = r.text + "\n— matched=" + r.matched + " listed=" + r.listed
                          + " omitted=" + r.omitted + " nextCursor=" + r.nextCursor
                          + (r.truncated ? " [TRUNCATED]" : "");
    }

    // Journal live : chaque événement publié entre dans le modèle.
    Connections {
        target: GameplayEventBus
        function onEventPublished(event) {
            eventsModel.append({
                seq: "" + (event.seq !== undefined ? event.seq : "?"),
                etype: event.type !== undefined ? ("" + event.type) : "?",
                actor: event.author || event.actor || "—",
                summary: (event.payload && event.payload.summary)
                         ? event.payload.summary
                         : (event.summary || "")
            });
            if (eventsModel.count > 200)
                eventsModel.remove(0, eventsModel.count - 200);
        }
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.spacingXXL
        spacing: Theme.spacingM

        Text {
            text: "Bus d'événements"
            color: root.host.textPrimary
            font.bold: true
            font.pixelSize: Theme.fontSizeMedium
            Layout.fillWidth: true
        }
        Text {
            text: "MeowEvents · GameplayEventBus (M5, journal + curseur + canal IA)"
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeCaption
            font.italic: true
            Layout.fillWidth: true
        }

        // ── Compteurs ────────────────────────────────────────────────────────
        GridLayout {
            columns: 4
            columnSpacing: Theme.spacingL
            rowSpacing: Theme.spacingXS
            Layout.fillWidth: true

            Text { text: "eventCount"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text {
                objectName: "eventCountLabel"
                text: "" + GameplayEventBus.eventCount
                color: root.host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas"
            }
            Text { text: "logicalClock"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + GameplayEventBus.logicalClock; color: root.host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "auditCount"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + GameplayEventBus.auditCount; color: root.host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }
            Text { text: "rejectedCount"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text {
                text: "" + GameplayEventBus.rejectedCount
                color: GameplayEventBus.rejectedCount > 0 ? Theme.danger : root.host.textPrimary
                font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas"
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.host.cardBorder }

        // ── Injection d'un événement de test ─────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS

            MeowComboBox {
                id: typeCombo
                objectName: "eventTypeCombo"
                Layout.preferredWidth: Theme.px(150)
                font.pixelSize: Theme.fontSizeSmall
                model: root._eventTypes.map(function (e) { return e.label; })
            }
            MeowTextField {
                id: actorField
                objectName: "eventActorField"
                Layout.preferredWidth: Theme.px(80)
                text: "tester"
                placeholderText: "actor"
                font.pixelSize: Theme.fontSizeSmall
                color: root.host.textPrimary
            }
            MeowTextField {
                id: summaryField
                objectName: "eventSummaryField"
                Layout.fillWidth: true
                text: "évènement de test"
                placeholderText: "summary (payload)"
                font.pixelSize: Theme.fontSizeSmall
                color: root.host.textPrimary
            }
            MeowButton {
                objectName: "eventPublishButton"
                text: "publish"
                font.pixelSize: Theme.fontSizeSmall
                onClicked: root._publish()
            }
        }

        // ── Journal live ─────────────────────────────────────────────────────
        Text {
            text: "Journal live (seq · type · actor · résumé)"
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeSmall
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.px(120)
            color: Theme.background
            radius: Theme.radiusM
            border.color: root.host.cardBorder
            border.width: 1
            clip: true

            ListView {
                id: eventsView
                objectName: "eventJournalList"
                anchors.fill: parent
                anchors.margins: Theme.spacingXS
                model: ListModel { id: eventsModel }
                delegate: RowLayout {
                    required property string seq
                    required property string etype
                    required property string actor
                    required property string summary
                    width: eventsView.width
                    spacing: Theme.spacingS
                    Text { text: seq; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeCaption; font.family: "Consolas"; Layout.preferredWidth: Theme.px(28) }
                    Text { text: etype; color: Theme.accent; font.pixelSize: Theme.fontSizeCaption; font.family: "Consolas"; Layout.preferredWidth: Theme.px(24) }
                    Text { text: actor; color: root.host.textPrimary; font.pixelSize: Theme.fontSizeCaption; font.family: "Consolas"; Layout.preferredWidth: Theme.px(60); elide: Text.ElideRight }
                    Text { text: summary; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeCaption; Layout.fillWidth: true; elide: Text.ElideRight }
                }
                onCountChanged: positionViewAtEnd()
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.host.cardBorder }

        // ── Curseur : events_poll + résumé injecté ───────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS

            Text { text: "cursor"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall; Layout.alignment: Qt.AlignVCenter }
            MeowTextField {
                id: cursorField
                objectName: "eventCursorField"
                Layout.preferredWidth: Theme.px(64)
                text: "0"
                inputMethodHints: Qt.ImhDigitsOnly
                font.pixelSize: Theme.fontSizeSmall
                color: root.host.textPrimary
            }
            Text { text: "audience"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall; Layout.alignment: Qt.AlignVCenter }
            MeowComboBox {
                id: audienceCombo
                objectName: "eventAudienceCombo"
                Layout.preferredWidth: Theme.px(96)
                font.pixelSize: Theme.fontSizeSmall
                model: ["proposer", "arbiter"]
            }
            MeowButton {
                objectName: "eventPollButton"
                text: "events_poll"
                font.pixelSize: Theme.fontSizeSmall
                onClicked: root._poll()
            }
            MeowButton {
                objectName: "eventSummaryButton"
                text: "canalSummary"
                font.pixelSize: Theme.fontSizeSmall
                onClicked: root._summary()
            }
        }

        Text {
            text: "events_poll(cursor) → réponse Q-E06"
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeSmall
            visible: root._pollResult !== ""
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: pollText.implicitHeight + Theme.spacingS * 2
            visible: root._pollResult !== ""
            color: Theme.background
            radius: Theme.radiusM
            border.color: root.host.cardBorder
            border.width: 1
            Text {
                id: pollText
                objectName: "eventPollResult"
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                text: root._pollResult
                color: root.host.textPrimary
                font.pixelSize: Theme.fontSizeCaption
                font.family: "Consolas"
                wrapMode: Text.WrapAnywhere
            }
        }

        Text {
            text: "canalSummary (bloc injecté)"
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeSmall
            visible: root._summaryText !== ""
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: summaryText.implicitHeight + Theme.spacingS * 2
            visible: root._summaryText !== ""
            color: Theme.background
            radius: Theme.radiusM
            border.color: root.host.cardBorder
            border.width: 1
            Text {
                id: summaryText
                objectName: "eventSummaryResult"
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                text: root._summaryText
                color: root.host.textPrimary
                font.pixelSize: Theme.fontSizeCaption
                font.family: "Consolas"
                wrapMode: Text.WordWrap
            }
        }
    }
}
