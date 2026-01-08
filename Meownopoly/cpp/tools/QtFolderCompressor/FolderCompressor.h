#ifndef FOLDERCOMPRESSOR_H
#define FOLDERCOMPRESSOR_H

#include <QFile>
#include <QObject>
#include <QDir>
#include <QtQml>

// Enum for deletion options using bit flags
enum FolderCompressorDeleteOptions {
    FC_DELETE_NONE = 0x00,                    // No deletion
    FC_DELETE_SOURCE = 0x01,                  // Delete source file after decompression
    FC_DELETE_DESTINATION = 0x02,             // Delete destination folder before decompression
    FC_DELETE_BOTH = FC_DELETE_SOURCE | FC_DELETE_DESTINATION  // Delete both
};

class FolderCompressor : public QObject
{
    Q_OBJECT
    QML_ELEMENT
public:
    explicit FolderCompressor(QObject *parent = 0);

    //A recursive function that scans all files inside the source folder
    //and serializes all files in a row of file names and compressed
    //binary data in a single file
    Q_INVOKABLE bool compressFolder(QString sourceFolder, QString destinationFile);

    //A function that deserializes data from the compressed file and
    //creates any needed subfolders before saving the file
    Q_INVOKABLE bool decompressFolder(QString sourceFile, QString destinationFolder, FolderCompressorDeleteOptions deleteOptions = FC_DELETE_NONE);

    // Static method to register the QML type
    static void registerQml();

private:
    QFile file;
    QDataStream dataStream;

    bool compress(QString sourceFolder, QString prefex);
};

#endif // FOLDERCOMPRESSOR_H
