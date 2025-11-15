# RLS Quick Reference for App Developers

## Overview

This guide provides quick code examples for implementing Row-Level Security (RLS) in your frontend applications.

**Key Point**: RLS is automatic! Once configured, Supabase automatically filters data based on the authenticated user's permissions. You don't need to add brand filters in most queries.

---

## Common Patterns

### 1. List All Accessible Styles

```typescript
// ✅ GOOD - RLS handles filtering automatically
const { data: styles, error } = await supabase
  .from('style')
  .select('*')
  .eq('deleted', false)
  .order('created_at', { ascending: false });

// ❌ BAD - Don't manually filter by brand (RLS does this)
const { data } = await supabase
  .from('style')
  .select('*')
  .in('brand', userBrands); // Unnecessary!
```

### 2. Get User's Accessible Brands

```typescript
// Get brands user can access
const { data: brands, error } = await supabase
  .rpc('get_accessible_brands');

// Returns:
// [
//   { brand_id: '...', brand_code: 'NIKE_SPORT', brand_name: 'Nike Sport', access_level: 'read' },
//   { brand_id: '...', brand_code: 'NIKE_CASUAL', brand_name: 'Nike Casual', access_level: 'write' }
// ]

// Use for UI elements (dropdowns, filters, etc.)
const brandOptions = brands.map(b => ({
  value: b.brand_code,
  label: b.brand_name
}));
```

### 3. Filter Tracking Plans

```typescript
// ✅ GOOD - RLS filters by brand or factory access
const { data: plans, error } = await supabase
  .from('plans')
  .select(`
    id,
    name,
    brand,
    season,
    folder:folders(id, name),
    styles:plan_styles(id, style_number, style_name)
  `)
  .eq('active', true);

// RLS automatically:
// - Shows all plans for internal users
// - Shows brand-filtered plans for customer users
// - Shows allocated plans for factory users
```

### 4. Check Brand Access Before Showing UI

```typescript
const checkBrandAccess = async (brandCode: string) => {
  const { data: hasAccess } = await supabase
    .rpc('can_access_brand', { p_brand_code: brandCode });
  
  return hasAccess;
};

// Use in component
const showNikeSection = await checkBrandAccess('NIKE_SPORT');
if (showNikeSection) {
  // Render Nike-specific UI
}
```

### 5. Get User Profile Info

```typescript
const getUserProfile = async () => {
  const { data: { user } } = await supabase.auth.getUser();
  
  if (!user) return null;
  
  const { data: profile, error } = await supabase
    .from('user_profile')
    .select(`
      *,
      company:company_id(id, code, name),
      factory:factory_id(id, code, name)
    `)
    .eq('id', user.id)
    .single();
  
  return profile;
};

// Returns user type, company, factory info
const profile = await getUserProfile();
console.log('User type:', profile.user_type); // 'internal', 'customer', or 'factory'
```

---

## React Hooks Examples

### useAccessibleBrands Hook

```typescript
import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';

export const useAccessibleBrands = () => {
  const [brands, setBrands] = useState([]);
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    const fetchBrands = async () => {
      const { data, error } = await supabase.rpc('get_accessible_brands');
      if (!error) setBrands(data || []);
      setLoading(false);
    };
    
    fetchBrands();
  }, []);
  
  return { brands, loading };
};

// Usage in component
function BrandSelector() {
  const { brands, loading } = useAccessibleBrands();
  
  if (loading) return <div>Loading...</div>;
  
  return (
    <select>
      {brands.map(b => (
        <option key={b.brand_id} value={b.brand_code}>
          {b.brand_name}
        </option>
      ))}
    </select>
  );
}
```

### useUserProfile Hook

```typescript
import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';

export const useUserProfile = () => {
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    const fetchProfile = async () => {
      const { data: { user } } = await supabase.auth.getUser();
      
      if (user) {
        const { data } = await supabase
          .from('user_profile')
          .select('*, company:company_id(*), factory:factory_id(*)')
          .eq('id', user.id)
          .single();
        
        setProfile(data);
      }
      
      setLoading(false);
    };
    
    fetchProfile();
  }, []);
  
  const isInternal = profile?.user_type === 'internal';
  const isCustomer = profile?.user_type === 'customer';
  const isFactory = profile?.user_type === 'factory';
  
  return { profile, loading, isInternal, isCustomer, isFactory };
};

// Usage
function Dashboard() {
  const { profile, isInternal, isCustomer, isFactory } = useUserProfile();
  
  return (
    <div>
      <h1>Welcome, {profile?.full_name}</h1>
      {isInternal && <AdminPanel />}
      {isCustomer && <CustomerDashboard />}
      {isFactory && <FactoryDashboard />}
    </div>
  );
}
```

---

## Page-Level Filtering Examples

### Styles Page (Customer View)

