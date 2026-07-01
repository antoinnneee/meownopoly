#include "npcparameter.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QDebug>

NPCParameter::NPCParameter(QObject *parent)
    : QObject(parent)
{
}

NPCParameter::NPCParameter(const QJsonObject &json, QObject *parent)
    : QObject(parent)
{
    // Le ctor JSON ne passe pas par applyJson (pas d'émission de signaux
    // pendant la construction) mais lit les mêmes clés.
    const int version = json.value("npcVersion").toInt(k_currentNpcVersion);
    if (version > k_currentNpcVersion) {
        qWarning() << "NPC_PARAMETER: npcVersion" << version
                   << "> version courante" << k_currentNpcVersion
                   << "- paramètres réinitialisés aux défauts";
        return;
    }
    m_npcName = json.value("npcName").toString("");
    m_visualKind = json.value("visualKind").toInt(Model3D);
    m_modelName = json.value("modelName").toString("");
    const QJsonArray lines = json.value("dialogueLines").toArray();
    for (const QJsonValue &v : lines)
        m_dialogueLines.append(v.toString());
    m_triggerMode = json.value("triggerMode").toInt(Proximity);
    m_advanceOnClick = json.value("advanceOnClick").toBool(true);
}

QJsonObject NPCParameter::toJsonObject() const
{
    QJsonArray lines;
    for (const QString &l : m_dialogueLines)
        lines.append(l);
    return QJsonObject{
        { "npcVersion",     k_currentNpcVersion },
        { "npcName",        m_npcName },
        { "visualKind",     m_visualKind },
        { "modelName",      m_modelName },
        { "dialogueLines",  lines },
        { "triggerMode",    m_triggerMode },
        { "advanceOnClick", m_advanceOnClick },
    };
}

QString NPCParameter::toJSON()
{
    // Sérialisation via QJsonDocument : dialogueLines est du texte libre,
    // l'échappement manuel des autres toJSON() du projet casserait ici.
    return QString::fromUtf8(
        QJsonDocument(toJsonObject()).toJson(QJsonDocument::Compact));
}

void NPCParameter::applyJson(const QJsonObject &json)
{
    const int version = json.value("npcVersion").toInt(k_currentNpcVersion);
    if (version > k_currentNpcVersion) {
        qWarning() << "NPC_PARAMETER: applyJson npcVersion" << version
                   << "> version courante" << k_currentNpcVersion << "- ignoré";
        return;
    }
    setNpcName(json.value("npcName").toString(""));
    setVisualKind(json.value("visualKind").toInt(Model3D));
    setModelName(json.value("modelName").toString(""));
    // Remplacement complet du tableau (pas de mutation en place) pour que
    // le NOTIFY parte une seule fois avec l'état final.
    QStringList newLines;
    const QJsonArray lines = json.value("dialogueLines").toArray();
    for (const QJsonValue &v : lines)
        newLines.append(v.toString());
    setDialogueLines(newLines);
    setTriggerMode(json.value("triggerMode").toInt(Proximity));
    setAdvanceOnClick(json.value("advanceOnClick").toBool(true));
}

QString NPCParameter::npcName() const
{
    return m_npcName;
}

void NPCParameter::setNpcName(const QString &name)
{
    if (m_npcName == name)
        return;
    m_npcName = name;
    emit npcNameChanged();
}

int NPCParameter::visualKind() const
{
    return m_visualKind;
}

void NPCParameter::setVisualKind(int kind)
{
    if (m_visualKind == kind)
        return;
    m_visualKind = kind;
    emit visualKindChanged();
}

QString NPCParameter::modelName() const
{
    return m_modelName;
}

void NPCParameter::setModelName(const QString &name)
{
    if (m_modelName == name)
        return;
    m_modelName = name;
    emit modelNameChanged();
}

QStringList NPCParameter::dialogueLines() const
{
    return m_dialogueLines;
}

void NPCParameter::setDialogueLines(const QStringList &lines)
{
    if (m_dialogueLines == lines)
        return;
    m_dialogueLines = lines;
    emit dialogueLinesChanged();
}

void NPCParameter::addLine(const QString &line)
{
    m_dialogueLines.append(line);
    emit dialogueLinesChanged();
}

void NPCParameter::insertLine(int index, const QString &line)
{
    index = qBound(0, index, m_dialogueLines.size());
    m_dialogueLines.insert(index, line);
    emit dialogueLinesChanged();
}

void NPCParameter::setLineAt(int index, const QString &line)
{
    if (index < 0 || index >= m_dialogueLines.size())
        return;
    if (m_dialogueLines[index] == line)
        return;
    m_dialogueLines[index] = line;
    emit dialogueLinesChanged();
}

void NPCParameter::removeLineAt(int index)
{
    if (index < 0 || index >= m_dialogueLines.size())
        return;
    m_dialogueLines.removeAt(index);
    emit dialogueLinesChanged();
}

void NPCParameter::moveLine(int from, int to)
{
    if (from < 0 || from >= m_dialogueLines.size())
        return;
    if (to < 0 || to >= m_dialogueLines.size() || from == to)
        return;
    m_dialogueLines.move(from, to);
    emit dialogueLinesChanged();
}

void NPCParameter::clearLines()
{
    if (m_dialogueLines.isEmpty())
        return;
    m_dialogueLines.clear();
    emit dialogueLinesChanged();
}

int NPCParameter::lineCount() const
{
    return m_dialogueLines.size();
}

QString NPCParameter::lineAt(int index) const
{
    if (index < 0 || index >= m_dialogueLines.size())
        return QString();
    return m_dialogueLines.at(index);
}

int NPCParameter::triggerMode() const
{
    return m_triggerMode;
}

void NPCParameter::setTriggerMode(int mode)
{
    if (m_triggerMode == mode)
        return;
    m_triggerMode = mode;
    emit triggerModeChanged();
}

bool NPCParameter::advanceOnClick() const
{
    return m_advanceOnClick;
}

void NPCParameter::setAdvanceOnClick(bool advance)
{
    if (m_advanceOnClick == advance)
        return;
    m_advanceOnClick = advance;
    emit advanceOnClickChanged();
}
