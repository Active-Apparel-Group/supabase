require('dotenv').config({ path: '.env.local' });
const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const csv = require('csv-parser');

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_KEY || process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY || process.env.SUPABASE_PUBLISHABLE_DEFAULT_KEY;
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function batchInsertColorwayStaging() {
  const results = [];
  const allowedColumns = [
    'beproduct_material_id','header_number','colorway_id','name','code','hex'
  ];
  fs.createReadStream('./material_colorway.csv')
    .pipe(csv())
    .on('data', (data) => {
      const filtered = {};
      for (const col of allowedColumns) {
        filtered[col] = data[col] || null;
      }
      results.push(filtered);
    })
    .on('end', async () => {
      const batchSize = 100;
      for (let i = 0; i < results.length; i += batchSize) {
        const batch = results.slice(i, i + batchSize);
        const { error } = await supabase
          .from('pim.material_colorway_staging')
          .insert(batch);
        if (error) console.error('Insert error:', error);
      }
      console.log('Colorway staging import complete!');
    });
}

batchInsertColorwayStaging();
