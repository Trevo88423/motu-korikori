/**
 * Seed Words Script
 *
 * This script reads the motu_vocabulary.csv and aligned_verses.csv files
 * and generates SQL INSERT statements for seeding the words table.
 *
 * Usage: ts-node supabase/seed-words.ts
 */

import * as fs from 'fs';
import * as path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

interface VocabEntry {
  motu_word: string;
  frequency: number;
  example_reference: string;
  english_gloss: string;
  notes: string;
}

interface VerseEntry {
  reference: string;
  motu: string;
  english: string;
}

// Parse CSV file
function parseCSV(filePath: string): any[] {
  const content = fs.readFileSync(filePath, 'utf-8');
  const lines = content.split('\n');
  const headers = lines[0].split(',');

  const result: any[] = [];

  for (let i = 1; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line) continue;

    // Handle CSV with quoted fields
    const values: string[] = [];
    let current = '';
    let inQuotes = false;

    for (let char of line) {
      if (char === '"') {
        inQuotes = !inQuotes;
      } else if (char === ',' && !inQuotes) {
        values.push(current.trim());
        current = '';
      } else {
        current += char;
      }
    }
    values.push(current.trim()); // Push last value

    const obj: any = {};
    headers.forEach((header, index) => {
      obj[header.trim()] = values[index] || '';
    });

    result.push(obj);
  }

  return result;
}

// Escape single quotes for SQL
function escapeSql(str: string): string {
  if (!str) return '';
  return str.replace(/'/g, "''");
}

// Main function
function generateSeedSQL() {
  console.log('Reading CSV files...');

  // Read vocabulary file
  const vocabPath = path.join(__dirname, '../../files/motu_vocabulary.csv');
  const vocabEntries: VocabEntry[] = parseCSV(vocabPath).map(entry => ({
    motu_word: entry.motu_word,
    frequency: parseInt(entry.frequency) || 0,
    example_reference: entry.example_reference,
    english_gloss: entry.english_gloss,
    notes: entry.notes
  }));

  console.log(`Found ${vocabEntries.length} vocabulary entries`);

  // Read verses file
  const versesPath = path.join(__dirname, '../../files/aligned_verses.csv');
  const verses: VerseEntry[] = parseCSV(versesPath).map(entry => ({
    reference: entry.reference,
    motu: entry.motu,
    english: entry.english
  }));

  // Create verse lookup map
  const verseLookup = new Map<string, VerseEntry>();
  verses.forEach(verse => {
    verseLookup.set(verse.reference, verse);
  });

  console.log(`Found ${verses.length} verses for examples`);

  // Generate SQL INSERT statements
  const sqlStatements: string[] = [];

  sqlStatements.push('-- Auto-generated seed file for True Motu Dictionary');
  sqlStatements.push('-- Generated from motu_vocabulary.csv and aligned_verses.csv');
  sqlStatements.push(`-- Total words: ${vocabEntries.length}`);
  sqlStatements.push('-- Generated at: ' + new Date().toISOString());
  sqlStatements.push('');
  sqlStatements.push('BEGIN;');
  sqlStatements.push('');

  let insertCount = 0;
  let batchSize = 100;
  let currentBatch: string[] = [];

  vocabEntries.forEach((entry, index) => {
    const verse = verseLookup.get(entry.example_reference);

    // Build the VALUES part
    const values = [
      `'${escapeSql(entry.motu_word)}'`, // motu_word
      entry.frequency.toString(), // frequency
      entry.example_reference ? `'${escapeSql(entry.example_reference)}'` : 'NULL', // example_reference
      verse?.motu ? `'${escapeSql(verse.motu)}'` : 'NULL', // example_motu
      verse?.english ? `'${escapeSql(verse.english)}'` : 'NULL', // example_english
      'ARRAY[]::TEXT[]', // suggested_translations (empty array)
      "'pending'", // status
    ];

    currentBatch.push(`(${values.join(', ')})`);

    // Insert in batches
    if (currentBatch.length >= batchSize || index === vocabEntries.length - 1) {
      sqlStatements.push(
        `INSERT INTO words (motu_word, frequency, example_reference, example_motu, example_english, suggested_translations, status)`
      );
      sqlStatements.push(`VALUES `);
      sqlStatements.push(currentBatch.join(',\n       ') + ';');
      sqlStatements.push('');

      insertCount += currentBatch.length;
      currentBatch = [];

      if (insertCount % 1000 === 0) {
        console.log(`Generated ${insertCount} INSERT statements...`);
      }
    }
  });

  sqlStatements.push('COMMIT;');
  sqlStatements.push('');
  sqlStatements.push(`-- Successfully seeded ${insertCount} words`);

  // Write to file
  const outputPath = path.join(__dirname, 'seed.sql');
  fs.writeFileSync(outputPath, sqlStatements.join('\n'), 'utf-8');

  console.log('');
  console.log('✓ Seed file generated successfully!');
  console.log(`  Location: ${outputPath}`);
  console.log(`  Total words: ${insertCount}`);
  console.log('');
  console.log('To seed your database:');
  console.log('1. Go to your Supabase dashboard');
  console.log('2. Navigate to SQL Editor');
  console.log('3. Copy and paste the contents of seed.sql');
  console.log('4. Run the query');
}

// Run the script
try {
  generateSeedSQL();
} catch (error) {
  console.error('Error generating seed file:', error);
  process.exit(1);
}
