#ifndef CRASHREPORTTOOL_H
#define CRASHREPORTTOOL_H
#include <QtMessageHandler>

#define CRASH_REPORT_FILE_PATH "crash_report.txt"
#define CRASH_REPORT_LINE_NUMBER 100
void crashHandler(int signal);
void crashMessageHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg);

void installCrashHandler();
#endif // CRASHREPORTTOOL_H
