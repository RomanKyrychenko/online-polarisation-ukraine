#!/usr/bin/env python3
"""
Entity Extractor for Ukrainian Twitter Data

This script efficiently finds entities in a PostgreSQL table containing Twitter data.
It handles different variations (inflections, declensions) of entity names while
avoiding false positives and confusion with similar terms.

The extracted entities can be used for Aspect Polarity Classification (APC) processing.
"""

import psycopg2
from psycopg2.extras import RealDictCursor
import yaml
import re
from typing import Dict, List, Optional
from collections import defaultdict
import argparse


class EntityExtractor:
    """Extract and normalize entities from Twitter data in PostgreSQL."""

    def __init__(self, entities_file: str, db_config: Optional[Dict] = None):
        """
        Initialize the entity extractor.

        Args:
            entities_file: Path to YAML file containing entity variations
            db_config: Database configuration dict with keys: host, port, dbname, user, password
        """
        self.entities_file = entities_file
        self.entities = self._load_entities()
        self.db_config = db_config or {
            'host': 'localhost',
            'port': '5432',
            'dbname': 'twitter'
        }
        self.conn = None

    def _load_entities(self) -> Dict[str, List[str]]:
        """Load entities from YAML file and parse variations."""
        with open(self.entities_file, 'r', encoding='utf-8') as f:
            raw_entities = yaml.safe_load(f)

        entities = {}
        for entity_name, variations_str in raw_entities.items():
            if isinstance(variations_str, str):
                # Split by comma and strip whitespace
                variations = [v.strip() for v in variations_str.split(',') if v.strip()]
                entities[entity_name] = variations
            elif isinstance(variations_str, list):
                entities[entity_name] = variations_str
            else:
                entities[entity_name] = [str(variations_str)]

        return entities

    def _build_entity_regex_pattern(self, variations: List[str]) -> str:
        """
        Build a PostgreSQL-compatible regex pattern for entity variations.
        Uses word boundaries to avoid partial matches.

        Args:
            variations: List of entity variations

        Returns:
            PostgreSQL regex pattern
        """
        # Escape special regex characters
        escaped_variations = [re.escape(v) for v in variations]
        # Join with OR and add word boundaries
        pattern = r'\y(' + '|'.join(escaped_variations) + r')\y'
        return pattern

    def _build_sql_entity_pattern(self, variations: List[str], case_sensitive: bool = False) -> str:
        """
        Build SQL pattern for efficient entity matching.

        Args:
            variations: List of entity variations
            case_sensitive: Whether to use case-sensitive matching

        Returns:
            SQL pattern string
        """
        # Escape special regex characters for PostgreSQL
        escaped_variations = []
        for v in variations:
            # Escape special characters
            escaped = v.replace('\\', '\\\\').replace('(', r'\(').replace(')', r'\)')
            escaped = escaped.replace('[', r'\[').replace(']', r'\]')
            escaped = escaped.replace('{', r'\{').replace('}', r'\}')
            escaped = escaped.replace('.', r'\.')
            escaped = escaped.replace('+', r'\+').replace('*', r'\*')
            escaped = escaped.replace('?', r'\?').replace('^', r'\^')
            escaped = escaped.replace('$', r'\$').replace('|', r'\|')
            escaped_variations.append(escaped)

        # Use \m and \M for word boundaries (more reliable than \y in some PostgreSQL versions)
        pattern = r'\m(' + '|'.join(escaped_variations) + r')\M'
        return pattern

    def connect_db(self):
        """Establish database connection."""
        if self.conn is None or self.conn.closed:
            self.conn = psycopg2.connect(**self.db_config)

    def close_db(self):
        """Close database connection."""
        if self.conn and not self.conn.closed:
            self.conn.close()

    def find_tweets_with_entity(
        self,
        entity_name: str,
        table_name: str = 'tweets',
        text_column: str = 'text',
        limit: Optional[int] = None,
        additional_where: Optional[str] = None
    ) -> List[Dict]:
        """
        Find all tweets containing a specific entity.

        Args:
            entity_name: Name of the entity (key in entities.yaml)
            table_name: Name of the database table
            text_column: Name of the column containing tweet text
            limit: Optional limit on number of results
            additional_where: Optional additional WHERE clause conditions

        Returns:
            List of matching rows as dictionaries
        """
        if entity_name not in self.entities:
            raise ValueError(f"Entity '{entity_name}' not found in entities file")

        self.connect_db()

        variations = self.entities[entity_name]
        pattern = self._build_sql_entity_pattern(variations)

        # Build query
        query = f"""
            SELECT *
            FROM {table_name}
            WHERE {text_column} ~* %s
        """

        if additional_where:
            query += f" AND {additional_where}"

        if limit:
            query += f" LIMIT {limit}"

        with self.conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(query, (pattern,))
            results = cur.fetchall()

        return [dict(row) for row in results]

    def find_tweets_with_any_entity(
        self,
        table_name: str = 'tweets',
        text_column: str = 'text',
        limit: Optional[int] = None,
        additional_where: Optional[str] = None
    ) -> List[Dict]:
        """
        Find all tweets containing any of the defined entities.

        Args:
            table_name: Name of the database table
            text_column: Name of the column containing tweet text
            limit: Optional limit on number of results
            additional_where: Optional additional WHERE clause conditions

        Returns:
            List of matching rows with an additional 'matched_entities' field
        """
        self.connect_db()

        # Build combined pattern for all entities
        all_variations = []
        for variations in self.entities.values():
            all_variations.extend(variations)

        pattern = self._build_sql_entity_pattern(all_variations)

        # Build query
        query = f"""
            SELECT *
            FROM {table_name}
            WHERE {text_column} ~* %s
        """

        if additional_where:
            query += f" AND {additional_where}"

        if limit:
            query += f" LIMIT {limit}"

        with self.conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(query, (pattern,))
            results = cur.fetchall()

        # Add matched entities information
        enriched_results = []
        for row in results:
            row_dict = dict(row)
            row_dict['matched_entities'] = self.extract_entities_from_text(row_dict[text_column])
            enriched_results.append(row_dict)

        return enriched_results

    def extract_entities_from_text(self, text: str) -> Dict[str, List[str]]:
        """
        Extract all entity mentions from a text.

        Args:
            text: Text to analyze

        Returns:
            Dictionary mapping entity names to list of matched variations
        """
        matched_entities = defaultdict(list)

        for entity_name, variations in self.entities.items():
            for variation in variations:
                # Use word boundary matching
                pattern = r'\b' + re.escape(variation) + r'\b'
                if re.search(pattern, text, re.IGNORECASE):
                    matched_entities[entity_name].append(variation)

        return dict(matched_entities)

    def normalize_entities_in_text(self, text: str, use_canonical: bool = True) -> str:
        """
        Replace all entity variations with normalized forms.

        Args:
            text: Text to normalize
            use_canonical: If True, use the entity name; if False, use first variation

        Returns:
            Normalized text
        """
        normalized_text = text

        # Sort entities by variation length (longest first) to avoid partial replacements
        all_replacements = []
        for entity_name, variations in self.entities.items():
            for variation in variations:
                canonical = entity_name if use_canonical else variations[0]
                all_replacements.append((variation, canonical))

        # Sort by length descending
        all_replacements.sort(key=lambda x: len(x[0]), reverse=True)

        # Perform replacements
        for variation, canonical in all_replacements:
            pattern = r'\b' + re.escape(variation) + r'\b'
            normalized_text = re.sub(pattern, canonical, normalized_text, flags=re.IGNORECASE)

        return normalized_text

    def create_entity_index(self, table_name: str, text_column: str):
        """
        Create a GIN index on the text column for faster regex searches.

        Args:
            table_name: Name of the database table
            text_column: Name of the column containing tweet text
        """
        self.connect_db()

        index_name = f"idx_{table_name}_{text_column}_gin"

        # Create GIN index with pg_trgm for faster pattern matching
        query = f"""
            CREATE INDEX IF NOT EXISTS {index_name}
            ON {table_name} USING gin ({text_column} gin_trgm_ops);
        """

        with self.conn.cursor() as cur:
            # First, ensure pg_trgm extension is enabled
            cur.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm;")
            cur.execute(query)
            self.conn.commit()

        print(f"Created index {index_name} on {table_name}.{text_column}")

    def get_entity_statistics(
        self,
        table_name: str = 'tweets',
        text_column: str = 'text',
        additional_where: Optional[str] = None
    ) -> Dict[str, int]:
        """
        Get count of tweets mentioning each entity.

        Args:
            table_name: Name of the database table
            text_column: Name of the column containing tweet text
            additional_where: Optional additional WHERE clause conditions

        Returns:
            Dictionary mapping entity names to tweet counts
        """
        self.connect_db()

        stats = {}
        for entity_name, variations in self.entities.items():
            pattern = self._build_sql_entity_pattern(variations)

            query = f"""
                SELECT COUNT(*) as count
                FROM {table_name}
                WHERE {text_column} ~* %s
            """

            if additional_where:
                query += f" AND {additional_where}"

            with self.conn.cursor() as cur:
                cur.execute(query, (pattern,))
                count = cur.fetchone()[0]
                stats[entity_name] = count

        return stats

    def export_for_apc(
        self,
        output_file: str,
        table_name: str = 'tweets',
        text_column: str = 'text',
        entity_filter: Optional[List[str]] = None,
        normalize: bool = True,
        limit: Optional[int] = None
    ):
        """
        Export tweets with entities for APC (Aspect Polarity Classification) processing.

        Args:
            output_file: Path to output file
            table_name: Name of the database table
            text_column: Name of the column containing tweet text
            entity_filter: Optional list of entity names to include
            normalize: Whether to normalize entity variations
            limit: Optional limit on number of tweets
        """
        tweets = self.find_tweets_with_any_entity(
            table_name=table_name,
            text_column=text_column,
            limit=limit
        )

        with open(output_file, 'w', encoding='utf-8') as f:
            for tweet in tweets:
                text = tweet[text_column]
                entities = tweet['matched_entities']

                # Filter entities if specified
                if entity_filter:
                    entities = {k: v for k, v in entities.items() if k in entity_filter}

                # Skip if no entities after filtering
                if not entities:
                    continue

                # Normalize if requested
                if normalize:
                    text = self.normalize_entities_in_text(text)

                # Write tweet with metadata
                f.write(f"{text}\n")
                f.write(f"# Entities: {', '.join(entities.keys())}\n\n")

        print(f"Exported {len(tweets)} tweets to {output_file}")


