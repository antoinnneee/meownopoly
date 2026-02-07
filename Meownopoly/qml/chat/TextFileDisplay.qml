import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs

Column {
    id: textFileDisplay
    width: parent.width
    spacing: 4

    required property string text
    required property string fileExtension
    property var chatClient: null

    // Parse the text file format: 📄FILE:ext:filename\n\ncontenu
    property string fileName: {
        if (!text.startsWith("📄FILE:")) return "Unknown"
        let firstLine = text.split('\n')[0]
        let fileIdx = firstLine.indexOf("FILE:")
        if (fileIdx === -1) return "Unknown"
        let afterPrefix = firstLine.substring(fileIdx + 5)
        let parts = afterPrefix.split(':')
        return parts.length > 1 ? parts[1] : "Unknown"
    }

    property string fileContent: {
        if (!text.startsWith("📄FILE:")) return text
        let idx = text.indexOf('\n\n')
        if (idx === -1) {
            let nlIdx = text.indexOf('\n')
            if (nlIdx === -1) return ""
            return text.substring(nlIdx + 1)
        }
        return text.substring(idx + 2)
    }

    property var extensionIcons: ({
        "txt": "📄", "md": "📝", "json": "📊", "xml": "🏷️",
        "js": "📜", "ts": "📜", "py": "🐍", "cpp": "⚙️", "c": "⚙️", "h": "⚙️",
        "java": "☕", "html": "🌐", "css": "🎨", "log": "📋",
        "csv": "📊", "sql": "🗄️", "sh": "🖥️", "bat": "🖥️", "qml": "🎨"
    })

    property string icon: extensionIcons[fileExtension.toLowerCase()] || "📄"
    property bool copyFeedback: false

    FileDialog {
        id: saveDialog
        title: "Sauvegarder le fichier"
        fileMode: FileDialog.SaveFile
        currentFile: "file:///" + textFileDisplay.fileName
        onAccepted: {
            if (textFileDisplay.chatClient) {
                textFileDisplay.chatClient.saveTextToFile(
                    saveDialog.selectedFile,
                    textFileDisplay.fileContent
                )
            }
        }
    }

    // En-tête violet avec infos fichier
    Rectangle {
        width: parent.width
        height: 30
        color: "#667eea"
        radius: 6

        Row {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 6
            spacing: 8

            // Icône + nom du fichier
            Text {
                text: textFileDisplay.icon + " " + textFileDisplay.fileName
                font.pixelSize: 11
                font.bold: true
                color: "white"
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideMiddle
                width: parent.width - 170
            }

            // Badge extension
            Rectangle {
                width: 36
                height: 18
                color: "#5568d3"
                radius: 9
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: textFileDisplay.fileExtension.toUpperCase()
                    font.pixelSize: 8
                    font.bold: true
                    color: "white"
                    anchors.centerIn: parent
                }
            }

            // Bouton Copier
            Rectangle {
                width: 52
                height: 20
                color: copyArea.containsMouse ? "#5568d3" : "#4a5bc7"
                radius: 4
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: textFileDisplay.copyFeedback ? "✓ Copié" : "Copier"
                    font.pixelSize: 9
                    font.bold: true
                    color: "white"
                    anchors.centerIn: parent
                }

                MouseArea {
                    id: copyArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        contentText.selectAll()
                        contentText.copy()
                        contentText.deselect()
                        textFileDisplay.copyFeedback = true
                        copyTimer.restart()
                    }
                }
            }

            // Bouton Sauver
            Rectangle {
                width: 52
                height: 20
                color: saveArea.containsMouse ? "#5568d3" : "#4a5bc7"
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                visible: !!textFileDisplay.chatClient

                Text {
                    text: "Sauver"
                    font.pixelSize: 9
                    font.bold: true
                    color: "white"
                    anchors.centerIn: parent
                }

                MouseArea {
                    id: saveArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: saveDialog.open()
                }
            }
        }
    }

    Timer {
        id: copyTimer
        interval: 1500
        onTriggered: textFileDisplay.copyFeedback = false
    }

    // Contenu du fichier (scrollable)
    Rectangle {
        width: parent.width
        height: Math.min(contentText.contentHeight + 20, 300)
        color: "#2a2a2a"
        radius: 6
        border.color: "#444444"
        border.width: 1

        ScrollView {
            id: scrollView
            anchors.fill: parent
            anchors.margins: 10
            clip: true

            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ScrollBar.horizontal.policy: ScrollBar.AsNeeded

            TextEdit {
                id: contentText
                width: scrollView.width - 10
                text: textFileDisplay.fileContent
                wrapMode: TextEdit.Wrap
                readOnly: true
                selectByMouse: true
                color: "#e0e0e0"
                font.family: "Consolas, Monaco, monospace"
                font.pixelSize: 11
                textFormat: TextEdit.PlainText
            }
        }
    }
}
