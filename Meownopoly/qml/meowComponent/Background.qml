import QtQuick 2.15
import QtQml
import ItemSnapable
import MapInfo
import EditorEnum

import meowComponent

Image {
    required property GridManager grid
    anchors.fill: mapInfo.isBackgroundOnGrill ? grid : parent

    visible : mapInfo.backgroundPath === "" ? false : true
    source: mapInfo.backgroundPath

    sourceSize.width: mapInfo.backgroundTileSize
    sourceSize.height: mapInfo.backgroundTileSize


    fillMode: {
        if (mapInfo.backgroundScaling === "Stretch") return Image.Stretch
        else if (mapInfo.backgroundScaling === "Fit") return Image.PreserveAspectFit
        else if (mapInfo.backgroundScaling === "Tile") return Image.Tile
        else return Image.Stretch
    }
    onFillModeChanged:{
        console.log("Background fill mode changed to:", mapInfo.backgroundScaling)
    }

    onSourceChanged: {
        console.log("Background image changed to:", source)
    }
}
