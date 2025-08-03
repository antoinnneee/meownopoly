import QtQuick
import QtQuick3D

Node {
    id: node

    // Resources
    PrincipledMaterial {
        id: defaultMaterial_material
        objectName: "DefaultMaterial"
        baseColor: "#ffcccccc"
    }

    // Nodes:
    Node {
        id: rootNode
        objectName: "RootNode"
        Model {
            id: cylinder
            objectName: "Cylinder"
            rotation: Qt.quaternion(0.707107, -0.707107, 0, 0)
            scale: Qt.vector3d(100, 100, 100)
            source: "meshes/cylinder_000_mesh.mesh"
            materials: [
                defaultMaterial_material
            ]
        }
        Model {
            id: icosphere
            objectName: "Icosphere"
            position: Qt.vector3d(350.534, 1367.57, -117.282)
            rotation: Qt.quaternion(0.707107, -0.707107, 0, 0)
            scale: Qt.vector3d(496.762, 496.762, 496.762)
            source: "meshes/icosphere_001_mesh.mesh"
            materials: [
                defaultMaterial_material
            ]
        }
    }

    // Animations:
}
