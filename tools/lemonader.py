import os

def scan_folder():
    output_file = "lemonade.txt"
    
    with open(output_file, "w", encoding="utf-8") as f:
        for root, dirs, files in os.walk("."):
            f.write(f"Directory: {root}\n")
            for file in files:
                # Optionally skip the output file itself
                if file == output_file:
                    continue
                f.write(f"  - {file}\n")
            f.write("\n")
            
    print(f"Scan complete! Saved to {output_file}")

if __name__ == "__main__":
    scan_folder()