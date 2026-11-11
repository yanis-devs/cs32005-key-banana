from collections import Counter
import string


def analyze_letter_frequencies(filename='words.txt'):
  letter_counts = Counter()
  total_letters = 0

  print(f"Reading '{filename}'...")

  try:
    with open(filename, 'r', encoding='utf-8') as f:
      for line in f:
        # Strip whitespace and convert to lowercase for uniform counting
        word = line.strip().lower()
        for char in word:
          if char in string.ascii_lowercase:
            letter_counts[char] += 1
            total_letters += 1
  except FileNotFoundError:
    print(f"Error: Could not find '{filename}' in the current directory.")
    print("Make sure 'words.txt' is in the exact same folder as this script.")
    return

  if total_letters == 0:
    print('The word list is empty or contains no valid alphabetical letters.')
    return

  # Print summary table header
  print(f'\nSuccessfully analyzed {total_letters:,} total letters.')
  print('Letter Frequency Ranking (Most to Least):')
  print('-' * 42)
  print(f"{'Rank':<6} {'Letter':<8} {'Count':<12} {'Percentage':<10}")
  print('-' * 42)

  # Sort letters by count in descending order
  sorted_letters = letter_counts.most_common()

  for rank, (letter, count) in enumerate(sorted_letters, start=1):
    percentage = (count / total_letters) * 100
    print(f'{rank:<6} {letter.upper():<8} {count:<12} {percentage:.2f}%')

  print('-' * 42)


if __name__ == '__main__':
  analyze_letter_frequencies()