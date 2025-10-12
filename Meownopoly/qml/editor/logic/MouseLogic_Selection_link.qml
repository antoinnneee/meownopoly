import QtQuick 2.15
import "../tools/snapable"

MouseLogic_Selection {
    id: mouseLogic
    
    // Paramètre pour le type de lien
    property string kind: ""
    
    // Propriétés pour la gestion des liens
    property bool isLinking: false
    property var linkSourceCase: null
    
    
}

