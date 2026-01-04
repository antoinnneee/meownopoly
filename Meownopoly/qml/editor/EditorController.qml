pragma Singleton
import QtQuick
import EditorEnum
import MapTypes
import Game
import Logger

Item {
    id: keyController

    property var logic: null
    property var selectionPanel: null
    property var escMenu: null
    property var adminCommandPanel: null
    // --- Gestion Clavier ---
    // Cette propriété doit recevoir le focus ou être appelée depuis un Item focusable
    property Item keysHandler: Item {
        focus: true
        Keys.onPressed: (event) => { keyController.handleKeyPress(event) }
        Keys.onReleased: (event) => { keyController.handleKeyRelease(event) }
    }
    function init(logic, selectionPanel, escMenu, adminCommandPanel)
    {
        keyController.logic = logic
        keyController.selectionPanel = selectionPanel
        keyController.escMenu = escMenu
        keyController.adminCommandPanel = adminCommandPanel
        Logger.info("key Controller init", "EditorController")
    }

    function handleKeyPress(event){

        if (event.key === Qt.Key_Delete) {
            var selectItem = logic.mouseLogic.selectedElements
            if (selectItem.length === 0) {
                event.accepted = true
                return
            }

            // Attendre que toutes les animations de suppression soient terminées avant de sauvegarder
            var pendingDeletions = selectItem.length

            // Handler appelé quand chaque animation de suppression est terminée
            var deletionHandler = function() {
                pendingDeletions--
                if (pendingDeletions === 0) {
                    // Toutes les animations sont terminées, sauvegarder maintenant
                    logic.saveMap(MapTypes.UNDOREDO)
                }
            }

            // Connecter au signal elementDeleted de chaque élément et déclencher la suppression
            for (var i = 0; i < selectItem.length; i++) {
                var element = selectItem[i]
                element.elementDeleted.connect(deletionHandler)
                element.deleteRequest(false)
            }
            event.accepted = true
        }
        else if (event.key === Qt.Key_Escape) {
            if (selectionPanel.isAssetSelected) {
                selectionPanel.clearAssetSelection()
                event.accepted = true
            } else if (logic.editorMouseMode === EditorEnum.EM_SELECTION_LINK) {
                logic.mouseLogic.unselectSelectedElements()
                logic.mouseLogic.changeMouseMode(EditorEnum.EM_NORMAL)
                event.accepted = true
            } else {
                // Afficher le menu d'échappement
                escMenu.show()
                event.accepted = true
            }
        }
        else if (event.key === Qt.Key_Control) {
            logic.mouseLogic.isControlPressed = true
            event.accepted = true
        }
        else if (event.key === Qt.Key_Y) {
            if (logic.mouseLogic.isControlPressed)
            {
                console.log("Redo requested via Ctrl+Y")
                Game.askNext()
                event.accepted = true
            }
        }
        else if (event.key === Qt.Key_Z) {
            if (logic.mouseLogic.isControlPressed)
            {
                console.log("Undo requested via Ctrl+Z")
                Game.askPreview()
                event.accepted = true
            }
        }
        else if (event.key === 178)
        {
            adminCommandPanel.visible = !adminCommandPanel.visible
            event.accepted = true
        }
    }


    function handleKeyRelease(event){
        logic.mouseLogic.isControlPressed = false

    }
}
