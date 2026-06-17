import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import theme

Column {
    id: textFileDisplay
    width: parent.width
    spacing: Theme.spacingXS

    required property string text
    required property string fileExtension
    property var chatClient: null

    property int fullScreenHeight: -1

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

    // En-tête violet avec infos fichier (même style que l'en-tête des images)
    Rectangle {
        width: parent.width
        height: 30
        color: Theme.violetStart
        radius: Theme.radiusM

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingL
            anchors.rightMargin: Theme.spacingS
            spacing: Theme.spacingM

            // Icône + nom du fichier
            Text {
                text: textFileDisplay.icon + " " + textFileDisplay.fileName
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                color: Theme.textPrimary
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                elide: Text.ElideMiddle
            }

            // Badge extension
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 18
                color: Theme.violetEnd
                radius: 9
                Layout.alignment: Qt.AlignVCenter

                Text {
                    text: textFileDisplay.fileExtension.toUpperCase()
                    font.pixelSize: Theme.fontSizeTiny
                    font.bold: true
                    color: Theme.textPrimary
                    anchors.centerIn: parent
                }
            }

            // Bouton Copier (icône comme pour les images)
            Rectangle {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                color: copyArea.containsMouse ? Theme.violetEnd : "transparent"
                radius: Theme.radiusXS
                Layout.alignment: Qt.AlignVCenter

                Text {
                    text: textFileDisplay.copyFeedback ? "✓" : "📋"
                    font.pixelSize: Theme.fontSizeBody
                    color: Theme.textPrimary
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
                ToolTip {
                    visible: copyArea.containsMouse
                    text: "Copier le texte"
                    delay: 400
                }
            }

            // Bouton Sauver (icône comme pour les images)
            Rectangle {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                color: saveArea.containsMouse ? Theme.violetEnd : "transparent"
                radius: Theme.radiusXS
                Layout.alignment: Qt.AlignVCenter
                visible: !!textFileDisplay.chatClient

                Text {
                    text: "💾"
                    font.pixelSize: Theme.fontSizeBody
                    color: Theme.textPrimary
                    anchors.centerIn: parent
                }

                MouseArea {
                    id: saveArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: saveDialog.open()
                }
                ToolTip {
                    visible: saveArea.containsMouse
                    text: "Enregistrer sous..."
                    delay: 400
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
        height: fullScreenHeight == -1 ?  Math.min(contentText.contentHeight + 20, 300) :
                                         Math.min(contentText.contentHeight + 20, fullScreenHeight)
        color: Theme.surface
        radius: Theme.radiusM
        border.color: Theme.border
        border.width: 1

        ScrollView {
            id: scrollView
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            clip: true

            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ScrollBar.horizontal.policy: ScrollBar.AsNeeded

            TextEdit {
                id: contentText
                width: scrollView.width - 10
                text: textFileDisplay.fileContent
                wrapMode: Text.WordWrap
                readOnly: true
                selectByMouse: true
                color: Theme.textSoft
                font.family: "Consolas, Monaco, monospace"
                font.pixelSize: Theme.fontSizeSmall
                textFormat: textFileDisplay.fileExtension == "md" ? Text.MarkdownText : Text.AutoText
            }
        }
    }
}
