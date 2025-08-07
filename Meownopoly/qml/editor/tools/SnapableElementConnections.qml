import QtQuick 2.15

QtObject {
    id: connectionManager
    
    property var targetElement
    property var previousElements: []
    property var nextElements: []
    
    function addPreviousElement(element) {
        if (element && !previousElements.includes(element)) {
            previousElements.push(element)
            element.connections.nextElements.push(targetElement)
        }
    }

    function addNextElement(element) {
        if (element && !nextElements.includes(element)) {
            nextElements.push(element)
            element.connections.previousElements.push(targetElement)
        }
    }

    function removePreviousElement(element) {
        var index = previousElements.indexOf(element)
        if (index !== -1) {
            previousElements.splice(index, 1)
            var otherIndex = element.connections.nextElements.indexOf(targetElement)
            if (otherIndex !== -1) {
                element.connections.nextElements.splice(otherIndex, 1)
            }
        }
    }

    function removeNextElement(element) {
        var index = nextElements.indexOf(element)
        if (index !== -1) {
            nextElements.splice(index, 1)
            var otherIndex = element.connections.previousElements.indexOf(targetElement)
            if (otherIndex !== -1) {
                element.connections.previousElements.splice(otherIndex, 1)
            }
        }
    }

    function isConnectedTo(element) {
        return previousElements.includes(element) || nextElements.includes(element)
    }

    function getAllConnectedElements() {
        return previousElements.concat(nextElements)
    }
} 