from pathlib import Path


SUBFOLDERS = [
    'data',
    'game',
    'screens',
    'services',
    'theme',
    'widgets',
]


def main() -> None:
    target_dir = Path(__file__).resolve().parent
    for folder_name in SUBFOLDERS:
        (target_dir / folder_name).mkdir(parents=True, exist_ok=True)


if __name__ == "__main__":
    main()
