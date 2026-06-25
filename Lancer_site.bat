@echo off
echo ==================================================
echo   Lancement du Projet Sudoku - Licence Info
echo ==================================================
echo.

:: Lance l'installation et le serveur en arrière-plan
start "" npm install
start "" npm run dev

:: Attend 5 secondes pour laisser le temps au serveur de démarrer
echo Attente du demarrage du serveur...
timeout /t 5 /nobreak >nul

:: Ouvre le navigateur par défaut sur l'adresse locale
echo Ouverture du navigateur...
start http://localhost:5173

echo.
echo ==================================================
echo   Projet lance ! Ne fermez pas cette fenetre.
echo ==================================================
pause