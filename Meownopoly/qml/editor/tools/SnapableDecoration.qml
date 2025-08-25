import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "snapable"

SnapableElement {
    // Configuration du redimensionnement
    isResizable: true
    autoSnap: true

    unitSizeHeight: 6
    unitSizeWidth:4


    property string decorationType: "grass"  // Can be "grass" or "tree"
    property string decorationId: "1"  // Asset ID to use
    property int randomImageIndex: Math.floor(Math.random() * 6)  // Random number between 0 and 3
    property string imagePath: appInstance.getAssetPath("decoration/grass/" + randomImageIndex + ".png")
    Component.onCompleted: {
        type = 1
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

        // Fallback to old system if AssetManager path fails
        onStatusChanged: {
            if (status === Image.Error) {
                console.log("AssetManager path failed, falling back to legacy system")
                source = appInstance.getAssetPath("element/" + decorationType + "/" + decorationId + ".png")
            }
        }
    }
}
