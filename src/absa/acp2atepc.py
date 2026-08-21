#!/usr/bin/env python3
"""
Convert APC (Aspect Polarity Classification) format to ATEPC format.

APC format (3 lines per sample):
    Line 1: Sentence with $T$ as aspect placeholder
    Line 2: Aspect term
    Line 3: Polarity (1=positive, 0=neutral, -1=negative)

ATEPC format (token per line):
    token1 tag1 polarity1
    token2 tag2 polarity2
    ...
    (blank line between sentences)

Tags: B-ASP (beginning of aspect), I-ASP (inside aspect), O (outside aspect)
Polarity: 1, 0, -1, or -999 (for non-aspect tokens)

Note: If the same sentence appears multiple times in the APC file with different
aspect terms, they are automatically grouped and converted into a single ATEPC
sentence with all aspects labeled. This avoids duplicate sentences in the output.
"""

import re
import argparse
import sys
from pathlib import Path
from typing import List, Tuple, Dict, Optional
from collections import Counter
import json


def tokenize(text: str) -> List[str]:
    """
    Tokenize text while keeping @mentions, hashtags, and punctuation as separate tokens.

    Args:
        text: Input text to tokenize

    Returns:
        List of tokens
    """
    # Split @mentions, #hashtags, URLs, words, and punctuation
    return re.findall(r'@\w+|#\w+|https?://\S+|\w+|[^\w\s]', text)


def convert_apc_to_atepc(sentence: str, aspects: List[Tuple[str, int]]) -> List[Tuple[str, str, str]]:
    """
    Convert a single sentence with multiple aspects to ATEPC format.

    Args:
        sentence: Sentence with $T$ placeholder(s)
        aspects: List of (aspect_term, polarity) tuples

    Returns:
        List of (token, tag, polarity) tuples
    """
    # Get the full sentence by replacing the first $T$ with the first aspect
    # (we assume all $T$ placeholders would be replaced to get the full text)
    if aspects:
        sentence_with_aspect = sentence.replace("$T$", aspects[0][0])
    else:
        sentence_with_aspect = sentence.replace("$T$", "")

    tokens = tokenize(sentence_with_aspect)

    # Initialize all tokens with O tag and -999 polarity
    labels = [(token, "O", "-999") for token in tokens]

    # Track which tokens have been labeled to handle overlapping aspects
    labeled_positions = set()

    # For each aspect, find and label its tokens
    for aspect, polarity in aspects:
        aspect_tokens = tokenize(aspect)
        n = len(aspect_tokens)

        # Find all occurrences of this aspect in the sentence
        i = 0
        while i <= len(tokens) - n:
            # Check if we have a match and these positions aren't already labeled
            if tokens[i:i+n] == aspect_tokens:
                # Check if any position in this range is already labeled
                positions = set(range(i, i+n))
                if not positions.intersection(labeled_positions):
                    # Label the aspect tokens
                    labels[i] = (tokens[i], "B-ASP", str(polarity))
                    for j in range(1, n):
                        labels[i+j] = (tokens[i+j], "I-ASP", str(polarity))
                    # Mark these positions as labeled
                    labeled_positions.update(positions)
                    i += n  # Skip past this aspect
                else:
                    i += 1  # Move forward to find next occurrence
            else:
                i += 1

    return labels


