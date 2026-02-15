import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: udpTestRoot
    required property var host

    property var selectedPlayer: null

    color: "transparent"

    RowLayout {
        anchors.fill: parent
        spacing: 12

        UdpPlayersPanel {
            Layout.preferredWidth: 280
            Layout.fillHeight: true
            host: udpTestRoot.host
            selectedPlayer: udpTestRoot.selectedPlayer
            onPlayerClicked: function(player) {
                udpTestRoot.selectedPlayer = player
            }
        }

        ScrollView {
            id: scrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            contentWidth: availableWidth
            contentHeight: testTilesColumn.implicitHeight

            ColumnLayout {
                id: testTilesColumn
                width: scrollView.availableWidth
                spacing: 12

                UdpChatTile {
                    host: udpTestRoot.host
                }

                UdpDrawTile {
                    host: udpTestRoot.host
                }

                // Ajouter d'autres tuiles ici (ex: NouvelleTuile { host: udpTestRoot.host })
            }
        }
    }
}
