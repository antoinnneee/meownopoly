import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Game

Page {
    anchors.fill: parent
    //  Comment -> not sure about this idea
    // Rectangle {
    //     id: background
    //     anchors.fill: parent
    //     gradient: Gradient {
    //         GradientStop { position: 0.0; color: "lightsteelblue" }
    //         GradientStop { position: 1.0; color: "blue" }
    //     }
    // }

    Image {
        anchors.fill: parent
        id: titleImage
        fillMode: Image.PreserveAspectCrop
        source: "qrc:/asset/title.jpg"
    }
    Button{
        anchors.centerIn: parent
        text:"debug Button"
        onClicked:{
            Game.debugButton();
        }
    }

}
