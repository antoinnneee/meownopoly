#ifndef DECORATION_H
#define DECORATION_H

#include <QObject>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUuid>

class Decoration : public QObject
{
    Q_OBJECT
public:
    explicit Decoration(QObject *parent = nullptr);
    Decoration(const QJsonDocument &json, QObject *parent = nullptr);

    enum DecorationType {
        DC_Fountain,
        DC_Bench,
        DC_Statue,
        DC_LampPost,
        DC_Plant,
        DC_Bush,
        DC_ParkingMeter,
        DC_Unknow
    };

    Q_ENUM(DecorationType)

    static DecorationType intToDecorationType(int type);
private:

    QString name = "unknow_decoration";
    DecorationType type =  DC_Unknow;
    QUuid uniqueId = QUuid::createUuid();
    bool isObstacle = false;
    bool isAnimation = false;


};

#endif // DECORATION_H
