// ============================================================================
// tst_mapinfo — couvre MapInfo et PlayerProfile sans dépendance ItemSnapable.
//
// Voir doc/architecture/MAP_LIFECYCLE.md §2 (anatomie de MapInfo) et §7 (bugs).
// ============================================================================

#include <QtTest/QtTest>
#include <QSignalSpy>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QString>

#include "game/map/mapinfo.h"
#include "game/map/playerprofile.h"

class tst_MapInfo : public QObject
{
    Q_OBJECT

private slots:
    // ----- Constructeur par défaut -----
    void defaultCtor_mapNameIsAutosaveTmp();
    void defaultCtor_hasFallbackProfile();
    void defaultCtor_minMaxAtSafeDefaults();

    // ----- Constructeur JSON -----
    void jsonCtor_emptyJson_stillHasFallbackProfile();
    void jsonCtor_readsNameKey_notMapNameKey();
    void jsonCtor_clampsMinMaxAgainstHardCap();
    void jsonCtor_versioningTooNew_resetsRoster();
    void jsonRoundTrip_preservesScalarFields();
    void jsonRoundTrip_preservesProfileCount();

    // ----- Setters guards -----
    void setMapName_emitsEvenIfSame_REPRO_G2();
    void setBackgroundPath_doesNotEmitOnSame();
    void setMinPlayers_clampsAgainstMaxPlayers();
    void setMaxPlayers_clampsAgainstMinPlayers();
    void setMaxPlayers_clampsAgainstHardCap();

    // ----- Player profile API -----
    void addPlayerProfile_appends_emitsChanged();
    void removePlayerProfile_byId_removes_emitsChanged();
    void removePlayerProfile_unknownId_isNoOp();
    void duplicatePlayerProfile_copiesFieldsButNewId();
    void reorderPlayerProfile_movesAndEmits();
    void reorderPlayerProfile_clampsIndex();
    void updatePlayerProfile_partialFieldsApplied();
    void clearPlayerProfiles_removesAll_emitsChanged();
};

// ============================================================================
// Constructeur par défaut
// ============================================================================

void tst_MapInfo::defaultCtor_mapNameIsAutosaveTmp()
{
    MapInfo mi;
    QCOMPARE(mi.getMapName(), QStringLiteral("autosave_tmp"));
    QCOMPARE(mi.autosaveMapName(), QStringLiteral("autosave_tmp"));
}

void tst_MapInfo::defaultCtor_hasFallbackProfile()
{
    MapInfo mi;
    QCOMPARE(mi.playerProfileCount(), 1);
    PlayerProfile *p = mi.playerProfileAt(0);
    QVERIFY(p != nullptr);
    QCOMPARE(p->name(), QStringLiteral("Princess"));
}

void tst_MapInfo::defaultCtor_minMaxAtSafeDefaults()
{
    MapInfo mi;
    QCOMPARE(mi.minPlayers(), 2);
    QCOMPARE(mi.maxPlayers(), MapInfo::MAX_PLAYERS_HARD_CAP);
    QCOMPARE(mi.playerConfigVersion(), MapInfo::CURRENT_PLAYER_CONFIG_VERSION);
}

// ============================================================================
// Constructeur JSON
// ============================================================================

void tst_MapInfo::jsonCtor_emptyJson_stillHasFallbackProfile()
{
    MapInfo mi(QJsonObject{});
    QCOMPARE(mi.playerProfileCount(), 1);
}

void tst_MapInfo::jsonCtor_readsNameKey_notMapNameKey()
{
    // toJSON() utilise la clé "name". MapInfo::MapInfo(json) lit "name".
    // Le bug G1 (mapfilemanager.cpp:276 `createMapFile` qui écrit "mapName")
    // est testé dans tst_mapfilemanager. Ici on gèle le contrat MapInfo.
    QJsonObject j;
    j["name"] = "BonneClé";
    j["mapName"] = "MauvaiseClé"; // doit être ignorée
    MapInfo mi(j);
    QCOMPARE(mi.getMapName(), QStringLiteral("BonneClé"));
}

void tst_MapInfo::jsonCtor_clampsMinMaxAgainstHardCap()
{
    QJsonObject j;
    j["minPlayers"] = 0;            // clamp à 1
    j["maxPlayers"] = 999;          // clamp à HARD_CAP
    MapInfo mi(j);
    QCOMPARE(mi.minPlayers(), 1);
    QCOMPARE(mi.maxPlayers(), MapInfo::MAX_PLAYERS_HARD_CAP);
}

