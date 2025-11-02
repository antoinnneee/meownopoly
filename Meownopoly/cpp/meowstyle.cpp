#include "meowstyle.h"

#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include <QMap>
#include "case/Case.h"

MeowStyle *MeowStyle::m_pThis = nullptr;

MeowStyle::MeowStyle(QObject *parent)
    : QObject(parent)
{
    // Initialisation des couleurs des familles selon l'ordre de l'enum FamilyType dans CaseRestArea.h
    m_familyColors = QStringList{
        "#ecf0f1",  // FT_NONE
        "#795548",  // FT_BROWN
        "#81D4FA",  // FT_LIGHTBLUE
        "#F48FB1",  // FT_PINK
        "#FF9800",  // FT_ORANGE
        "#e74c3c",  // FT_RED
        "#F9E155",  // FT_YELLOW
        "#66BB6A",  // FT_GREEN
        "#006064"   // FT_DARKBLUE
    };

    // Initialisation des noms des types de cases selon l'enum CaseType dans Case.h
    m_caseTypeNames = {
        {Case::CS_KibbleDispenser, "Kibble Dispenser (Départ)"},
        {Case::CS_RestArea, "Rest Area (Terrain)"},
        {Case::CS_CardBoardBox, "Cardboard Box (Caisse communauté)"},
        {Case::CS_CatNip, "Cat Nip (Chance)"},
        {Case::CS_Jail, "Jail (Prison)"},
        {Case::CS_ToJail, "To Jail (Aller en prison)"},
        {Case::CS_CatDoor, "Cat Door (Gare)"},
        {Case::CS_FreeNap, "Free Nap (Parking gratuit)"},
        {Case::CS_Device, "Device (Services)"},
        {Case::CS_Taxe, "Taxe (Taxe de luxe)"},
        {Case::CS_Unknow, "Unknown (Inconnu)"}
    };
}

void MeowStyle::registerQml()
{
    qmlRegisterSingletonType<MeowStyle>("MeowStyle", 1, 0, "MeowStyle", &MeowStyle::qmlInstance);
}

MeowStyle *MeowStyle::instance()
{
    if (m_pThis == nullptr) // avoid creation of new instances
    {
        m_pThis = new MeowStyle;
    }
    return m_pThis;
}

QObject *MeowStyle::qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine)
{
    Q_UNUSED(engine);
    Q_UNUSED(scriptEngine);
    // C++ and QML instance they are the same instance
    return MeowStyle::instance();
}

QStringList MeowStyle::familyColors() const
{
    return m_familyColors;
}

QMap<int, QString> MeowStyle::caseTypeNames() const
{
    return m_caseTypeNames;
}

QString MeowStyle::getCaseTypeName(int caseType) const
{
    return m_caseTypeNames.value(caseType, "Type inconnu");
}
