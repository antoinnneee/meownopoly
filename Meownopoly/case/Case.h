    #ifndef CASE_H
#define CASE_H

#include <QObject>
#include <QString>

// Forward declaration instead of including player.h
class Player;

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

class Case : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString name READ name CONSTANT)
    Q_PROPERTY(int position READ position CONSTANT)
    Q_PROPERTY(int type READ getType CONSTANT)
    
public:
    explicit Case(QObject *parent = nullptr);
    Case(const QString &name, int position = -1, QObject *parent = nullptr);

    int position() const;
    void setPosition(int newPosition);

    enum CaseType getType() const;
    void setType(CaseType newType);

    QString name() const;
    void setName(const QString &newName);

    virtual void onLand(Player* player);
    virtual void onLeave(Player* player);
    virtual void onHover(Player* player);

signals:

protected:
    QString m_name = "Unknown";
    int m_position = -1;
    enum CaseType type = CS_Unknow;

};

#endif // CASE_H