def main():
    """Command-line interface for entity extraction."""
    parser = argparse.ArgumentParser(
        description='Extract entities from Ukrainian Twitter data in PostgreSQL'
    )
    parser.add_argument(
        '--entities-file',
        default='entities.yaml',
        help='Path to entities YAML file'
    )
    parser.add_argument(
        '--db-host',
        default='localhost',
        help='Database host'
    )
    parser.add_argument(
        '--db-port',
        default='5432',
        help='Database port'
    )
    parser.add_argument(
        '--db-name',
        default='twitter',
        help='Database name'
    )
    parser.add_argument(
        '--db-user',
        help='Database user'
    )
    parser.add_argument(
        '--db-password',
        help='Database password'
    )
    parser.add_argument(
        '--table',
        default='tweets',
        help='Table name'
    )
    parser.add_argument(
        '--text-column',
        default='text',
        help='Text column name'
    )
    parser.add_argument(
        '--entity',
        help='Specific entity to search for'
    )
    parser.add_argument(
        '--stats',
        action='store_true',
        help='Show entity statistics'
    )
    parser.add_argument(
        '--create-index',
        action='store_true',
        help='Create GIN index for faster searches'
    )
    parser.add_argument(
        '--export',
        help='Export tweets to file for APC processing'
    )
    parser.add_argument(
        '--limit',
        type=int,
        help='Limit number of results'
    )

    args = parser.parse_args()

    # Build database config
    db_config = {
        'host': args.db_host,
        'port': args.db_port,
        'dbname': args.db_name
    }
    if args.db_user:
        db_config['user'] = args.db_user
    if args.db_password:
        db_config['password'] = args.db_password

    # Initialize extractor
    extractor = EntityExtractor(args.entities_file, db_config)

    try:
        if args.create_index:
            extractor.create_entity_index(args.table, args.text_column)

        if args.stats:
            stats = extractor.get_entity_statistics(args.table, args.text_column)
            print("\nEntity Statistics:")
            print("-" * 50)
            for entity, count in sorted(stats.items(), key=lambda x: x[1], reverse=True):
                print(f"{entity:30s}: {count:6d} tweets")

        if args.entity:
            results = extractor.find_tweets_with_entity(
                args.entity,
                args.table,
                args.text_column,
                args.limit
            )
            print(f"\nFound {len(results)} tweets mentioning '{args.entity}'")
            for i, tweet in enumerate(results[:5], 1):
                print(f"\n{i}. {tweet.get(args.text_column, '')[:200]}...")

        if args.export:
            extractor.export_for_apc(
                args.export,
                args.table,
                args.text_column,
                limit=args.limit
            )

    finally:
        extractor.close_db()


if __name__ == '__main__':
    main()

