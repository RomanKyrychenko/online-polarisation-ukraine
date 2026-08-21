#!/usr/bin/env python3
"""
Generate APC (Aspect Polarity Classification) dataset using OpenAI API.

This script reads text files (one text per line) and uses OpenAI API to extract
aspects and their sentiment polarities, generating APC format training data.

APC Format Output (3 lines per sample):
    Line 1: Sentence with $T$ as aspect placeholder
    Line 2: Aspect term
    Line 3: Polarity (1=positive, 0=neutral, -1=negative)
"""

import argparse
import json
import sys
from pathlib import Path
from typing import List, Dict, Optional, Literal
import time
from collections import Counter
import os
from openai import OpenAI
from pydantic import BaseModel, Field
from dotenv import load_dotenv

load_dotenv()

# Pydantic models for structured output
class AspectSentiment(BaseModel):
    """Single aspect with its sentiment polarity."""
    aspect: str = Field(description="The exact text span of the aspect as it appears in the original text")
    polarity: Literal[-1, 0, 1] = Field(description="Sentiment polarity: 1 for positive, 0 for neutral, -1 for negative")


class AspectExtractionResponse(BaseModel):
    """Response containing all extracted aspects."""
    aspects: List[AspectSentiment] = Field(description="List of political aspects found in the text with their sentiment polarities")


# System prompt for aspect extraction
SYSTEM_PROMPT = """You are an expert in aspect-based sentiment analysis for political discourse.
Your task is to extract political aspects (politicians, parties, policies, events, etc.) from text 
and determine the sentiment polarity for each aspect.

For each text, identify:
1. All relevant political aspects (people, parties, organizations, policies, events)
2. The sentiment expressed toward each aspect (positive=1, neutral=0, or negative=-1)

Guidelines:
- Extract specific entities and topics, not general words
- Consider context for sentiment (irony, sarcasm should be reflected)
- If multiple aspects have same sentiment, extract all of them
- Aspect must appear exactly as it is in the original text
- Return empty list if no political aspects found
"""


class APCGenerator:
    """Generate APC dataset using OpenAI API."""

    def __init__(self, api_key: Optional[str] = None, model: str = "gpt-4o-mini",
                 temperature: float = 0.3, max_retries: int = 3):
        """
        Initialize APC generator.

        Args:
            api_key: OpenAI API key (or use OPENAI_API_KEY env var)
            model: OpenAI model to use
            temperature: Sampling temperature (lower = more deterministic)
            max_retries: Maximum retry attempts for API calls
        """
        self.api_key = api_key or os.getenv("OPENAI_API_KEY")
        if not self.api_key:
            raise ValueError("OpenAI API key required. Set OPENAI_API_KEY env var or pass api_key parameter.")

        self.client = OpenAI(api_key=self.api_key)
        self.model = model
        self.temperature = temperature
        self.max_retries = max_retries

        self.stats = {
            'total_texts': 0,
            'successful_extractions': 0,
            'failed_extractions': 0,
            'total_aspects': 0,
            'polarity_distribution': Counter(),
            'api_calls': 0,
            'errors': []
        }

    def extract_aspects(self, text: str, retry_count: int = 0) -> Optional[List[Dict]]:
        """
        Extract aspects and polarities from text using OpenAI API with structured outputs.

        Args:
            text: Input text
            retry_count: Current retry attempt

        Returns:
            List of aspect dictionaries or None on failure
        """
        try:
            self.stats['api_calls'] += 1

            # Use structured outputs with parse method
            completion = self.client.beta.chat.completions.parse(
                model=self.model,
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": text}
                ],
                temperature=self.temperature,
                response_format=AspectExtractionResponse
            )

            # Extract parsed response
            response = completion.choices[0].message.parsed

            if not response or not response.aspects:
                return None

            # Validate that aspects exist in text
            valid_aspects = []
            for aspect_obj in response.aspects:
                if aspect_obj.aspect in text:
                    valid_aspects.append({
                        'aspect': aspect_obj.aspect,
                        'polarity': aspect_obj.polarity
                    })

            return valid_aspects if valid_aspects else None

        except Exception as e:
            error_msg = f"API error: {e}"
            if retry_count < self.max_retries:
                time.sleep(2 * (retry_count + 1))  # Exponential backoff
                return self.extract_aspects(text, retry_count + 1)
            self.stats['errors'].append(error_msg)
            return None

    def text_to_apc(self, text: str) -> List[tuple]:
        """
        Convert text to APC format entries.

        Args:
            text: Input text

        Returns:
            List of (sentence, aspect, polarity) tuples
        """
        aspects = self.extract_aspects(text)

        if not aspects:
            return []

        apc_entries = []
        for aspect_data in aspects:
            aspect = aspect_data['aspect']
            polarity = aspect_data['polarity']

            # Replace aspect with $T$ placeholder
            sentence_with_placeholder = text.replace(aspect, "$T$", 1)

            apc_entries.append((sentence_with_placeholder, aspect, polarity))
            self.stats['polarity_distribution'][polarity] += 1

        return apc_entries

    def process_file(self, input_path: str, output_path: str,
                    max_texts: Optional[int] = None,
                    skip_lines: int = 0,
                    verbose: bool = False) -> Dict:
        """
        Process input file and generate APC dataset.

        Args:
            input_path: Path to input text file (one text per line)
            output_path: Path to output APC file
            max_texts: Maximum number of texts to process (None = all)
            skip_lines: Number of lines to skip at start
            verbose: If True, print progress

        Returns:
            Statistics dictionary
        """
        # Read input texts
        with open(input_path, 'r', encoding='utf-8') as f:
            texts = [line.strip() for line in f.readlines()]

        # Remove empty lines and apply skip
        texts = [t for t in texts[skip_lines:] if t]

        if max_texts:
            texts = texts[:max_texts]

        self.stats['total_texts'] = len(texts)

        if verbose:
            print(f"Processing {len(texts)} texts from {input_path}")
            print(f"Output: {output_path}")
            print(f"Model: {self.model}")
            print()

        # Process texts and write output iteratively
        with open(output_path, 'w', encoding='utf-8') as out_f:
            for idx, text in enumerate(texts, 1):
                if verbose and idx % 10 == 0:
                    print(f"Processing {idx}/{len(texts)}... "
                          f"(Aspects: {self.stats['total_aspects']}, "
                          f"API calls: {self.stats['api_calls']})",
                          end='\r', file=sys.stderr)

                apc_entries = self.text_to_apc(text)

                if apc_entries:
                    self.stats['successful_extractions'] += 1
                    for sentence, aspect, polarity in apc_entries:
                        # Write APC format (3 lines per entry) immediately
                        out_f.write(f"{sentence}\n")
                        out_f.write(f"{aspect}\n")
                        out_f.write(f"{polarity}\n")
                        self.stats['total_aspects'] += 1

                    # Flush to disk after each text to ensure data is written
                    out_f.flush()
                else:
                    self.stats['failed_extractions'] += 1

                # Rate limiting (avoid hitting API rate limits)
                if idx % 50 == 0:
                    time.sleep(1)

        if verbose:
            print()  # New line after progress

        return self.stats

    def print_stats(self):
        """Print processing statistics."""
        print("\n" + "="*70)
        print("Processing Statistics")
        print("="*70)
        print(f"Total texts processed:      {self.stats['total_texts']}")
        print(f"Successful extractions:     {self.stats['successful_extractions']}")
        print(f"Failed extractions:         {self.stats['failed_extractions']}")
        print(f"Total aspects extracted:    {self.stats['total_aspects']}")
        print(f"Total API calls:            {self.stats['api_calls']}")
        print()
        print("Polarity Distribution:")
        for polarity in [-1, 0, 1]:
            count = self.stats['polarity_distribution'][polarity]
            name = {-1: 'Negative', 0: 'Neutral', 1: 'Positive'}[polarity]
            percentage = (count / self.stats['total_aspects'] * 100) if self.stats['total_aspects'] > 0 else 0
            print(f"  {name:8s} ({polarity:2d}): {count:5d} ({percentage:5.1f}%)")

        if self.stats['errors']:
            print(f"\nErrors encountered: {len(self.stats['errors'])}")
            if len(self.stats['errors']) <= 5:
                for error in self.stats['errors']:
                    print(f"  - {error}")
            else:
                print(f"  (Showing first 5 of {len(self.stats['errors'])})")
                for error in self.stats['errors'][:5]:
                    print(f"  - {error}")
        print("="*70)


