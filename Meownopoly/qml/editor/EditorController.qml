pragma Singleton
import QtQuick
import EditorEnum
import MapTypes
import Game
import Logger
import EditDelta 1.0

    Item {
    id: keyController

    property var logic: null
    property var selectionPanel: null
    property var escMenu: null
    property var fullScreenMsgPopup: null
    property var adminCommandPanel: null
    // --- Gestion Clavier ---
    // Cette propriété doit recevoir le focus ou être appelée depuis un Item focusable
    property Item keysHandler: Item {
        focus: true
        Keys.onPressed: (event) => { keyController.handleKeyPress(event) }
        Keys.onReleased: (event) => { keyController.handleKeyRelease(event) }
    }
    function init(logic, selectionPanel, escMenu, fullScreenMsgPopup, adminCommandPanel)
    {
        keyController.logic = logic
        keyController.selectionPanel = selectionPanel
        keyController.escMenu = escMenu
        keyController.fullScreenMsgPopup = fullScreenMsgPopup
        keyController.adminCommandPanel = adminCommandPanel
        Logger.info("key Controller init", "EditorController")
    }

    function handleKeyPress(event){

        switch(event.key) {
        case (Qt.Key_Control) :
            logic.mouseLogic.isControlPressed = true
            event.accepted = true
            break;
        case (Qt.Key_Delete) :
            var selectItem = logic.mouseLogic.selectedElements
            if (selectItem.length === 0) {
                event.accepted = true
                return
            }

            // Capturer l'état AVANT la suppression pendant que le pointeur C++ est encore valide
            var txId = Game.beginTransaction()
            for (var i = 0; i < selectItem.length; i++) {
                var element = selectItem[i]
                Game.updateEditState(EditDelta.TileDeleted, element.snapableParameters, txId)
                element.deleteRequest(false)
            }
            Game.commitTransaction()
            event.accepted = true
            break;

        case (Qt.Key_Escape) :
            if (selectionPanel.isAssetSelected) {
                selectionPanel.clearAssetSelection()
                event.accepted = true
            } else if (logic.editorMouseMode === EditorEnum.EM_SELECTION_LINK) {
                logic.mouseLogic.unselectSelectedElements()
                logic.mouseLogic.changeMouseMode(EditorEnum.EM_NORMAL)
                event.accepted = true
            } else if (fullScreenMsgPopup.visible) {
                fullScreenMsgPopup.close()
                event.accepted = true
            }
            else {
                // Afficher le menu d'échappement
                escMenu.show()
                event.accepted = true
            }
            break;

        case (Qt.Key_Y) :
            if (logic.mouseLogic.isControlPressed)
            {
                console.log("Redo requested via Ctrl+Y")
                Game.askNext()
                event.accepted = true
            }
            break;

        case (Qt.Key_Z) :
            if (logic.mouseLogic.isControlPressed)
            {
                console.log("Undo requested via Ctrl+Z")
                Game.askPreview()
                event.accepted = true
            }
            break;
        case (178):
            adminCommandPanel.visible = !adminCommandPanel.visible
            event.accepted = true
            break;
        }

    }


    function handleKeyRelease(event) {

        switch(event.key) {
        case (Qt.Key_Control) :
            logic.mouseLogic.isControlPressed = false
            break;
        }

    }
}
