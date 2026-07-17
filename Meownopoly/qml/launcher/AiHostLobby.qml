import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import theme
import AiSupervisor

/*
 * AiHostLobby.qml — Lobby « Héberger une partie IA » (C6, D24/D31).
 *
 * Panneau réutilisable et autonome qui matérialise le prérequis arbitre avant
 * d'ouvrir le mode IA :
 *   - indicateur d'état à 4 valeurs (Absent → Test en cours → Prêt → Erreur),
 *     lié à AiProcessSupervisor.arbiterLobbyState (projection D31 qui intègre le
 *     résultat du handshake/challenge, pas seulement l'état du process) ;
 *   - motif actionnable affiché à côté en cas d'Erreur (pas de dialogue
 *     bloquant, D31) ;
 *   - bouton « Tester l'arbitre » (re-test manuel) + test AUTOMATIQUE à
 *     l'ouverture (Component.onCompleted) ;
 *   - bouton « Héberger une partie IA » GRISÉ tant que l'état ≠ Prêt.
 *
 * Ce composant ne lance pas la partie lui-même : il émet `hostRequested()` que
 * le flux d'intégration (C7 / menu) branche. Les options du challenge (token de
 * rôle éphémère D20, programme CLI, URL passerelle, skill) sont fournies par le
 * contexte via `handshakeOpts` — jamais codées en dur ici (doc 14 §2.2).
 */
Item {
    id: root

    // Options passées au challenge d'arbitre (voir AiProcessSupervisor.startAgent).
    // Ex. { token, program, adapter, gatewayUrl, skillPath, model }. Le token
    // (D20) est un secret : il n'apparaît jamais dans l'UI ni les logs.
    property var handshakeOpts: ({})

    // Lance-t-on un test automatique dès l'affichage du lobby ? (D31)
    property bool autoTestOnOpen: true

    // Émis quand le joueur clique « Héberger une partie IA » (état Prêt requis).
    signal hostRequested()

    implicitWidth: 420
    implicitHeight: content.implicitHeight + 2 * Theme.spacingXL

    // Résout l'état lobby courant de l'arbitre en (couleur, libellé).
    readonly property int _lobby: AiProcessSupervisor.arbiterLobbyState
    readonly property color _stateColor:
          _lobby === AiProcessSupervisor.Prete   ? Theme.success
        : _lobby === AiProcessSupervisor.Testing ? Theme.warning
        : _lobby === AiProcessSupervisor.Erreur  ? Theme.danger
        : Theme.textSecondary
    readonly property string _stateLabel:
          _lobby === AiProcessSupervisor.Prete   ? qsTr("Prêt")
        : _lobby === AiProcessSupervisor.Testing ? qsTr("Test en cours…")
        : _lobby === AiProcessSupervisor.Erreur  ? qsTr("Erreur")
        : qsTr("Absent")

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        radius: Theme.radiusL
        border.color: Theme.border
        border.width: 1

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: Theme.spacingXL
            spacing: Theme.spacingL

            Text {
                text: qsTr("Arbitre IA")
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeTitle
                font.bold: true
            }

            // — Indicateur 4 états (pastille + libellé) —
            RowLayout {
                spacing: Theme.spacingM
                Layout.fillWidth: true

                Rectangle {
                    width: Theme.fontSizeBody
                    height: width
                    radius: width / 2
                    color: root._stateColor
                    // Pulsation discrète pendant le test.
                    SequentialAnimation on opacity {
                        running: root._lobby === AiProcessSupervisor.Testing
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 600 }
                        NumberAnimation { to: 1.0; duration: 600 }
                    }
                }
                Text {
                    text: root._stateLabel
                    color: root._stateColor
                    font.pixelSize: Theme.fontSizeMedium
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                BusyIndicator {
                    running: root._lobby === AiProcessSupervisor.Testing
                    visible: running
                    implicitWidth: Theme.fontSizeHeading
                    implicitHeight: Theme.fontSizeHeading
                }
            }

            // — Motif actionnable en cas d'erreur (D31 : pas de modale) —
            Text {
                Layout.fillWidth: true
                visible: root._lobby === AiProcessSupervisor.Erreur
                         && text.length > 0
                text: AiProcessSupervisor.arbiterHandshakeReason
                color: Theme.danger
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
            }

            Text {
                Layout.fillWidth: true
                visible: root._lobby === AiProcessSupervisor.Absent
                text: qsTr("Aucun arbitre validé. Lancez un test pour vérifier "
                           + "qu'un arbitre fonctionnel est branché.")
                color: Theme.textSecondary
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
            }

            // — Actions —
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingM

                Button {
                    text: root._lobby === AiProcessSupervisor.Testing
                          ? qsTr("Test en cours…")
                          : qsTr("Tester l'arbitre")
                    enabled: root._lobby !== AiProcessSupervisor.Testing
                    onClicked: root.startTest()
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: qsTr("Héberger une partie IA")
                    // Grisé tant que l'arbitre n'est pas Prêt (D31).
                    enabled: AiProcessSupervisor.arbiterReady
                    onClicked: root.hostRequested()
                }
            }

            // Motif du grisage, affiché à côté du bouton (pas de modale, D31).
            Text {
                Layout.fillWidth: true
                visible: !AiProcessSupervisor.arbiterReady
                text: root._lobby === AiProcessSupervisor.Testing
                      ? qsTr("Vérification de l'arbitre…")
                      : qsTr("« Héberger une partie IA » sera disponible une fois "
                             + "l'arbitre validé.")
                color: Theme.textSecondary
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeCaption
            }
        }
    }

    /// Lance (ou relance) le handshake/challenge de l'arbitre.
    function startTest() {
        AiProcessSupervisor.testArbiter(root.handshakeOpts)
    }

    // Test automatique à l'ouverture du lobby (D31).
    Component.onCompleted: {
        if (autoTestOnOpen
                && AiProcessSupervisor.arbiterLobbyState !== AiProcessSupervisor.Testing)
            startTest()
    }

    // Journalise l'issue du challenge pour diagnostic (optionnel).
    Connections {
        target: AiProcessSupervisor
        function onHandshakeCompleted(role, ok, reason) {
            if (role === AiProcessSupervisor.Arbiter && !ok)
                console.warn("[AiHostLobby] handshake arbitre échoué :", reason)
        }
    }
}
