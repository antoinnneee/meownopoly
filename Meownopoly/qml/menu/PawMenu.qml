pragma ComponentBehavior:Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
//import Qt5Compat.GraphicalEffects
import AssetManager
import theme

Item {
    id: root
    
    // Dimensions par défaut
    width: 300
    height: 400
    
    // Propriétés de configuration
    property int mainPadSize: width * 0.6
    property int subPadSize: mainPadSize*0.4
    
    // Propriétés de couleur
    property color mainColor: "#FFA7B6"
    property color hoverColor: "#FF8A9B"
    property color pressedColor: "#FF6B82"
    property color subPadColor: "#FFB6C1"

    property alias mainPad: mainPad

    // État du menu
    property bool isOpen: false
    onIsOpenChanged: {
        console.log("isOpen pawMenu : ", isOpen)

    }
    
    // Actions disponibles
    property var actions: [
    PawTools.createActionButtonModel(AssetManager.getDecorationPath("tree", 0),
                                "info",
                                true,
                                function() {logText.text += "Action: Déplacer\n"}),
    PawTools.createActionButtonModel(AssetManager.getDecorationPath("tree", 1),
                                "explorer",
                                true,
                                function() {logText.text += "Action: Explorer\n"}),
    PawTools.createActionButtonModel(AssetManager.getDecorationPath("tree", 2),
                                "go home",
                                true,
                                function() {logText.text += "Action: goHome\n";mainPad.menuToggled(false)}),
    PawTools.createActionButtonModel(AssetManager.getDecorationPath("grass", 3),
                                "settings",
                                true,
                                function() {logText.text += "Action: Paramètres\n"})
    ]
    property int maxActions: 4
    
    // Signaux
    signal actionTriggered(int actionIndex, var action)
    signal menuToggled(bool opened)
    
    // Animation d'état
    states: [
        State {
            name: "opened"
            when: root.isOpen
            PropertyChanges {
                target: subPadsContainer
                opacity: 1
                scale: 1
            }
        },
        State {
            name: "closed"
            when: !root.isOpen
            PropertyChanges {
                target: subPadsContainer
                opacity: 0
                scale: 0.3
            }
        }
    ]
    
    transitions: [
        Transition {
            from: "closed"
            to: "opened"
            ParallelAnimation {
                NumberAnimation {
                    target: subPadsContainer
                    properties: "opacity,scale"
                    duration: 300
                    easing.type: Easing.OutBack
                }
                SequentialAnimation {
                    loops: 1
                    NumberAnimation {
                        target: mainPad
                        property: "scale"
                        to: 1.1
                        duration: Theme.durationFast
                    }
                    NumberAnimation {
                        target: mainPad
                        property: "scale"
                        to: 1.0
                        duration: Theme.durationFast
                    }
                }
            }
        },
        Transition {
            from: "opened"
            to: "closed"
            NumberAnimation {
                target: subPadsContainer
                properties: "opacity,scale"
                duration: 200
                easing.type: Easing.InBack
            }
        }
    ]
    
    // Conteneur des boutons secondaires (doigts de la patte)
    Item {
        id: subPadsContainer
        anchors.bottom: mainPad.top
        anchors.horizontalCenter: parent.horizontalCenter
        height: mainPad.height
        width: parent.width
        opacity: 0
        scale: 0.3
        
        // Répéteur pour créer les boutons d'action
        Repeater {
            model: Math.min(actions.length, maxActions)
            delegate: PawSubButton {
                required property int index
                id: subButton
                
                // Position calculée pour former une courbe de patte
                x: {
                    const centerX = subPadsContainer.width / 2 - width / 2
                    const positions = [-subButton.width*1.4, -(subButton.width+2)/2, (subButton.width+2)/2, subButton.width*1.4] // Positions relatives au centre
                    return centerX + (positions[index] || 0)
                }
                
                y: {
                    const baseY = subPadsContainer.height - height
                    const heights = [0, subButton.height/2, subButton.height/2, -2] // Hauteurs différentes pour former une courbe
                    return baseY - (heights[index] || 0)
                }
                
                // Propriétés du bouton
                action: actions[index] || null
                padSize: root.subPadSize
                padColor: root.subPadColor
                
                // Gestion du clic
                onClicked: {
                    if (action) {
                        root.actionTriggered(index, action)
                        if (action.action) {
                            action.action()
                        }
                    }
                }
                
                // Animation d'entrée décalée
                Component.onCompleted: {
                    // Délai d'animation basé sur l'index pour un effet en cascade
                    animationDelay.interval = index * 50
                    animationDelay.start()
                }
                
                Timer {
                    id: animationDelay
                    repeat: false
                    onTriggered: {
                        if (root.isOpen) {
                            subButton.opacity = 1
                        }
                    }
                }
            }
        }
    }
    
    // Bouton principal (coussin central de la patte)
    PawMainPad {
        id: mainPad
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        pressedColor: root.pressedColor
        hoverColor: root.hoverColor
        mainColor: root.mainColor
        mainPadSize: root.mainPadSize
        isOpen:  root.isOpen
        onMenuToggled: function(toogle){ root.menuToggled(toogle); root.isOpen = toogle}

    }
    
    // Fermeture automatique si on clique ailleurs
    MouseArea {
        anchors.fill: parent
        enabled: root.isOpen
        z: -1
        onClicked: {
            //root.isOpen = false
            //root.menuToggled(false)
        }
    }
}