def parse_apc_file(filepath: str, verbose: bool = False) -> Tuple[List[dict], Dict]:
    """
    Parse an APC format file and group by sentence.

    Args:
        filepath: Path to the APC format file
        verbose: If True, print warnings for malformed entries

    Returns:
        Tuple of (data list, statistics dictionary)
        Each data item has: {'sentence': str, 'aspects': [(aspect, polarity), ...]}
    """
    from collections import defaultdict

    # Use defaultdict to group aspects by sentence
    sentence_aspects = defaultdict(list)

    stats = {
        'total_lines': 0,
        'parsed_samples': 0,
        'skipped_samples': 0,
        'polarity_distribution': Counter(),
        'errors': []
    }

    with open(filepath, 'r', encoding='utf-8') as f:
        lines = [line.strip() for line in f.readlines()]

    stats['total_lines'] = len(lines)

    # Process in groups of 3 lines
    i = 0
    sample_num = 0
    while i < len(lines) - 2:
        sample_num += 1
        sentence = lines[i]
        aspect = lines[i + 1]
        polarity_str = lines[i + 2]

        # Validate polarity
        try:
            polarity = int(polarity_str)
            if polarity not in [-1, 0, 1]:
                raise ValueError(f"Polarity must be -1, 0, or 1, got {polarity}")
        except ValueError as e:
            error_msg = f"Sample {sample_num} (line {i + 3}): Invalid polarity '{polarity_str}' - {e}"
            stats['errors'].append(error_msg)
            if verbose:
                print(f"Warning: {error_msg}", file=sys.stderr)
            stats['skipped_samples'] += 1
            i += 3
            continue

        # Validate sentence and aspect
        if not sentence or not aspect:
            error_msg = f"Sample {sample_num} (line {i + 1}): Empty sentence or aspect"
            stats['errors'].append(error_msg)
            if verbose:
                print(f"Warning: {error_msg}", file=sys.stderr)
            stats['skipped_samples'] += 1
            i += 3
            continue

        # Check if $T$ placeholder exists in sentence
        if "$T$" not in sentence:
            error_msg = f"Sample {sample_num} (line {i + 1}): Missing $T$ placeholder in sentence"
            stats['errors'].append(error_msg)
            if verbose:
                print(f"Warning: {error_msg}", file=sys.stderr)
            stats['skipped_samples'] += 1
            i += 3
            continue

        # Group aspects by sentence
        sentence_aspects[sentence].append((aspect, polarity))
        stats['polarity_distribution'][polarity] += 1
        stats['parsed_samples'] += 1

        i += 3

    # Convert grouped data to list format
    data = [
        {'sentence': sentence, 'aspects': aspects}
        for sentence, aspects in sentence_aspects.items()
    ]

    return data, stats


def write_atepc_file(data: List[dict], output_path: str, verbose: bool = False) -> Dict:
    """
    Convert APC data and write to ATEPC format file.

    Args:
        data: List of dictionaries with 'sentence' and 'aspects' keys
              where 'aspects' is a list of (aspect, polarity) tuples
        output_path: Path to write ATEPC format output
        verbose: If True, show progress

    Returns:
        Statistics dictionary
    """
    stats = {
        'total_tokens': 0,
        'aspect_tokens': 0,
        'sentences': 0,
        'unique_sentences': 0
    }

    with open(output_path, 'w', encoding='utf-8') as f:
        for idx, item in enumerate(data, 1):
            if verbose and idx % 100 == 0:
                print(f"Processing sentence {idx}/{len(data)}...", file=sys.stderr)

            atepc_labels = convert_apc_to_atepc(
                item['sentence'],
                item['aspects']
            )

            # Write tokens with their labels
            for token, tag, polarity in atepc_labels:
                f.write(f"{token} {tag} {polarity}\n")
                stats['total_tokens'] += 1
                if tag in ['B-ASP', 'I-ASP']:
                    stats['aspect_tokens'] += 1

            # Blank line between sentences
            f.write("\n")
            stats['unique_sentences'] += 1

    stats['sentences'] = stats['unique_sentences']

    return stats


def process_file(input_path: Path, output_path: Optional[Path] = None,
                verbose: bool = False) -> Tuple[Dict, bool]:
    """
    Process a single APC file and convert it to ATEPC format.

    Args:
        input_path: Path to input file
        output_path: Path to output file (optional)
        verbose: If True, print verbose output

    Returns:
        Tuple of (statistics dict, success bool)
    """
    if output_path is None:
        output_path = input_path.parent / f"{input_path.stem}.atepc.txt"

    try:
        # Parse input file
        apc_data, parse_stats = parse_apc_file(str(input_path), verbose=verbose)

        if not apc_data:
            print(f"Warning: No valid data found in {input_path}", file=sys.stderr)
            return None, False

        # Write output file
        write_stats = write_atepc_file(apc_data, str(output_path), verbose=verbose)

        # Combine statistics
        stats = {
            'input_file': str(input_path),
            'output_file': str(output_path),
            'parsing': {
                'total_lines': parse_stats['total_lines'],
                'parsed_samples': parse_stats['parsed_samples'],
                'skipped_samples': parse_stats['skipped_samples'],
                'polarity_distribution': dict(parse_stats['polarity_distribution']),
                'error_count': len(parse_stats['errors'])
            },
            'output': write_stats
        }

        return stats, True

    except Exception as e:
        print(f"Error processing {input_path}: {e}", file=sys.stderr)
        return None, False


