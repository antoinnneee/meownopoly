import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    
    clip: true
    property int tileType: -1
    property string tileName: ""
    property var tileData: null

    // Icons for different tile types
    property var tileIcons: [
        "qrc:/asset/kibble.png",       // 0: Kibble Dispenser
        "qrc:/asset/bed.png",          // 1: Rest Area
        "qrc:/asset/cardboard.png",    // 2: Card Board Box
        "qrc:/asset/catnip.png",       // 3: Cat Nip
        "qrc:/asset/jail.png",         // 4: Jail
        "qrc:/asset/tojail.png",       // 5: To Jail
        "qrc:/asset/catdoor.png",      // 6: Cat Door
        "qrc:/asset/nap.png",          // 7: Free Nap
        "qrc:/asset/fountain.png",     // 8: Water Fountain
        "qrc:/asset/laser.png",        // 9: Laser Pointer
        "qrc:/asset/tax.png",          // 10: Golden Collar
        "qrc:/asset/tax.png"           // 11: Fur Tax
    ]

    property var fallbackIcons: [
        "🐱💰",       // 0: Kibble Dispenser
        "🛌",          // 1: Rest Area
        "📦❓",       // 2: Card Board Box
        "🌿",          // 3: Cat Nip
        "🔒",          // 4: Jail
        "➡️🔒",       // 5: To Jail
        "🚪",          // 6: Cat Door
        "😴",          // 7: Free Nap
        "💧",          // 8: Water Fountain
        "🔴",          // 9: Laser Pointer
        "👑",          // 10: Golden Collar
        "💸",          // 11: Fur Tax
    ]

    Text {
        id: nameText
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
        }
        text: root.tileName
        color: "#2c3e50"
        font.pixelSize: Math.min(parent.width * 0.13, 11)
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        width: parent.width
        z: 1
    }

    StarRating {
        id: starRating
        anchors {
            top: nameText.bottom
            topMargin: - nameText.height/3
            left: parent.left
            right: parent.right
        }
        Rectangle{
            anchors.fill: parent
            color: "red"
            visible: false
        }

        height: parent.height * 0.2 + nameText.height
        visible: root.tileType === 1
        restQuality: root.tileData && root.tileData.restQuality ? root.tileData.restQuality : 0
        z: 2
    }

    Image {
        id: icon
        anchors {
            horizontalCenter: parent.horizontalCenter
            verticalCenter: parent.verticalCenter
            verticalCenterOffset: root.tileType === 1 ? parent.height * 0.1 : parent.height * 0.1
        }
        width: parent.width * (root.tileType === 1 ? 0.8 : 0.8)
        height: width
        source: root.tileType >= 0 && root.tileType < tileIcons.length ? tileIcons[root.tileType] : ""
        sourceSize {
            width: width * 2  // Request a larger source image for better scaling
            height: height * 2
        }
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true  // Enable mipmapping for better quality when scaling down
        antialiasing: true
        visible: status === Image.Ready
        asynchronous: true
        
        onStatusChanged: {
            if (status === Image.Error) {
                fallbackText.visible = true
            }
        }
    }
    
    Text {
        id: fallbackText
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: nameText.bottom
            topMargin: 2
        }
        width: parent.width * 0.4
        height: width
        text: root.tileType >= 0 && root.tileType < fallbackIcons.length ? fallbackIcons[root.tileType] : "?"
        font.pixelSize: parent.width * 0.25
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        visible: !icon.visible
    }

    Text {
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: parent.height * 0.02
        }
        visible: root.tileType === 1 && root.tileData && root.tileData.price
        text: visible ? root.tileData.price + "K" : ""
        color: "#2c3e50"
        font.pixelSize: parent.width * 0.12
    }
} 
