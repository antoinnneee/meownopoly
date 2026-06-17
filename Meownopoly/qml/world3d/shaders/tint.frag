// tint.frag — Qt Quick 3D CustomMaterial fragment shader  (Color ID Map, N=20, MAX_TEX=8)
//
// Porté de kura_qt_viewer/generate_zones.py (armorpaint). NE PAS éditer pour les
// parties répétitives sans reporter le changement de N/MAX_TEX.
//
// Composition par-dessus la base color (la couleur de peau) :
//   base color → teinte globale du skin (baseTint/Mode/Strength)
//   par zone qui matche son ID :
//     couche texture : tex = (inv ? 1-pat : pat) * texTint ; zone = mix(base, tex, texOpacity)
//     couche teinte  : zone = mix(zone, apply_tint(zone, tint, tintMode), tintStrength)
//
// Modes (apply_tint) : 0 = Aplat, 1 = Multiply, 2 = Overlay.

const vec3 RAW_IDS[20] = vec3[20](
    vec3(0.950, 0.095, 0.095), //  0,
    vec3(0.095, 0.950, 0.950), //  1,
    vec3(0.523, 0.950, 0.095), //  2,
    vec3(0.523, 0.095, 0.950), //  3,
    vec3(0.950, 0.736, 0.095), //  4,
    vec3(0.095, 0.309, 0.950), //  5,
    vec3(0.095, 0.950, 0.309), //  6,
    vec3(0.950, 0.095, 0.736), //  7,
    vec3(0.950, 0.416, 0.095), //  8,
    vec3(0.095, 0.629, 0.950), //  9,
    vec3(0.202, 0.950, 0.095), // 10,
    vec3(0.843, 0.095, 0.950), // 11,
    vec3(0.843, 0.950, 0.095), // 12,
    vec3(0.202, 0.095, 0.950), // 13,
    vec3(0.095, 0.950, 0.629), // 14,
    vec3(0.950, 0.095, 0.416), // 15,
    vec3(0.950, 0.255, 0.095), // 16,
    vec3(0.095, 0.790, 0.950), // 17,
    vec3(0.362, 0.950, 0.095), // 18,
    vec3(0.683, 0.095, 0.950)  // 19
);

const float ID_TOLERANCE = 0.15;

vec3 apply_tint(vec3 base, vec3 color, int mode) {
    if (mode == 1) return base * color;                    // Multiply
    if (mode == 2) {                                       // Overlay (par canal)
        vec3 lo = 2.0 * base * color;
        vec3 hi = 1.0 - 2.0 * (1.0 - base) * (1.0 - color);
        return mix(lo, hi, step(vec3(0.5), base));
    }
    return color;                                          // Aplat
}

vec3 compose_slot(vec3 base, vec3 pat, int texInvert, vec3 texTint, float texOpacity,
                  vec3 tint, int tintMode, float tintStrength) {
    vec3 tex  = mix(pat, vec3(1.0) - pat, float(texInvert));
    tex      *= texTint;
    vec3 zone = mix(base, tex, texOpacity);
    zone      = mix(zone, apply_tint(zone, tint, tintMode), tintStrength);
    return zone;
}

