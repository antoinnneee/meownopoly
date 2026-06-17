import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Particles
import theme
import "./components"
import ui_item
import AssetManager
import MapFileManager
import MapTypes

/**
 * Écran de création de session
 * Utilise le ChatClient mutualisé du parent
 */
Rectangle {
    id: root

    // Animation fluide sur le fond
    Behavior on color { ColorAnimation { duration: 300 } }

    // Propriété pour recevoir le ChatClient du parent
    required property var chatClient

    // Signaux pour la navigation
    signal backRequested()
    // sessionData : { name, password, isEditionMode,
    //                 initialMap: { mode: "new"|"existing", mapName: "..." } }
    signal sessionCreateRequested(var sessionData)

    // Règles de validation du nom de session :
    //   - longueur ≥ 3
    //   - seulement [A-Za-z0-9_] (filtré côté input par le validator)
    //   - la sous-chaîne "_map" est interdite : elle est réservée par la
    //     normalisation de fichier (<name>_map.json) pour éviter les
    //     collisions de noms entre cartes mono et fichiers de session.
    function _validateSessionName(name) {
        if (!name || name.length < 3) return "Trop court (min. 3 caractères)"
        if (name.indexOf("_map") !== -1) return "La séquence « _map » est réservée"
        // Le validator filtre déjà à l'input, mais double-check si collé.
        if (/[^A-Za-z0-9_]/.test(name)) return "Seuls A-Z, a-z, 0-9 et _ sont permis"
        return ""
    }
    readonly property string sessionNameError: _validateSessionName(sessionNameInput.text)

    // État du formulaire — seul le nom est obligatoire
    property bool formValid: sessionNameError === ""

    // Mode : Edition ou Jeu — par défaut on crée une session éditeur collab
    // (le mode "Jeu" n'est pas encore câblé sur le networking côté main.qml).
    property bool isEditionMode: true

    // Choix de la carte de départ (Edition uniquement) : soit "new" pour une
    // carte vierge (le nom utilisé sur disque sera celui de la session), soit
    // "existing" pour partir d'une carte locale (son mapName et ses
    // métadonnées sont conservés). La différenciation mono/collab des
    // fichiers sera traitée plus tard — pour l'instant option "existing"
    // écrit directement sur le fichier mono d'origine.
    property string initialMapMode: "new"        // "new" | "existing"
    property string initialMapName: ""           // valide quand mode == "existing"
    property var    availableMapsForPicker: []   // peuplé dans onCompleted

    // G9 — mode "existing" : par défaut on crée une **copie** du fichier
    // mono pour que la session collab n'écrase pas la carte d'origine. Si
    // l'utilisateur décoche, la session édite directement le fichier mono
    // (et la sortie collab "ne pas conserver" peut le supprimer).
    property bool initialMapUseCopy: true

    // G9 — collision détectée quand sessionName (mode "new") résoud au même
    // fichier qu'une carte mono existante (case-insensitive + espaces vs
    // underscores via normalizeMapName). Signal visuel rouge sous le champ ;
    // ne bloque pas le clic Créer (l'utilisateur peut sciemment vouloir
    // éditer cette carte mono — auquel cas il devrait plutôt passer en mode
    // "existing", mais on laisse libre).
    readonly property bool sessionNameCollidesWithMono: {
        if (root.initialMapMode !== "new") return false
        if (sessionNameInput.text.length === 0) return false
        if (root.sessionNameError !== "") return false
        return MapFileManager.mapNameCollidesIgnoringCase(
                    sessionNameInput.text, MapTypes.CUSTOM)
    }

    // ═══════════════════════════════════════
    // Palette Dynamique (Orange 🎮 <-> Violet 🛠️)
    // ═══════════════════════════════════════
    readonly property color cOrangePrimary: "#E67E22"
    readonly property color cOrangeSecondary: "#D4692A"
    readonly property color cOrangeDark: "#c0681a"
    readonly property color cVioletPrimary: "#9B59B6"
    readonly property color cVioletSecondary: "#BB77DD"
    readonly property color cVioletDark: "#6b4d8a"

    readonly property color bgRoot: isEditionMode ? "#2a2035" : "#2b2220"
    readonly property color bgPanel: isEditionMode ? "#352a42" : "#352a22"

    readonly property color cPrimary: isEditionMode ? cVioletPrimary : cOrangePrimary
    readonly property color cSecondary: isEditionMode ? cVioletSecondary : cOrangeSecondary
    readonly property color cDark: isEditionMode ? cVioletDark : cOrangeDark

    readonly property color bgInput: isEditionMode ? "#2e2440" : "#2e2418"
    readonly property color bgInputFocus: isEditionMode ? "#3f3350" : "#3f3025"
    readonly property color borderInput: isEditionMode ? "#5a4d6b" : "#6b5a40"

    readonly property color textHighlight: isEditionMode ? "#d4b8e8" : "#f0d4a8"
    readonly property color textMuted: isEditionMode ? "#7a6b8e" : "#8a7a60"
    readonly property color textDim: isEditionMode ? "#6b5a7a" : "#7a6540"

    readonly property color bgBtnHover: isEditionMode ? "#3f3350" : "#3f3020"
    readonly property color bgBtnPress: isEditionMode ? "#4a3d5a" : "#4a3520"
    readonly property color borderBtn: isEditionMode ? "#5a4d6b" : "#6b5a40"
    readonly property color borderBtnHover: isEditionMode ? "#9a8aae" : "#a08a6a"

    color: bgRoot

    // ═══════════════════════════════════════
    // Patounes — Particle animation background
    // ═══════════════════════════════════════
    ParticleSystem {
        id: particleSystem
        anchors.fill: parent
        clip: true

        Emitter {
            id: burstEmitter
            enabled: true
            anchors.fill: parent
            lifeSpan: 2000
            size: 50
            emitRate: 15
            velocity: AngleDirection {
                angle: 270
                angleVariation: 15
                magnitude: 200
                magnitudeVariation: 50
            }
        }

        ImageParticle {
            id: firework
            source: AssetManager.getAssetById("ui", "particules", "pawn1").path
            color: Qt.rgba(Math.random(), Math.random(), Math.random(), 1)
            colorVariation: 0.5
            alpha: 0.75
            rotationVariation: 360
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            burstEmitter.burst(1)
            firework.color = Qt.rgba(Math.random(), Math.random(), Math.random(), 1)
        }
    }

    // ═══════════════════════════════════════
    // Layout principal — pas de scroll
    // ═══════════════════════════════════════
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 0

        // HEADER
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingXXL

            BackButton {
                onBackClicked: root.backRequested()
            }

            Item {
                Layout.fillWidth: true
                Text {
                    text: "🐱 Créer une Session"
                    color: "#f5f0ff"
                    font.pixelSize: Theme.fontSizeDisplay
                    font.bold: true
                    anchors.centerIn: parent
                }
            }

            Item { width: 40; height: 40 }
        }

        // Separator dynamique central
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spacingXL
            height: 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.15; color: root.cPrimary }
                GradientStop { position: 0.5; color: root.cSecondary }
                GradientStop { position: 0.85; color: root.cPrimary }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // ═══════════════════════════════════════
        // FORMULAIRE — layout horizontal spacieux
        // ═══════════════════════════════════════
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: Theme.spacingHuge

            // Conteneur central limité en largeur
            RowLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width, 820)
                height: Math.min(parent.height, 420)
                spacing: Theme.spacingHuge

                // ── COLONNE GAUCHE : Nom + Mot de passe ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.bgPanel
                    radius: 16
                    border.color: root.cPrimary
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 300 } }
                    Behavior on border.color { ColorAnimation { duration: 300 } }

                    // Accent bar top
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 3
                        radius: 16
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: root.cPrimary }
                            GradientStop { position: 1.0; color: root.cSecondary }
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingHuge
                        spacing: 0

                        // Section header
                        Row {
                            spacing: Theme.spacingL
                            Layout.bottomMargin: Theme.spacingHuge

                            Text {
                                text: "📝"
                                font.pixelSize: Theme.fontSizeHeading
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Informations"
                                color: root.textHighlight
                                font.pixelSize: Theme.fontSizeLarge
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 300 } }
                            }
                        }

                        // — Nom de la session —
                        Text {
                            text: "Nom de la session *"
                            color: root.textHighlight
                            font.pixelSize: Theme.fontSizeMedium
                            font.bold: true
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }

                        TextField {
                            id: sessionNameInput
                            Layout.fillWidth: true
                            Layout.preferredHeight: 46
                            Layout.topMargin: Theme.spacingM
                            placeholderTextColor: root.textDim
                            color: "#f5f0ff"
                            font.pixelSize: Theme.fontSizeMedium
                            maximumLength: 50
                            // Filtre à la frappe : rejette les caractères hors
                            // [A-Za-z0-9_] (accents, espaces, ponctuation).
                            // Complément logique dans _validateSessionName
                            // pour bloquer la sous-chaîne « _map ».
                            validator: RegularExpressionValidator {
                                regularExpression: /[A-Za-z0-9_]*/
                            }

                            background: Rectangle {
                                color: sessionNameInput.focus ? root.bgInputFocus : root.bgInput
                                radius: Theme.radiusXL
                                border.color: {
                                    if (sessionNameInput.focus) return root.cPrimary
                                    if (sessionNameInput.text.length > 0 && root.sessionNameError !== "")
                                        return Theme.danger
                                    return root.borderInput
                                }
                                border.width: 2
                                Behavior on border.color { ColorAnimation { duration: 200 } }
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                        }

                        // Bulle-info live : rule hint quand vide, erreur de
                        // validation, **collision avec carte mono existante
                        // (G9)**, ou compteur de caractères si tout est ok.
                        Text {
                            Layout.topMargin: Theme.spacingS
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: {
                                const count = sessionNameInput.text.length
                                if (count === 0)
                                    return "💡 Lettres, chiffres, `_`. Pas de « _map »."
                                if (root.sessionNameError !== "")
                                    return "⚠ " + root.sessionNameError + "  (" + count + "/50)"
                                if (root.sessionNameCollidesWithMono)
                                    return "⚠ Une carte locale porte déjà ce nom (insensible à la casse). " +
                                           "La session écrirait dans son fichier — préférez « Existante » + copie."
                                return "✓ " + count + "/50"
                            }
                            color: {
                                if (sessionNameInput.text.length === 0) return root.textMuted
                                if (root.sessionNameError !== "" || root.sessionNameCollidesWithMono) return Theme.danger
                                return Theme.success
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            font.italic: true
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }

                        // Spacer
                        Item { Layout.preferredHeight: 16 }

                        // — Mot de passe —
                        Row {
                            spacing: Theme.spacingM
                            Text {
                                text: "Mot de passe"
                                color: root.textHighlight
                                font.pixelSize: Theme.fontSizeMedium
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 300 } }
                            }
                            Text {
                                text: "(optionnel)"
                                color: root.textMuted
                                font.pixelSize: Theme.fontSizeBody
                                font.italic: true
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 300 } }
                            }
                        }

                        TextField {
                            id: sessionPasswordInput
                            Layout.fillWidth: true
                            Layout.preferredHeight: 46
                            Layout.topMargin: Theme.spacingM
                            placeholderText: "Laisser vide pour session ouverte"
                            placeholderTextColor: root.textDim
                            echoMode: showPasswordCheckbox.checked ? TextInput.Normal : TextInput.Password
                            color: "#f5f0ff"
                            font.pixelSize: Theme.fontSizeMedium
                            maximumLength: 30

                            background: Rectangle {
                                color: sessionPasswordInput.focus ? root.bgInputFocus : root.bgInput
                                radius: Theme.radiusXL
                                border.color: sessionPasswordInput.focus ? root.cPrimary : root.borderInput
                                border.width: 2
                                Behavior on border.color { ColorAnimation { duration: 200 } }
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                        }

                        Row {
                            Layout.topMargin: Theme.spacingL
                            spacing: Theme.spacingL

                            CheckBox {
                                id: showPasswordCheckbox
                                checked: false
                                indicator: Rectangle {
                                    width: 22; height: 22; radius: Theme.radiusM
                                    color: showPasswordCheckbox.checked ? root.cPrimary : root.bgInput
                                    border.color: showPasswordCheckbox.checked ? root.cSecondary : root.borderInput
                                    border.width: 2
                                    Behavior on color { ColorAnimation { duration: 200 } }

                                    Text {
                                        text: "✓"; color: Theme.textPrimary
                                        font.pixelSize: Theme.fontSizeLarge; font.bold: true
                                        anchors.centerIn: parent
                                        visible: showPasswordCheckbox.checked
                                    }
                                }
                            }

                            Text {
                                text: "Afficher le mot de passe"
                                color: root.textMuted
                                font.pixelSize: Theme.fontSizeBody
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 300 } }
                            }
                        }

                        // Fill remaining space
                        Item { Layout.fillHeight: true }
                    }
                }

                // ── COLONNE DROITE : Mode + Actions ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.bgPanel
                    radius: 16
                    border.color: root.cPrimary
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 300 } }
                    Behavior on border.color { ColorAnimation { duration: 300 } }

                    // Accent bar top
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 3
                        radius: 16
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: root.cPrimary }
                            GradientStop { position: 1.0; color: root.cSecondary }
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingHuge
                        spacing: 0

                        // Section header
                        Row {
                            spacing: Theme.spacingL
                            Layout.bottomMargin: Theme.spacingHuge

                            Text {
                                text: "⚙️"
                                font.pixelSize: Theme.fontSizeHeading
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Configuration"
                                color: root.textHighlight
                                font.pixelSize: Theme.fontSizeLarge
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 300 } }
                            }
                        }

                        // — Mode toggle —
                        Text {
                            text: "Mode de la session"
                            color: root.textHighlight
                            font.pixelSize: Theme.fontSizeMedium
                            font.bold: true
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }

                        // Toggle switch row
                        Row {
                            Layout.topMargin: Theme.spacingXL
                            spacing: Theme.spacingXXL

                            CheckBox {
                                id: modeCheckbox
                                checked: root.isEditionMode
                                onCheckedChanged: root.isEditionMode = checked

                                indicator: Rectangle {
                                    width: 56; height: 30; radius: 15
                                    color: modeCheckbox.checked ? root.cVioletPrimary : root.cOrangePrimary
                                    border.color: modeCheckbox.checked ? root.cVioletSecondary : root.cOrangeSecondary
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 250 } }

                                    Rectangle {
                                        width: 24; height: 24; radius: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: modeCheckbox.checked ? parent.width - width - 3 : 3
                                        color: "#f5f0ff"
                                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                                    }
                                }
                            }

                            Row {
                                spacing: Theme.spacingM
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    text: root.isEditionMode ? "🛠️" : "🎮"
                                    font.pixelSize: Theme.fontSizeHeading
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: root.isEditionMode ? "Édition" : "Jeu"
                                    color: root.isEditionMode ? root.cVioletSecondary : root.cOrangeSecondary
                                    font.pixelSize: Theme.fontSizeTitle
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                            }
                        }

                        // Description du mode
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.topMargin: Theme.spacingXXL
                            height: modeDescText.implicitHeight + 24
                            radius: Theme.radiusXL

                            // Cette description de mode utilise toujours du contraste par rapport au mode actif
                            color: root.isEditionMode ? "#352840" : "#3d2d20"
                            border.color: root.isEditionMode ? "#6b4d8a" : "#8a6530"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 250 } }
                            Behavior on border.color { ColorAnimation { duration: 250 } }

                            Text {
                                id: modeDescText
                                anchors.centerIn: parent
                                width: parent.width - 24
                                text: root.isEditionMode ?
                                          "📐 Collaborer sur l'éditeur de carte avec d'autres joueurs" :
                                          "🎲 Lancer une partie de Meownopoly classique"
                                color: root.isEditionMode ? "#c9a8e8" : "#e8c8a0"
                                font.pixelSize: Theme.fontSizeBody
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                                Behavior on color { ColorAnimation { duration: 250 } }
                            }
                        }

                        // ── Carte de départ (mode Édition uniquement) ──
                        // Choix entre carte vierge (nom = session) ou carte
                        // existante (nom + méta conservés).
                        Text {
                            Layout.topMargin: Theme.spacingXXL
                            text: "Carte de départ"
                            color: root.textHighlight
                            font.pixelSize: Theme.fontSizeMedium
                            font.bold: true
                            visible: root.isEditionMode
                        }

                        RowLayout {
                            Layout.topMargin: Theme.spacingL
                            Layout.fillWidth: true
                            spacing: Theme.spacingXL
                            visible: root.isEditionMode

                            RadioButton {
                                id: radioNew
                                text: "Nouvelle (vide)"
                                checked: root.initialMapMode === "new"
                                onClicked: root.initialMapMode = "new"
                                contentItem: Text {
                                    text: radioNew.text
                                    color: root.textMuted
                                    font.pixelSize: Theme.fontSizeBody
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: radioNew.indicator.width + 6
                                }
                            }
                            RadioButton {
                                id: radioExisting
                                text: "Existante"
                                checked: root.initialMapMode === "existing"
                                enabled: root.availableMapsForPicker.length > 0
                                onClicked: root.initialMapMode = "existing"
                                contentItem: Text {
                                    text: radioExisting.text +
                                          (radioExisting.enabled ? "" : " (aucune)")
                                    color: radioExisting.enabled ? root.textMuted : root.textDim
                                    font.pixelSize: Theme.fontSizeBody
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: radioExisting.indicator.width + 6
                                }
                            }
                        }

                        ComboBox {
                            id: existingMapCombo
                            Layout.fillWidth: true
                            Layout.topMargin: Theme.spacingM
                            Layout.preferredHeight: 40
                            visible: root.isEditionMode &&
                                     root.initialMapMode === "existing"
                            model: root.availableMapsForPicker
                            currentIndex: Math.max(0, root.availableMapsForPicker.indexOf(root.initialMapName))
                            onActivated: {
                                if (currentIndex >= 0 && currentIndex < root.availableMapsForPicker.length)
                                    root.initialMapName = root.availableMapsForPicker[currentIndex]
                            }
                            background: Rectangle {
                                color: root.bgInput
                                radius: Theme.radiusL
                                border.color: existingMapCombo.pressed ? root.cPrimary : root.borderInput
                                border.width: 1
                            }
                            contentItem: Text {
                                text: existingMapCombo.currentText || "—"
                                color: "#f5f0ff"
                                font.pixelSize: Theme.fontSizeBody
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: Theme.spacingL
                            }
                        }

                        // G9 — checkbox "Créer une copie" : visible UNIQUEMENT
                        // en mode existant. Coché par défaut (comportement sûr :
                        // la session collab travaille sur une copie, la carte
                        // mono d'origine n'est pas modifiée même si la sortie
                        // collab "ne pas conserver" purge le fichier de session).
                        // Décocher fait pointer la session sur la carte mono
                        // d'origine — comportement legacy, à utiliser sciemment.
                        Row {
                            Layout.topMargin: 10
                            Layout.fillWidth: true
                            spacing: 10
                            visible: root.isEditionMode &&
                                     root.initialMapMode === "existing"

                            CheckBox {
                                id: useCopyCheckbox
                                checked: root.initialMapUseCopy
                                onCheckedChanged: root.initialMapUseCopy = checked

                                indicator: Rectangle {
                                    width: 20; height: 20; radius: 4
                                    color: useCopyCheckbox.checked ? root.cPrimary : root.bgInput
                                    border.color: useCopyCheckbox.checked ? root.cSecondary : root.borderInput
                                    border.width: 2
                                    Behavior on color { ColorAnimation { duration: 200 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "✓"
                                        color: "#ffffff"
                                        font.pixelSize: 14
                                        font.bold: true
                                        visible: useCopyCheckbox.checked
                                    }
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    text: "Créer une copie de la carte"
                                    color: root.textHighlight
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                                Text {
                                    text: useCopyCheckbox.checked
                                          ? "🛡 La carte d'origine reste intacte"
                                          : "⚠ La session éditera directement le fichier d'origine"
                                    color: useCopyCheckbox.checked ? root.textMuted : "#E67E22"
                                    font.pixelSize: 11
                                    font.italic: true
                                }
                            }
                        }

                        // Fill space
                        Item { Layout.fillHeight: true }

                        // ── Boutons d'action ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingXL

                            // Annuler
                            MeowButton {
                                text: "Annuler"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 48
                                baseColor: root.bgPanel
                                textColor: root.textHighlight
                                fontSize: Theme.fontSizeMedium
                                hoverZoom: false
                                onClicked: root.backRequested()
                            }

                            // Créer
                            ParticleButton {
                                text: "✨ Créer"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 48
                                enabled: root.formValid

                                // Style unifié via MeowButton ; couleur dynamique
                                // du formulaire portée par baseColor.
                                baseColor: root.cPrimary
                                fontSize: Theme.fontSizeMedium

                                particleColor: root.cPrimary
                                particleColorVariation: root.cSecondary
                                particleCount: 30

                                onClicked: {
                                    // Carte de départ : mode "existing" n'a
                                    // de sens que si une carte a été
                                    // effectivement choisie, sinon fallback
                                    // "new" (vierge au nom de la session).
                                    // G9 : `useCopy` n'est pertinent qu'en
                                    // mode existing — Editor.qml l'ignore en
                                    // mode new.
                                    const initialMap = {
                                        "mode":    (root.isEditionMode &&
                                                    root.initialMapMode === "existing" &&
                                                    root.initialMapName !== "")
                                                        ? "existing" : "new",
                                        "mapName": (root.initialMapMode === "existing")
                                                        ? root.initialMapName : "",
                                        "useCopy": root.initialMapUseCopy
                                    }
                                    console.log("🎉 Création de session demandée")
                                    console.log("  - Nom:", sessionNameInput.text)
                                    console.log("  - Mot de passe:", sessionPasswordInput.text.length > 0 ? "***" : "(vide)")
                                    console.log("  - Mode:", root.isEditionMode ? "Edition" : "Jeu")
                                    console.log("  - Carte de départ:", JSON.stringify(initialMap))

                                    root.sessionCreateRequested({
                                        name:         sessionNameInput.text,
                                        password:     sessionPasswordInput.text,
                                        isEditionMode: root.isEditionMode,
                                        initialMap:   initialMap
                                    })
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Animation d'entrée + chargement de la liste des cartes locales pour
    // le picker "Carte existante".
    opacity: 0
    Component.onCompleted: {
        fadeInAnimation.start()
        // Exclut l'autosave de la liste sélectionnable (démarrer une session
        // depuis autosave_tmp n'a pas de sens utilisateur — c'est un
        // scratch-pad, pas une carte éditoriale).
        const all = MapFileManager.getAvailableMaps() || []
        const filtered = []
        for (let i = 0; i < all.length; i++) {
            if (!MapFileManager.isAutosaveMap(all[i])) filtered.push(all[i])
        }
        availableMapsForPicker = filtered
        if (filtered.length > 0) initialMapName = filtered[0]
    }

    NumberAnimation {
        id: fadeInAnimation
        target: root
        property: "opacity"
        from: 0
        to: 1
        duration: 300
        easing.type: Easing.OutQuad
    }
}
