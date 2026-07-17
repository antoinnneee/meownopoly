#ifndef CASECATNIP_H
#define CASECATNIP_H

#include "Case.h"

class CaseCatNip : public Case {
    Q_OBJECT

public:
    explicit CaseCatNip(QObject *parent = nullptr);
    CaseCatNip(const QString &name, QObject *parent = nullptr);
    CaseCatNip(const QJsonObject &json, QObject *parent = nullptr);
    ~CaseCatNip() override = default;

    // void onLand(Player* player) override;
    // Pas de champs propres : toJsonObject()/toJSON() de Case suffisent.

signals:
    void cardDrawn();

private:
    enum CaseType type = CS_CatNip;
};

#endif // CASECATNIP_H 
