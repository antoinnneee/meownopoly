import QtQuick 2.15
import QtQuick3D
import QtQuick3D.Helpers
import AssetManager

Item {
    id: root

    // --- Public API ---
    property alias view3D: view3D
    property alias scene: sceneNode
    property alias camera: cameraOrthographic
    property alias entity: entityNode
    property alias environment: sceneEnvironment
    
    // Properties for camera control
    property real cameraMagnification: 1.0

    // Internal scene structure
    Node {
        id: sceneNode

        DirectionalLight {
            x: 0
            y: 264.806
            z: 1111.39001
            ambientColor: Qt.rgba(0.5, 0.5, 0.5, 1.0)
            brightness: 1.2
            eulerRotation.x: -25
        }
        
        Node {
            id: entityNode
            x: 0
            y: 0
            z: 0

            Loader3D {
                id: modelLoader
                property string modelName: "Princess" // Nom du modèle par défaut
                
                // Construction du chemin vers AppData/models/Nom/Nom.qml
                source: "file:///" + AssetManager.getAppDataPath() + "/models/" + modelName + "/" + modelName + ".qml"
                
                onStatusChanged: {
                    if (status === Loader3D.Error) {
                        console.error("Erreur chargement modèle 3D:", sourceComponent.errorString())
                    } else if (status === Loader3D.Ready) {
                        console.log("Modèle 3D chargé:", source)
                    }
                }
            }
        }

        // Stationary orthographic camera viewing from the top
        OrthographicCamera {
            id: cameraOrthographic
            x: 0
            y: 1000
            clipNear: -10000
            clipFar: 1000055
            eulerRotation.z: 0
            eulerRotation.y: 0
            pivot.x: 0
            z: 600
            eulerRotation.x: -55
            horizontalMagnification: root.cameraMagnification
            verticalMagnification: root.cameraMagnification
        }
    }

    View3D {
        id: view3D
        anchors.fill: parent
        camera: cameraOrthographic
        importScene: sceneNode

        environment: SceneEnvironment {
            id: sceneEnvironment
            antialiasingMode: SceneEnvironment.ProgressiveAA
            backgroundMode: SceneEnvironment.Transparent
        }
    }
}

