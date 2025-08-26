import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "snapable"
import AssetManager
import ItemSnapable

SnapableElement {
    // Configuration du redimensionnement
    isResizable: true
    autoSnap: true

    unitSizeHeight: 6
    unitSizeWidth:4
    type: 1

    type : ItemSnapable.TileType.DecorationTile

    property string decorationType: "grass"  // Can be "grass" or "tree"
    property var decorationModel : AssetManager.getTypeModel("decoration", decorationType)
    property string decorationId: Math.floor(Math.random() * decorationModel.rowCount())
    property string imagePath: AssetManager.getDecorationPath(decorationType, decorationId)

    Component.onCompleted: {
        console.log("Decoration created with model:", decorationModel)
        console.log("model length:", decorationModel.rowCount())
    }

    Image {
        id: tileImage
        anchors.fill: parent
        source: imagePath
        z: 1  // Assurer que le contenu est sous les poignées
        asynchronous: true
        cache: true  // Cache the image to prevent reloading
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true  // Enable mipmapping for better quality when scaling down

        onStatusChanged: {
            if (status === Image.Error) {
                console.log("AssetManager path failed, falling back to legacy system")
            }
        }
    }
}