void tst_MapInfo::jsonCtor_versioningTooNew_resetsRoster()
{
    QJsonObject j;
    j["playerConfigVersion"] = 999;
    QJsonArray profiles;
    QJsonObject p1; p1["name"] = "Should Be Wiped"; profiles.append(p1);
    j["playerProfiles"] = profiles;

    MapInfo mi(j);
    // Roster wipé puis fallback injecté → 1 profil "Princess".
    QCOMPARE(mi.playerProfileCount(), 1);
    QCOMPARE(mi.playerProfileAt(0)->name(), QStringLiteral("Princess"));
    // Version normalisée.
    QCOMPARE(mi.playerConfigVersion(), MapInfo::CURRENT_PLAYER_CONFIG_VERSION);
}

void tst_MapInfo::jsonRoundTrip_preservesScalarFields()
{
    MapInfo source;
    source.setMapName("RoundTrip");
    source.setMapDescription("desc");
    source.setBackgroundPath("/tmp/bg.png");
    source.setBackgroundScaling("Tile");
    source.setBackgroundTileSize(120);
    source.setIsBackgroundOnGrill(true);
    source.setMusicPath("/tmp/music.mp3");
    source.setMinPlayers(3);
    source.setMaxPlayers(6);

    const QString jsonStr = source.toJSON();
    const QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8());
    QVERIFY(doc.isObject());
    MapInfo restored(doc.object());

    QCOMPARE(restored.getMapName(), QStringLiteral("RoundTrip"));
    QCOMPARE(restored.getMapDescription(), QStringLiteral("desc"));
    QCOMPARE(restored.getBackgroundPath(), QStringLiteral("/tmp/bg.png"));
    QCOMPARE(restored.getBackgroundScaling(), QStringLiteral("Tile"));
    QCOMPARE(restored.getBackgroundTileSize(), 120);
    QCOMPARE(restored.getIsBackgroundOnGrill(), true);
    QCOMPARE(restored.getMusicPath(), QStringLiteral("/tmp/music.mp3"));
    QCOMPARE(restored.minPlayers(), 3);
    QCOMPARE(restored.maxPlayers(), 6);
}

void tst_MapInfo::jsonRoundTrip_preservesProfileCount()
{
    MapInfo source;                 // 1 profil fallback
    source.addPlayerProfile();      // +1
    source.addPlayerProfile();      // +1 → total 3

    const QString jsonStr = source.toJSON();
    const QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8());
    MapInfo restored(doc.object());

    QCOMPARE(restored.playerProfileCount(), 3);
}

// ============================================================================
// Setters guards (G2)
// ============================================================================

void tst_MapInfo::setMapName_emitsEvenIfSame_REPRO_G2()
{
    // G2 fixé : setMapName a maintenant un guard d'égalité, comme les autres
    // setters (background, music, etc.). Aucune émission attendue sur valeur
    // identique.
    MapInfo mi;
    mi.setMapName("SameName");
    QSignalSpy spy(&mi, &MapInfo::mapNameChanged);
    mi.setMapName("SameName");
    QCOMPARE(spy.count(), 0);
}

void tst_MapInfo::setBackgroundPath_doesNotEmitOnSame()
{
    // Contre-exemple : ce setter a déjà la garde, document le contraste avec G2.
    MapInfo mi;
    mi.setBackgroundPath("/tmp/bg.png");
    QSignalSpy spy(&mi, &MapInfo::backgroundPathChanged);
    mi.setBackgroundPath("/tmp/bg.png");
    QCOMPARE(spy.count(), 0);
}

void tst_MapInfo::setMinPlayers_clampsAgainstMaxPlayers()
{
    MapInfo mi;
    mi.setMaxPlayers(4);
    mi.setMinPlayers(10);          // clamp → 4 (= max)
    QCOMPARE(mi.minPlayers(), 4);
}

void tst_MapInfo::setMaxPlayers_clampsAgainstMinPlayers()
{
    MapInfo mi;
    mi.setMinPlayers(5);
    mi.setMaxPlayers(2);           // clamp → 5 (= min)
    QCOMPARE(mi.maxPlayers(), 5);
}

void tst_MapInfo::setMaxPlayers_clampsAgainstHardCap()
{
    MapInfo mi;
    mi.setMaxPlayers(999);
    QCOMPARE(mi.maxPlayers(), MapInfo::MAX_PLAYERS_HARD_CAP);
}

