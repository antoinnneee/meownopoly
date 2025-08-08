import QtQuick 2.15

QtObject {
    id: connectionManager
    
    property var parentElement
    property var previousElements: []
    property var nextElements: []
    
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
            // Réaffecter pour notifier QML
            previousElements = previousElements.filter(function(e) { return e !== element })
            if (element.connectionManager) {
                element.connectionManager.nextElements = element.connectionManager.nextElements.filter(function(e) { return e !== parentElement })
            }
        }
    }

    function removeNextElement(element) {
        var index = nextElements.indexOf(element)
        if (index !== -1) {
            // Réaffecter pour notifier QML
            nextElements = nextElements.filter(function(e) { return e !== element })
            if (element.connectionManager) {
                element.connectionManager.previousElements = element.connectionManager.previousElements.filter(function(e) { return e !== parentElement })
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
