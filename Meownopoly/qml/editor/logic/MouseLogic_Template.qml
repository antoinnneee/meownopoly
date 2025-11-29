import QtQuick 2.15
import QtCore

import "../../component"
import "../../component/snapable"

MouseLogic_Selection {
    id: mouseLogic
    property list<SnapableElement> snapableTemplateTileList
    Component.onCompleted: console.log("MouseLogic_Template loaded")
    function addToList(selectedTiles)
    {
        for (var i = 0; i < selectedTiles.length; i++) {
            var element = selectedTiles[i]
            console.log("newElement add ", element)
            if (element)
                snapableTemplateTileList.push(element)
        }
    }

    // Propriétés pour la sélection par rectangle
    property bool isRectangleSelecting: false
    property point rectangleStart: Qt.point(0, 0)
    property point rectangleCurrent: Qt.point(0, 0)

    // Nouvelles propriétés pour détecter le mouvement même lors d'un "clic"
    property point pressPosition: Qt.point(0, 0)
    property bool hadPressWithoutElement: false


}
