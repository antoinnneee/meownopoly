#include "metadata_generator.h"

#include <QDir>
#include <QFile>
#include <QImageReader>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QFileInfo>
#include <QDebug>
#include <algorithm>

bool MetadataGenerator::generateMetadataForDirectory(const QString &directoryPath) {
    QDir dir(directoryPath);
    if (!dir.exists()) {
        qWarning() << "Directory does not exist:" << directoryPath;
        return false;
    }
    
    // Get all supported image files in the directory
    QStringList filters;
    filters << "*.png" << "*.jpg" << "*.jpeg" << "*.bmp" << "*.gif" << "*.webp";
    QStringList imageFiles = dir.entryList(filters, QDir::Files);
    
    if (imageFiles.isEmpty()) {
        qWarning() << "No image files found in:" << directoryPath;
        return false;
    }
    
    // Sort files naturally (1.png, 2.png, 10.png, etc.)
    std::sort(imageFiles.begin(), imageFiles.end(), [](const QString &a, const QString &b) {
        QFileInfo fileInfoA(a);
        QFileInfo fileInfoB(b);
        
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
        
        QImageReader reader(fullPath);
        QSize imageSize = reader.size();
        
        if (!imageSize.isValid()) {
            qWarning() << "Cannot read image dimensions for:" << fullPath;
            continue;
        }
        
        QFileInfo fileInfo(filename);
        QString id = fileInfo.baseName();
        QString extension = fileInfo.suffix().toLower();
        
        // Detect animation
        bool isAnimated = reader.supportsAnimation() && reader.imageCount() > 1;
        int frameCount = isAnimated ? reader.imageCount() : 1;
        
        // Calculate simplified ratio using GCD
        int w = imageSize.width();
        int h = imageSize.height();
        int a = w;
        int b = h;
        while (b != 0) {
            int temp = b;
            b = a % b;
            a = temp;
        }
        int gcd = (a == 0) ? 1 : a;
        int ratioWidth = w / gcd;
        int ratioHeight = h / gcd;
        
        // Create asset object with all required fields for AssetManager
        QJsonObject assetObj;
        assetObj["id"] = id;
        assetObj["filename"] = filename;
        assetObj["extension"] = extension;
        assetObj["width"] = w;
        assetObj["height"] = h;
        assetObj["ratioWidth"] = ratioWidth;
        assetObj["ratioHeight"] = ratioHeight;
        assetObj["animated"] = isAnimated;
        assetObj["frameCount"] = frameCount;
        
        assetsArray.append(assetObj);
        
        qDebug() << "  " << filename << "->" << id << "(" << w << "x" << h << ") ratio:" << ratioWidth << ":" << ratioHeight << (isAnimated ? " [ANIMATED]" : "");
    }
    
    QJsonObject metadataObj;
    metadataObj["assets"] = assetsArray;
    
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
    return true;
}

bool MetadataGenerator::generateAllMetadata(const QString &assetsBasePath) {
    QDir assetsDir(assetsBasePath);
    if (!assetsDir.exists()) {
        qWarning() << "Assets base directory does not exist:" << assetsBasePath;
        return false;
    }
    
    bool success = true;
    int generatedCount = 0;
    
    qDebug() << "Scanning assets directory for metadata generation:" << assetsBasePath;
    
    // Get all subdirectories (categories)
    QStringList categories = assetsDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    
    for (const QString &category : categories) {
        QString categoryPath = assetsDir.absoluteFilePath(category);
        QDir categoryDir(categoryPath);
        
        // Check if this category has subdirectories (types) or just files
        QStringList typeDirs = categoryDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        
        if (typeDirs.isEmpty()) {
            // No sub-types, process this directory directly if it contains images
            if (generateMetadataForDirectory(categoryPath)) {
                generatedCount++;
            }
        } else {
            // Process each type directory
            for (const QString &typeName : typeDirs) {
                QString typePath = categoryDir.absoluteFilePath(typeName);
                if (generateMetadataForDirectory(typePath)) {
                    generatedCount++;
                } else {
                    // We don't necessarily want to fail the whole process if one dir fails (e.g. empty)
                }
            }
        }
    }
    
    qDebug() << "Metadata generation finished. Directories processed:" << generatedCount;
    return success;
}