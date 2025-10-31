import QtQuick 2.15
import EditorEnum
import "../../component/snapable"

MouseLogic_Selection {
    id: mouseLogic
    
    // Paramètre pour le type de lien
    property string kind: ""
    
    // Propriétés pour la gestion des liens
    property var linkSourceCase: null
    
    // Propriétés pour le suivi de la souris et la prévisualisation du lien
    property real currentMouseX: 0
    property real currentMouseY: 0
    property var linkPreviewCursor: null
    

    function clickedLeft(mouse, drag)
    {
        mouse.accepted = true
        if (clickElement.length > 0) {
            if (clickElement[0] !== linkSourceCase)
            {
                console.log(clickElement[0], linkSourceCase)
                logic.tileLogic.createSnapableLink(linkSourceCase, clickElement[0], kind)
                clickElement = []
                
                
                // Ne pas masquer la prévisualisation pour permettre plusieurs liens
                return
            }
            else
            {
                console.log("go back to normal selection mode")
                hideLinkPreview()
                changeMouseMode(EditorEnum.EM_NORMAL)
            }
        }
        else
        {
            console.log("go back to normal selection mode")
            hideLinkPreview()
            changeMouseMode(EditorEnum.EM_NORMAL)
        }

        clickElement = []
    }
    
    // Fonction pour mettre à jour la position de la souris
    function updateMousePosition(mouseX, mouseY) {
        currentMouseX = mouseX
        currentMouseY = mouseY
        
        if (linkPreviewCursor) {
            linkPreviewCursor.mouseX = mouseX
            linkPreviewCursor.mouseY = mouseY
            
            // Vérifier si on survole un élément valide pour le lien
            var hoveredElement = getElementAtPosition(mouseX, mouseY)
            var isValidTarget = hoveredElement && hoveredElement !== linkSourceCase
            linkPreviewCursor.updateHoverState(isValidTarget, hoveredElement)
        }
    }
    
    // Fonction pour obtenir l'élément à une position donnée
    function getElementAtPosition(x, y) {
        // Convertir les coordonnées de mainMa vers workArea
        var workAreaPos = mainMa.mapToItem(workArea, x, y)
        
        // Parcourir tous les éléments snapables pour trouver celui sous la souris
        for (var i = 0; i < logic.snapableTilesList.length; i++) {
            var element = logic.snapableTilesList[i]
            if (!element) continue
            
            // Vérifier si la position est dans les limites de l'élément
            if (workAreaPos.x >= element.x && workAreaPos.x <= element.x + element.width &&
                workAreaPos.y >= element.y && workAreaPos.y <= element.y + element.height) {
                return element
            }
        }
        return null
    }
    
    // Fonction pour afficher la prévisualisation du lien
    function showLinkPreview() {
        if (!linkPreviewCursor && linkSourceCase) {
            // Initialiser la position de la souris avec la position actuelle
            // Utiliser la position du centre de l'élément source comme position par défaut
            currentMouseX = linkSourceCase.globalCenterX
            currentMouseY = linkSourceCase.globalCenterY
            
            // Créer le composant LinkPreviewCursor
            var component = Qt.createComponent("../tools/preview/LinkPreviewCursor.qml")
            if (component.status === Component.Ready) {
                linkPreviewCursor = component.createObject(workArea, {
                    "sourceElement": linkSourceCase,
                    "mouseX": currentMouseX,
                    "mouseY": currentMouseY,
                    "gridManager": editorGrid
                })
            }
        }
    }
    
    // Fonction pour masquer la prévisualisation du lien
    function hideLinkPreview() {
        if (linkPreviewCursor) {
            linkPreviewCursor.destroy()
            linkPreviewCursor = null
        }
    }
}

