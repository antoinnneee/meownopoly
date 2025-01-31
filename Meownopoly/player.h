#ifndef PLAYER_H
#define PLAYER_H

#include <QObject>

class Player : public QObject
{
    Q_OBJECT
public:
    explicit Player(QObject *parent = nullptr);

    int position() const;
    void setPosition(int newPosition);

    int croquettes() const;
    void setCroquettes(int newCroquettes);

signals:

private:
    int m_position = 0;
    int m_croquettes = 0;

};

#endif // PLAYER_H
