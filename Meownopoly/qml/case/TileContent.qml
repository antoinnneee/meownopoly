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


    // Specific tile details
    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        anchors.fill: parent
        sourceComponent: {
            if (root.caseData == undefined) return null;
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
        RestAreaContent2 {
            caseData: (root.caseData != undefined && root.caseData.type === Case.CS_RestArea) ? root.caseData : null
            familyColors: root.familyColors
        }
    }

    Component {
        id: kibbleDispenserContent
        KibbleDispenserContent2{
            caseData: (root.caseData != undefined && root.caseData.type === Case.CS_KibbleDispenser) ? root.caseData : null
        }
    }

    Component {
        id: cardBoardBoxContent
        CardBoardBoxContent2 {
            caseData: (root.caseData != undefined && root.caseData.type === Case.CS_CardBoardBox) ? root.caseData : null
        }
    }

    Component {
        id: catNipContent
        CatNipContent2 {
            caseData: (root.caseData != undefined && root.caseData.type === Case.CS_CatNip) ? root.caseData : null
        }
    }

    Component {
        id: jailContent
        JailContent2 {
            caseData: root.caseData
        }
    }

    Component {
        id: toJailContent
        ToJailContent2 {
            caseData: (root.caseData != undefined && root.caseData.type === Case.CS_ToJail) ? root.caseData : null
        }
    }

    Component {
        id: catDoorContent
        CatDoorContent2 {
            caseData: (root.caseData != undefined && root.caseData.type === Case.CS_CatDoor) ? root.caseData : null
        }
    }

    Component {
        id: freeNapContent
        FreeNapContent2 {
            caseData: (root.caseData != undefined && root.caseData.type === Case.CS_FreeNap) ? root.caseData : null
        }
    }

    Component {
        id: catDeviceContent
        CatDeviceContent2 {
            caseData: (root.caseData != undefined && root.caseData.type === Case.CS_Device) ? root.caseData : null
        }
    }
} 
