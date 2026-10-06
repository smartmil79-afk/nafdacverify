// Copies every product from the NAFDAC Greenbook into your Supabase table greenbook_products.
// Needs Node 18+.   Run:   node ingest-greenbook.mjs --dry     (checks the connection and column mapping, writes nothing)
//                          node ingest-greenbook.mjs           (full sync, a few minutes)
//
// ONE-TIME SETUP (the Greenbook has no documented API; its table loads JSON from its home page):
//  1. Open https://greenbook.nafdac.gov.ng in Chrome, press F12 > Network > Fetch/XHR, reload the page.
//  2. Click the request that returns the product rows, right-click > Copy > Copy URL.
//  3. export GB_URL="<that URL>"          (the script overrides paging and keeps any other filters in it)
//  4. export SUPABASE_URL="https://xxxx.supabase.co"   export SUPABASE_SERVICE_KEY="<service_role key, keep secret>"
// Optional: GB_PAGE=100  GB_DELAY_MS=600  PRUNE=1 (delete rows that no longer exist on the Greenbook after a complete sync)
// Please keep the delay polite. This is public government data, but check the site's terms/robots.txt before frequent runs.
import crypto from "node:crypto";

const GB_URL = process.env.GB_URL || "https://greenbook.nafdac.gov.ng/?draw=1&columns%5B0%5D%5Bdata%5D=product_name&columns%5B0%5D%5Bname%5D=product_name&columns%5B0%5D%5Bsearchable%5D=true&columns%5B0%5D%5Borderable%5D=true&columns%5B0%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B0%5D%5Bsearch%5D%5Bregex%5D=false&columns%5B1%5D%5Bdata%5D=ingredient.ingredient_name&columns%5B1%5D%5Bname%5D=ingredient.ingredient_name&columns%5B1%5D%5Bsearchable%5D=true&columns%5B1%5D%5Borderable%5D=true&columns%5B1%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B1%5D%5Bsearch%5D%5Bregex%5D=false&columns%5B2%5D%5Bdata%5D=product_category.name&columns%5B2%5D%5Bname%5D=product_category.name&columns%5B2%5D%5Bsearchable%5D=true&columns%5B2%5D%5Borderable%5D=false&columns%5B2%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B2%5D%5Bsearch%5D%5Bregex%5D=false&columns%5B3%5D%5Bdata%5D=product_category_id&columns%5B3%5D%5Bname%5D=product_category_id&columns%5B3%5D%5Bsearchable%5D=true&columns%5B3%5D%5Borderable%5D=true&columns%5B3%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B3%5D%5Bsearch%5D%5Bregex%5D=false&columns%5B4%5D%5Bdata%5D=ingredient.synonym&columns%5B4%5D%5Bname%5D=ingredient.synonym&columns%5B4%5D%5Bsearchable%5D=true&columns%5B4%5D%5Borderable%5D=true&columns%5B4%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B4%5D%5Bsearch%5D%5Bregex%5D=false&columns%5B5%5D%5Bdata%5D=NAFDAC&columns%5B5%5D%5Bname%5D=NAFDAC&columns%5B5%5D%5Bsearchable%5D=true&columns%5B5%5D%5Borderable%5D=true&columns%5B5%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B5%5D%5Bsearch%5D%5Bregex%5D=false&columns%5B6%5D%5Bdata%5D=form.name&columns%5B6%5D%5Bname%5D=form.name&columns%5B6%5D%5Bsearchable%5D=true&columns%5B6%5D%5Borderable%5D=true&columns%5B6%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B6%5D%5Bsearch%5D%5Bregex%5D=false&columns%5B7%5D%5Bdata%5D=route.name&columns%5B7%5D%5Bname%5D=route.name&columns%5B7%5D%5Bsearchable%5D=true&columns%5B7%5D%5Borderable%5D=true&columns%5B7%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B7%5D%5Bsearch%5D%5Bregex%5D=false&columns%5B8%5D%5Bdata%5D=strength&columns%5B8%5D%5Bname%5D=strength&columns%5B8%5D%5Bsearchable%5D=true&columns%5B8%5D%5Borderable%5D=true&columns%5B8%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B8%5D%5Bsearch%5D%5Bregex%5D=false&columns%5B9%5D%5Bdata%5D=applicant.name&columns%5B9%5D%5Bname%5D=applicant.name&columns%5B9%5D%5Bsearchable%5D=true&columns%5B9%5D%5Borderable%5D=true&columns%5B9%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B9%5D%5Bsearch%5D%5Bregex%5D=false&columns%5B10%5D%5Bdata%5D=approval_date&columns%5B10%5D%5Bname%5D=approval_date&columns%5B10%5D%5Bsearchable%5D=true&columns%5B10%5D%5Borderable%5D=true&columns%5B10%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B10%5D%5Bsearch%5D%5Bregex%5D=false&columns%5B11%5D%5Bdata%5D=status&columns%5B11%5D%5Bname%5D=status&columns%5B11%5D%5Bsearchable%5D=true&columns%5B11%5D%5Borderable%5D=true&columns%5B11%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B11%5D%5Bsearch%5D%5Bregex%5D=false&order%5B0%5D%5Bcolumn%5D=0&order%5B0%5D%5Bdir%5D=asc&start=0&length=10&search%5Bvalue%5D=&search%5Bregex%5D=false&search_ingredient=&_=1791296359569";
const SB = (process.env.SUPABASE_URL || "").replace(/\/$/, ""), KEY = process.env.SUPABASE_SERVICE_KEY;
const PAGE = +process.env.GB_PAGE || 100, DELAY = +process.env.GB_DELAY_MS || 600;
const DRY = process.argv.includes("--dry"), STARTED = new Date().toISOString();
const ORDER = ["product_name", "active_ingredients", "category", "category_id", "synonym", "nrn", "form", "roa", "strengths", "applicant_name", "approval_date", "status"];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const strip = (v) => String(v ?? "").replace(/<[^>]*>/g, "").replace(/&amp;/g, "&").replace(/\s+/g, " ").trim();

