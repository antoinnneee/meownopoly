import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import AssetManager

import "../"
import "../editorBottomPanel"

EBP_FilterButton {
    id: filterButton
    visible: true
    spacing: 10

    buttonModel : ["All", "Decoration", "Tile"]
}
