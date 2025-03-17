#ifndef CASECARDBOARDBOX_H
#define CASECARDBOARDBOX_H

#include "Case.h"
#include "player.h"

class CaseCardBoardBox : public Case {
    Q_OBJECT

public:
    explicit CaseCardBoardBox(QObject *parent = nullptr);
    CaseCardBoardBox(const QString &name, int position, QObject *parent = nullptr);
    ~CaseCardBoardBox() override = default;

    void onLand(Player* player) override;

signals:
    void cardDrawn();

private:
    enum CaseType type = CT_CardBoardBox;
    // Add any private members needed for community chest card functionality
};

#endif // CASECARDBOARDBOX_H 