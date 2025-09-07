import QtQuick 2.15
import QtQuick.Controls

Rectangle {
    id: selectionRect
    parent: workArea
    visible: false
    color: "#C7E8FF" // Bleu semi-transparent
    border.width: 2
    border.color: "#3498db"
    opacity: 0.7
    z: 100 // S'assurer qu'il est au-dessus des autres éléments
}
