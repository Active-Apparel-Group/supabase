...existing code...
# PIM Schema Documentation

This document describes the `pim` schema tables for the Supabase fashion/PLM data model. It includes table/column descriptions, relationships, and business notes. Columns marked as `-- DropDown` or similar are placeholders for future enum/configuration.

---

## Table: pim.style
| Column                     | Type      | Description / Business Note                                   |
|----------------------------|-----------|--------------------------------------------------------------|
| id                         | uuid      | Primary key.                                                 |
| beproduct_style_id         | uuid      | Unique style ID from BeProduct.                              |
| beproduct_folder_id        | uuid      | Folder ID from BeProduct.                                    |
| folder_name                | varchar   | Name of the folder in BeProduct.                             |
| header_number              | varchar   | Style number/header.                                         |
| header_name                | varchar   | Style name/header.                                           |
| version                    | varchar   | Version of the style.                                        |
| brand                      | varchar   | Brand. -- DropDown                                           |
| block_number               | varchar   | Block number.                                                |
| product_type               | varchar   | Product type. -- DropDown                                    |
| product_category           | varchar   | Product category. -- DropDown                                |
| delivery                   | varchar   | Delivery window. -- DropDown                                 |
| gender                     | varchar   | Gender. -- DropDown                                          |
| season                     | varchar   | Season. -- DropDown                                          |
| year                       | varchar   | Year. -- DropDown                                            |
| season_year                | varchar   | Season and year.                                             |
| fabric_group               | varchar   | Fabric group. -- DropDown                                    |
| classification             | varchar   | Classification. -- DropDown                                  |
| status                     | varchar   | Status. -- DropDown                                          |
| account_manager            | varchar   | Account manager. -- DropDown                                 |
| senior_product_developer   | varchar   | Senior product developer. -- DropDown                        |
| supplier_name              | varchar   | Supplier name. -- PartnerDropDown                            |
| bulk_order_qty             | integer   | Bulk order quantity.                                         |
| style_code                 | varchar   | Style code.                                                  |
| core_size_range            | text      | Core size range.                                             |
| core_main_material         | text      | Main material.                                               |
| front_image_url            | text      | Front image URL.                                             |
| front_image_preview        | text      | Front image preview.                                         |
| back_image_url             | text      | Back image URL.                                              |
| back_image_preview         | text      | Back image preview.                                          |
| side_image_url             | text      | Side image URL.                                              |
| side_image_preview         | text      | Side image preview.                                          |
| created_at                 | timestamptz| Created timestamp.                                           |
| updated_at                 | timestamptz| Updated timestamp.                                           |
| created_by                 | varchar   | User who created.                                            |
| modified_by                | varchar   | User who last modified.                                      |
| beproduct_created_at       | timestamptz| Created in BeProduct.                                        |
| beproduct_modified_at      | timestamptz| Modified in BeProduct.                                       |
| is_deleted                 | boolean   | Marked as deleted (legacy).                                  |
| raw_beproduct_data         | jsonb     | Raw BeProduct data.                                          |
| deleted                    | boolean   | Marked as deleted.                                           |

**Relationships:**
- Referenced by `pim.style_colorway` and `pim.style_size_class` via `style_id`.

---

## Table: pim.style_colorway
| Column                     | Type      | Description / Business Note                                   |
|----------------------------|-----------|--------------------------------------------------------------|
| id                         | uuid      | Primary key.                                                 |
| beproduct_colorway_id      | uuid      | Colorway ID from BeProduct.                                  |
| style_id                   | uuid      | FK to `pim.style`.                                          |
| color_number               | varchar   | Color number.                                                |
| color_name                 | varchar   | Color name.                                                  |
| primary_hex                | varchar   | Primary color hex.                                           |
| secondary_hex              | varchar   | Secondary color hex.                                         |
| secondary_color_number     | varchar   | Secondary color number.                                      |
| secondary_color_name       | varchar   | Secondary color name.                                        |
| pantone                    | varchar   | Pantone code.                                                |
| brand_marketing_name       | varchar   | Brand marketing name.                                        |
| color_reference            | varchar   | Color reference.                                             |
| color_number_ls            | varchar   | Color number (legacy system).                                |
| hide_colorway              | boolean   | Hide this colorway.                                          |
| image_header_id            | uuid      | Image header ID.                                             |
| color_source_id            | uuid      | Color source ID.                                             |
| comments                   | text      | Comments.                                                    |
| created_at                 | timestamptz| Created timestamp.                                           |
| raw_beproduct_data         | jsonb     | Raw BeProduct data.                                          |
| bulk_order_qty             | integer   | Bulk order quantity.                                         |
| core_colorway_main_material| text      | Main material for colorway.                                  |
| marketing_name             | text      | Marketing name.                                              |
| deleted                    | boolean   | Marked as deleted.                                           |

