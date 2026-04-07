@echo off
REM Lance 2 instances de Meownopoly pour tester le P2P en local
REM Instance 1 = profil normal, Instance 2 = profil separe (QSettings + DB distincts)

echo Lancement de l'instance 1...
start "Meownopoly - Instance 1" build\Meownopoly.exe

timeout /t 2 /nobreak >nul

echo Lancement de l'instance 2...
start "Meownopoly - Instance 2" build\Meownopoly.exe --instance 2

echo Les 2 instances sont lancees.
