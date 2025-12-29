import QtQuick 2.15
import "../../meowComponent/grid"
import "../../meowComponent/snapable"

QtObject {
    required property list<SnapableElement> snapableTilesList
    required property GridManager editorGrid
    required property var logic

    property int minPlanDisplayed: 1
    property int maxPlanDisplayed: 10

    onMinPlanDisplayedChanged: {
        updatePlanVisibility()
    }

    onMaxPlanDisplayedChanged: {
        updatePlanVisibility()
    }

    // Function to update visibility based on plan range
    function updatePlanVisibility() {
        if (logic.isEditing) {
            console.log("Changement de plage de plans affichés:", minPlanDisplayed, "-", maxPlanDisplayed)
            for (var i = 0; i < snapableTilesList.length; i++) {
                if (snapableTilesList[i]) {
                    var currentTile = snapableTilesList[i]
                    var tileZ = currentTile.z || currentTile.snapableParameters.displayParameter.zLayer || 1

                    if ((tileZ >= minPlanDisplayed && tileZ <= maxPlanDisplayed) || tileZ === 11 ) {
                        currentTile.enabled = true
                        currentTile.opacity = 1
                    } else {
                        currentTile.enabled = false
                        currentTile.opacity = 0.2
                    }
                }
            }
        }
    }

}
