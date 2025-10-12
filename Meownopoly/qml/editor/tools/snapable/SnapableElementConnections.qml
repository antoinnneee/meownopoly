import QtQuick 2.15
import ".."
Item {
    id: connectionManager
    
    property var parentElement
    property var previousElements: []
    property var nextElements: []
    property var hoveredElement: null

    signal nextElementAdded(var element)
    signal previousElementAdded(var element)
    signal nextElementRemoved(var element)
    signal previousElementRemoved(var element)

    onNextElementsChanged: {
        nextElementsSegments.updateModel()

    }
    onPreviousElementsChanged: {
    }
    // Segments de connexion (fromItem -> toItem)
    ListModel {
        id: nextElementsSegments
        function updateModel()
        {
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
    }

    Repeater {
        id: connectionRepeater
        model: nextElementsSegments
        delegate: ConnectionOverlay{
            x: -parentElement.x
            y: -parentElement.y
            selected: toElement === connectionManager.hoveredElement
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
        console.log(" function addPreviousElement(element)")
        if (element && !previousElements.includes(element)) {
            // Réaffecter pour notifier QML
            previousElements = previousElements.concat([element])
            previousElementAdded(element)
            if (element.connectionManager && !element.connectionManager.nextElements.includes(parentElement)) {
                element.connectionManager.nextElements = element.connectionManager.nextElements.concat([parentElement])
                element.connectionManager.nextElementAdded(parentElement)
            }
        }
    }

    function addNextElement(element) {
        console.log(" function addNextElement(element)")
        if (element && !nextElements.includes(element)) {
            // Réaffecter pour notifier QML
            nextElements = nextElements.concat([element])
            nextElementAdded(element)
            if (element.connectionManager && !element.connectionManager.previousElements.includes(parentElement)) {
                element.connectionManager.previousElements = element.connectionManager.previousElements.concat([parentElement])
                element.connectionManager.previousElementAdded(parentElement)
            }
        }
    }

    function removePreviousElement(element) {
        var index = previousElements.indexOf(element)
        if (index !== -1) {
            previousElements.splice(index, 1)
            previousElementRemoved(element)
            if (element.connectionManager && element.connectionManager.nextElements.includes(parentElement)) {
                element.connectionManager.nextElements.splice(element.connectionManager.nextElements.indexOf(parentElement), 1)
                element.connectionManager.nextElementRemoved(parentElement)
            }
        }

    }

    function removeNextElement(element) {
        var index = nextElements.indexOf(element)
        if (index !== -1) {
            nextElements.splice(index, 1)
            nextElementsSegments.updateModel()
            nextElementRemoved(element)
            if (element.connectionManager && element.connectionManager.previousElements.includes(parentElement)) {
                element.connectionManager.previousElements.splice(element.connectionManager.previousElements.indexOf(parentElement), 1)
                element.connectionManager.previousElementRemoved(parentElement)
            }
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
                previousElements[i].connectionManager.removeNextElement(parentElement)
            }
        }
        for (var i = 0; i < nextElements.length; i++) {
            if (nextElements[i]) {
                nextElements[i].connectionManager.removePreviousElement(parentElement)
            }
        }
        previousElements = []
        nextElements = []
        nextElementsSegments.clear()
    }

}
