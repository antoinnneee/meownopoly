# Landing page Meownopoly V3

Landing page statique issue du cadrage `doc/v3/`. Elle ne dépend d'aucun
framework, service ou asset externe.

## Ouvrir localement

Ouvrir directement `index.html` dans un navigateur, ou lancer depuis la racine
du dépôt :

```powershell
python -m http.server 8765 --bind 127.0.0.1 --directory Meownopoly/landing-v3
```

Puis visiter `http://127.0.0.1:8765/`.

## Structure

- `index.html` : contenu et structure sémantique ;
- `styles.css` : direction artistique, plateau isométrique et responsive ;
- `script.js` : scénarios du hero, apparitions au scroll et en-tête compact.

Les liens de fin de page pointent vers le cadrage V3 local. La mention « V3 en
construction » distingue les ambitions de la V3 des fondations déjà présentes
dans la V2.
