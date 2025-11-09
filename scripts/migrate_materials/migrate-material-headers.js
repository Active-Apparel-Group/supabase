require('dotenv').config({ path: '.env.local' });
const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const csv = require('csv-parser');

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_PROJECT_URL;
const SUPABASE_KEY = process.env.SUPABASE_KEY || process.env.NEXT_PUBLIC_SUPABASE_KEY || process.env.SUPABASE_PUBLISHABLE_KEY || process.env.SUPABASE_PUBLISHABLE_DEFAULT_KEY || process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY;
if (!SUPABASE_URL || !SUPABASE_KEY) {
  console.error('Missing Supabase URL or Key in environment variables.');
  console.error('Checked SUPABASE_URL, NEXT_PUBLIC_SUPABASE_URL, SUPABASE_PROJECT_URL and SUPABASE_KEY, NEXT_PUBLIC_SUPABASE_KEY, SUPABASE_PUBLISHABLE_KEY.');
  process.exit(1);
}
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function migrateMaterialHeaders() {
  const results = [];
  fs.createReadStream('./beproduct_int__material_headers.csv')
    .pipe(csv())
    .on('data', (data) => results.push(data))
    .on('end', async () => {
      const batchSize = 100;
      for (let i = 0; i < results.length; i += batchSize) {
        const batch = results.slice(i, i + batchSize);
        const { error } = await supabase
          .from('pim.material')
          .upsert(batch, { onConflict: 'material_id' });
        if (error) console.error('Upsert error:', error);
      }
      console.log('Material headers migration complete!');
    });
}

migrateMaterialHeaders();
