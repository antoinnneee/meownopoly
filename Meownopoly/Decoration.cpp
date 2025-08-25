#include "Decoration.h"

Decoration::Decoration(QObject *parent): QObject{parent}{

}

Decoration::Decoration(const QJsonDocument &json, QObject *parent)
{
    QJsonObject obj = json.object();
    name = obj["name"].toString();
    uniqueId = uniqueId.fromString(obj["uniqueId"].toString());
    type = intToDecorationType(obj["type"].toInt());
}

Decoration::DecorationType Decoration::intToDecorationType(int type)
{
    switch (type) {
    case 0: return DC_Fountain;
    case 1: return DC_Bench;
    case 2: return DC_Statue;
    case 3: return DC_LampPost;
    case 4: return DC_Plant;
    case 5: return DC_Bush;
    case 6: return DC_ParkingMeter;
    default: return DC_Unknow; // Unknown type
    }
}
