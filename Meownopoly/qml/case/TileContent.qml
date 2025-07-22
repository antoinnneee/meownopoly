pragma ComponentBehavior:Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Case
import "content/"

Item {
    id: root
    
    clip: true
    required property Case caseData
    property var familyColors: []

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
            switch(root.caseData.type) {
                case Case.CS_KibbleDispenser: return kibbleDispenserContent
                case Case.CS_RestArea: return restAreaContent
                case Case.CS_CardBoardBox: return cardBoardBoxContent
                case Case.CS_CatNip: return catNipContent
                case Case.CS_Jail: return jailContent
                case Case.CS_ToJail: return toJailContent
                case Case.CS_CatDoor: return catDoorContent
                case Case.CS_FreeNap: return freeNapContent
                case Case.CS_Device: return catDeviceContent
                default: return null
            }
        }
    }

    Component {
        id: restAreaContent
        RestAreaContent {
            caseData: (root.caseData.type === Case.CS_RestArea) ? root.caseData : null
            familyColors: root.familyColors
        }
    }

    Component {
        id: kibbleDispenserContent
        KibbleDispenserContent{
            caseData: (root.caseData.type === Case.CS_KibbleDispenser) ? root.caseData : null
        }

        // KibbleDispenserContent {
        //     caseData: root.caseData
        // }
    }

    Component {
        id: cardBoardBoxContent
        CardBoardBoxContent {
            caseData: (root.caseData.type === Case.CS_CardBoardBox) ? root.caseData : null
        }
    }

    Component {
        id: catNipContent
        CatNipContent {
            caseData: (root.caseData.type === Case.CS_CatNip) ? root.caseData : null
        }
    }

    Component {
        id: jailContent
        JailContent {
            caseData: root.caseData
        }
    }

    Component {
        id: toJailContent
        ToJailContent {
            caseData: (root.caseData.type === Case.CS_ToJail) ? root.caseData : null
        }
    }

    Component {
        id: catDoorContent
        CatDoorContent {
            caseData: (root.caseData.type === Case.CS_CatDoor) ? root.caseData : null
        }
    }

    Component {
        id: freeNapContent
        FreeNapContent {
            caseData: (root.caseData.type === Case.CS_FreeNap) ? root.caseData : null
        }
    }

    Component {
        id: catDeviceContent
        CatDeviceContent {
            caseData: (root.caseData.type === Case.CS_Device) ? root.caseData : null
        }
    }



} 
