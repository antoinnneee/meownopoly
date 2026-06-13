pragma Singleton
import QtQuick

/*
 * Theme — Singleton centralisant toutes les valeurs de style de l'UI.
 *
 * Toutes les tailles (polices, espacements, rayons) sont dérivées de
 * uiScale : modifier uiScale redimensionne toute l'interface d'un coup.
 *
 * Frontière : les couleurs MÉTIER (familles de cases → MeowStyle,
 * couleurs de joueurs, swatches de pickers, color ID maps) ne passent
 * PAS par ce singleton.
 */
QtObject {
    id: root

    // ── Facteur d'échelle global ─────────────────────────────────
    // 1.0 = taille de référence. Toute l'UI re-bind au changement.
    property real uiScale: 1.0

    // Échelonne une valeur brute ; utilisable pour les tailles hors tokens.
    function px(base) { return Math.max(1, Math.round(base * root.uiScale)) }

    // ── Échelle typographique (font.pixelSize) ───────────────────
    readonly property int fontSizeTiny:    px(9)
    readonly property int fontSizeCaption: px(10)
    readonly property int fontSizeSmall:   px(11)
    readonly property int fontSizeBody:    px(12)
    readonly property int fontSizeMedium:  px(14)
    readonly property int fontSizeLarge:   px(16)
    readonly property int fontSizeTitle:   px(18)
    readonly property int fontSizeHeading: px(20)
    readonly property int fontSizeDisplay: px(24)
    readonly property int fontSizeHero:    px(32)

    // ── Espacements (spacing / margins / paddings) ───────────────
    readonly property int spacingXXS:  px(2)
    readonly property int spacingXS:   px(4)
    readonly property int spacingS:    px(6)
    readonly property int spacingM:    px(8)
    readonly property int spacingL:    px(10)
    readonly property int spacingXL:   px(12)
    readonly property int spacingXXL:  px(16)
    readonly property int spacingHuge: px(24)

    // ── Rayons de bordure ────────────────────────────────────────
    readonly property int radiusXS:  px(2)
    readonly property int radiusS:   px(4)
    readonly property int radiusM:   px(6)
    readonly property int radiusL:   px(8)
    readonly property int radiusXL:  px(10)
    readonly property int radiusXXL: px(12)

    // ── Surfaces (du plus profond au plus clair) ─────────────────
    readonly property color background:   "#1a1a1a"  // fond le plus profond
    readonly property color surface:      "#2a2a2a"  // panneaux, champs
    readonly property color surfaceAlt:   "#333333"  // panneaux secondaires
    readonly property color surfaceHover: "#3a3a3a"  // survol de lignes/cellules
    readonly property color surfaceBoard: "#2c3e50"  // fonds bleu nuit des UI plateau
    readonly property color surfaceLight: "#ffffff"  // fonds clairs (cases, popups claires)

    // ── Bordures ─────────────────────────────────────────────────
    readonly property color border:      "#444444"
    readonly property color borderLight: "#555555"

    // ── Textes ───────────────────────────────────────────────────
    readonly property color textPrimary:   "#ffffff"
    readonly property color textSoft:      "#e0e0e0"
    readonly property color textSecondary: "#cccccc"
    readonly property color textHint:      "#9ca3af"
    readonly property color textMuted:     "#888888"
    readonly property color textDisabled:  "#666666"

    // ── Accents & états sémantiques ──────────────────────────────
    readonly property color accent:      "#4A90E2"  // bleu principal
    readonly property color accentAlt:   "#569c58"  // vert focus/validation (launcher + panneaux)
    readonly property color success:     "#4caf50"
    readonly property color warning:     "#ff9800"
    readonly property color danger:      "#e74c3c"
    readonly property color dangerSoft:  "#ff6b6b"
    readonly property color violetStart: "#667eea"  // gradients décoratifs
    readonly property color violetEnd:   "#5568d3"

    // ── Encadrés d'information (MeowInfoBox) ──────────────────────
    // Trios fond / bordure / titre / texte par variante sémantique.
    readonly property color infoBg:        "#1a2e3a"
    readonly property color infoBorder:    "#2a3e4a"
    readonly property color infoTitle:     "#99d6f0"
    readonly property color infoText:      "#80c1d9"
    readonly property color warningBg:     "#3a3a1a"
    readonly property color warningBorder: "#4a4a2a"
    readonly property color warningTitle:  "#ffeb99"
    readonly property color warningText:   "#d4c894"
    readonly property color tipBg:         "#1a3a2a"
    readonly property color tipBorder:     "#2a4a3a"
    readonly property color tipTitle:      "#99f0c0"
    readonly property color tipText:       "#80d9a8"

    // ── États dérivés ────────────────────────────────────────────
    function hover(c)   { return Qt.lighter(c, 1.12) }
    function pressed(c) { return Qt.darker(c, 1.25) }
    readonly property color overlayLight: Qt.rgba(1, 1, 1, 0.08)
    readonly property color scrim:        Qt.rgba(0, 0, 0, 0.5)

    // ── Durées d'animation ───────────────────────────────────────
    readonly property int durationFast:   100
    readonly property int durationNormal: 150
}
