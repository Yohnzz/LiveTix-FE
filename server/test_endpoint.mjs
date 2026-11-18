// Gunakan built-in fetch Node 18+
const BASE = 'http://localhost:3000';

async function test() {
  console.log('=== TEST /api/health ===');
  const h = await fetch(`${BASE}/api/health`);
  console.log('Status:', h.status);
  console.log(await h.json());

  console.log('\n=== TEST /api/ai/concert-info (HS Punya Cerita) ===');
  const r = await fetch(`${BASE}/api/ai/concert-info`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ query: 'jelaskan konser HS' })
  });
  console.log('Status:', r.status);
  const json = await r.json();
  console.log('matched:', json.matched, '| ambiguous:', json.ambiguous);
  console.log('concert:', json.concert?.title ?? '(null)');
  console.log('message (first 500):\n', (json.message || '').substring(0, 500));
}

test().catch(console.error);
