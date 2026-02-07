#!/bin/bash

echo "Test de l'API du dashboard..."
echo ""

# Test de l'API /api/stats
echo "📊 Récupération des statistiques..."
curl -s http://localhost:3000/api/stats | jq '.' || curl -s http://localhost:3000/api/stats

echo ""
echo "✅ Test terminé"
