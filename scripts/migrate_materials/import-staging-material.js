require('dotenv').config({ path: '.env.local' });
const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const csv = require('csv-parser');

const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_KEY || process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY || process.env.SUPABASE_PUBLISHABLE_DEFAULT_KEY;
const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function batchInsertStagingMaterial() {
  const results = [];
  // Columns in staging_material
  const allowedColumns = [
    'beproduct_material_id','header_number','header_name','beproduct_folder_id','folder_name','brand','material_type','fabric_group','fabric_name_cn','status','season_year','composition','back_content','care_instructions','properties_fabric','supplier','supplier_code','material_reference_code','lead_time','material_width','material_full_width','material_weight','unit_of_measure_base','material_purchase_price','currency_lookup','unit_of_measure_purchase_price','costing_price_usd','material_yield','material_moq','material_mcq','surcharge_moq','surcharge_mcq','core_3d_material','main_image_preview','main_image_url','detail_image_preview','detail_image_url','notes','created_by','beproduct_created_at','modified_by','beproduct_modified_at','deleted','raw_beproduct_data','created_at','updated_at'
  ];
  fs.createReadStream('./beproduct_int__material_headers.csv')
    .pipe(csv())
    .on('data', (data) => {
      // Only keep allowed columns and convert empty strings in numeric columns to null
      const numericColumns = [
        'material_width','material_full_width','material_weight','material_purchase_price','costing_price_usd','material_yield','material_moq','material_mcq','surcharge_moq','surcharge_mcq'
      ];
      const filtered = {};
      for (const col of allowedColumns) {
        if (data.hasOwnProperty(col)) {
          if (numericColumns.includes(col) && data[col] === '') {
            filtered[col] = null;
          } else {
            filtered[col] = data[col];
          }
        }
      }
      // Map CSV 'material_id' to staging 'beproduct_material_id'
      if (data.material_id && data.material_id.trim() !== '') {
        filtered.beproduct_material_id = data.material_id;
        results.push(filtered);
      }
    })
    .on('end', async () => {
      const batchSize = 100;
      for (let i = 0; i < results.length; i += batchSize) {
        const batch = results.slice(i, i + batchSize);
        const { error } = await supabase
          .from('staging_material')
          .insert(batch);
        if (error) console.error('Insert error:', error);
      }
      console.log('Staging material import complete!');
    });
}

batchInsertStagingMaterial();
