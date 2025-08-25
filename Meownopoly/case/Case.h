#ifndef CASE_H
#define CASE_H

#include <QObject>
#include <QString>
#include "player.h"
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
    Q_PROPERTY(QUuid uniqueId READ uniqueId WRITE setUniqueId NOTIFY uniqueIdChanged FINAL)
    Q_PROPERTY(CaseType type READ getType WRITE setType NOTIFY typeChanged FINAL)
    
    explicit Case(QObject *parent = nullptr);
    Case(const QString &name, QUuid uniqueId, QObject *parent = nullptr);
    Case(const QJsonDocument &json, QObject *parent = nullptr);



    QUuid uniqueId() const;
    void setUniqueId(QUuid newUniqueId);

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

    Q_INVOKABLE virtual QString toJSON();




// ---- CHAINED LIST MANIPULATION ----

    bool addNode();
    bool removeNode();


    bool isNextEmpty(){return next.isEmpty();}
    bool isPrevEmpty(){return prev.isEmpty();}

    Case *getNext(int userSelectNext);
    void addNext(Case *newNext);
    bool removeNext(Case *caseToRemove); // Nouvelle fonction
    bool removeNextAt(int index); // Nouvelle fonction

    Case *getPrev(int userSelectPrev);
    void addPrev(Case *newPrev);
    bool removePrev(Case *caseToRemove); // Nouvelle fonction
    bool removePrevAt(int index); // Nouvelle fonction

    QList<Case*> next = QList<Case*>();
    QList<Case*> prev = QList<Case*>();


signals:

    void nameChanged();

    void uniqueIdChanged();

    void typeChanged();




protected:
    QList<Player*> listPlayer;

    QString m_name = "Unknown";
    QUuid m_uniqueId = QUuid::createUuid();
    CaseType type = CS_Unknow;


};

#endif // CASE_H
