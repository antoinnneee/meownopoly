#ifndef CASE_H
#define CASE_H

#include <QObject>

enum CaseType{
    CT_KibbleDispenser, // depart
    CT_RestArea,        // terrain
    CT_CardBoardBox,    // caisse communauté
    CT_CatNip,          // chance
    CT_Jail,            // prison
    CT_ToJail,          // go to jail
    CT_CatDoor,         // gare
    CT_FreeNap,         // parking gratuit
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
public:
    explicit Case(QObject *parent = nullptr);

    int position() const;
    void setPosition(int newPosition);

    CaseType getType() const;
    void setType(CaseType newType);

signals:

private:
    int m_position = -1;
    enum CaseType type = CT_Unknow;

};

#endif // CASE_H
