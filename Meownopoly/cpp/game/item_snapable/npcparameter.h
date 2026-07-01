#ifndef NPCPARAMETER_H
#define NPCPARAMETER_H

#include <QObject>
#include <QJsonObject>
#include <QStringList>

/// Paramètres d'un PNJ (personnage non-joueur) porté par un ItemSnapable de
/// type NPCTile : identité (nom + visuel), séquence de lignes de dialogue et
/// mode de déclenchement. Calqué sur les conventions de ZoneParameter
/// (Q_PROPERTY, ctor JSON, applyJson, operator==) — mais toJSON() passe par
/// QJsonObject/QJsonDocument (pas de concat manuelle) car dialogueLines est
/// du texte libre (guillemets, retours à la ligne) que la concat casserait.
class NPCParameter : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString npcName READ npcName WRITE setNpcName NOTIFY npcNameChanged FINAL)
    Q_PROPERTY(int visualKind READ visualKind WRITE setVisualKind NOTIFY visualKindChanged FINAL)
    Q_PROPERTY(QString modelName READ modelName WRITE setModelName NOTIFY modelNameChanged FINAL)
    // Lecture seule côté binding : l'édition passe par les Q_INVOKABLE
    // add/insert/set/remove/move/clearLines (mutation en place non observée
    // par QML — même raison que ZoneParameter::addPoint).
    Q_PROPERTY(QStringList dialogueLines READ dialogueLines WRITE setDialogueLines NOTIFY dialogueLinesChanged FINAL)
    Q_PROPERTY(int triggerMode READ triggerMode WRITE setTriggerMode NOTIFY triggerModeChanged FINAL)
    Q_PROPERTY(bool advanceOnClick READ advanceOnClick WRITE setAdvanceOnClick NOTIFY advanceOnClickChanged FINAL)

public:
    enum VisualKind {
        Model3D  = 0,
        Sprite2D = 1,
    };
    Q_ENUM(VisualKind)

    enum TriggerMode {
        Proximity = 0,
        Click     = 1,
        Always    = 2,
    };
    Q_ENUM(TriggerMode)

    /// Version courante du schéma de sérialisation (analogue à
    /// playerConfigVersion) : version > courante → reset aux défauts + warning.
    static constexpr int k_currentNpcVersion = 1;

    explicit NPCParameter(QObject *parent = nullptr);
    explicit NPCParameter(const QJsonObject &json, QObject *parent = nullptr);

    bool operator==(const NPCParameter &other) const {
        return m_npcName        == other.m_npcName
            && m_visualKind     == other.m_visualKind
            && m_modelName      == other.m_modelName
            && m_dialogueLines  == other.m_dialogueLines
            && m_triggerMode    == other.m_triggerMode
            && m_advanceOnClick == other.m_advanceOnClick;
    }

    Q_INVOKABLE QString toJSON();
    QJsonObject toJsonObject() const;
    /// Q_INVOKABLE : le remote-apply QML (op SetNpcParameter) passe le
    /// payload `fields` directement (JS object → QJsonObject).
    Q_INVOKABLE void applyJson(const QJsonObject &json);

    QString npcName() const;
    void setNpcName(const QString &name);

    int visualKind() const;
    void setVisualKind(int kind);

    QString modelName() const;
    void setModelName(const QString &name);

    QStringList dialogueLines() const;
    void setDialogueLines(const QStringList &lines);

    Q_INVOKABLE void addLine(const QString &line);
    Q_INVOKABLE void insertLine(int index, const QString &line);
    Q_INVOKABLE void setLineAt(int index, const QString &line);
    Q_INVOKABLE void removeLineAt(int index);
    Q_INVOKABLE void moveLine(int from, int to);
    Q_INVOKABLE void clearLines();
    Q_INVOKABLE int lineCount() const;
    Q_INVOKABLE QString lineAt(int index) const;

    int triggerMode() const;
    void setTriggerMode(int mode);

    bool advanceOnClick() const;
    void setAdvanceOnClick(bool advance);

signals:
    void npcNameChanged();
    void visualKindChanged();
    void modelNameChanged();
    void dialogueLinesChanged();
    void triggerModeChanged();
    void advanceOnClickChanged();

private:
    QString m_npcName;
    int m_visualKind = Model3D;
    QString m_modelName;
    QStringList m_dialogueLines;
    int m_triggerMode = Proximity;
    bool m_advanceOnClick = true;
};

#endif // NPCPARAMETER_H
