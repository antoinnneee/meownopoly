import QtQuick 2.15
import EditorEnum
import "../tools/snapable"

MouseLogic_Selection {
    id: mouseLogic
    
    // Paramètre pour le type de lien
    property string kind: ""
    
    // Propriétés pour la gestion des liens
    property var linkSourceCase: null
    

    function clickedLeft(mouse, drag)
    {
        mouse.accepted = true
        var deltaX = groupeSelection.x
        var deltaY = groupeSelection.y
        if (clickElement.length > 0) {
            if (clickElement[0] !== linkSourceCase)
            {
                console.log(clickElement[0], linkSourceCase)
                logic.tileLogic.createSnapableLink(linkSourceCase, clickElement[0], kind)
                clickElement = []
                return
            }
            else
            {
                console.log("go back to normal selection mode")
                changeMouseMode(EditorEnum.EM_NORMAL)
            }
        }
        clickElement = []
    }
}

