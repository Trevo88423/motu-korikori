import { createClient } from '@supabase/supabase-js'
import * as dotenv from 'dotenv'
import * as path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

dotenv.config({ path: path.join(__dirname, '../.env.local') })

console.log('Checking database columns...')

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
)

async function main() {
  const { data, error } = await supabase
    .from('words')
    .select('motu_word, ai_morphology, ai_patterns, ai_notes')
    .limit(1)

  if (error) {
    console.log('Error:', error.message)
    if (error.message.includes('ai_morphology') || error.message.includes('column')) {
      console.log('\nColumns need to be added!')
    }
  } else {
    console.log('Columns exist! Sample:', JSON.stringify(data, null, 2))
  }
}

main()
