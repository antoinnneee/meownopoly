import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import theme

// Onglet « V3 IA » du harness CatwayTest (phases 0-5).
//
// Conteneur à sections des briques V3 livrées en phases 0-3, désormais câblées
// à QML (cf. qmlapp.cpp). Chaque section est un fichier séparé, instancié
// DIRECTEMENT (pas de Loader/qrc — cf. piège documenté dans CLAUDE.md « Loader.
// source = qrc:/… peut fail silencieusement » : les modules C++ sont déjà
// importés dans la scène, donc l'instanciation directe est fiable).
//
// Les panneaux couvrent le pipeline IA ainsi que les briques runtime T4/T5.
Rectangle {
    id: root
    required property var host
    color: "transparent"

    // Hauteur implicite dérivée du contenu : indispensable pour que le
    // ScrollView parent (CatwayTest.qml) calcule un contentHeight réel et que
    // l'onglet scrolle. Avec anchors.fill l'implicitHeight restait à 0 → le
    // contenu débordait sans scroll et les panneaux compressés se chevauchaient
    // (clics volés par le voisin).
    implicitHeight: contentColumn.implicitHeight + Theme.spacingS * 2

    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingS
        spacing: Theme.spacingXL

        Text {
            text: "V3 IA — canal, runtime et distribution (phases 0-5)"
            color: root.host.textPrimary
            font.bold: true
            font.pixelSize: Theme.fontSizeLarge
            Layout.fillWidth: true
        }
        Text {
            text: "Banc interactif : pipeline IA, artefacts, saves, migration, règles et bibliothèque GLB."
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
            V3ArtifactPanel   { host: root.host; Layout.fillWidth: true; Layout.alignment: Qt.AlignTop }
            V3GameSavePanel   { host: root.host; Layout.fillWidth: true; Layout.alignment: Qt.AlignTop }
            V3MigrationPanel  { host: root.host; Layout.fillWidth: true; Layout.alignment: Qt.AlignTop }
            V3RulesPanel      { host: root.host; Layout.fillWidth: true; Layout.alignment: Qt.AlignTop }
            V3LibraryPanel    { host: root.host; Layout.fillWidth: true; Layout.alignment: Qt.AlignTop }
        }
    }
}