def main():
    parser = argparse.ArgumentParser(
        description='Generate APC dataset using OpenAI API',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument(
        'input',
        help='Input text file (one text per line)'
    )
    parser.add_argument(
        '-o', '--output',
        help='Output APC file path (default: input_file.apc.txt)',
        default=None
    )
    parser.add_argument(
        '-k', '--api-key',
        help='OpenAI API key (or set OPENAI_API_KEY env var)',
        default=None
    )
    parser.add_argument(
        '-m', '--model',
        help='OpenAI model to use (default: gpt-4o-mini)',
        default='gpt-5.1'
    )
    parser.add_argument(
        '-t', '--temperature',
        help='Sampling temperature (default: 0.3)',
        type=float,
        default=0.3
    )
    parser.add_argument(
        '-n', '--max-texts',
        help='Maximum number of texts to process',
        type=int,
        default=None
    )
    parser.add_argument(
        '--skip-lines',
        help='Number of lines to skip at start of file',
        type=int,
        default=0
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

    args = parser.parse_args()

    # Validate input file
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: Input file '{args.input}' not found", file=sys.stderr)
        sys.exit(1)

    # Determine output path
    if args.output:
        output_path = Path(args.output)
    else:
        output_path = input_path.parent / f"{input_path.stem}.apc.txt"

    # Create output directory if needed
    output_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        # Initialize generator
        generator = APCGenerator(
            api_key=args.api_key,
            model=args.model,
            temperature=args.temperature
        )

        # Process file
        stats = generator.process_file(
            str(input_path),
            str(output_path),
            max_texts=args.max_texts,
            skip_lines=args.skip_lines,
            verbose=args.verbose
        )

        # Print statistics
        if args.verbose:
            generator.print_stats()

        # Save statistics if requested
        if args.stats:
            stats_path = Path(args.stats)
            stats_data = {
                'input_file': str(input_path),
                'output_file': str(output_path),
                'model': args.model,
                'temperature': args.temperature,
                'statistics': {
                    'total_texts': stats['total_texts'],
                    'successful_extractions': stats['successful_extractions'],
                    'failed_extractions': stats['failed_extractions'],
                    'total_aspects': stats['total_aspects'],
                    'api_calls': stats['api_calls'],
                    'polarity_distribution': dict(stats['polarity_distribution']),
                    'error_count': len(stats['errors'])
                }
            }

            with open(stats_path, 'w', encoding='utf-8') as f:
                json.dump(stats_data, f, indent=2, ensure_ascii=False)

            if args.verbose:
                print(f"\nStatistics saved to: {stats_path}")

        print(f"\nSuccessfully generated APC dataset: {output_path}")
        print(f"  Texts processed: {stats['total_texts']}")
        print(f"  Aspects extracted: {stats['total_aspects']}")

    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n\nInterrupted by user", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