def process_directory(input_dir: Path, output_dir: Optional[Path] = None,
                     pattern: str = "*.txt", verbose: bool = False) -> List[Dict]:
    """
    Process all APC files in a directory.

    Args:
        input_dir: Directory containing APC files
        output_dir: Directory for output files (optional)
        pattern: File pattern to match (default: *.txt)
        verbose: If True, print verbose output

    Returns:
        List of statistics dictionaries for each processed file
    """
    if output_dir is None:
        output_dir = input_dir
    else:
        output_dir.mkdir(parents=True, exist_ok=True)

    input_files = sorted(input_dir.glob(pattern))

    if not input_files:
        print(f"No files matching '{pattern}' found in {input_dir}", file=sys.stderr)
        return []

    print(f"Found {len(input_files)} files to process")

    all_stats = []
    success_count = 0

    for input_file in input_files:
        if verbose:
            print(f"\nProcessing: {input_file.name}")

        output_file = output_dir / f"{input_file.stem}.atepc.txt"
        stats, success = process_file(input_file, output_file, verbose=verbose)

        if success:
            all_stats.append(stats)
            success_count += 1
            if not verbose:
                print(f"✓ {input_file.name} -> {output_file.name}")

    print(f"\nProcessed {success_count}/{len(input_files)} files successfully")

    return all_stats


def fix_atepc_file(
        filepath: str = "os.environ.get('ATEPC_TRAIN', 'data/atepc/politics/train.atepc.txt')",
        verbose: bool = False) -> bool:
    """ Fix common issues in an ATEPC format file.
    Args:
        filepath: Path to the ATEPC format file
        verbose: If True, print verbose output
    Returns:
        True if file was fixed successfully, False otherwise
    """

    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()
            # split into sentences by blank lines
            sentences = []
            current_sentence = []
            for line in lines:
                line = line.strip()
                if line:
                    current_sentence.append(line)
                else:
                    if current_sentence:
                        sentences.append(current_sentence)
                        current_sentence = []
            if current_sentence:
                sentences.append(current_sentence)

        # Group sentences by text
        from collections import defaultdict

        sentence_groups = defaultdict(list)
        for idx, sentence in enumerate(sentences):
            sentence_text = ' '.join([token.split(' ')[0] for token in sentence])
            sentence_groups[sentence_text].append(idx)

        # Merge labels for duplicate sentences
        sentences_to_keep = []
        processed_indices = set()

        for sentence_text, indices in sentence_groups.items():
            if indices[0] in processed_indices:
                continue

            # Mark all indices as processed
            processed_indices.update(indices)

            if len(indices) == 1:
                # No duplicates, keep as is
                sentences_to_keep.append(sentences[indices[0]])
            else:
                # Merge all duplicate sentences
                merged_sentence = merge_duplicate_sentences([sentences[i] for i in indices])
                sentences_to_keep.append(merged_sentence)

                if verbose:
                    print(f"Merged {len(indices)} duplicate sentences: {sentence_text[:50]}...")

        # Write back to file
        with open(filepath, 'w', encoding='utf-8') as f:
            for sentence in sentences_to_keep:
                for token_line in sentence:
                    f.write(f"{token_line}\n")
                f.write("\n")

        if verbose:
            print(f"Fixed {filepath}: {len(sentences)} -> {len(sentences_to_keep)} sentences")

        return True

    except Exception as e:
        if verbose:
            print(f"Error fixing file: {e}", file=sys.stderr)
        return False


def merge_duplicate_sentences(sentence_list: List[List[str]]) -> List[str]:
    """ Merge multiple duplicate sentences by combining their aspect labels.
    Args:
        sentence_list: List of sentences (each sentence is a list of token lines)

    Returns:
        Merged sentence as list of token lines
    """


    if not sentence_list:
        return []

    # Parse all sentences into structured format
    parsed_sentences = []
    for sentence in sentence_list:
        parsed_tokens = []
        for line in sentence:
            parts = line.split(' ')
            if len(parts) == 3:
                token, tag, polarity = parts
                parsed_tokens.append({'token': token, 'tag': tag, 'polarity': polarity})
        parsed_sentences.append(parsed_tokens)

    # Start with the first sentence as base
    merged = parsed_sentences[0].copy()

    # Merge aspect labels from other sentences
    for sentence in parsed_sentences[1:]:
        for i, token_info in enumerate(sentence):
            # If this token is an aspect in current sentence but not in merged
            if token_info['tag'] in ['B-ASP', 'I-ASP'] and merged[i]['tag'] == 'O':
                merged[i]['tag'] = token_info['tag']
                merged[i]['polarity'] = token_info['polarity']

    # Convert back to string format
    result = [f"{t['token']} {t['tag']} {t['polarity']}" for t in merged]
    return result


