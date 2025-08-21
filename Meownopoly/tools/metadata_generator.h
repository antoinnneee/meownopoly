#ifndef METADATA_GENERATOR_H
#define METADATA_GENERATOR_H

#include <QString>

class MetadataGenerator
{
public:
    static bool generateMetadataForDirectory(const QString &directoryPath);
    static bool generateAllMetadata(const QString &assetsBasePath);
};

#endif // METADATA_GENERATOR_H
