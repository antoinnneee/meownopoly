#ifndef CASE_H
#define CASE_H

#include <QObject>
#include <QQmlEngine>
#include <QString>
#include "game/player.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QUuid>

class Case : public QObject
{
    Q_OBJECT
    
public:
    enum CaseType{
        CS_KibbleDispenser, // depart
        CS_RestArea,        // terrain
        CS_CardBoardBox,    // caisse communauté
        CS_CatNip,          // chance
        CS_Jail,            // prison
        CS_ToJail,          // go to jail
        CS_CatDoor,         // gare
        CS_FreeNap,         // free parking
        CS_Device,    // service electricite
        CS_Taxe,    // Taxe de luxe   // Taxe sur le revenu
        CS_Unknow,
        CS_Count,
    };
    Q_ENUM(CaseType)

    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged FINAL)
    Q_PROPERTY(CaseType type READ getType WRITE setType NOTIFY typeChanged FINAL)
    
    explicit Case(QObject *parent = nullptr);
    Case(const QString &name, QObject *parent = nullptr);
    Case(const QJsonObject &json, QObject *parent = nullptr);


    CaseType getType() const;
    void setType(CaseType newType);

    QString name() const;
    void setName(const QString &newName);

    // Static conversion function from int to CaseType enum
    static CaseType intToCaseType(int type);

    Q_INVOKABLE void removePlayer(Player *player);
    Q_INVOKABLE void addPlayer(Player *player);

    
    // Overloaded versions with player parameter for direct calls
    Q_INVOKABLE virtual void onLand(Player* player);
    Q_INVOKABLE virtual void onLeave(Player* player); 
    Q_INVOKABLE virtual void onHover(Player* player);

    // Construction JSON structurée (échappement garanti par QJsonObject).
    // Les sous-classes overrident toJsonObject() ; toJSON() reste le point
    // d'entrée string (wrapper QJsonDocument, virtualise via toJsonObject).
    virtual QJsonObject toJsonObject() const;
    Q_INVOKABLE virtual QString toJSON();



signals:

    void nameChanged();


    void typeChanged();

protected:
    QList<Player*> listPlayer;

    QString m_name = "Unknown";
    CaseType type = CS_Unknow;

};
Q_DECLARE_METATYPE(Case)

#endif // CASE_H
