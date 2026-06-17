import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import theme
import ui_item

Rectangle {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: 210
    color: Theme.surfaceHover
    radius: Theme.radiusXL
    border.color: Theme.borderLight
    border.width: 1
    
    property alias serverUrl: serverUrlField.text
    property alias uploadToken: uploadTokenField.text
    property bool connectionValid: false
    property string connectionMessage: ""

    property alias statusAnimation: statusAnimation
    property alias statusIcon: statusIcon

    signal testConnectionRequested()
    signal uploadTokenEdited(string token)
    
    // Animation pour l'icône de statut
    SequentialAnimation {
        id: statusAnimation
        running: false
        
        PropertyAnimation {
            target: statusIcon
            property: "scale"
            to: 1.2
            duration: Theme.durationFast
        }
        PropertyAnimation {
            target: statusIcon
            property: "scale"
            to: 1.0
            duration: Theme.durationFast
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingXXL
        spacing: Theme.spacingL

        Text {
            text: "⚙️ Configuration du serveur"
            font.pixelSize: Theme.fontSizeLarge
            font.bold: true
            color: Theme.textPrimary
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "URL du serveur:"
                color: Theme.textSecondary
                Layout.preferredWidth: 120
            }

            TextField {
                id: serverUrlField
                Layout.fillWidth: true
                placeholderText: "https://localhost:8080"
                color: Theme.textPrimary

                background: Rectangle {
                    color: Theme.surface
                    border.color: Theme.borderLight
                    border.width: 1
                    radius: Theme.radiusS
                }
            }

            MeowButton {
                text: "Tester"
                variant: "primary"
                fontSize: Theme.fontSizeBody
                onClicked: {
                    root.testConnectionRequested()
                    statusIcon.state = "testing"
                }
            }
            
            // Indicateur de statut
            Item {
                id: statusIcon
                width: 24
                height: 24
                
                property string currentIcon: "❓"
                property color currentColor: Theme.textMuted

                states: [
                    State {
                        name: "valid"
                        PropertyChanges {
                            target: statusIcon
                            currentIcon: "✅"
                            currentColor: Theme.success
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
                            currentColor: Theme.danger
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
                            currentColor: Theme.accent
                        }
                    }
                ]

                Text {
                    id: iconText
                    anchors.centerIn: parent
                    text: parent.currentIcon
                    font.pixelSize: Theme.fontSizeLarge
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
            font.pixelSize: Theme.fontSizeBody
            visible: text !== ""
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            opacity: 0.8
        }

        // Token d'upload
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Token upload:"
                color: Theme.textSecondary
                Layout.preferredWidth: 120
            }

            TextField {
                id: uploadTokenField
                Layout.fillWidth: true
                placeholderText: "Token pour autoriser les uploads"
                echoMode: TextInput.Password
                color: Theme.textPrimary
                onTextChanged: root.uploadTokenEdited(text)

                background: Rectangle {
                    color: Theme.surface
                    border.color: Theme.borderLight
                    border.width: 1
                    radius: Theme.radiusS
                }
            }
        }
    }
}