```typescript
function StylesPage() {
  const [styles, setStyles] = useState([]);
  const { brands } = useAccessibleBrands();
  const [selectedBrand, setSelectedBrand] = useState('all');
  
  useEffect(() => {
    const fetchStyles = async () => {
      let query = supabase
        .from('style')
        .select('*')
        .eq('deleted', false);
      
      // Optional: Additional client-side filtering
      if (selectedBrand !== 'all') {
        query = query.eq('brand', selectedBrand);
      }
      
      const { data } = await query;
      setStyles(data || []);
    };
    
    fetchStyles();
  }, [selectedBrand]);
  
  return (
    <div>
      <select onChange={(e) => setSelectedBrand(e.target.value)}>
        <option value="all">All Brands</option>
        {brands.map(b => (
          <option key={b.brand_code} value={b.brand_code}>
            {b.brand_name}
          </option>
        ))}
      </select>
      
      <StyleList styles={styles} />
    </div>
  );
}
```

### Tracking Plans Page (Factory View)

```typescript
function TrackingPlansPage() {
  const [plans, setPlans] = useState([]);
  const { isFactory } = useUserProfile();
  
  useEffect(() => {
    const fetchPlans = async () => {
      // RLS automatically filters to allocated plans for factory users
      const { data } = await supabase
        .from('plans')
        .select(`
          *,
          folder:folders(name),
          styles:plan_styles(
            id,
            style_number,
            style_name,
            allocation:style_factory_allocation(allocated_quantity)
          )
        `)
        .eq('active', true);
      
      setPlans(data || []);
    };
    
    fetchPlans();
  }, []);
  
  return (
    <div>
      <h1>My Production Plans</h1>
      {isFactory && <p>Showing plans you are allocated to</p>}
      <PlanList plans={plans} />
    </div>
  );
}
```

---

## Server-Side / Edge Function Examples

### Allocate Factory (Backend Only)

```typescript
// Edge Function: allocate-factory/index.ts
import { createClient } from '@supabase/supabase-js';

Deno.serve(async (req) => {
  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')! // Bypass RLS
  );
  
  const { planId, styleId, factoryId, quantity } = await req.json();
  
  // Create allocation (trigger will auto-grant access)
  const { data, error } = await supabaseAdmin
    .from('style_factory_allocation')
    .insert({
      tracking_plan_id: planId,
      plan_style_id: styleId,
      factory_id: factoryId,
      allocated_quantity: quantity,
      active: true
    });
  
  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' }
    });
  }
  
  // Access is automatically granted via trigger
  return new Response(JSON.stringify({ 
    success: true,
    message: 'Factory allocated and access granted'
  }), {
    headers: { 'Content-Type': 'application/json' }
  });
});
```

---

## Filtering in Tables (UI Components)

### Using Tanstack Table with RLS

```typescript
import { useReactTable, getCoreRowModel } from '@tanstack/react-table';

function StylesTable() {
  const [styles, setStyles] = useState([]);
  const { brands } = useAccessibleBrands();
  
  useEffect(() => {
    // RLS filters automatically
    const fetchStyles = async () => {
      const { data } = await supabase
        .from('style')
        .select('*')
        .eq('deleted', false);
      
      setStyles(data || []);
    };
    
    fetchStyles();
  }, []);
  
  const columns = [
    { accessorKey: 'header_name', header: 'Style Name' },
    { 
      accessorKey: 'brand', 
      header: 'Brand',
      // Optional: Show brand display name
      cell: ({ row }) => {
        const brand = brands.find(b => b.brand_code === row.original.brand);
        return brand?.brand_name || row.original.brand;
      }
    },
    { accessorKey: 'season', header: 'Season' },
    { accessorKey: 'year', header: 'Year' }
  ];
  
  const table = useReactTable({
    data: styles,
    columns,
    getCoreRowModel: getCoreRowModel()
  });
  
  // Render table...
}
```

### Using AG Grid with RLS

```typescript
import { AgGridReact } from 'ag-grid-react';

function StylesGrid() {
  const [rowData, setRowData] = useState([]);
  const { brands } = useAccessibleBrands();
  
  useEffect(() => {
    const fetchData = async () => {
      const { data } = await supabase
        .from('style')
        .select('*')
        .eq('deleted', false);
      
      setRowData(data || []);
    };
    
    fetchData();
  }, []);
  
  const columnDefs = [
    { field: 'header_name', headerName: 'Style Name', filter: 'agTextColumnFilter' },
    { 
      field: 'brand', 
      headerName: 'Brand',
      filter: 'agSetColumnFilter',
      // RLS has already filtered, but you can add client-side filter
      filterParams: {
        values: brands.map(b => b.brand_code)
      }
    },
    { field: 'season', filter: 'agSetColumnFilter' },
    { field: 'year', filter: 'agNumberColumnFilter' }
  ];
  
  return (
    <div className="ag-theme-alpine" style={{ height: 600 }}>
      <AgGridReact
        rowData={rowData}
        columnDefs={columnDefs}
        defaultColDef={{ sortable: true, filter: true }}
      />
    </div>
  );
}
```

---

## Real-Time Subscriptions with RLS

