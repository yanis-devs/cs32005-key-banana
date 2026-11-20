from pathlib import Path

def count_dart_lines():
    total_lines = 0
    # Gets the directory where this script is located
    current_dir = Path(__file__).parent
    
    # Find all .dart files recursively in subfolders
    dart_files = list(current_dir.rglob('*.dart'))
    
    if not dart_files:
        print("No .dart files found in this directory or its subfolders.")
        return

    print(f"Found {len(dart_files)} Dart file(s). Counting lines...\n")
    
    for file_path in dart_files:
        try:
            # Open and count lines safely (ignoring potential encoding issues)
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                lines = sum(1 for _ in f)
                total_lines += lines
                # Print relative path for cleaner output
                print(f"  - {file_path.relative_to(current_dir)}: {lines} lines")
        except Exception as e:
            print(f"  - Could not read {file_path.name}: {e}")
            
    print(f"\n========================================")
    print(f"Total lines of Dart code found: {total_lines}")
    print(f"========================================")

if __name__ == '__main__':
    count_dart_lines()