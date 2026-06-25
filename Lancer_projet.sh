#!/bin/bash

echo "=================================================="
echo "   Lancement du Projet - Licence Info (macOS/Linux)"
echo "=================================================="
echo ""

# Installation des dépendances
echo "Installation des dépendances..."
npm install

# Lancement du serveur en arrière-plan
echo "Démarrage du serveur..."
npm run dev &

# Attente du démarrage
echo "Attente du démarrage du serveur (5s)..."
sleep 5

# Ouverture du navigateur selon le système
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    open http://localhost:5173
else
    # Linux (Générique)
    xdg-open http://localhost:5173
fi

echo ""
echo "=================================================="
echo "   Projet lancé ! Ne fermez pas cette fenêtre."
echo "   Appuyez sur Entrée pour arrêter le serveur."
echo "=================================================="
read -p ""