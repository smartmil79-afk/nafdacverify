-- NAFDAC Greenbook copy for ChecknVerify search (NRN + Status). Run in the Supabase SQL Editor.
create extension if not exists pg_trgm with schema extensions;

create table public.greenbook_products (
  gb_key text primary key,            -- Greenbook product id, or a hash of NRN|name|applicant when no id is available
  detail_id text,                     -- id used in https://greenbook.nafdac.gov.ng/products/details/<id>
  product_name text, active_ingredients text, category text, category_id text, synonym text,
  nrn text, form text, roa text, strengths text, applicant_name text, approval_date text,
  status text,                        -- e.g. Active / Expired, exactly as the Greenbook shows it
  raw jsonb,                          -- the original row, for auditing
  updated_at timestamptz not null default now()
);
create index gb_name_idx on public.greenbook_products using gin (product_name extensions.gin_trgm_ops);
create index gb_nrn_idx  on public.greenbook_products using gin (nrn extensions.gin_trgm_ops);
create index gb_ing_idx  on public.greenbook_products using gin (active_ingredients extensions.gin_trgm_ops);

alter table public.greenbook_products enable row level security;
create policy "greenbook: public read" on public.greenbook_products for select to anon, authenticated using (true);
-- no insert/update policies: only the sync script (service role key) can write
