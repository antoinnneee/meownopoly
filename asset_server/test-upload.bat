@echo off
echo ===================================
echo   Test Upload vers Serveur Meownopoly
echo ===================================
echo.

REM Créer un fichier de test si il n'existe pas
if not exist "test_asset.meow" (
    echo Création d'un fichier de test...
    echo "Test asset file content" > test_asset.meow
)

echo Test 1: Ping du serveur
curl -X GET http://localhost:8080/api/ping
echo.
echo.

echo Test 2: Version du serveur
curl -X GET http://localhost:8080/api/version
echo.
echo.

echo Test 3: Upload du fichier de test
curl -X POST -F "package=@test_asset.meow" -F "version=1.0.1" -F "description=Test upload" http://localhost:8080/api/upload
echo.
echo.

echo Test 4: Vérification des fichiers sur le serveur
curl -X GET http://localhost:8080/api/files
echo.
echo.

echo Tests terminés!
pause
