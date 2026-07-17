import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import theme

// Onglet « V3 IA » du harness CatwayTest (étape 1 : squelette).
//
// Conteneur à sections des briques V3 livrées en phases 0-3, désormais câblées
// à QML (cf. qmlapp.cpp). Chaque section est un fichier séparé, instancié
// DIRECTEMENT (pas de Loader/qrc — cf. piège documenté dans CLAUDE.md « Loader.
// source = qrc:/… peut fail silencieusement » : les modules C++ sont déjà
// importés dans la scène, donc l'instanciation directe est fiable).
//
// Les 6 panneaux sont des PLACEHOLDERS avec un smoke test réel (1-2 bindings
// live sur le singleton correspondant) prouvant que le module s'importe et que
// le singleton répond. Ils seront étoffés par des agents suivants.
Rectangle {
    id: root
    required property var host
    color: "transparent"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingS
        spacing: Theme.spacingXL

        Text {
            text: "V3 IA — briques câblées (phases 0-3)"
            color: root.host.textPrimary
            font.bold: true
            font.pixelSize: Theme.fontSizeLarge
            Layout.fillWidth: true
        }
        Text {
            text: "Squelette de test : 6 sections placeholder, un smoke test live par singleton."
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeSmall
            font.italic: true
            Layout.fillWidth: true
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Theme.spacingXL
            rowSpacing: Theme.spacingXL

            V3BenchPanel      { host: root.host; Layout.fillWidth: true; Layout.alignment: Qt.AlignTop }
            V3SupervisorPanel { host: root.host; Layout.fillWidth: true; Layout.alignment: Qt.AlignTop }
            V3GatewayPanel    { host: root.host; Layout.fillWidth: true; Layout.alignment: Qt.AlignTop }
            V3ProposalPanel   { host: root.host; Layout.fillWidth: true; Layout.alignment: Qt.AlignTop }
            V3EventBusPanel   { host: root.host; Layout.fillWidth: true; Layout.alignment: Qt.AlignTop }
            V3StateTxPanel    { host: root.host; Layout.fillWidth: true; Layout.alignment: Qt.AlignTop }
        }

        Item { Layout.fillHeight: true }
    }
}
