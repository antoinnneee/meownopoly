@echo off
REM Lance 2 instances de Meownopoly pour tester le P2P en local
REM Instance 1 = profil normal, Instance 2 = profil separe (QSettings + DB distincts)

setlocal
set "REPO=%~dp0"

REM ----- Setup environnement Qt + MinGW -----
REM (sinon les DLLs Qt ne sont pas trouvees quand lance hors de Qt Creator)
set "QT_BIN=C:\Qt\6.10.2\mingw_64\bin"
set "MINGW_BIN=C:\Qt\Tools\mingw1310_64\bin"
set "PATH=%QT_BIN%;%MINGW_BIN%;%PATH%"

REM ----- Recherche de l'executable -----
set "EXE="
if exist "%REPO%Meownopoly\build\Desktop_Qt_6_10_2_MinGW_64_bit-Debug\Meownopoly.exe" (
    set "EXE=%REPO%Meownopoly\build\Desktop_Qt_6_10_2_MinGW_64_bit-Debug\Meownopoly.exe"
) else if exist "%REPO%Meownopoly\build\Desktop_Qt_6_10_2_MinGW_64_bit-Release\Meownopoly.exe" (
    set "EXE=%REPO%Meownopoly\build\Desktop_Qt_6_10_2_MinGW_64_bit-Release\Meownopoly.exe"
) else if exist "%REPO%build\Meownopoly.exe" (
    set "EXE=%REPO%build\Meownopoly.exe"
)

if "%EXE%"=="" (
    echo [ERREUR] Aucun executable Meownopoly.exe trouve. Lancez un build d'abord.
    exit /b 1
)

echo Executable: %EXE%
echo PATH Qt:    %QT_BIN%
echo PATH MinGW: %MINGW_BIN%
echo.
echo Lancement de l'instance 1...
start "Meownopoly - Instance 1" "%EXE%"

timeout /t 2 /nobreak >nul

echo Lancement de l'instance 2...
start "Meownopoly - Instance 2" "%EXE%" --instance 2

echo Les 2 instances sont lancees.
endlocal
