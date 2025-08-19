import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: 120
    color: "#3a3a3a"
    radius: 10
    border.color: "#555555"
    border.width: 1
    
    property alias serverUrl: serverUrlField.text
    property alias autoUpdate: autoUpdateCheckBox.checked
    
    signal testConnectionRequested()
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10
        
        Text {
            text: "⚙️ Configuration du serveur"
            font.pixelSize: 16
            font.bold: true
            color: "#ffffff"
        }
        
        RowLayout {
            Layout.fillWidth: true
            
            Text {
                text: "URL du serveur:"
                color: "#cccccc"
                Layout.preferredWidth: 120
            }
            
            TextField {
                id: serverUrlField
                Layout.fillWidth: true
                placeholderText: "http://localhost:8080"
                color: "#ffffff"
                
                background: Rectangle {
                    color: "#2a2a2a"
                    border.color: "#555555"
                    border.width: 1
                    radius: 4
                }
            }
            
            Button {
                text: "Tester"
                onClicked: root.testConnectionRequested()
                
                background: Rectangle {
                    color: parent.pressed ? "#1976d2" : "#2196f3"
                    radius: 6
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
        
        CheckBox {
            id: autoUpdateCheckBox
            text: "Mise à jour automatique"
            
            contentItem: Text {
                text: parent.text
                color: "#cccccc"
                leftPadding: parent.indicator.width + parent.spacing
            }
        }
    }
}