**Relationships:**
- FK to `pim.style` via `style_id`.

---

## Table: pim.style_size_class
| Column                     | Type      | Description / Business Note                                   |
|----------------------------|-----------|--------------------------------------------------------------|
| id                         | uuid      | Primary key.                                                 |
| beproduct_size_class_id    | uuid      | Size class ID from BeProduct.                                |
| style_id                   | uuid      | FK to `pim.style`.                                          |
| size_class_name            | varchar   | Name of the size class.                                      |
| is_default                 | boolean   | Is this the default size class?                              |
| sizes                      | jsonb     | List of sizes.                                               |
| created_at                 | timestamptz| Created timestamp.                                           |
| raw_beproduct_data         | jsonb     | Raw BeProduct data.                                          |
| size_class_fields          | jsonb     | Additional fields.                                           |
| deleted                    | boolean   | Marked as deleted.                                           |

**Relationships:**
- FK to `pim.style` via `style_id`.

---

## Table: pim.color_folder
| Column                     | Type      | Description / Business Note                                   |
|----------------------------|-----------|--------------------------------------------------------------|
| id                         | uuid      | Primary key.                                                 |
| beproduct_folder_id        | uuid      | Unique folder ID from BeProduct.                             |
| name                       | varchar   | Folder name.                                                 |
| description                | text      | Folder description.                                          |
| active                     | boolean   | Is folder active?                                            |
| created_at                 | timestamptz| Created timestamp.                                           |
| updated_at                 | timestamptz| Updated timestamp.                                           |

**Relationships:**
- Referenced by `pim.color_palette` via `folder_id`.

---

## Table: pim.color_palette
| Column                     | Type      | Description / Business Note                                   |
|----------------------------|-----------|--------------------------------------------------------------|
| id                         | uuid      | Primary key.                                                 |
| beproduct_palette_id       | uuid      | Unique palette ID from BeProduct.                            |
| folder_id                  | uuid      | FK to `pim.color_folder`.                                    |
| palette_number             | varchar   | Palette number.                                              |
| palette_name               | varchar   | Palette name.                                                |
| season                     | varchar   | Season.                                                      |
| year                       | varchar   | Year.                                                        |
| brand                      | varchar   | Brand.                                                       |
| version                    | varchar   | Version.                                                     |
| created_at                 | timestamptz| Created timestamp.                                           |
| updated_at                 | timestamptz| Updated timestamp.                                           |
| created_by                 | varchar   | User who created.                                            |
| modified_by                | varchar   | User who last modified.                                      |
| beproduct_created_at       | timestamptz| Created in BeProduct.                                        |
| beproduct_modified_at      | timestamptz| Modified in BeProduct.                                       |

**Relationships:**
- FK to `pim.color_folder` via `folder_id`.
- Referenced by `pim.color_palette_color` via `palette_id`.

---

## Table: pim.color_palette_color
| Column                     | Type      | Description / Business Note                                   |
|----------------------------|-----------|--------------------------------------------------------------|
| id                         | uuid      | Primary key.                                                 |
| beproduct_color_id         | uuid      | Color ID from BeProduct.                                     |
| palette_id                 | uuid      | FK to `pim.color_palette`.                                   |
| color_number               | varchar   | Color number.                                                |
| color_name                 | varchar   | Color name.                                                  |
| hex                        | varchar   | Hex color code.                                              |
| rgb_r                      | integer   | Red value.                                                   |
| rgb_g                      | integer   | Green value.                                                 |
| rgb_b                      | integer   | Blue value.                                                  |
| pantone                    | varchar   | Pantone code.                                                |
| brand_marketing_name       | varchar   | Brand marketing name.                                        |
| color_number_ls            | varchar   | Color number (legacy system).                                |
| color_reference            | varchar   | Color reference.                                             |
| sort_order                 | integer   | Sort order.                                                  |
| created_at                 | timestamptz| Created timestamp.                                           |

**Relationships:**
- FK to `pim.color_palette` via `palette_id`.

---

## ER Diagram (Mermaid)
```mermaid
erDiagram
    style ||--o{ style_colorway : has
    style ||--o{ style_size_class : has
    color_folder ||--o{ color_palette : has
    color_palette ||--o{ color_palette_color : has
```

---

*Columns marked as `-- DropDown` or similar are placeholders for future enum/configuration. See migration file for inline notes.*
