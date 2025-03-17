#ifndef CASECATNIP_H
#define CASECATNIP_H

#include "Case.h"
#include "player.h"

class CaseCatNip : public Case {
    Q_OBJECT

public:
    explicit CaseCatNip(QObject *parent = nullptr);
    CaseCatNip(const QString &name, int position, QObject *parent = nullptr);
    ~CaseCatNip() override = default;

    void onLand(Player* player) override;

signals:
    void cardDrawn();

private:
    enum CaseType type = CT_CatNip;
};

#endif // CASECATNIP_H 