#ifndef PLAYER_H
#define PLAYER_H

#include <QObject>
#include <QString>
#include <QColor>
#include <QList>

class CaseRestArea;
class CaseCatDevice;
class CaseCatDoor;


class Player : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    Q_PROPERTY(int indexLogo READ indexLogo WRITE setIndexLogo NOTIFY indexLogoChanged FINAL)
    Q_PROPERTY(int kibble READ kibble WRITE setKibble NOTIFY kibbleChanged)
    Q_PROPERTY(int propertyCount READ propertyCount NOTIFY propertyCountChanged)
    Q_PROPERTY(int position READ position WRITE setPosition NOTIFY positionChanged)
    Q_PROPERTY(bool inJail READ isInJail WRITE setInJail NOTIFY inJailChanged)
    Q_PROPERTY(int catDeviceCount READ catDeviceCount NOTIFY catDeviceCountChanged)
    Q_PROPERTY(int catDoorCount READ catDoorCount NOTIFY catDoorCountChanged)

public:
    explicit Player(QObject *parent = nullptr);
    explicit Player(QString name, QColor color, int indexLogo, int kibbles, QObject *parent = nullptr);

    QString name() const { return m_name; }
    void setName(const QString &name);

    QColor color() const { return m_color; }
    void setColor(const QColor &color);

    int kibble() const { return m_kibble; }
    void setKibble(int kibble);

    int position() const { return m_position; }
    void setPosition(int position);

    bool isInJail() const { return m_inJail; }
    void setInJail(bool inJail);

    Q_INVOKABLE bool canAfford(int amount) const;
    Q_INVOKABLE void earnKibble(int amount);
    Q_INVOKABLE  bool spendKibble(int amount);

    QList<CaseRestArea*> ownedProperties() const;
    void addProperty(CaseRestArea* property);
    void removeProperty(CaseRestArea* property);
    int propertyCount() const { return m_ownedProperties.size(); }

    QList<CaseCatDevice*> ownedCatDevices() const;
    void addCatDevice(CaseCatDevice* catDevice);
    void removeCatDevice(CaseCatDevice* catDevice);
    int catDeviceCount() const { return m_ownedCatDevices.size(); }

    QList<CaseCatDoor*> ownedCatDoors() const;
    void addCatDoor(CaseCatDoor* catDoor);
    void removeCatDoor(CaseCatDoor* catDoor);
    int catDoorCount() const { return m_ownedCatDoors.size(); }

    void movePLayer();


    int indexLogo() const;
    void setIndexLogo(int newIndexLogo);

signals:
    void nameChanged();
    void colorChanged();
    void kibbleChanged();
    void propertyCountChanged();
    void catDeviceCountChanged();
    void catDoorCountChanged();
    void positionChanged();
    void inJailChanged();
    void caseLand();
    void caseLeave();
    void caseHover();

    void indexLogoChanged();

private:

    QString m_name = "";
    QColor m_color = "";
    int m_kibble = 1500;  // Starting money
    int m_position = 0;
    QList<CaseRestArea*> m_ownedProperties;
    QList<CaseCatDevice*> m_ownedCatDevices;
    QList<CaseCatDoor*> m_ownedCatDoors;

    bool m_inJail = false;

    int m_indexLogo;
};

#endif // PLAYER_H
