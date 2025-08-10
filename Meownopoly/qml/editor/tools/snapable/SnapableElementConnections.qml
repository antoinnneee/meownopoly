import QtQuick 2.15
import ".."
Item {
    id: connectionManager
    
    property var parentElement
    property var previousElements: []
    property var nextElements: []

    // Segments de connexion (fromItem -> toItem)
    ListModel {
        id: nextElementsSegments
    }
    onNextElementsChanged: {
        nextElementsSegments.clear()

        var nexts = nextElements || []
        for (var j = 0; j < nexts.length; j++) {
            var nextEl = nexts[j]
            if (nextEl) {
                // Créer un objet segment avec les coordonnées
                nextElementsSegments.append( {
                    "fromElement": parentElement,
                    "toElement": nextEl,
                })

            }
        }

    }

    Repeater {
        id: connectionRepeater
        model: nextElementsSegments
        delegate: ConnectionOverlay2{
            x: -parentElement.x
            y: -parentElement.y
        }
    }

    // Point central de l'élément parent
    function getParentCenterLocal() {
        if (!parentElement) return Qt.point(0, 0)
        return Qt.point(parentElement.width / 2,parentElement.height / 2)
    }

    function getParentCenterScene() {
        if (!parentElement) return Qt.point(0, 0)
        return Qt.point(parentElement.x + parentElement.width / 2,parentElement.y +  parentElement.height / 2)
    }

    // Segments (from->to) depuis l'élément courant vers chaque "suivant"
    function computeNextPaths() {
        var paths = []
        var from = getParentCenterScene()
        for (var i = 0; i < nextElements.length; ++i) {
            var to = getElementCenterScene(nextElements[i])
            paths.push({ from: from, to: to })
        }
        return paths
    }

    function addPreviousElement(element) {
        if (element && !previousElements.includes(element)) {
            // Réaffecter pour notifier QML
            previousElements = previousElements.concat([element])
            if (element.connectionManager && !element.connectionManager.nextElements.includes(parentElement)) {
                element.connectionManager.nextElements = element.connectionManager.nextElements.concat([parentElement])
            }
        }
    }

    function addNextElement(element) {
        if (element && !nextElements.includes(element)) {
            // Réaffecter pour notifier QML
            nextElements = nextElements.concat([element])
            if (element.connectionManager && !element.connectionManager.previousElements.includes(parentElement)) {
                element.connectionManager.previousElements = element.connectionManager.previousElements.concat([parentElement])
            }
        }
    }

    function removePreviousElement(element) {
        var index = previousElements.indexOf(element)
        if (index !== -1) {
            previousElements.splice(index, 1)
        }
    }

    function removeNextElement(element) {
        var index = nextElements.indexOf(element)
        if (index !== -1) {
            nextElements.splice(index, 1)
        }
    }

    function isConnectedTo(element) {
        return previousElements.includes(element) || nextElements.includes(element)
    }

    function getAllConnectedElements() {
        return previousElements.concat(nextElements)
    }

    /*remove all connections to the element and remove the element from the previousElements and nextElements*/
    function deleteLinkedConnection()
    {
        for (var i = 0; i < previousElements.length; i++) {
            if (previousElements[i]) {
                previousElements[i].removeNextElement(parentElement)
            }
        }
        for (var i = 0; i < nextElements.length; i++) {
            if (nextElements[i]) {
                nextElements[i].removePreviousElement(parentElement)
            }
        }
        previousElements = []
        nextElements = []
        nextElementsSegments.clear()
    }

}