void MAIN()
{
    if (debugMode == 1) { BASE_COLOR = vec4(1.0, 0.0, 0.0, 1.0); return; }
    if (debugMode == 2) { BASE_COLOR = vec4(UV0, 0.0, 1.0); return; }
    if (debugMode == 3) { BASE_COLOR = vec4(texture(baseColorTex, UV0).rgb, 1.0); return; }
    if (debugMode == 4) { BASE_COLOR = vec4(texture(colorIDTex, UV0).rgb, 1.0); return; }
    if (debugMode == 5) {
        vec3 idSample = texture(colorIDTex, UV0).rgb;
        float matched = 0.0;
        for (int i = 0; i < 20; ++i)
            matched = max(matched, step(distance(idSample, RAW_IDS[i]), ID_TOLERANCE));
        BASE_COLOR = vec4(1.0 - matched, matched, 0.0, 1.0);
        return;
    }

    vec3 base     = texture(baseColorTex, UV0).rgb;
    vec3 idSample = texture(colorIDTex,   UV0).rgb;

    // Teinte globale du skin (visible hors zones).
    vec3 result = mix(base, apply_tint(base, baseTint.rgb, baseTintMode), baseTintStrength);

    vec3  tints_[20]  = vec3[20](tint0.rgb, tint1.rgb, tint2.rgb, tint3.rgb, tint4.rgb, tint5.rgb, tint6.rgb, tint7.rgb, tint8.rgb, tint9.rgb, tint10.rgb, tint11.rgb, tint12.rgb, tint13.rgb, tint14.rgb, tint15.rgb, tint16.rgb, tint17.rgb, tint18.rgb, tint19.rgb);
    int   tmode_[20]  = int[20](tintMode0, tintMode1, tintMode2, tintMode3, tintMode4, tintMode5, tintMode6, tintMode7, tintMode8, tintMode9, tintMode10, tintMode11, tintMode12, tintMode13, tintMode14, tintMode15, tintMode16, tintMode17, tintMode18, tintMode19);
    float tstr_[20]   = float[20](tintStrength0, tintStrength1, tintStrength2, tintStrength3, tintStrength4, tintStrength5, tintStrength6, tintStrength7, tintStrength8, tintStrength9, tintStrength10, tintStrength11, tintStrength12, tintStrength13, tintStrength14, tintStrength15, tintStrength16, tintStrength17, tintStrength18, tintStrength19);
    float topac_[20]  = float[20](slot0TexOpacity, slot1TexOpacity, slot2TexOpacity, slot3TexOpacity, slot4TexOpacity, slot5TexOpacity, slot6TexOpacity, slot7TexOpacity, slot8TexOpacity, slot9TexOpacity, slot10TexOpacity, slot11TexOpacity, slot12TexOpacity, slot13TexOpacity, slot14TexOpacity, slot15TexOpacity, slot16TexOpacity, slot17TexOpacity, slot18TexOpacity, slot19TexOpacity);
    vec3  ttint_[20]  = vec3[20](slot0TexTint.rgb, slot1TexTint.rgb, slot2TexTint.rgb, slot3TexTint.rgb, slot4TexTint.rgb, slot5TexTint.rgb, slot6TexTint.rgb, slot7TexTint.rgb, slot8TexTint.rgb, slot9TexTint.rgb, slot10TexTint.rgb, slot11TexTint.rgb, slot12TexTint.rgb, slot13TexTint.rgb, slot14TexTint.rgb, slot15TexTint.rgb, slot16TexTint.rgb, slot17TexTint.rgb, slot18TexTint.rgb, slot19TexTint.rgb);
    int   tinv_[20]   = int[20](texInvert0, texInvert1, texInvert2, texInvert3, texInvert4, texInvert5, texInvert6, texInvert7, texInvert8, texInvert9, texInvert10, texInvert11, texInvert12, texInvert13, texInvert14, texInvert15, texInvert16, texInvert17, texInvert18, texInvert19);
    vec3  pats_[20]   = vec3[20](
        texture(slot0Pattern, UV0).rgb,
        texture(slot1Pattern, UV0).rgb,
        texture(slot2Pattern, UV0).rgb,
        texture(slot3Pattern, UV0).rgb,
        texture(slot4Pattern, UV0).rgb,
        texture(slot5Pattern, UV0).rgb,
        texture(slot6Pattern, UV0).rgb,
        texture(slot7Pattern, UV0).rgb,
        base,
        base,
        base,
        base,
        base,
        base,
        base,
        base,
        base,
        base,
        base,
        base
    );

    for (int i = 0; i < 20; ++i) {
        float m = step(distance(idSample, RAW_IDS[i]), ID_TOLERANCE);
        vec3  z = compose_slot(base, pats_[i], tinv_[i], ttint_[i], topac_[i],
                               tints_[i], tmode_[i], tstr_[i]);
        result  = mix(result, z, m);
    }

    BASE_COLOR = vec4(result, 1.0);
    ROUGHNESS  = 0.7;
    METALNESS  = 0.0;
}
