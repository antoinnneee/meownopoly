#ifndef DEBUG_INFO_H
#define DEBUG_INFO_H

#include <QDebug>

#define DBG_CLR_RED "\033[31m"
#define DBG_CLR_GREEN "\033[32m"
#define DBG_CLR_YELLOW "\033[33m"
#define DBG_CLR_BLUE "\033[34m"
#define DBG_CLR_MAGENTA "\033[35m"
#define DBG_CLR_CYAN "\033[36m"
#define DBG_CLR_RESET "\033[0m"

#define QDBG_RED() qDebug() << DBG_CLR_RED
#define QDBG_GREEN() qDebug() << DBG_CLR_GREEN
#define QDBG_YELLOW() qDebug() << DBG_CLR_YELLOW
#define QDBG_BLUE() qDebug() << DBG_CLR_BLUE
#define QDBG_MAGENTA() qDebug() << DBG_CLR_MAGENTA
#define QDBG_CYAN() qDebug() << DBG_CLR_CYAN
#define QDBG_RESET() qDebug() << DBG_CLR_RESET

#define QDBG_RED_NOQUOTE() qDebug().noquote() << DBG_CLR_RED
#define QDBG_GREEN_NOQUOTE() qDebug().noquote() << DBG_CLR_GREEN
#define QDBG_YELLOW_NOQUOTE() qDebug().noquote() << DBG_CLR_YELLOW
#define QDBG_BLUE_NOQUOTE() qDebug().noquote() << DBG_CLR_BLUE
#define QDBG_MAGENTA_NOQUOTE() qDebug().noquote() << DBG_CLR_MAGENTA
#define QDBG_CYAN_NOQUOTE() qDebug().noquote() << DBG_CLR_CYAN

#define QDBG_FUNCNAME_RED(msg) qDebug() << DBG_CLR_RED << msg << Q_FUNC_INFO << DBG_CLR_RESET
#define QDBG_FUNCNAME_GREEN(msg) qDebug() << DBG_CLR_GREEN << msg << Q_FUNC_INFO << DBG_CLR_RESET
#define QDBG_FUNCNAME_YELLOW(msg) qDebug() << DBG_CLR_YELLOW << msg << Q_FUNC_INFO << DBG_CLR_RESET
#define QDBG_FUNCNAME_BLUE(msg) qDebug() << DBG_CLR_BLUE << msg << Q_FUNC_INFO << DBG_CLR_RESET
#define QDBG_FUNCNAME_MAGENTA(msg) \
    qDebug() << DBG_CLR_MAGENTA << msg << Q_FUNC_INFO << DBG_CLR_RESET
#define QDBG_FUNCNAME_CYAN(msg) qDebug() << DBG_CLR_CYAN << msg << Q_FUNC_INFO << DBG_CLR_RESET

#define COMPILATION_DATE_TIME \
    QString(QDateTime::fromString(QStringLiteral(__DATE__) + QStringLiteral(" ") \
                                      + QStringLiteral(__TIME__), \
                                  "MMM  d yyyy hh:mm:ss") \
                .toString("MMddyy_hhmmss"))

#endif // DEBUG_INFO_H
