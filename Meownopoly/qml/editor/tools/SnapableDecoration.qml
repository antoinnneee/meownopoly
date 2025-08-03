import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

SnapableElement {
    // Configuration du redimensionnement
    isResizable: true
    autoSnap: true

    unitSizeHeight: 6
    unitSizeWidth:4


    property int randomImageIndex: Math.floor(Math.random() * 3)  // Random number between 0 and 2

    Image {
        id: caseTile
        anchors.fill: parent
        source: "qrc:/asset/element/tree_lowpoly_" + randomImageIndex + ".png"
        z: 1  // Assurer que le contenu est sous les poignées
        asynchronous: true
        cache: true  // Cache the image to prevent reloading
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true  // Enable mipmapping for better quality when scaling down

    }

}
