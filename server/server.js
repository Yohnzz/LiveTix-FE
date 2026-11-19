import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
}));
app.options('*', cors());
app.use(express.json());

// Inisialisasi Supabase Client
const supabaseUrl = process.env.SUPABASE_URL || 'https://arvydukozxjvwwhqnbth.supabase.co';
const supabaseKey = process.env.SUPABASE_ANON_KEY || '';
const supabase = createClient(supabaseUrl, supabaseKey);

// Inisialisasi Gemini API
const geminiApiKey = process.env.GEMINI_API_KEY || '';
const primaryModel = process.env.GEMINI_MODEL || 'gemini-3.5-flash-lite';
const fallbackModels = ['gemini-3.5-flash-lite', 'gemini-3.6-flash', 'gemini-flash-lite-latest'];

/**
 * Helper untuk memanggil Google Generative Language (Gemini) API
 */
async function callGemini(systemInstruction, userContent, jsonMode = false) {
  if (!geminiApiKey) {
    throw new Error('GEMINI_API_KEY tidak dikonfigurasi di backend');
  }

  const modelsToTry = [primaryModel, ...fallbackModels.filter(m => m !== primaryModel)];
  let lastError = null;

  for (const model of modelsToTry) {
    try {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${geminiApiKey}`;

      const payload = {
        contents: [
          {
            role: 'user',
            parts: [{ text: userContent }]
          }
        ]
      };

      if (systemInstruction) {
        payload.system_instruction = {
          parts: [{ text: systemInstruction }]
        };
      }

      if (jsonMode) {
        payload.generationConfig = {
          responseMimeType: 'application/json'
        };
      }

      const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });

      if (!res.ok) {
        const errorText = await res.text();
        throw new Error(`Gemini API HTTP ${res.status}: ${errorText}`);
      }

      const data = await res.json();
      const candidate = data.candidates?.[0];
      const part = candidate?.content?.parts?.[0];
      const text = part?.text || '';

      if (text) {
        return text;
      }
    } catch (err) {
      lastError = err;
      console.warn(`[Gemini] Gagal menggunakan model ${model}: ${err.message}`);
    }
  }

  throw lastError || new Error('Semua model Gemini gagal merespons');
}

/**
 * Health Check Endpoint
 */
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    message: 'LiveTix AI Backend Service berjalan normal',
    timestamp: new Date().toISOString()
  });
});

// ============================================================================
// FITUR 1: ASISTEN INFO KONSER (SISI USER)
// ============================================================================
/**
 * Alur:
 * 1. User bertanya tentang konser (contoh: "Jelaskan mengenai konser HS")
 * 2. Backend mencari konser yang cocok dari Supabase
 * 3. Data konser dikirim ke Gemini sebagai konteks
 * 4. Gemini menjelaskan secara ramah, santun, ringkas berdasarkan data (tanpa halusinasi)
 */
app.post('/api/ai/concert-info', async (req, res) => {
  try {
    const { query } = req.body;
    if (!query || typeof query !== 'string' || query.trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Pertanyaan pengguna (query) tidak boleh kosong.'
      });
    }

    const cleanQuery = query.trim();

    // 1. Ambil seluruh data konser berstatus 'published' beserta tiket kategorinya dari database Supabase
    const { data: rawConcerts, error: dbError } = await supabase
      .from('concerts')
      .select('*, ticket_tiers(*)')
      .in('status', ['published', 'approved'])
      .order('created_at', { ascending: false });

    if (dbError) {
      console.error('[Fitur 1] Database error:', dbError);
      return res.status(500).json({
        success: false,
        message: 'Gagal mengambil data konser dari database.',
        error: dbError.message
      });
    }

    const concerts = rawConcerts || [];

    // 2. Cocokkan query user dengan konser di database
    const qLower = cleanQuery.toLowerCase();
    // Bersihkan kata-kata umum (stopwords) seperti "jelaskan", "mengenai", "konser", "tentang", "info"
    const stopWords = ['jelaskan', 'tentang', 'mengenai', 'konser', 'info', 'bagaimana', 'apa', 'itu', 'dong', 'tolong', 'min', 'bisa', 'jadwal', 'tiket', 'harga'];
    const queryTokens = qLower
      .replace(/[^\w\s]/gi, ' ')
      .split(/\s+/)
      .filter(t => t.length > 1 && !stopWords.includes(t));

    // Skor kecocokan untuk setiap konser
    const scored = concerts.map(c => {
      const title = (c.title || '').toLowerCase();
      const subtitle = (c.subtitle || '').toLowerCase();
      const category = (c.category || '').toLowerCase();
      const venue = (c.venue || '').toLowerCase();
      const desc = (c.description || '').toLowerCase();
      const producer = (c.producer_name || '').toLowerCase();

      let score = 0;

      // Cek kecocokan langsung dengan substring nama
      if (qLower.includes(title) || title.includes(qLower)) {
        score += 50;
      }

      // Cek inisial / akronim (contoh: "HS" untuk "HS Punya Cerita")
      const titleWords = title.split(/\s+/);
      const acronym = titleWords.map(w => w[0]).join('');
      if (queryTokens.some(t => t === acronym || titleWords.includes(t))) {
        score += 35;
      }

      // Cek token kata
      for (const token of queryTokens) {
        if (title.includes(token)) score += 20;
        if (subtitle.includes(token)) score += 15;
        if (venue.includes(token)) score += 10;
        if (category.includes(token)) score += 8;
        if (producer.includes(token)) score += 5;
        if (desc.includes(token)) score += 4;
      }

      return { concert: c, score };
    });

    const matches = scored.filter(item => item.score > 0).sort((a, b) => b.score - a.score);

    // KASUS 1: Konser tidak ditemukan di database
    if (matches.length === 0) {
      return res.json({
        success: true,
        matched: false,
        ambiguous: false,
        message: 'Maaf, konser yang Anda tanyakan tidak ditemukan di dalam sistem LiveTix. Silakan periksa kembali penulisan nama konser, atau gunakan fitur pencarian di halaman Jelajah untuk mengecek konser yang tersedia.',
        matchedConcerts: []
      });
    }

    // KASUS 2: Beberapa konser cocok dengan skor yang sangat berdekatan
    const topScore = matches[0].score;
    const closeMatches = matches.filter(m => m.score >= topScore * 0.75 && m.score >= 20);

    if (closeMatches.length > 1 && topScore < 60) {
      const concertListStr = closeMatches.map((m, idx) => `${idx + 1}. ${m.concert.title} (${m.concert.venue})`).join('\n');
      return res.json({
        success: true,
        matched: true,
        ambiguous: true,
        message: `Ditemukan beberapa konser yang mirip dengan pertanyaan Anda:\n${concertListStr}\n\nKonser mana yang ingin Anda ketahui lebih lanjut?`,
        matchedConcerts: closeMatches.map(m => m.concert)
      });
    }

    // KASUS 3: Ada satu konser yang paling cocok -> kirim data lengkap ke AI sebagai konteks
    const targetConcert = matches[0].concert;
    const tiers = targetConcert.ticket_tiers || [];
    const tiersText = tiers.length > 0
      ? tiers.map(t => {
          const quotaRemain = (t.quota || 0) - (t.sold_count || 0);
          return `- Kategori ${t.name}: Rp${Number(t.price).toLocaleString('id-ID')} (Sisa kuota: ${quotaRemain > 0 ? quotaRemain : 'Habis'})`;
        }).join('\n')
      : `- Harga mulai dari: Rp${Number(targetConcert.price || 0).toLocaleString('id-ID')}`;

    const concertContext = `DATA RESMI KONSER DARI DATABASE LIVETIX:
- Judul Konser: ${targetConcert.title}
- Artis / Penampil / Subtitle: ${targetConcert.subtitle || 'Belum dicantumkan'}
- Tema / Kategori Musik: ${targetConcert.category || 'Musik Umum'}
- Tanggal & Waktu: ${targetConcert.date} ${targetConcert.time ? '· ' + targetConcert.time : ''}
- Lokasi / Venue: ${targetConcert.venue} ${targetConcert.venue_address ? `(${targetConcert.venue_address})` : ''}
- Penyelenggara / Produser: ${targetConcert.producer_name || 'Promotor Resmi LiveTix'}
- Deskripsi Konser: ${targetConcert.description || 'Tidak ada deskripsi tambahan'}
- Total Daya Tampung: ${targetConcert.total_capacity ? targetConcert.total_capacity + ' penonton' : 'Sesuai kapasitas venue'}
- Daftar Kategori & Harga Tiket:
${tiersText}`;

    const systemPrompt = `Anda adalah asisten informasi konser resmi LiveTix.
Tugas Anda adalah menjelaskan konser kepada penonton secara ramah, santun, dan ringkas dalam Bahasa Indonesia berdasarkan DATA RESMI yang diberikan.

ATURAN WAJIB - BACA BAIK-BAIK:
1. Data konser yang diberikan di bawah adalah DATA RESMI yang sudah TERVERIFIKASI dari database LiveTix. Konser INI MEMANG ADA dan SUDAH TERDAFTAR di LiveTix.
2. JANGAN pernah mengatakan konser "tidak terdaftar", "tidak ada di sistem", atau kalimat sejenis. Konser yang datanya diberikan PASTI TERDAFTAR.
3. Jawab HANYA berdasarkan DATA KONSER yang disediakan. DILARANG mengarang informasi yang tidak ada di data.
4. Jika informasi tertentu tidak tercantum dalam data (misalnya artis pendukung atau dresscode), katakan dengan ramah bahwa informasi tersebut belum tersedia.
5. Gunakan bahasa Indonesia yang santun, ramah, dan ringkas (maksimal 2-3 paragraf singkat atau poin-poin yang mudah dibaca).
6. Akhiri dengan ajakan ramah untuk memesan tiket langsung di aplikasi LiveTix sebelum kuota habis.`;

    const userPrompt = `Berikut adalah DATA RESMI konser yang SUDAH TERDAFTAR di platform LiveTix:

${concertContext}

Pertanyaan Penonton: "${cleanQuery}"

Tolong jelaskan konser di atas berdasarkan data yang diberikan. Konser ini SUDAH TERDAFTAR dan TERSEDIA di LiveTix.`;

    const aiExplanation = await callGemini(systemPrompt, userPrompt, false);

    return res.json({
      success: true,
      matched: true,
      ambiguous: false,
      message: aiExplanation.trim(),
      concert: targetConcert,
      matchedConcerts: [targetConcert]
    });
  } catch (err) {
    console.error('[Fitur 1] Exception:', err);
    return res.status(500).json({
      success: false,
      message: 'Terjadi kendala saat memproses informasi konser dengan AI.',
      error: err.message
    });
  }
});

// ============================================================================
// FITUR 2: PENCARIAN KONSER DENGAN AI (SISI USER)
// ============================================================================
/**
 * Alur:
 * 1. AI mengubah kalimat pencarian bahasa alami user menjadi filter terstruktur JSON:
 *    { "genre": "rock", "year": 2027, "location": "Malang", "keyword": null, "min_price": null, "max_price": null }
 * 2. Backend memakai JSON tersebut untuk memfilter data konser di database Supabase
 * 3. Hasil dikembalikan ke aplikasi.
 * 4. Jika kosong, kirim pesan "Konser tidak ditemukan" beserta saran melonggarkan filter.
 */
app.post('/api/ai/search-concerts', async (req, res) => {
  try {
    const { query } = req.body;
    if (!query || typeof query !== 'string' || query.trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Query pencarian tidak boleh kosong.'
      });
    }

    const naturalQuery = query.trim();

    // System prompt ketat untuk mengubah natural query menjadi JSON
    const systemInstruction = `Anda adalah AI parser pencarian konser LiveTix.
Tugas Anda adalah mengubah kalimat pencarian bahasa alami pengguna menjadi filter terstruktur dalam format JSON MURNI.

ATURAN WAJIB:
- Output HANYA berupa JSON valid TANPA format markdown, TANPA triple backticks (\`\`\`json), TANPA penjelasan teks tambahan apa pun.
- Format JSON harus persis seperti ini:
{
  "genre": string atau null,
  "year": integer atau null,
  "location": string atau null,
  "keyword": string atau null,
  "min_price": integer atau null,
  "max_price": integer atau null
}
- Field yang TIDAK disebutkan secara eksplisit oleh pengguna WAJIB diisi null (DILARANG menebak atau berspekulasi).
- Ekstrak genre/tema musik (contoh: "rock", "pop", "jazz", "indie", "metal", "dangdut") ke field "genre".
- Ekstrak tahun 4 digit (contoh: 2026, 2027) ke field "year".
- Ekstrak nama kota atau tempat (contoh: "Malang", "Jakarta", "Bandung", "Surabaya") ke field "location".
- Ekstrak batasan harga angka numerik rupiah jika ada (misal: "di bawah 100 ribu" -> max_price: 100000; "maksimal 50rb" -> max_price: 50000; "di atas 200rb" -> min_price: 200000).
- Ekstrak kata kunci nama artis atau judul acara (misal "Slank", "Hindia", "Coldplay") ke field "keyword".`;

    const userPrompt = `Kalimat pengguna: "${naturalQuery}"`;

    let rawJsonText = await callGemini(systemInstruction, userPrompt, true);
    // Bersihkan backticks markdown jika AI masih menyertakannya
    rawJsonText = rawJsonText.replace(/```json/gi, '').replace(/```/g, '').trim();

    let filter = {};
    try {
      filter = JSON.parse(rawJsonText);
    } catch (parseErr) {
      console.warn('[Fitur 2] JSON parse error, fallback regex:', parseErr);
      const match = rawJsonText.match(/\{[\s\S]*\}/);
      if (match) {
        filter = JSON.parse(match[0]);
      } else {
        filter = { genre: null, year: null, location: null, keyword: naturalQuery, min_price: null, max_price: null };
      }
    }

    // Ambil data konser dari database Supabase
    const { data: rawConcerts, error: dbError } = await supabase
      .from('concerts')
      .select('*, ticket_tiers(*)')
      .in('status', ['published', 'approved'])
      .order('created_at', { ascending: false });

    if (dbError) {
      return res.status(500).json({
        success: false,
        message: 'Gagal mengambil data konser dari database.',
        error: dbError.message
      });
    }

    const concerts = rawConcerts || [];

    // Filter data konser di backend berdasarkan filter yang diekstrak AI
    const filtered = concerts.filter(c => {
      // 1. Filter Genre
      if (filter.genre) {
        const g = filter.genre.toLowerCase();
        const cat = (c.category || '').toLowerCase();
        const tag = (c.tag || '').toLowerCase();
        if (!cat.includes(g) && !tag.includes(g)) return false;
      }

      // 2. Filter Tahun
      if (filter.year) {
        const yrStr = filter.year.toString();
        const dateStr = (c.date || '').toLowerCase();
        const subtitleStr = (c.subtitle || '').toLowerCase();
        const titleStr = (c.title || '').toLowerCase();
        const createdStr = (c.created_at || '');
        if (!dateStr.includes(yrStr) && !subtitleStr.includes(yrStr) && !titleStr.includes(yrStr) && !createdStr.includes(yrStr)) {
          return false;
        }
      }

      // 3. Filter Lokasi / Kota
      if (filter.location) {
        const loc = filter.location.toLowerCase();
        const venue = (c.venue || '').toLowerCase();
        const address = (c.venue_address || '').toLowerCase();
        const subtitle = (c.subtitle || '').toLowerCase();
        if (!venue.includes(loc) && !address.includes(loc) && !subtitle.includes(loc)) {
          return false;
        }
      }

      // 4. Filter Kata Kunci (Artis / Judul)
      if (filter.keyword) {
        const kw = filter.keyword.toLowerCase();
        const title = (c.title || '').toLowerCase();
        const subtitle = (c.subtitle || '').toLowerCase();
        const desc = (c.description || '').toLowerCase();
        if (!title.includes(kw) && !subtitle.includes(kw) && !desc.includes(kw)) {
          return false;
        }
      }

      // 5. Filter Harga
      const tiers = c.ticket_tiers || [];
      const prices = [Number(c.price || 0), ...tiers.map(t => Number(t.price || 0))].filter(p => p > 0);
      const minAvailable = prices.length > 0 ? Math.min(...prices) : Number(c.price || 0);
      const maxAvailable = prices.length > 0 ? Math.max(...prices) : Number(c.price || 0);

      if (filter.min_price != null && maxAvailable < filter.min_price) {
        return false;
      }
      if (filter.max_price != null && minAvailable > filter.max_price) {
        return false;
      }

      return true;
    });

    if (filtered.length === 0) {
      return res.json({
        success: true,
        filter: filter,
        total: 0,
        results: [],
        message: 'Konser tidak ditemukan. Coba longgarkan filter pencarian Anda (misalnya tanpa batasan tahun atau cari di kota lain).'
      });
    }

    return res.json({
      success: true,
      filter: filter,
      total: filtered.length,
      results: filtered,
      message: `Ditemukan ${filtered.length} konser yang sesuai dengan pencarian Anda.`
    });
  } catch (err) {
    console.error('[Fitur 2] Exception:', err);
    return res.status(500).json({
      success: false,
      message: 'Terjadi kendala saat memproses pencarian dengan AI.',
      error: err.message
    });
  }
});

// ============================================================================
// FITUR 3: AI ASSISTANT DESKRIPSI (SISI PRODUSER)
// ============================================================================
/**
 * Alur:
 * 1. Produser menulis instruksi/poin singkat di field deskripsi form Tambah Konser
 * 2. Tombol [AI Assistant] ditekan
 * 3. Dikirim ke backend beserta data form lain yang tersedia (judul, tema, tanggal, lokasi, artis)
 * 4. AI menghasilkan deskripsi konser 2-3 paragraf menarik dan profesional (tanpa menambah fakta fiktif)
 * 5. Teks langsung menggantikan field deskripsi di Flutter dengan opsi Undo
 */
app.post('/api/ai/generate-description', async (req, res) => {
  try {
    const { prompt, title, genre, date, venue, artists } = req.body;

    if (!prompt || typeof prompt !== 'string' || prompt.trim().length < 10) {
      return res.status(400).json({
        success: false,
        message: 'Tuliskan poin-poin atau instruksi deskripsi minimal 10 karakter terlebih dahulu.'
      });
    }

    const cleanPrompt = prompt.trim();

    const systemInstruction = `Anda adalah asisten copywriter profesional untuk platform promotor konser LiveTix.
Tugas Anda adalah membantu produser membuat deskripsi konser yang menarik, profesional, dan menggugah emosi penonton di form "Tambah Konser".

ATURAN KETAT:
1. Gunakan HANYA informasi dan poin-poin yang diberikan oleh produser (judul, tema/genre, tanggal, lokasi, artis, serta poin-poin instruksi).
2. DILARANG KERAS menambahkan fakta baru yang TIDAK disebutkan oleh produser (DILARANG mengarang harga tiket, tanggal baru, atau nama artis/bintang tamu yang tidak ada di input).
3. Buat deskripsi dalam 2-3 paragraf berbahasa Indonesia yang memikat, elegan, dan terstruktur rapi.
4. Output HANYA berupa teks deskripsi konser saja. DILARANG menyertakan salam pembuka (seperti "Berikut adalah deskripsinya:") dan DILARANG menyertakan penutup atau penjelasan tambahan apa pun.`;

    const userPrompt = `DATA KONSER DARI PRODUSER:
- Judul Konser: ${title || 'Belum diisi'}
- Tema / Genre: ${genre || 'Musik'}
- Tanggal & Waktu: ${date || 'Segera Diumumkan'}
- Lokasi / Venue: ${venue || 'Segera Diumumkan'}
- Daftar Artis / Penampil: ${artists || 'Artis Utama'}

POIN-POIN / INSTRUKSI PRODUSER DI FIELD DESKRIPSI:
"${cleanPrompt}"

Tolong buatkan teks deskripsi konser 2-3 paragraf yang menarik berdasarkan data di atas.`;

    const generatedDescription = await callGemini(systemInstruction, userPrompt, false);

    return res.json({
      success: true,
      description: generatedDescription.trim()
    });
  } catch (err) {
    console.error('[Fitur 3] Exception:', err);
    return res.status(500).json({
      success: false,
      message: 'Terjadi kesalahan saat membuat deskripsi dengan AI.',
      error: err.message
    });
  }
});

app.listen(port, () => {
  console.log(`[LiveTix AI Backend] Berjalan di port ${port}`);
  console.log(`[Supabase] Terhubung ke: ${supabaseUrl}`);
  console.log(`[Gemini] Menggunakan model: ${primaryModel}`);
});
