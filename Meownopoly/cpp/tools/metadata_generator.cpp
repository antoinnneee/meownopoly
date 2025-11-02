/*
 * Standalone Metadata Generator Tool
 * 
 * This tool can be used to generate metadata.json files for asset directories
 * without running the full Meownopoly application.
 * 
 * Usage: metadata_generator.exe <assets_directory>
 * Example: metadata_generator.exe "C:\path\to\assets"
 */

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QImageReader>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QFileInfo>
#include <QDebug>
#include <QCommandLineParser>
#include <algorithm>

class MetadataGenerator
{
public:
    static bool generateMetadataForDirectory(const QString &directoryPath) {
        QDir dir(directoryPath);
        if (!dir.exists()) {
            qWarning() << "Directory does not exist:" << directoryPath;
            return false;
        }
        
        // Get all image files in the directory
        QStringList filters;
        filters << "*.png" << "*.jpg" << "*.jpeg" << "*.bmp" << "*.gif";
        QStringList imageFiles = dir.entryList(filters, QDir::Files);
        
        if (imageFiles.isEmpty()) {
            qWarning() << "No image files found in:" << directoryPath;
            return false;
        }
        
        // Sort files naturally (1.png, 2.png, 10.png, etc.)
        std::sort(imageFiles.begin(), imageFiles.end(), [](const QString &a, const QString &b) {
            QFileInfo fileInfoA(a);
            QFileInfo fileInfoB(b);
            
            // Extract numbers from filenames for natural sorting
            QString baseA = fileInfoA.baseName();
            QString baseB = fileInfoB.baseName();
            
            bool okA, okB;
            int numA = baseA.toInt(&okA);
            int numB = baseB.toInt(&okB);
            
            if (okA && okB) {
                return numA < numB;
            }
            
            return a < b;
        });
        
        QJsonArray assetsArray;
        
        for (int i = 0; i < imageFiles.size(); ++i) {
            const QString &filename = imageFiles[i];
            QString fullPath = dir.absoluteFilePath(filename);
            
            // Read image dimensions
            QImageReader reader(fullPath);
            QSize imageSize = reader.size();
            
            if (!imageSize.isValid()) {
                qWarning() << "Cannot read image dimensions for:" << fullPath;
                continue;
            }
            
            // Generate ID from filename (remove extension)
            QFileInfo fileInfo(filename);
            QString id = fileInfo.baseName();
            
            // Calculate ratio
            double ratio = static_cast<double>(imageSize.width()) / imageSize.height();
            
            // Create asset object
            QJsonObject assetObj;
            assetObj["id"] = id;
            assetObj["filename"] = filename;
            assetObj["ratio"] = ratio;
            assetObj["width"] = imageSize.width();
            assetObj["height"] = imageSize.height();
            
            assetsArray.append(assetObj);
            
            qDebug() << "  " << filename << "->" << id << "(" << imageSize.width() << "x" << imageSize.height() << ")";
        }
        
        // Create metadata object
        QJsonObject metadataObj;
        metadataObj["assets"] = assetsArray;
        
        // Write to metadata.json
        QString metadataPath = dir.absoluteFilePath("metadata.json");
        QFile metadataFile(metadataPath);
        
        if (!metadataFile.open(QIODevice::WriteOnly)) {
            qWarning() << "Cannot create metadata file:" << metadataPath;
            return false;
        }
        
        QJsonDocument doc(metadataObj);
        metadataFile.write(doc.toJson());
        metadataFile.close();
        
        qDebug() << "Generated metadata for" << imageFiles.size() << "assets in:" << directoryPath;
        qDebug() << "Metadata saved to:" << metadataPath;
        
        return true;
    }

    static bool generateAllMetadata(const QString &assetsBasePath) {
        QDir assetsDir(assetsBasePath);
        if (!assetsDir.exists()) {
            qWarning() << "Assets base directory does not exist:" << assetsBasePath;
            return false;
        }
        
        bool success = true;
        int generatedCount = 0;
        
        qDebug() << "Scanning assets directory:" << assetsBasePath;
        
        // Generate for decoration subdirectories
        QString decorationPath = assetsDir.absoluteFilePath("decoration");
        QDir decorationDir(decorationPath);
        if (decorationDir.exists()) {
            QStringList typeDirectories = decorationDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
            
            qDebug() << "Found decoration types:" << typeDirectories;
            
            for (const QString &typeName : typeDirectories) {
                QString typePath = decorationDir.absoluteFilePath(typeName);
                qDebug() << "Processing decoration type:" << typeName;
                
                if (generateMetadataForDirectory(typePath)) {
                    generatedCount++;
                } else {
                    success = false;
                }
            }
        }
        
        // Generate for player_icons directory
        QString playerIconsPath = assetsDir.absoluteFilePath("player_icons");
        if (QDir(playerIconsPath).exists()) {
            qDebug() << "Processing player icons directory";
            
            if (generateMetadataForDirectory(playerIconsPath)) {
                generatedCount++;
            } else {
                success = false;
            }
        }
        
        qDebug() << "Generated metadata for" << generatedCount << "directories";
        return success;
    }
};

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    app.setApplicationName("Metadata Generator");
    app.setApplicationVersion("1.0");
    
    QCommandLineParser parser;
    parser.setApplicationDescription("Generate metadata.json files for Meownopoly assets");
    parser.addHelpOption();
    parser.addVersionOption();
    
    QCommandLineOption assetsPathOption(QStringList() << "p" << "path",
                                       "Path to assets directory", "path");
    parser.addOption(assetsPathOption);
    
    QCommandLineOption directoryOption(QStringList() << "d" << "directory",
                                      "Generate metadata for specific directory", "directory");
    parser.addOption(directoryOption);
    
    parser.process(app);
    
    QString assetsPath = parser.value(assetsPathOption);
    QString specificDirectory = parser.value(directoryOption);
    
    if (assetsPath.isEmpty()) {
        assetsPath = QDir::currentPath() + "/assets";
        qDebug() << "No assets path specified, using default:" << assetsPath;
    }
    
    bool success = false;
    
    if (!specificDirectory.isEmpty()) {
        // Generate metadata for specific directory
        qDebug() << "Generating metadata for specific directory:" << specificDirectory;
        success = MetadataGenerator::generateMetadataForDirectory(specificDirectory);
    } else {
        // Generate metadata for all directories
        qDebug() << "Generating metadata for all asset directories";
        success = MetadataGenerator::generateAllMetadata(assetsPath);
    }
    
    if (success) {
        qDebug() << "Metadata generation completed successfully!";
        return 0;
    } else {
        qDebug() << "Metadata generation failed!";
        return 1;
    }
}
