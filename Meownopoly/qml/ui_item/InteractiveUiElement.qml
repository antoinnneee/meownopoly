import QtQuick 2.15
import QtQuick.Controls

/**
 * Composant UI de base interactif
 * Permet le déplacement et le redimensionnement après un long clic
 * Affiche un overlay visuel en mode édition
 */
Item {
    id: root
    
    // Propriétés configurables
    property alias contentItem: contentContainer.data
    property color overlayColor: "#4000AAFF"
    property color borderColor: "#00AAFF"
    property real borderWidth: 2
    property real handleSize: 12
    property real minWidth: 50
    property real minHeight: 50
    
    // État d'édition
    property bool editMode: false
    
    // Dimensions par défaut
    width: 200
    height: 200
    
    // États
    states: [
        State {
            name: "editing"
            when: root.editMode
            PropertyChanges {
                target: overlay
                visible: true
            }
            PropertyChanges {
                target: dragArea
                enabled: true
                cursorShape: Qt.SizeAllCursor
            }
        }
    ]
    
    // Conteneur pour le contenu utilisateur
    Item {
        id: contentContainer
        anchors.fill: parent
        z: 0
    }
    
    // Overlay semi-transparent en mode édition
    Rectangle {
        id: overlay
        anchors.fill: parent
        color: root.overlayColor
        border.color: root.borderColor
        border.width: root.borderWidth
        visible: false
        z: 1
        
        // Animation de l'apparition de l'overlay
        opacity: 0
        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.InOutQuad
            }
        }
        
        Component.onCompleted: {
            if (visible) opacity = 1
        }
        
        onVisibleChanged: {
            opacity = visible ? 1 : 0
        }
    }
    
    // Zone de détection pour activer le mode édition (quand pas en mode édition)
    MouseArea {
        id: activationArea
        anchors.fill: parent
        enabled: !root.editMode
        z: 1
        
        acceptedButtons: Qt.LeftButton
        pressAndHoldInterval: 500
        
        property point longPressPos: Qt.point(0, 0)
        
        onPressAndHold: function(mouse) {
            // Activer le mode édition et démarrer le drag
            longPressPos = Qt.point(mouse.x, mouse.y)
            root.editMode = true
            root.z = 999
            dragArea.clickPos = Qt.point(mouse.x, mouse.y)
        }
        onPositionChanged: function(mouse) {
            if (root.editMode) {
                var delta = Qt.point(mouse.x - dragArea.clickPos.x, mouse.y - dragArea.clickPos.y)

                // Déplacer si mouvement détecté
                if (Math.abs(delta.x) > 2 || Math.abs(delta.y) > 2) {
                    dragArea.hasMoved = true
                    root.x += delta.x
                    root.y += delta.y
                }
            }
        }
    }
    
    // Zone centrale pour le déplacement (évite les conflits avec les bords)
    MouseArea {
        id: dragArea
        anchors.fill: parent
        anchors.topMargin: root.handleSize
        anchors.bottomMargin: root.handleSize
        anchors.leftMargin: root.handleSize
        anchors.rightMargin: root.handleSize
        enabled: false
        z: 1
        
        acceptedButtons: Qt.LeftButton
        pressAndHoldInterval: 500
        
        property point clickPos: Qt.point(0, 0)
        property bool hasMoved: false
        property bool isDraggingFromActivation: false
        
        onPressed: function(mouse) {
            clickPos = Qt.point(mouse.x, mouse.y)
            hasMoved = false
            isDraggingFromActivation = false
            root.z = 999 // Mettre au premier plan pendant le déplacement
        }
        
        onPressAndHold: function(mouse) {
            // Sortir du mode édition seulement si pas de mouvement
            if (!hasMoved) {
                root.editMode = false
            }
        }
        
        onPositionChanged: function(mouse) {
            if ((pressed || isDraggingFromActivation) && root.editMode) {
                var delta = Qt.point(mouse.x - clickPos.x, mouse.y - clickPos.y)
                
                // Déplacer si mouvement détecté
                if (Math.abs(delta.x) > 2 || Math.abs(delta.y) > 2 || isDraggingFromActivation) {
                    hasMoved = true
                    root.x += delta.x
                    root.y += delta.y
                }
            }
        }
        
        onReleased: function(mouse) {
            isDraggingFromActivation = false
        }
    }
    
    // Watcher pour arrêter les drags en cours quand on sort du mode édition
    onEditModeChanged: {
        if (!editMode) {
            // Réinitialiser les états de drag
            dragArea.isDraggingFromActivation = false
            dragArea.hasMoved = false
        }
    }
    
    // Zones de redimensionnement dynamiques
    Repeater {
        id: resizeHandles
        model: [
            {
                edge: "top",
                cursor: Qt.SizeVerCursor,
                isHorizontal: false,
                isStart: true,
                anchors: {left: true, right: true, top: true},
                size: "height"
            },
            {
                edge: "bottom",
                cursor: Qt.SizeVerCursor,
                isHorizontal: false,
                isStart: false,
                anchors: {left: true, right: true, bottom: true},
                size: "height"
            },
            {
                edge: "left",
                cursor: Qt.SizeHorCursor,
                isHorizontal: true,
                isStart: true,
                anchors: {left: true, top: true, bottom: true},
                size: "width"
            },
            {
                edge: "right",
                cursor: Qt.SizeHorCursor,
                isHorizontal: true,
                isStart: false,
                anchors: {right: true, top: true, bottom: true},
                size: "width"
            }
        ]
        
        MouseArea {
            id: handle
            z: 2
            enabled: false
            
            // Ancrage dynamique selon le bord
            anchors.left: modelData.anchors.left ? parent.left : undefined
            anchors.right: modelData.anchors.right ? parent.right : undefined
            anchors.top: modelData.anchors.top ? parent.top : undefined
            anchors.bottom: modelData.anchors.bottom ? parent.bottom : undefined
            
            width: modelData.isHorizontal ? root.handleSize : undefined
            height: !modelData.isHorizontal ? root.handleSize : undefined

            cursorShape: enabled ? modelData.cursor : Qt.ArrowCursor
            
            property bool isHorizontal: modelData.isHorizontal
            property bool isStart: modelData.isStart
            property real startSize: 0
            property real startRootPos: 0
            property point startGlobalPos: Qt.point(0, 0)
            
            onPressed: function(mouse) {
                // Capturer les valeurs initiales
                startSize = isHorizontal ? root.width : root.height
                startRootPos = isHorizontal ? root.x : root.y
                
                // Utiliser les coordonnées globales (par rapport au parent de root)
                var globalPos = mapToItem(root.parent, mouse.x, mouse.y)
                startGlobalPos = Qt.point(globalPos.x, globalPos.y)
            }
            
            onPositionChanged: function(mouse) {
                if (pressed) {
                    // Coordonnées globales actuelles
                    var globalPos = mapToItem(root.parent, mouse.x, mouse.y)
                    
                    // Calculer le delta depuis le début
                    var delta = isHorizontal ?
                        (globalPos.x - startGlobalPos.x) :
                        (globalPos.y - startGlobalPos.y)
                    
                    var newSize = isStart ? startSize - delta : startSize + delta
                    var minSize = isHorizontal ? root.minWidth : root.minHeight
                    
                    if (newSize >= minSize) {
                        if (isHorizontal) {
                            root.width = newSize
                            if (isStart) {
                                root.x = startRootPos + delta
                            }
                        } else {
                            root.height = newSize
                            if (isStart) {
                                root.y = startRootPos + delta
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Connecter l'état d'édition aux handles de redimensionnement
    Connections {
        target: root
        function onEditModeChanged() {
            for (var i = 0; i < resizeHandles.count; i++) {
                var handle = resizeHandles.itemAt(i)
                if (handle) {
                    handle.enabled = root.editMode
                }
            }
        }
    }
    
    // Indicateurs visuels des poignées de redimensionnement
    Repeater {
        model: root.editMode ? [
            {edge: "top", x: root.width / 2 - 15, y: 0, w: 30, h: 3},
            {edge: "bottom", x: root.width / 2 - 15, y: root.height - 3, w: 30, h: 3},
            {edge: "left", x: 0, y: root.height / 2 - 15, w: 3, h: 30},
            {edge: "right", x: root.width - 3, y: root.height / 2 - 15, w: 3, h: 30}
        ] : []
        
        Rectangle {
            x: modelData.x
            y: modelData.y
            width: modelData.w
            height: modelData.h
            color: root.borderColor
            radius: 1.5
            z: 3
        }
    }
}

