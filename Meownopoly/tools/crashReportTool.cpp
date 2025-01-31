#include "crashreporttool.h"
#include <QMutex>
#include <QtCore>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
QMutex mutex;

QStringList debugHistory;

QString humanReadableSignal(int signal)
{
    switch (signal) {
    case SIGINT:
        return "Interrupt";
    case SIGILL:
        return "Illegal instruction";
#ifdef Q_OS_WINDOWS
    case SIGABRT_COMPAT:
        return "Abort";
#endif
    case SIGFPE:
        return "Floating point exception";
    case SIGSEGV:
        return "Segmentation fault";
    case SIGTERM:
        return "Terminated";
#ifdef Q_OS_WINDOWS
    case SIGBREAK:
        return "Break";
#endif
    case SIGABRT:
        return "Abort";
    default:
        return "Unknown signal";
    }
}

void crashMessageHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    mutex.lock();
    QDateTime currentTime = QDateTime::currentDateTime();
    QString messageDate = currentTime.toString("ddd MMMM d yy - hh:mm:ss.zzz");
    QString formattedMessage;
    switch (type) {
    case QtDebugMsg:
        formattedMessage = QString("Debug: %1 -> %2\n").arg(context.function).arg(msg);
        fprintf(stdout, "%s\n", msg.toLocal8Bit().constData());
        break;
    case QtWarningMsg:
        formattedMessage = QString("Warning: %1 -> %2\n").arg(context.function).arg(msg);
        fprintf(stderr, "%s\n", msg.toLocal8Bit().constData());
        break;
    case QtCriticalMsg:
        formattedMessage = QString("Critical: %1 -> %2\n").arg(context.function).arg(msg);
        fprintf(stderr, "%s\n", msg.toLocal8Bit().constData());
        break;
    case QtFatalMsg:
        formattedMessage = QString("Fatal: %1 -> %2\n").arg(context.function).arg(msg);
        fprintf(stderr, "%s\n", msg.toLocal8Bit().constData());
        abort(); // QtFatalMsg appelle abort() par défaut
    case QtInfoMsg:
        formattedMessage = QString("Info: %1 -> %2\n").arg(context.function).arg(msg);
        fprintf(stdout, "%s\n", msg.toLocal8Bit().constData());
        break;
    }
    formattedMessage.prepend(messageDate + " - ");
    debugHistory.append(formattedMessage);
    if (debugHistory.size() > CRASH_REPORT_LINE_NUMBER) {
        debugHistory.removeFirst();
    }
    mutex.unlock();
}

void crashHandler(int signal)
{
    qInstallMessageHandler(0);

    qDebug() << "crash detected";
    QString path = CRASH_REPORT_FILE_PATH;
    qDebug() << CRASH_REPORT_FILE_PATH;
    QFile file(path);
    if (file.open(QIODevice::WriteOnly | QIODevice::Append)) {
        QTextStream stream(&file);
        // print date and a rectangle made with stars
        for (int i = 0; i < 80; i++) {
            stream << "*";
        }
        stream << "\n";
        stream << QDateTime::currentDateTime().toString() << "\n";
        stream << "Crash detected! Signal: " << signal << " -> " << humanReadableSignal(signal)
               << "\n";
        for (int i = 0; i < 80; i++) {
            stream << "*";
        }
        stream << "\n";
        for (int i = 0; i < debugHistory.size(); i++) {
            stream << debugHistory.at(i).toUtf8();
        }
    }
    file.close();
    std::exit(1);
}

void installCrashHandler()
{
    qInstallMessageHandler(crashMessageHandler);
    // Install the crash handler
    signal(SIGSEGV, crashHandler);
    signal(SIGILL, crashHandler);
    signal(SIGABRT, crashHandler);
    signal(SIGFPE, crashHandler);
    signal(SIGTERM, crashHandler);
    signal(SIGINT, crashHandler);
#ifdef Q_OS_WINDOWS
    signal(SIGBREAK, crashHandler);
    signal(SIGABRT_COMPAT, crashHandler);
#endif
}
