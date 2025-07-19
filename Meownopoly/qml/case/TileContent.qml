import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import "content/"

Item {
    id: root
    
    clip: true
    required property Case caseData

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


    // Specific tile details
    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        anchors.fill: parent
        sourceComponent: {
            console.log("loading type : ", root.caseData.type)
            console.log("root.caseData.type" + root.caseData.type)
            switch(root.caseData.type) {
                case Case.CS_RestArea: return restAreaContent
                case Case:CS_KibbleDispenser: return kibbleDispenserContent
                default: return null
            }
        }
    }

    Component {
        id: restAreaContent
        RestAreaContent {
            caseData: root.caseData
        }
    }

    Component {
        id: kibbleDispenserContent
        Rectangle{
        color:"red"
        }

        /*
        KibbleDispenserContent {
            caseData: root.caseData
        }
        */
    }



} 
