#!/usr/bin/env python3
"""
tagger_images.py
~~~~~~~~~~~~~~~~
Génère 10 tags et une description pour chaque image d'un dossier
en utilisant Claude CLI (modèle Sonnet) pour l'analyse visuelle.

Optimisé : les images sont envoyées par batch (5 par défaut) et les
batchs sont traités en parallèle (2 workers par défaut).

Usage:
    python tagger_images.py <dossier> [sortie.json] [options]

Options:
    --recursive, -r       Inclure les sous-dossiers
    --batch-size N        Nombre d'images par appel CLI (défaut: 5)
    --workers N           Nombre d'appels CLI en parallèle (défaut: 2)
    --model MODEL         Modèle Claude à utiliser (défaut: sonnet)

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

# Schema pour un batch : tableau d'objets {filename, tags, description}
BATCH_SCHEMA = json.dumps({
    "type": "object",
    "properties": {
        "images": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "filename": {"type": "string"},
                    "tags": {
                        "type": "array",
                        "items": {"type": "string"},
                        "minItems": 10,
                        "maxItems": 10,
                    },
                    "description": {"type": "string", "maxLength": 200},
                },
                "required": ["filename", "tags", "description"],
            },
        }
    },
    "required": ["images"],
})


def build_batch_prompt(image_paths: list[tuple[str, Path]]) -> str:
    """Construit le prompt pour un batch d'images."""
    reads = "\n".join(
        f"- '{str(p.resolve()).replace(chr(92), '/')}' (filename: \"{name}\")"
        for name, p in image_paths
    )
    return (
        f"Lis chacune des {len(image_paths)} images suivantes avec l'outil Read :\n"
        f"{reads}\n\n"
        "Pour CHAQUE image, génère :\n"
        "1) Exactement 10 tags pertinents — mots-clés courts en français, "
        "décrivant le contenu, le style, les couleurs, l'ambiance. "
        "Ne jamais utiliser le tag 'illustration'.\n"
        "2) Une description de l'image en français, 200 caractères maximum.\n\n"
        "Utilise le champ 'filename' pour identifier chaque image dans ta réponse.\n"
        "Réponds uniquement au format JSON demandé."
    )


def analyze_batch(
    image_paths: list[tuple[str, Path]], model: str = "sonnet"
) -> dict[str, dict] | None:
    """Envoie un batch d'images à Claude CLI et retourne les résultats."""
    prompt = build_batch_prompt(image_paths)

    try:
        result = subprocess.run(
            [
                "claude",
                "-p", prompt,
                "--model", model,
                "--output-format", "json",
                "--json-schema", BATCH_SCHEMA,
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


def parse_args():
    directory = None
    output_file = "tags_images.json"
    recursive = False
    batch_size = 5
    workers = 2
    model = "sonnet"

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

    return directory, output_file, recursive, batch_size, workers, model


def main():
    directory, output_file, recursive, batch_size, workers, model = parse_args()

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
    print(f" Dossier : {directory.resolve()}")
    print(f" Sortie  : {output_file}")
    print(f"{'=' * 55}\n")

    results = {}
    done = 0
    t_start = time.time()

    def process_batch(batch_idx, batch):
        return batch_idx, analyze_batch(batch, model=model)

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
                tags_preview = ""
                first = next(iter(batch_data.values()), {})
                if first.get("tags"):
                    tags_preview = f" — {', '.join(first['tags'][:3])} ..."
                print(
                    f"  Batch {idx + 1}/{nb_batches} : "
                    f"{matched}/{len(batch)} OK{tags_preview}"
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