export function norm(r) {
  const id = (JSON.stringify(r).match(/products\/details\/(\d+)/) || [])[1] || (r && !Array.isArray(r) && r.id ? String(r.id) : "");
  const o = {};
  if (Array.isArray(r)) ORDER.forEach((k, i) => (o[k] = strip(r[i])));
  else {
    const pick = (pats, not = []) => {
      for (const k of Object.keys(r)) {
        const kl = k.toLowerCase();
        if (pats.some((p) => kl.includes(p)) && !not.some((n) => kl.includes(n))) return strip(r[k]);
      }
      return "";
    };
    o.product_name = pick(["product_name", "productname", "name"], ["applicant", "manufacturer"]);
    o.active_ingredients = pick(["ingredient"]); o.category = pick(["category"], ["id"]); o.category_id = pick(["category_id", "categoryid"]);
    o.synonym = pick(["synonym"]); o.nrn = pick(["nrn", "reg_no", "regno"]); o.form = pick(["form"]); o.roa = pick(["roa"]);
    o.strengths = pick(["strength"]); o.applicant_name = pick(["applicant"]); o.approval_date = pick(["approv"]); o.status = pick(["status"]);
  }
  const gb_key = id || crypto.createHash("sha1").update(`${o.nrn}|${o.product_name}|${o.applicant_name}`).digest("hex");
  return { gb_key, detail_id: id || null, ...o, raw: r, updated_at: new Date().toISOString() };
}

async function getPage(start) {
  const u = new URL(GB_URL);
  u.searchParams.set("draw", String(Math.floor(start / PAGE) + 1));
  u.searchParams.set("start", String(start));
  u.searchParams.set("length", String(PAGE));
  for (let a = 1; a <= 4; a++) {
    try {
      const r = await fetch(u, { headers: { "X-Requested-With": "XMLHttpRequest", Accept: "application/json", "User-Agent": "ChecknVerify-sync/1.0" } });
      if (!r.ok) throw new Error("HTTP " + r.status);
      return await r.json();
    } catch (e) {
      if (a === 4) throw e;
      await sleep(DELAY * a * 3);
    }
  }
}

async function upsert(rows) {
  for (let i = 0; i < rows.length; i += 500) {
    const r = await fetch(`${SB}/rest/v1/greenbook_products?on_conflict=gb_key`, {
      method: "POST",
      headers: { apikey: KEY, Authorization: `Bearer ${KEY}`, "Content-Type": "application/json", Prefer: "resolution=merge-duplicates,return=minimal" },
      body: JSON.stringify(rows.slice(i, i + 500)),
    });
    if (!r.ok) throw new Error("Supabase " + r.status + ": " + (await r.text()).slice(0, 200));
  }
}

async function main() {
  if (!DRY && (!SB || !KEY)) throw new Error("Set SUPABASE_URL and SUPABASE_SERVICE_KEY (or use --dry).");
  const all = new Map();
  let start = 0, total = Infinity;
  while (start < total) {
    const j = await getPage(start);
    if (!Array.isArray(j?.data)) throw new Error("The response has no 'data' array. Re-copy GB_URL from DevTools (see the header of this file).");
    total = +j.recordsFiltered || +j.recordsTotal || j.data.length;
    if (DRY) {
      console.log("recordsTotal:", j.recordsTotal, "| rows on this page:", j.data.length);
      console.log("raw first row:", JSON.stringify(j.data[0]).slice(0, 600));
      console.log("mapped first rows:", JSON.stringify(j.data.slice(0, 2).map((r) => { const n = norm(r); delete n.raw; return n; }), null, 1));
      console.log("\nCheck that nrn and status look right above. If not, the column mapping needs adjusting.");
      return;
    }
    j.data.forEach((r) => { const n = norm(r); all.set(n.gb_key, n); });
    start += PAGE;
    process.stdout.write(`\rfetched ${Math.min(start, total)} / ${total}`);
    if (!j.data.length) break;
    await sleep(DELAY);
  }
  const rows = [...all.values()];
  const missing = rows.filter((r) => !r.nrn || !r.status).length;
  console.log(`\n${rows.length} unique products. ${missing} lack an NRN or status.`);
  if (missing > rows.length * 0.2) throw new Error("Over 20% of rows have no NRN/status, so the column mapping is probably wrong. Run with --dry and check. Nothing was written.");
  await upsert(rows);
  console.log("Saved to Supabase.");
  if (process.env.PRUNE === "1" && rows.length >= total * 0.98) {
    const r = await fetch(`${SB}/rest/v1/greenbook_products?updated_at=lt.${encodeURIComponent(STARTED)}`, { method: "DELETE", headers: { apikey: KEY, Authorization: `Bearer ${KEY}` } });
    console.log(r.ok ? "Pruned products no longer on the Greenbook." : "Prune failed: " + r.status);
  }
}
if (import.meta.url === `file://${process.argv[1]}`) main().catch((e) => { console.error("\nERROR:", e.message); process.exit(1); });
