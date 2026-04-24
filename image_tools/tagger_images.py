#!/usr/bin/env python3
"""
tagger_images.py
~~~~~~~~~~~~~~~~
Génère pour chaque image d'un dossier :
  - 5 à 10 tags de style (choisis dans une liste contrôlée → tri par style)
  - 10 à 20 tags descriptifs libres
  - une description

Utilise Claude CLI (modèle Sonnet) pour l'analyse visuelle.
Les images sont envoyées par batch (5 par défaut) et les batchs sont
traités en parallèle (2 workers par défaut).

Usage:
    python tagger_images.py <dossier> [sortie.json] [options]

Options:
    --recursive, -r       Inclure les sous-dossiers
    --batch-size N        Nombre d'images par appel CLI (défaut: 5)
    --workers N           Nombre d'appels CLI en parallèle (défaut: 2)
    --model MODEL         Modèle Claude à utiliser (défaut: sonnet)
    --styles-file FILE    Fichier texte (un style par ligne) pour
                          surcharger la liste de styles par défaut

Exemples:
    python tagger_images.py ./mes_images
    python tagger_images.py ./mes_images resultat.json --recursive
    python tagger_images.py ./mes_images -r --batch-size 8 --workers 3
"""

import subprocess
import json
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".tiff", ".tif"}

# Vocabulaire contrôlé pour le tri par style. Claude choisit 5 à 10
# entrées de cette liste par image. Surchargeable via --styles-file.
DEFAULT_STYLE_VOCAB = [
    # Techniques de rendu
    "cartoon",
    "réaliste",
    "pixel-art",
    "aquarelle",
    "flat-design",
    "3d-rendu",
    "croquis",
    "anime",
    "vintage",
    "minimaliste",
    "vectoriel",
    "isométrique",
    "peinture",
    "bande-dessinée",
    "low-poly",
    "chibi",
    "doodle",
    "photo",
    # Thèmes / univers / époques
    "médiéval",
    "futuriste",
    "cyberpunk",
    "steampunk",
    "fantastique",
    "science-fiction",
    "gothique",
    "art-déco",
    "art-nouveau",
    "pop-art",
    "baroque",
    "renaissance",
    "western",
    "post-apocalyptique",
    "japonais",
    "tribal",
    "préhistorique",
    "antique",
    "nautique",
    "militaire",
    "horreur",
    "enfantin",
    "kawaii",
    "halloween",
    "noël",
    "nature",
    "urbain",
]


def build_batch_schema(style_vocab: list[str]) -> str:
    """Construit le JSON schema en contraignant style_tags au vocabulaire."""
    return json.dumps({
        "type": "object",
        "properties": {
            "images": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "filename": {"type": "string"},
                        "style_tags": {
                            "type": "array",
                            "items": {"type": "string", "enum": style_vocab},
                            "minItems": 5,
                            "maxItems": 10,
                            "uniqueItems": True,
                        },
                        "tags": {
                            "type": "array",
                            "items": {"type": "string"},
                            "minItems": 10,
                            "maxItems": 20,
                            "uniqueItems": True,
                        },
                        "description": {"type": "string", "maxLength": 200},
                    },
                    "required": ["filename", "style_tags", "tags", "description"],
                },
            }
        },
        "required": ["images"],
    })


def build_batch_prompt(
    image_paths: list[tuple[str, Path]], style_vocab: list[str]
) -> str:
    """Construit le prompt pour un batch d'images."""
    reads = "\n".join(
        f"- '{str(p.resolve()).replace(chr(92), '/')}' (filename: \"{name}\")"
        for name, p in image_paths
    )
    styles_list = ", ".join(style_vocab)
    return (
        f"Lis chacune des {len(image_paths)} images suivantes avec l'outil Read :\n"
        f"{reads}\n\n"
        "Pour CHAQUE image, génère :\n"
        "1) 'style_tags' : entre 5 et 10 tags de style choisis EXCLUSIVEMENT "
        f"dans cette liste contrôlée : [{styles_list}]. "
        "Ne choisis QUE les styles qui s'appliquent réellement à l'image. "
        "Aucun style hors liste n'est autorisé.\n"
        "2) 'tags' : entre 10 et 20 tags descriptifs libres — mots-clés courts "
        "en français décrivant le contenu, le sujet, les couleurs, l'ambiance, "
        "la composition. Ne jamais utiliser le tag 'illustration'. "
        "Les style_tags ne doivent PAS être répétés dans tags.\n"
        "3) 'description' : une description de l'image en français, "
        "200 caractères maximum.\n\n"
        "Utilise le champ 'filename' pour identifier chaque image dans ta réponse.\n"
        "Réponds uniquement au format JSON demandé."
    )


def analyze_batch(
    image_paths: list[tuple[str, Path]],
    style_vocab: list[str],
    schema: str,
    model: str = "sonnet",
) -> dict[str, dict] | None:
    """Envoie un batch d'images à Claude CLI et retourne les résultats."""
    prompt = build_batch_prompt(image_paths, style_vocab)

    try:
        result = subprocess.run(
            [
                "claude",
                "-p", prompt,
                "--model", model,
                "--output-format", "json",
                "--json-schema", schema,
                "--allowed-tools", "Read",
                "--no-session-persistence",
            ],
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=300,
        )
    except subprocess.TimeoutExpired:
        return None

    if result.returncode != 0:
        return None

    try:
        response = json.loads(result.stdout)
        data = response.get("structured_output", response)
        if isinstance(data, str):
            data = json.loads(data)

        # Convertir le tableau en dict par filename
        results = {}
        for entry in data.get("images", []):
            fname = entry.get("filename", "")
            results[fname] = {
                "style_tags": entry.get("style_tags", []),
                "tags": entry.get("tags", []),
                "description": entry.get("description", ""),
            }
        return results
    except (json.JSONDecodeError, TypeError, AttributeError):
        return None


