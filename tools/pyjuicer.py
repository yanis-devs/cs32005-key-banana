#!/usr/bin/env python3
"""Export the text contents of a folder tree into juice.txt.

Place this script in the folder you want to export, then run it with Python.
The output file is created beside this script and completely overwritten
whenever the script runs.
"""

from datetime import datetime
from pathlib import Path
import os
import sys


SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_FILE = SCRIPT_DIR / "juice.txt"
SCRIPT_FILE = Path(__file__).resolve()


def write_file(output, file_path: Path, relative_path: Path) -> None:
    """Write one file's name and UTF-8 text content to the export."""
    try:
        # utf-8-sig also handles UTF-8 files that begin with a byte-order mark.
        # Strict decoding means binary or non-UTF-8 files are marked inaccessible
        # instead of producing corrupted text in the export.
        with file_path.open("r", encoding="utf-8-sig", errors="strict", newline="") as source:
            content = source.read()
    except (OSError, UnicodeError):
        output.write(f"FILE: {relative_path.as_posix()} (inaccessible)\n")
        output.write("-" * 80 + "\n\n")
        return

    output.write(f"FILE: {relative_path.as_posix()}\n")
    output.write("-" * 80 + "\n")

    if content == "":
        output.write("[empty]\n\n")
        return

    output.write(content)
    if not content.endswith("\n"):
        output.write("\n")
    output.write("\n")


def walk_folder(output, folder: Path, relative_folder: Path) -> None:
    """Export files in this folder, then recursively export its subfolders."""
    folder_label = relative_folder.as_posix()
    if folder_label == ".":
        folder_label = "./"
    else:
        folder_label += "/"

    output.write("=" * 80 + "\n")
    output.write(f"FOLDER: {folder_label}\n")
    output.write("=" * 80 + "\n\n")

    try:
        entries = list(os.scandir(folder))
    except OSError:
        output.write("(inaccessible folder)\n\n")
        return

    files = []
    directories = []

    for entry in entries:
        entry_path = Path(entry.path)

        # Do not follow symbolic links. This keeps the walk inside the chosen
        # folder tree and prevents symlink loops.
        try:
            if entry.is_dir(follow_symlinks=False):
                directories.append(entry_path)
            elif entry.is_file(follow_symlinks=False):
                files.append(entry_path)
        except OSError:
            # If the entry cannot be inspected, report it as inaccessible.
            files.append(entry_path)

    files.sort(key=lambda path: path.name.casefold())
    directories.sort(key=lambda path: path.name.casefold())

    for file_path in files:
        try:
            resolved_path = file_path.resolve()
        except OSError:
            resolved_path = file_path.absolute()

        # Avoid exporting the script itself or the export file into itself.
        if resolved_path in (SCRIPT_FILE, OUTPUT_FILE.resolve()):
            continue

        try:
            relative_path = file_path.relative_to(SCRIPT_DIR)
        except ValueError:
            relative_path = file_path

        write_file(output, file_path, relative_path)

    for directory in directories:
        relative_directory = directory.relative_to(SCRIPT_DIR)
        walk_folder(output, directory, relative_directory)


def main() -> int:
    """Create/overwrite juice.txt and export the folder tree."""
    try:
        # Opening in write mode clears an existing juice.txt automatically.
        with OUTPUT_FILE.open("w", encoding="utf-8", newline="\n") as output:
            output.write("PYJUICER EXPORT\n")
            output.write(f"ROOT: {SCRIPT_DIR}\n")
            output.write(
                "GENERATED: "
                + datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S %Z")
                + "\n\n"
            )
            walk_folder(output, SCRIPT_DIR, Path("."))

        print(f"Done! Export written to: {OUTPUT_FILE}")
        return 0
    except OSError as error:
        print(f"Could not write {OUTPUT_FILE}: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
