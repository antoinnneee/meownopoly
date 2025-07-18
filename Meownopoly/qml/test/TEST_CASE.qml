import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Game
import CaseRestArea
import "../case"

Dialog {
    title: "Test Case"
    width: 600
    height: 400

    CaseRestArea {
        id: caseInfo
        name: "testCase"
        onNameChanged:{
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        Rectangle { // left side
            id: leftSide
            Layout.preferredWidth: parent.width * 0.4
            Layout.preferredHeight: parent.height * 0.4
            Layout.alignment: Qt.AlignVCenter
            border.color: "black"
            border.width: 1
            color: "white"

            CaseTile {
                anchors.fill: parent
                caseData: caseInfo
            }
        }

        // Right side controls
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Label {
                text: "Case Name:"
                font.bold: true
            }

            TextField {
                id: nameField
                Layout.fillWidth: true
                text: caseInfo.name
                placeholderText: "Enter case name"
                onTextChanged: {

                    caseInfo.name = text
                    console.log("name changed to ", caseInfo.name);
                }
            }

            Item { // Spacer
                Layout.fillHeight: true
            }
        }
    }
}