def main():
    parser = argparse.ArgumentParser(
        description='Convert APC format to ATEPC format',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument(
        'input',
        help='Input file or directory in APC format'
    )
    parser.add_argument(
        '-o', '--output',
        help='Output file or directory path (default: input_file.atepc.txt or same directory)',
        default=None
    )
    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Print verbose output'
    )
    parser.add_argument(
        '-s', '--stats',
        help='Save statistics to JSON file',
        default=None
    )
    parser.add_argument(
        '-p', '--pattern',
        help='File pattern for directory processing (default: *.txt)',
        default='*.txt'
    )
    parser.add_argument(
        '--fix-output',
        action='store_true',
        help='Run fix_atepc_file on each generated ATEPC file'
    )

    args = parser.parse_args()

    # Validate input path
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: Input path '{args.input}' not found", file=sys.stderr)
        sys.exit(1)

    # Determine if we're processing a file or directory
    if input_path.is_file():
        # Single file processing
        output_path = Path(args.output) if args.output else None

        if args.verbose:
            print(f"Reading APC data from: {input_path}")

        stats, success = process_file(input_path, output_path, verbose=args.verbose)

        if not success:
            sys.exit(1)

        if args.fix_output:
            if args.verbose:
                print(f"Fixing ATEPC output: {stats['output_file']}")
            if not fix_atepc_file(stats['output_file'], verbose=args.verbose):
                print(f"Warning: Could not fix {stats['output_file']}", file=sys.stderr)

        # Display statistics
        if args.verbose:
            print(f"\nParsing Statistics:")
            print(f"  Total lines: {stats['parsing']['total_lines']}")
            print(f"  Parsed samples: {stats['parsing']['parsed_samples']}")
            print(f"  Skipped samples: {stats['parsing']['skipped_samples']}")
            print(f"  Polarity distribution:")
            for polarity, count in sorted(stats['parsing']['polarity_distribution'].items()):
                polarity_name = {-1: 'Negative', 0: 'Neutral', 1: 'Positive'}[polarity]
                print(f"    {polarity_name:8s} ({polarity:2d}): {count:5d}")

            print(f"\nConversion complete!")
            print(f"  Sentences processed: {stats['output']['sentences']}")
            print(f"  Total tokens: {stats['output']['total_tokens']}")
            print(f"  Aspect tokens: {stats['output']['aspect_tokens']}")

        # Save statistics if requested
        if args.stats:
            stats_path = Path(args.stats)
            try:
                with open(stats_path, 'w', encoding='utf-8') as f:
                    json.dump(stats, f, indent=2, ensure_ascii=False)
                if args.verbose:
                    print(f"Statistics saved to: {stats_path}")
            except Exception as e:
                print(f"Warning: Could not save statistics: {e}", file=sys.stderr)

        print(f"Successfully converted {stats['parsing']['parsed_samples']} samples to {stats['output_file']}")

    elif input_path.is_dir():
        # Directory processing
        output_dir = Path(args.output) if args.output else None

        if args.verbose:
            print(f"Processing directory: {input_path}")
            if output_dir:
                print(f"Output directory: {output_dir}")

        all_stats = process_directory(input_path, output_dir, pattern=args.pattern,
                                     verbose=args.verbose)

        if not all_stats:
            sys.exit(1)

        if args.fix_output:
            for file_stats in all_stats:
                output_file = file_stats.get('output_file')
                if not output_file:
                    continue
                if args.verbose:
                    print(f"Fixing ATEPC output: {output_file}")
                if not fix_atepc_file(output_file, verbose=args.verbose):
                    print(f"Warning: Could not fix {output_file}", file=sys.stderr)

        # Save combined statistics if requested
        if args.stats:
            stats_path = Path(args.stats)
            try:
                with open(stats_path, 'w', encoding='utf-8') as f:
                    json.dump(all_stats, f, indent=2, ensure_ascii=False)
                if args.verbose:
                    print(f"\nCombined statistics saved to: {stats_path}")
            except Exception as e:
                print(f"Warning: Could not save statistics: {e}", file=sys.stderr)

    else:
        print(f"Error: Input path '{args.input}' is neither a file nor a directory",
              file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