// ============================================================================
// Player profile API
// ============================================================================

void tst_MapInfo::addPlayerProfile_appends_emitsChanged()
{
    MapInfo mi;                                 // 1 fallback
    QSignalSpy spy(&mi, &MapInfo::playerProfilesChanged);
    PlayerProfile *p = mi.addPlayerProfile();
    QVERIFY(p != nullptr);
    QCOMPARE(mi.playerProfileCount(), 2);
    QCOMPARE(spy.count(), 1);
}

void tst_MapInfo::removePlayerProfile_byId_removes_emitsChanged()
{
    MapInfo mi;
    PlayerProfile *p = mi.addPlayerProfile();
    const QString id = p->id();
    QSignalSpy spy(&mi, &MapInfo::playerProfilesChanged);
    mi.removePlayerProfile(id);
    QCOMPARE(mi.playerProfileCount(), 1);       // reste le fallback
    QVERIFY(mi.playerProfileById(id) == nullptr);
    QCOMPARE(spy.count(), 1);
}

void tst_MapInfo::removePlayerProfile_unknownId_isNoOp()
{
    MapInfo mi;
    QSignalSpy spy(&mi, &MapInfo::playerProfilesChanged);
    mi.removePlayerProfile(QStringLiteral("non-existant"));
    QCOMPARE(mi.playerProfileCount(), 1);
    QCOMPARE(spy.count(), 0);
}

void tst_MapInfo::duplicatePlayerProfile_copiesFieldsButNewId()
{
    MapInfo mi;
    PlayerProfile *src = mi.playerProfileAt(0);
    src->setName("Original");
    src->setRadius(0.7);
    const QString srcId = src->id();

    PlayerProfile *dup = mi.duplicatePlayerProfile(srcId);
    QVERIFY(dup != nullptr);
    QCOMPARE(dup->name(), QStringLiteral("Original"));
    QCOMPARE(dup->radius(), 0.7);
    QVERIFY(dup->id() != srcId);                // nouvel UUID
}

void tst_MapInfo::reorderPlayerProfile_movesAndEmits()
{
    MapInfo mi;
    PlayerProfile *a = mi.playerProfileAt(0);
    PlayerProfile *b = mi.addPlayerProfile();
    PlayerProfile *c = mi.addPlayerProfile();
    QCOMPARE(mi.playerProfileAt(0), a);
    QCOMPARE(mi.playerProfileAt(2), c);

    QSignalSpy spy(&mi, &MapInfo::playerProfilesChanged);
    QVERIFY(mi.reorderPlayerProfile(c->id(), 0));   // c devient premier
    QCOMPARE(mi.playerProfileAt(0), c);
    QCOMPARE(mi.playerProfileAt(1), a);
    QCOMPARE(mi.playerProfileAt(2), b);
    QCOMPARE(spy.count(), 1);
}

void tst_MapInfo::reorderPlayerProfile_clampsIndex()
{
    MapInfo mi;
    PlayerProfile *a = mi.playerProfileAt(0);
    PlayerProfile *b = mi.addPlayerProfile();
    QVERIFY(mi.reorderPlayerProfile(a->id(), 99)); // clamp à size-1 = 1
    QCOMPARE(mi.playerProfileAt(0), b);
    QCOMPARE(mi.playerProfileAt(1), a);
}

void tst_MapInfo::updatePlayerProfile_partialFieldsApplied()
{
    MapInfo mi;
    PlayerProfile *p = mi.playerProfileAt(0);
    p->setName("Avant");
    p->setRadius(0.4);

    QJsonObject patch;
    patch["radius"] = 0.9;
    QJsonDocument doc(patch);
    QVERIFY(mi.updatePlayerProfile(p->id(), QString::fromUtf8(doc.toJson())));

    QCOMPARE(p->radius(), 0.9);
    QCOMPARE(p->name(), QStringLiteral("Avant"));   // pas touché
}

void tst_MapInfo::clearPlayerProfiles_removesAll_emitsChanged()
{
    MapInfo mi;
    mi.addPlayerProfile();
    mi.addPlayerProfile();
    QSignalSpy spy(&mi, &MapInfo::playerProfilesChanged);
    mi.clearPlayerProfiles();
    QCOMPARE(mi.playerProfileCount(), 0);           // pas de re-fallback
    QCOMPARE(spy.count(), 1);
}

QTEST_GUILESS_MAIN(tst_MapInfo)
#include "tst_mapinfo.moc"
