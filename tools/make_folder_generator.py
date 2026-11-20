from pathlib import Path


def main() -> None:
    base_dir = Path(__file__).resolve().parent
    output_script = base_dir / "recreate_subfolders.py"

    # Collect immediate subfolder names (ignores files and the current directory)
    subfolders = sorted(
        entry.name
        for entry in base_dir.iterdir()
        if entry.is_dir()
    )

    lines = [
        "from pathlib import Path",
        "",
        "",
        "SUBFOLDERS = [",
    ]
    for name in subfolders:
        lines.append(f"    {name!r},")
    lines.extend([
        "]",
        "",
        "",
        "def main() -> None:",
        "    target_dir = Path(__file__).resolve().parent",
        "    for folder_name in SUBFOLDERS:",
        "        (target_dir / folder_name).mkdir(parents=True, exist_ok=True)",
        "",
        "",
        'if __name__ == "__main__":',
        "    main()",
        "",
    ])

    output_script.write_text("\n".join(lines), encoding="utf-8")
    print(f"Generated {output_script.name} with {len(subfolders)} subfolder(s).")


if __name__ == "__main__":
    main()