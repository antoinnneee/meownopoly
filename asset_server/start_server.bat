@echo off
echo ===================================
echo   Serveur Meownopoly Resources
echo ===================================
echo.

REM Vérifier si Node.js est installé
node --version >nul 2>&1
if errorlevel 1 (
    echo ERREUR: Node.js n'est pas installé ou pas dans le PATH
    echo Téléchargez Node.js depuis https://nodejs.org/
    pause
    exit /b 1
)

REM Vérifier si les dépendances sont installées
if not exist "node_modules" (
    echo Installation des dépendances...
    npm install
    if errorlevel 1 (
        echo ERREUR: Échec de l'installation des dépendances
        pause
        exit /b 1
    )
)

echo Démarrage du serveur...
echo.
echo Le serveur sera accessible sur:
echo - Local: http://localhost:8080
echo - Réseau: http://%COMPUTERNAME%:8080
echo.
echo Appuyez sur Ctrl+C pour arrêter le serveur
echo.

REM Démarrer le serveur
npm start

pause
