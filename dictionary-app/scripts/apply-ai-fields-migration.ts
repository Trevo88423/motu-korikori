import pg from 'pg'
import * as dotenv from 'dotenv'
import * as path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

dotenv.config({ path: path.join(__dirname, '../.env.local') })

const { Client } = pg

async function main() {
  console.log('Applying AI fields migration...')

  const client = new Client({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false }
  })

  try {
    await client.connect()
    console.log('Connected to database')

    const sql = `
      ALTER TABLE words
      ADD COLUMN IF NOT EXISTS ai_morphology TEXT,
      ADD COLUMN IF NOT EXISTS ai_patterns TEXT,
      ADD COLUMN IF NOT EXISTS ai_notes TEXT;
    `

    await client.query(sql)
    console.log('Migration applied successfully!')

    // Verify
    const result = await client.query(
      "SELECT column_name FROM information_schema.columns WHERE table_name = 'words' AND column_name LIKE 'ai_%'"
    )
    console.log('New columns:', result.rows.map(r => r.column_name))

  } catch (error) {
    console.error('Error:', error)
  } finally {
    await client.end()
  }
}

main()
