import QtQuick 2.12
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.15
import QtQuick.Layouts 1.11
import "."

Item {
    id:root
    height:60
    property alias tabBarre: tabBarre
    property alias repeater: repeater
    property int currentIndex: 3
    property int nbButton: 5
    property var nameModel: []
    property AppToolButton selectedButton: undefined


    RadialGradient{
        id: select
        height: selectedButton.height/4
        y: selectedButton.y + selectedButton.height*0.6
        width: selectedButton.width*0.7
        x: selectedButton.x + (width * 0.175)
        gradient: Gradient {
            GradientStop { position: 0.0; color:  (AppStyle.darkEnable) ? Qt.darker(AppStyle.primary) : Qt.lighter(AppStyle.primary)}
            GradientStop { position: 0.5; color: "#00000000" }
        }
        Behavior on x { NumberAnimation {  easing.type: Easing.InOutQuad; duration: 200 } }
    }

    RowLayout{
        id:tabBarre
        anchors.fill: parent
        ButtonGroup{
            id:grp
        }

        width: 300

        Repeater{
            id: repeater
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            Layout.fillWidth: true
            model: root.nbButton

            AppToolButton{
                id:button
                buttonIndex: index
                Layout.fillWidth: true
                ButtonGroup.group: grp
                text: (nameModel[index])? nameModel[index] : "button " + index
                onClicked: {
                }
                onCheckedChanged: {
                    if(checked)
                        root.currentIndex = buttonIndex
                }
                onReleased:  {

                }
                Component.onCompleted: {
                    if(currentIndex == index)
                    {
                        checked = true
                    }

                }

            }
        }
    }
    Component.onCompleted: { selectedButton =  Qt.binding(function() { return repeater.itemAt(currentIndex)}) }
}


