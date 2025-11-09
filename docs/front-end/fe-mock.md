# AAG Allocations — Front‑End PRD (FE‑only, Mocked)

**Scope:** End‑to‑end allocation lifecycle in UI using **mocked APIs** (MSW + in‑memory store). No backend dependency; safe to ship behind a feature flag.

---

## 1) Goals & Non‑Goals

**User goals**

* Convert **unallocated order lines** into **preallocations**, then **allocations** (RFQ sent).
* Intake **factory quotes** (price, ex‑factory), **award** (including split awards).
* Generate **contract & PO** (mock docs), download individually or in bulk.
* Track **production** on the same allocation rows (status + cut/sew/finish/QC quantities & dates).
* Plan against **factory capacity** while allocating.
* Ensure all mock data models, fields, and status flows match backend schema for easy future integration.

**Non‑goals**

* Real Supabase calls, auth/RLS, real docs. (Use mocked endpoints + Blob URLs.)
* Full backend constraints (just main fields, not all constraints or indexes).

---

## 2) Data Model & Schema Mapping

All mock types/interfaces and API payloads must use the main fields and naming conventions from the backend schema. See mapping table below for reference.

| Mock Type         | Backend Table                  | Key Fields (Main Only)                                  |
|-------------------|-------------------------------|---------------------------------------------------------|
| OrderItem         | ops.order_items                | item_id, order_id, style_id, colorway_id, qty, plan_id, node_id, allocation_status, allocation_item_id |
| Allocation        | ops.allocations                | id, name, plan_id, customer, brand, status, factory_ids, created_at |
| AllocationItem    | ops.allocation_items           | id, allocation_id, order_item_id, node_id, committed_qty |
| AIS               | ops.allocation_items_supplier  | id, allocation_item_id, factory_id, quote_status, price_from_quote, ex_factory_date, remarks, is_awarded, awarded_qty, awarded_at, agreed_price, production_status, contract_url, po_number, po_url |
| FactoryPO         | ops.factory_pos                | id, allocation_id, factory_id, po_number, status, ex_factory_date, po_url |

**Naming convention:** Use the app’s existing convention (camelCase or snake_case as used in your codebase).

---

## 3) IA & Navigation

Top‑level tabs:

* **Orders** (Unallocated | Preallocation | Allocated)
* **Allocations** (list + detail)
* **Capacity** (factory load vs capacity)
* **Shipments** (builder/tracker – optional stub)

Deep link: `/allocations/:allocationId` (single allocation, end‑to‑end view)

---

## 4) Screens & Flows

### A. Orders — Unallocated → Preallocation → Allocation

**A1. Unallocated Orders**

* Grid of order lines: Style, Color (marketing), Customer, Qty, Plan/Season, **Status**, Node due (EX‑Fty), Last Supplier, Last Price.
* Filters: Status, Plan, Supplier, Factory, Brand, Season.
* Actions:
  * **Create Preallocation** (multi‑select) → choose factory(ies) + see capacity preview → creates Allocation + AIS candidates; set lines to `PREALLOCATED`.
  * Supplier History side panel (prior factories + prices).

**A2. Preallocation Review**

* Allocation(s) with candidate factories & proposed quantities.
* **Send to Factories** → RFQ sent; lines → `ALLOCATED`; AIS.quote_status=`SENT`.

**A3. Quote Intake**

* Per AIS row: enter `price_from_quote`, `ex_factory_date`, `remarks`; set `quote_status`.
* **Award** (split allowed): set `is_awarded`, `awarded_qty`, `awarded_at`; lines → `CONFIRMED`.

### B. Single Allocation (Hero screen)

**Header**

* Name, Plan/Season, Customer/Brand. Factory chips with per‑factory status: `DRAFT` → `RFQ_SENT` → `QUOTED` → `AWARDED` → `PC_ISSUED` → `PC_SIGNED` → `IN_PRODUCTION` → `COMPLETED`.
* Actions: **Generate Contract**, **Issue PO**, **Bulk Download**, **Share**.

**Main table (rows = AIS slices)**

* Columns: Style, Color, **Order Qty**, **Awarded Qty**, **Quoted Price**, **Agreed Price**, **Ex‑Factory (Agreed)**, **Production Status**, checkpoints (Cut/Sew/Finish/QC qty & dates), Late flag.
* Row actions: Award/Unaward, Edit Ex‑Factory, Update Production, Upload Doc.

**Right drawer (row details)**

* Timeline badges (EX‑Fty/Delivery due), Factory contact, Activity feed, Documents.

**Tabs**: Overview (table), Quotes, Contract & PO, Production, Documents.

### C. Capacity

* Heatmap grid (Factories × Weeks). Cell shows **Load/Capacity**.
* Click cell → drawer with contributing AIS rows.
* “What‑if” capacity slider (mock only) affects overflow badges.

### D. Production Tracking (on AIS rows)

* `production_status`: `NOT_STARTED` → `CUTTING` → `SEWING` → `FINISHING` → `QC` → `PACKED` → `READY` → `COMPLETED`.
* Checkpoints: `cut_qty/date`, `sewn_qty/date`, `finished_qty/date`, `qc_pass_qty/date`, `packed_qty/date`.
* Inspections: array of `{date, result, defects, notes, doc_url}`.
* Bulk actions: set status; post QC for selected rows.

### E. Documents

* Per‑row **Download Contract/PO**; header **Bulk Download** (ZIP mock).