def collect_images(directory: Path, recursive: bool) -> list[Path]:
    """Collecte les fichiers image du dossier."""
    if recursive:
        return sorted(
            f for f in directory.rglob("*")
            if f.is_file() and f.suffix.lower() in IMAGE_EXTENSIONS
        )
    return sorted(
        f for f in directory.iterdir()
        if f.is_file() and f.suffix.lower() in IMAGE_EXTENSIONS
    )


def chunk(lst, size):
    """Découpe une liste en sous-listes de taille `size`."""
    for i in range(0, len(lst), size):
        yield lst[i : i + size]


def load_style_vocab(path: Path) -> list[str]:
    """Charge un vocabulaire de styles depuis un fichier texte (un par ligne)."""
    vocab = []
    seen = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        if s not in seen:
            seen.add(s)
            vocab.append(s)
    if len(vocab) < 5:
        print(f"Erreur : le fichier de styles doit contenir au moins 5 entrées "
              f"(trouvé {len(vocab)}).")
        sys.exit(1)
    return vocab


def parse_args():
    directory = None
    output_file = "tags_images.json"
    recursive = False
    batch_size = 5
    workers = 2
    model = "sonnet"
    styles_file = None

    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(__doc__.strip())
        sys.exit(0)

    i = 0
    positional = 0
    while i < len(args):
        arg = args[i]
        if arg in ("--recursive", "-r"):
            recursive = True
        elif arg == "--batch-size" and i + 1 < len(args):
            i += 1
            batch_size = max(1, int(args[i]))
        elif arg == "--workers" and i + 1 < len(args):
            i += 1
            workers = max(1, int(args[i]))
        elif arg == "--model" and i + 1 < len(args):
            i += 1
            model = args[i]
        elif arg == "--styles-file" and i + 1 < len(args):
            i += 1
            styles_file = Path(args[i])
        elif not arg.startswith("-"):
            if positional == 0:
                directory = Path(arg)
            elif positional == 1:
                output_file = arg
            positional += 1
        i += 1

    if directory is None:
        print("Erreur : dossier non spécifié.")
        sys.exit(1)

    return directory, output_file, recursive, batch_size, workers, model, styles_file


def main():
    (directory, output_file, recursive, batch_size,
     workers, model, styles_file) = parse_args()

    if styles_file is not None:
        if not styles_file.is_file():
            print(f"Erreur : fichier de styles introuvable : {styles_file}")
            sys.exit(1)
        style_vocab = load_style_vocab(styles_file)
    else:
        style_vocab = list(DEFAULT_STYLE_VOCAB)

    schema = build_batch_schema(style_vocab)

    if not directory.is_dir():
        print(f"Erreur : '{directory}' n'est pas un dossier valide.")
        sys.exit(1)

    images = collect_images(directory, recursive)
    if not images:
        print(f"Aucune image trouvée dans '{directory}'.")
        sys.exit(0)

    # Préparer les noms relatifs
    named_images = []
    for img in images:
        rel = img.relative_to(directory).as_posix() if recursive else img.name
        named_images.append((rel, img))

    batches = list(chunk(named_images, batch_size))
    total = len(images)
    nb_batches = len(batches)

    print(f"{'=' * 55}")
    print(f" Tagger Images")
    print(f" {total} image(s) | {nb_batches} batch(s) de {batch_size}")
    print(f" {workers} worker(s) en parallèle | modèle: {model}")
    print(f" Styles ({len(style_vocab)}) : {', '.join(style_vocab)}")
    print(f" Dossier : {directory.resolve()}")
    print(f" Sortie  : {output_file}")
    print(f"{'=' * 55}\n")

    results = {}
    done = 0
    t_start = time.time()

    def process_batch(batch_idx, batch):
        return batch_idx, analyze_batch(batch, style_vocab, schema, model=model)

    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {
            pool.submit(process_batch, idx, batch): (idx, batch)
            for idx, batch in enumerate(batches)
        }

        for future in as_completed(futures):
            idx, batch = futures[future]
            batch_names = [name for name, _ in batch]
            batch_data = future.result()[1]

            if batch_data:
                matched = 0
                for name in batch_names:
                    if name in batch_data:
                        results[name] = batch_data[name]
                        matched += 1
                done += len(batch)
                preview = ""
                first = next(iter(batch_data.values()), {})
                if first.get("style_tags"):
                    preview = f" — styles: {', '.join(first['style_tags'][:3])}"
                elif first.get("tags"):
                    preview = f" — {', '.join(first['tags'][:3])} ..."
                print(
                    f"  Batch {idx + 1}/{nb_batches} : "
                    f"{matched}/{len(batch)} OK{preview}"
                )
            else:
                done += len(batch)
                print(
                    f"  Batch {idx + 1}/{nb_batches} : ECHEC "
                    f"({', '.join(batch_names)})"
                )

    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    elapsed = time.time() - t_start
    print(f"\n{'=' * 55}")
    print(f" Terminé en {elapsed:.0f}s ({elapsed / max(total, 1):.1f}s/image)")
    print(f" {len(results)}/{total} images analysées")
    print(f" Résultat : {output_file}")
    print(f"{'=' * 55}")


if __name__ == "__main__":
    main()
