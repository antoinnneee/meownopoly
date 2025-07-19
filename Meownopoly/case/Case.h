    #ifndef CASE_H
#define CASE_H

#include <QObject>
#include <QString>
#include "player.h"
// Forward declaration instead of including player.h

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
    Q_PROPERTY(int position READ position WRITE setPosition NOTIFY positionChanged FINAL)
    Q_PROPERTY(CaseType type READ getType WRITE setType NOTIFY typeChanged FINAL)
    
    explicit Case(QObject *parent = nullptr);
    Case(const QString &name, int position = -1, QObject *parent = nullptr);

    int position() const;
    void setPosition(int newPosition);

    CaseType getType() const;
    void setType(CaseType newType);

    QString name() const;
    void setName(const QString &newName);

    virtual void onLand(Player* player);
    virtual void onLeave(Player* player);
    virtual void onHover(Player* player);

    // Static conversion function from int to CaseType enum
    static CaseType intToCaseType(int type);

signals:

    void nameChanged();

    void positionChanged();

    void typeChanged();

protected:
    QString m_name = "Unknown";
    int m_position = -1;
    CaseType type = CS_Unknow;

};

#endif // CASE_H
