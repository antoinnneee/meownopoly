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
    property bool connectionValid: false
    property string connectionMessage: ""

    property alias statusAnimation: statusAnimation
    property alias statusIcon: statusIcon

    signal testConnectionRequested()
    
    // Animation pour l'icône de statut
    SequentialAnimation {
        id: statusAnimation
        running: false
        
        PropertyAnimation {
            target: statusIcon
            property: "scale"
            to: 1.2
            duration: 100
        }
        PropertyAnimation {
            target: statusIcon
            property: "scale"
            to: 1.0
            duration: 100
        }
    }
    
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
                placeholderText: "https://localhost:8080"
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
                onClicked: {
                    root.testConnectionRequested()
                    statusIcon.state = "testing"
                }
                
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
            
            // Indicateur de statut
            Item {
                id: statusIcon
                width: 24
                height: 24
                
                property string currentIcon: "❓"
                property color currentColor: "#888888"
                
                states: [
                    State {
                        name: "valid"
                        PropertyChanges {
                            target: statusIcon
                            currentIcon: "✅"
                            currentColor: "#4CAF50"
                        }
                        PropertyChanges {
                            target: iconText
                            rotation: 0
                        }
                    },
                    State {
                        name: "invalid"
                        PropertyChanges {
                            target: statusIcon
                            currentIcon: "❌"
                            currentColor: "#f44336"
                        }
                        PropertyChanges {
                            target: iconText
                            rotation: 0
                        }
                    },
                    State {
                        name: "testing"
                        PropertyChanges {
                            target: statusIcon
                            currentIcon: "🔄"
                            currentColor: "#2196f3"
                        }
                    }
                ]
                
                Text {
                    id: iconText
                    anchors.centerIn: parent
                    text: parent.currentIcon
                    font.pixelSize: 16
                    color: parent.currentColor
                    
                    RotationAnimation on rotation {
                        running: statusIcon.state === "testing"
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    
                    ToolTip {
                        visible: parent.containsMouse && root.connectionMessage !== ""
                        text: root.connectionMessage
                        delay: 200
                    }
                }
            }
        }
        
        // Message de statut
        Text {
            id: statusText
            text: root.connectionMessage
            color: statusIcon.currentColor
            font.pixelSize: 12
            visible: text !== ""
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            opacity: 0.8
        }
    }
}
