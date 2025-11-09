-- DDL References for pim schema tables (see Supabase schema)
--
-- Table: pim.style
-- Table: pim.style_colorway
-- Table: pim.style_size_class
-- Table: pim.color_palette
-- Table: pim.color_palette_color
-- Table: pim.color_folder

-- Table: pim.style
CREATE TABLE IF NOT EXISTS pim.style (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    beproduct_style_id uuid UNIQUE,
    beproduct_folder_id uuid,
    folder_name varchar,
    header_number varchar,
    header_name varchar,
    version varchar,
    brand varchar, -- DropDown
    block_number varchar,
    product_type varchar, -- DropDown
    product_category varchar, -- DropDown
    delivery varchar, -- DropDown
    gender varchar, -- DropDown
    season varchar, -- DropDown
    year varchar, -- DropDown
    season_year varchar,
    fabric_group varchar, -- DropDown
    classification varchar, -- DropDown
    status varchar, -- DropDown
    account_manager varchar, -- DropDown
    senior_product_developer varchar, -- DropDown
    supplier_name varchar, -- PartnerDropDown
    bulk_order_qty integer,
    style_code varchar,
    core_size_range text,
    core_main_material text,
    front_image_url text,
    front_image_preview text,
    back_image_url text,
    back_image_preview text,
    side_image_url text,
    side_image_preview text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    created_by varchar,
    modified_by varchar,
    beproduct_created_at timestamptz,
    beproduct_modified_at timestamptz,
    is_deleted boolean DEFAULT false,
    raw_beproduct_data jsonb,
    deleted boolean DEFAULT false
);

-- Table: pim.style_colorway
CREATE TABLE IF NOT EXISTS pim.style_colorway (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    beproduct_colorway_id uuid,
    style_id uuid REFERENCES pim.style(id),
    color_number varchar,
    color_name varchar,
    primary_hex varchar,
    secondary_hex varchar,
    secondary_color_number varchar,
    secondary_color_name varchar,
    pantone varchar,
    brand_marketing_name varchar,
    color_reference varchar,
    color_number_ls varchar,
    hide_colorway boolean DEFAULT false,
    image_header_id uuid,
    color_source_id uuid,
    comments text,
    created_at timestamptz DEFAULT now(),
    raw_beproduct_data jsonb,
    bulk_order_qty integer,
    core_colorway_main_material text,
    marketing_name text,
    deleted boolean DEFAULT false
);

-- Table: pim.style_size_class
CREATE TABLE IF NOT EXISTS pim.style_size_class (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    beproduct_size_class_id uuid,
    style_id uuid REFERENCES pim.style(id),
    size_class_name varchar,
    is_default boolean DEFAULT false,
    sizes jsonb,
    created_at timestamptz DEFAULT now(),
    raw_beproduct_data jsonb,
    size_class_fields jsonb,
    deleted boolean DEFAULT false
);

-- Table: pim.color_folder
CREATE TABLE IF NOT EXISTS pim.color_folder (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    beproduct_folder_id uuid UNIQUE,
    name varchar,
    description text,
    active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Table: pim.color_palette
CREATE TABLE IF NOT EXISTS pim.color_palette (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    beproduct_palette_id uuid UNIQUE,
    folder_id uuid REFERENCES pim.color_folder(id),
    palette_number varchar,
    palette_name varchar,
    season varchar,
    year varchar,
    brand varchar,
    version varchar,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    created_by varchar,
    modified_by varchar,
    beproduct_created_at timestamptz,
    beproduct_modified_at timestamptz
);

-- Table: pim.color_palette_color
CREATE TABLE IF NOT EXISTS pim.color_palette_color (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    beproduct_color_id uuid,
    palette_id uuid REFERENCES pim.color_palette(id),
    color_number varchar,
    color_name varchar,
    hex varchar,
    rgb_r integer,
    rgb_g integer,
    rgb_b integer,
    pantone varchar,
    brand_marketing_name varchar,
    color_number_ls varchar,
    color_reference varchar,
    sort_order integer DEFAULT 0,
    created_at timestamptz DEFAULT now()
);

-- Triggers and functions for updated_at, etc. can be added below as needed.
