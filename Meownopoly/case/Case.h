#ifndef CASE_H
#define CASE_H

#include <QObject>
#include <QString>

// Forward declaration instead of including player.h
class Player;

enum CaseType{
    CT_KibbleDispenser, // depart
    CT_RestArea,        // terrain
    CT_CardBoardBox,    // caisse communauté
    CT_CatNip,          // chance
    CT_Jail,            // prison
    CT_ToJail,          // go to jail
    CT_CatDoor,         // gare
    CT_FreeNap,         // free parking
    CT_WaterFountain,   // service des eaux
    CT_LaserPointer,    // service electricite
    CT_GoldenCollar,    // Taxe de luxe
    CT_FurTax,          // Taxe sur le revenu
    CT_Unknow,
    CT_Count
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

signals:

private:
    QString m_name = "Unknown";
    int m_position = -1;
    enum CaseType type = CT_Unknow;

};

#endif // CASE_H
