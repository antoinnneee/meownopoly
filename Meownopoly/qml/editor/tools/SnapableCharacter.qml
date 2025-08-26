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

    property int randomImageIndex: Math.floor(Math.random() * 6)  // Random number between 0 and 3

    Image {
        id: caseTile
        anchors.fill: parent
       source: appInstance.getAssetPath("avatar/avatar" + randomImageIndex + ".png")

        // source: "qrc:/asset/element/lake_" + 0 + ".png"
        z: 1  // Assurer que le contenu est sous les poignées
        asynchronous: true
        cache: true  // Cache the image to prevent reloading
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true  // Enable mipmapping for better quality when scaling down
    }
}