```typescript
function StylesLiveView() {
  const [styles, setStyles] = useState([]);
  
  useEffect(() => {
    // Initial fetch (RLS filtered)
    const fetchStyles = async () => {
      const { data } = await supabase
        .from('style')
        .select('*')
        .eq('deleted', false);
      
      setStyles(data || []);
    };
    
    fetchStyles();
    
    // Subscribe to changes (RLS filtered)
    const subscription = supabase
      .channel('styles-channel')
      .on(
        'postgres_changes',
        { 
          event: '*', 
          schema: 'pim', 
          table: 'style'
        },
        (payload) => {
          console.log('Style changed:', payload);
          
          // RLS ensures you only see changes you're allowed to
          if (payload.eventType === 'INSERT') {
            setStyles(prev => [...prev, payload.new]);
          } else if (payload.eventType === 'UPDATE') {
            setStyles(prev => prev.map(s => 
              s.id === payload.new.id ? payload.new : s
            ));
          } else if (payload.eventType === 'DELETE') {
            setStyles(prev => prev.filter(s => s.id !== payload.old.id));
          }
        }
      )
      .subscribe();
    
    return () => {
      subscription.unsubscribe();
    };
  }, []);
  
  return <StyleList styles={styles} />;
}
```

---

## Best Practices

### 1. Trust RLS, Don't Duplicate Filters

```typescript
// ❌ BAD - Redundant filtering
const { data } = await supabase
  .from('style')
  .select('*')
  .in('brand', userAccessibleBrands) // RLS does this!
  .eq('deleted', false);

// ✅ GOOD - Let RLS handle it
const { data } = await supabase
  .from('style')
  .select('*')
  .eq('deleted', false);
```

### 2. Use Helper Functions for UI Logic

```typescript
// ✅ GOOD - Use for UI decisions, not data filtering
const { brands } = useAccessibleBrands();

// Show/hide UI elements based on brand access
const canEditNike = brands.some(b => 
  b.brand_code === 'NIKE_SPORT' && b.access_level === 'write'
);

if (canEditNike) {
  return <EditButton />;
}
```

### 3. Cache Accessible Brands

```typescript
// ✅ GOOD - Cache in React context
const BrandsContext = createContext();

export function BrandsProvider({ children }) {
  const [brands, setBrands] = useState([]);
  
  useEffect(() => {
    const fetchBrands = async () => {
      const { data } = await supabase.rpc('get_accessible_brands');
      setBrands(data || []);
    };
    
    fetchBrands();
  }, []);
  
  return (
    <BrandsContext.Provider value={{ brands }}>
      {children}
    </BrandsContext.Provider>
  );
}
```

### 4. Handle Factory-Specific Views

```typescript
function AllocationStatus() {
  const { isFactory, profile } = useUserProfile();
  const [allocations, setAllocations] = useState([]);
  
  useEffect(() => {
    if (!isFactory) return;
    
    // RLS filters to factory's allocations
    const fetchAllocations = async () => {
      const { data } = await supabase
        .from('style_factory_allocation')
        .select(`
          *,
          style:plan_styles(style_number, style_name),
          plan:plans(name, season)
        `)
        .eq('active', true);
      
      setAllocations(data || []);
    };
    
    fetchAllocations();
  }, [isFactory]);
  
  return (
    <div>
      <h2>My Allocations</h2>
      {allocations.map(a => (
        <AllocationCard key={a.id} allocation={a} />
      ))}
    </div>
  );
}
```

---

## Debugging RLS Issues

### Check Current User's Access

```typescript
// Debug: See what brands user can access
const debugAccess = async () => {
  const { data: user } = await supabase.auth.getUser();
  console.log('User ID:', user?.user?.id);
  
  const { data: profile } = await supabase
    .from('user_profile')
    .select('*')
    .eq('id', user?.user?.id)
    .single();
  console.log('Profile:', profile);
  
  const { data: brands } = await supabase.rpc('get_accessible_brands');
  console.log('Accessible Brands:', brands);
  
  const { data: styles } = await supabase
    .from('style')
    .select('brand')
    .eq('deleted', false);
  console.log('Visible Styles by Brand:', 
    styles.reduce((acc, s) => {
      acc[s.brand] = (acc[s.brand] || 0) + 1;
      return acc;
    }, {})
  );
};
```

### Check Factory Access

```typescript
const debugFactoryAccess = async () => {
  const { data: plans } = await supabase.rpc('get_factory_accessible_plans');
  console.log('Accessible Plans:', plans);
  
  const { data: folders } = await supabase.rpc('get_factory_accessible_folders');
  console.log('Accessible Folders:', folders);
  
  const { data: allocations } = await supabase
    .from('style_factory_allocation')
    .select('*')
    .eq('active', true);
  console.log('Active Allocations:', allocations);
};
```

---

## Summary

**Remember**: RLS is automatic! Your queries are already filtered based on user permissions. Focus on:

1. Using helper functions to get accessible brands for UI logic
2. Trusting RLS for data filtering (don't add redundant filters)
3. Handling user-type-specific views (internal vs customer vs factory)
4. Testing with different user types to verify access control

For more details, see the [RLS Implementation Guide](./RLS-IMPLEMENTATION-GUIDE.md).