---

## 5) Mock Data Model (Store Types)

All types below must use only the main fields and match backend schema for easy transition. See mapping table above for reference.

```ts
// statuses
export type AllocationStatus =
  | 'DRAFT' | 'RFQ_SENT' | 'QUOTED' | 'AWARDED'
  | 'PC_ISSUED' | 'PC_SIGNED' | 'IN_PRODUCTION' | 'COMPLETED';

export type OrderAllocationStatus =
  | 'UNALLOCATED' | 'PREALLOCATED' | 'ALLOCATED'
  | 'CONFIRMED' | 'PC_ISSUED' | 'PC_SIGNED' | 'CANCELLED';

export type QuoteStatus = 'SENT' | 'RECEIVED' | 'REVISED' | 'DECLINED';

export type ProductionStatus =
  | 'NOT_STARTED' | 'CUTTING' | 'SEWING' | 'FINISHING'
  | 'QC' | 'PACKED' | 'READY' | 'COMPLETED';

export interface OrderItem {
  item_id: string; order_id: string; style_id: string; colorway_id: string;
  qty: number; plan_id: string; node_id: string; // canonical timeline node
  allocation_status: OrderAllocationStatus;
  allocation_item_id?: string; // linked when allocated
}

export interface Allocation { id: string; name: string; plan_id: string; customer: string; brand: string; status: AllocationStatus; factory_ids: string[]; created_at: string; }

export interface AllocationItem { id: string; allocation_id: string; order_item_id: string; node_id: string; committed_qty: number; }

export interface AIS {
  id: string; allocation_item_id: string; factory_id: string; quote_status: QuoteStatus;
  price_from_quote?: number; ex_factory_date?: string; remarks?: string;
  is_awarded: boolean; awarded_qty?: number; awarded_at?: string; agreed_price?: number;
  production_status: ProductionStatus;
  cut_qty?: number; cut_date?: string;
  sewn_qty?: number; sewn_date?: string;
  finished_qty?: number; finished_date?: string;
  qc_pass_qty?: number; qc_date?: string;
  packed_qty?: number; packed_date?: string;
  inspections?: Array<{date:string; result:'PASS'|'FAIL'; defects?:number; notes?:string; doc_url?:string;}>;
  contract_url?: string; po_number?: string; po_url?: string;
}

export interface FactoryPO { id: string; allocation_id: string; factory_id: string; po_number: string; status: 'DRAFT'|'ISSUED'|'SIGNED'|'CLOSED'|'CANCELLED'; ex_factory_date?: string; po_url?: string; }
```

---

## 6) Mock API (MSW)

* **Orders**
  * `GET /api/orders?status=`
  * `PATCH /api/order-items/:id` (status + allocation_item_id)
* **Allocations**
  * `POST /api/allocations` (from selection → preallocation)
  * `GET /api/allocations?plan_id=`
  * `GET /api/allocations/:id`
  * `POST /api/allocations/:id/send-rfq` (set allocation.status, AIS.quote_status, lines → `ALLOCATED`)
  * `POST /api/allocations/:id/award` (body: [{ais_id, awarded_qty, agreed_price}]) → lines → `CONFIRMED`
* **AIS**
  * `PATCH /api/ais/:id/quote`
  * `PATCH /api/ais/:id/production`
  * `POST /api/ais/:id/docs` (mock URLs)
  * `GET /api/ais/:id/download/:doc` (Blob)
* **POs**
  * `POST /api/pos` (create header, set ais.po_number/po_url)
  * `PATCH /api/pos/:id` (status)
* **Capacity**
  * `GET /api/capacity?factory_id&from&to`
  * `PATCH /api/capacity/:weekId`
  * `GET /api/load?factory_id&from&to`
* **Bulk**
  * `POST /api/allocations/:id/bulk-download` → ZIP Blob

---

## 7) UI/UX Edge Cases for Testing

Include the following edge cases in mock data to improve UI/UX and future backend integration:
- Split awards (multiple factories per allocation item)
- Cancelled orders and allocations
- Late shipments/production status
- Awarded vs non-awarded supplier rows
- Status transitions for all main flows

---

## 8) Acceptance Criteria

* End‑to‑end happy path works with mocks: create preallocation → send RFQ → intake quotes → split award → generate contract → issue PO → production updates → completion.
* Portfolio visibility: lists show counts per status; filters by Plan/Season and Factory.
* Single allocation view contains the entire lifecycle and per‑factory status.
* Capacity panel informs planning decisions in Orders and Allocations.
* Edge cases (split awards, cancellations, late shipments) are testable in the UI.

---

## 9) Developer Notes

* All mock fields and status flows must match backend schema for easy transition.
* Use optimistic UI, toasts, undo, and error toggles for resilience.
* MSW handlers + a single persisted store (localStorage) for seeds.
* Reuse production planning grid components for visual consistency.
* Provide example mock data covering all main status flows and edge cases.

---

## 10) Reference: Backend Workflow & Status Logic

See meeting notes and schema docs for full lifecycle, status flows, and business logic. Key points:
- `order_items.allocation_status` is the single source of truth for each line’s lifecycle.
- `allocation_items` link order lines into allocations.
- `allocation_items_supplier` holds per-factory assignment and award data.
- `factory_pos` is the contract/purchase order header table.
- `factory_receipts` captures actual goods received by awarded factory lines.
- Status transitions and business logic must be reflected in the mock for realistic UI/UX.

---