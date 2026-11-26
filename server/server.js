import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';

dotenv.config();

// ============================================================================
// KONFIGURASI (semua dari environment variable)
// ============================================================================
const csv = (value, fallback = '') =>
  (value ?? fallback).split(',').map((s) => s.trim()).filter(Boolean);

const requireEnv = (name) => {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Environment variable ${name} belum diisi`);
  }
  return value;
};

const config = {
  port: process.env.PORT || 3000,

  supabaseUrl: requireEnv('SUPABASE_URL'),
  supabaseKey: requireEnv('SUPABASE_ANON_KEY'),

  geminiApiKey: process.env.GEMINI_API_KEY || '',
  primaryModel: requireEnv('GEMINI_MODEL'),
  fallbackModels: csv(process.env.GEMINI_FALLBACK_MODELS),

  // Kosongkan ALLOWED_ORIGINS untuk mengizinkan semua origin (hanya untuk development)
  allowedOrigins: csv(process.env.ALLOWED_ORIGINS),

  // Status konser yang boleh tampil ke user
  visibleStatuses: csv(process.env.VISIBLE_STATUSES, 'published,approved'),

  // Kata umum yang diabaikan saat mencocokkan nama konser (hanya kata tanya/sapaan,
  // BUKAN kata yang bisa jadi bagian judul konser seperti "konser" atau "tiket")
  stopWords: csv(
    process.env.SEARCH_STOP_WORDS,
    'jelaskan,tentang,mengenai,info,bagaimana,apa,itu,dong,tolong,min,bisa'
  ),

  minBadgeDescriptionLength: Number(process.env.MIN_BADGE_DESCRIPTION_LENGTH || 60),
  maxBadgeLength: Number(process.env.MAX_BADGE_LENGTH || 15),
  maxBadges: Number(process.env.MAX_BADGES || 3),
  minPromptLength: Number(process.env.MIN_PROMPT_LENGTH || 10),
};

const app = express();

app.use(
  cors({
    origin: config.allowedOrigins.length > 0 ? config.allowedOrigins : '*',
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
  })
);
app.use(express.json());

const supabase = createClient(config.supabaseUrl, config.supabaseKey);

// ============================================================================
// HELPER
// ============================================================================

/**
 * Ambil semua konser yang boleh tampil beserta kategori tiketnya.
 * Satu-satunya tempat query ke tabel concerts, jadi kalau skema berubah
 * cukup edit di sini.
 */
async function fetchVisibleConcerts() {
  const { data, error } = await supabase
    .from('concerts')
    .select('*, ticket_tiers(*)')
    .in('status', config.visibleStatuses)
    .order('created_at', { ascending: false });

  if (error) throw Object.assign(new Error(error.message), { isDbError: true });
  return data || [];
}

const lower = (v) => String(v ?? '').toLowerCase();

/**
 * Helper untuk memanggil Google Generative Language (Gemini) API
 */
async function callGemini(systemInstruction, userContent, jsonMode = false) {
  if (!config.geminiApiKey) {
    throw new Error('GEMINI_API_KEY tidak dikonfigurasi di backend');
  }

  const modelsToTry = [
    config.primaryModel,
    ...config.fallbackModels.filter((m) => m !== config.primaryModel),
  ];
  let lastError = null;

  for (const model of modelsToTry) {
    try {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${config.geminiApiKey}`;

      const payload = {
        contents: [
          {
            role: 'user',
            parts: [{ text: userContent }],
          },
        ],
      };

      if (systemInstruction) {
        payload.system_instruction = {
          parts: [{ text: systemInstruction }],
        };
      }

      if (jsonMode) {
        payload.generationConfig = {
          responseMimeType: 'application/json',
        };
      }

      const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      if (!res.ok) {
        const errorText = await res.text();
        throw new Error(`Gemini API HTTP ${res.status}: ${errorText}`);
      }

      const data = await res.json();
      const text = data.candidates?.[0]?.content?.parts?.[0]?.text || '';

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
    timestamp: new Date().toISOString(),
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
        message: 'Pertanyaan pengguna (query) tidak boleh kosong.',
      });
    }

    const cleanQuery = query.trim();

    // 1. Ambil data konser dari Supabase
    let concerts;
    try {
      concerts = await fetchVisibleConcerts();
    } catch (dbErr) {
      console.error('[Fitur 1] Database error:', dbErr);
      return res.status(500).json({
        success: false,
        message: 'Gagal mengambil data konser dari database.',
        error: dbErr.message,
      });
    }

    // 2. Cocokkan query user dengan konser di database
    const qLower = cleanQuery.toLowerCase();
    const queryTokens = qLower
      .replace(/[^\w\s]/gi, ' ')
      .split(/\s+/)
      .filter((t) => t.length > 1 && !config.stopWords.includes(t));

    const scored = concerts.map((c) => {
      const title = lower(c.title);
      const subtitle = lower(c.subtitle);
      const category = lower(c.category);
      const venue = lower(c.venue);
      const desc = lower(c.description);
      const producer = lower(c.producer_name);

      let score = 0;

      // Kecocokan langsung dengan nama
      if (title && (qLower.includes(title) || title.includes(qLower))) {
        score += 50;
      }

      // Cek inisial / akronim (contoh: "HS" untuk "HS Punya Cerita")
      const titleWords = title.split(/\s+/).filter(Boolean);
      const acronym = titleWords.map((w) => w[0]).join('');
      if (queryTokens.some((t) => t === acronym || titleWords.includes(t))) {
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

    const matches = scored
      .filter((item) => item.score > 0)
      .sort((a, b) => b.score - a.score);

    // KASUS 1: Konser tidak ditemukan
    if (matches.length === 0) {
      return res.json({
        success: true,
        matched: false,
        ambiguous: false,
        message:
          'Maaf, konser yang Anda tanyakan tidak ditemukan di dalam sistem LiveTix. Silakan periksa kembali penulisan nama konser, atau gunakan fitur pencarian di halaman Jelajah untuk mengecek konser yang tersedia.',
        matchedConcerts: [],
      });
    }

    // KASUS 2: Beberapa konser cocok dengan skor berdekatan
    const topScore = matches[0].score;
    const closeMatches = matches.filter(
      (m) => m.score >= topScore * 0.75 && m.score >= 20
    );

    if (closeMatches.length > 1 && topScore < 60) {
      const concertListStr = closeMatches
        .map((m, idx) => `${idx + 1}. ${m.concert.title} (${m.concert.venue})`)
        .join('\n');
      return res.json({
        success: true,
        matched: true,
        ambiguous: true,
        message: `Ditemukan beberapa konser yang mirip dengan pertanyaan Anda:\n${concertListStr}\n\nKonser mana yang ingin Anda ketahui lebih lanjut?`,
        matchedConcerts: closeMatches.map((m) => m.concert),
      });
    }

    // KASUS 3: Satu konser paling cocok -> kirim data lengkap ke AI
    const targetConcert = matches[0].concert;
    const tiers = targetConcert.ticket_tiers || [];
    const tiersText =
      tiers.length > 0
        ? tiers
            .map((t) => {
              const quotaRemain = (t.quota || 0) - (t.sold_count || 0);
              return `- Kategori ${t.name}: Rp${Number(t.price).toLocaleString('id-ID')} (Sisa kuota: ${quotaRemain > 0 ? quotaRemain : 'Habis'})`;
            })
            .join('\n')
        : targetConcert.price
          ? `- Harga mulai dari: Rp${Number(targetConcert.price).toLocaleString('id-ID')}`
          : '- Harga belum dicantumkan';

    const concertContext = `DATA RESMI KONSER DARI DATABASE LIVETIX:
- Judul Konser: ${targetConcert.title}
- Artis / Penampil / Subtitle: ${targetConcert.subtitle || 'Belum dicantumkan'}
- Tema / Kategori Musik: ${targetConcert.category || 'Belum dicantumkan'}
- Tanggal & Waktu: ${targetConcert.date || 'Belum dicantumkan'} ${targetConcert.time ? '· ' + targetConcert.time : ''}
- Lokasi / Venue: ${targetConcert.venue || 'Belum dicantumkan'} ${targetConcert.venue_address ? `(${targetConcert.venue_address})` : ''}
- Penyelenggara / Produser: ${targetConcert.producer_name || 'Belum dicantumkan'}
- Deskripsi Konser: ${targetConcert.description || 'Tidak ada deskripsi tambahan'}
- Total Daya Tampung: ${targetConcert.total_capacity ? targetConcert.total_capacity + ' penonton' : 'Belum dicantumkan'}
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
      matchedConcerts: [targetConcert],
    });
  } catch (err) {
    console.error('[Fitur 1] Exception:', err);
    return res.status(500).json({
      success: false,
      message: 'Terjadi kendala saat memproses informasi konser dengan AI.',
      error: err.message,
    });
  }
});

// ============================================================================
// FITUR 2: PENCARIAN KONSER DENGAN AI (SISI USER)
// ============================================================================
/**
 * Alur:
 * 1. AI mengubah kalimat pencarian bahasa alami menjadi filter JSON terstruktur
 * 2. Backend memakai filter tersebut untuk memfilter konser dari Supabase
 * 3. Hasil dikembalikan ke aplikasi
 * 4. Jika kosong, kirim pesan dan saran melonggarkan filter
 */
app.post('/api/ai/search-concerts', async (req, res) => {
  try {
    const { query } = req.body;
    if (!query || typeof query !== 'string' || query.trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Query pencarian tidak boleh kosong.',
      });
    }

    const naturalQuery = query.trim();

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
- Ekstrak kata kunci nama artis atau judul acara (misal "Slank", "Hindia", "Coldplay", "Tulus") ke field "keyword". Kata umum seperti "konser", "tiket", "acara", "rekomendasi", "ada", "apa" BUKAN nama artis dan WAJIB diabaikan (set null).`;

    const userPrompt = `Kalimat pengguna: "${naturalQuery}"`;

    let rawJsonText = await callGemini(systemInstruction, userPrompt, true);
    rawJsonText = rawJsonText.replace(/```json/gi, '').replace(/```/g, '').trim();

    let filter = {};
    try {
      filter = JSON.parse(rawJsonText);
    } catch (parseErr) {
      console.warn('[Fitur 2] JSON parse error, fallback regex:', parseErr);
      const match = rawJsonText.match(/\{[\s\S]*\}/);
      try {
        filter = match
          ? JSON.parse(match[0])
          : { genre: null, year: null, location: null, keyword: naturalQuery, min_price: null, max_price: null };
      } catch (_) {
        filter = { genre: null, year: null, location: null, keyword: naturalQuery, min_price: null, max_price: null };
      }
    }

    // Pembersihan stop words pada keyword agar tidak memblokir pencarian
    if (filter.keyword) {
      const stopWords = [
        'konser', 'tiket', 'musik', 'acara', 'event', 'jadwal', 'rekomendasi',
        'terbaru', 'terdekat', 'ada', 'apa', 'semua', 'dong', 'saja', 'aja',
        'mau', 'cari', 'lihat', 'info', 'daftar', 'tentang', 'yang', 'hari', 'ini'
      ];
      let kwClean = filter.keyword.trim().toLowerCase();
      for (const sw of stopWords) {
        kwClean = kwClean.replace(new RegExp(`\\b${sw}\\b`, 'gi'), '').trim();
      }
      filter.keyword = kwClean.length >= 2 ? kwClean : null;
    }

    let concerts;
    try {
      concerts = await fetchVisibleConcerts();
    } catch (dbErr) {
      return res.status(500).json({
        success: false,
        message: 'Gagal mengambil data konser dari database.',
        error: dbErr.message,
      });
    }

    function matchConcert(c, f) {
      // 1. Genre
      if (f.genre) {
        const g = lower(f.genre);
        if (!lower(c.category).includes(g) && !lower(c.tag).includes(g)) return false;
      }

      // 2. Tahun (hanya berdasarkan tanggal pelaksanaan, bukan created_at)
      if (f.year) {
        const yrStr = String(f.year);
        if (!lower(c.date).includes(yrStr)) return false;
      }

      // 3. Lokasi / Kota
      if (f.location) {
        const loc = lower(f.location);
        if (
          !lower(c.venue).includes(loc) &&
          !lower(c.venue_address).includes(loc) &&
          !lower(c.subtitle).includes(loc)
        ) {
          return false;
        }
      }

      // 4. Kata kunci (artis / judul / deskripsi / genre)
      if (f.keyword) {
        const kw = lower(f.keyword);
        const inTitle = lower(c.title).includes(kw);
        const inSub = lower(c.subtitle).includes(kw);
        const inDesc = lower(c.description).includes(kw);
        const inVenue = lower(c.venue).includes(kw);
        const inCat = lower(c.category).includes(kw);
        if (!inTitle && !inSub && !inDesc && !inVenue && !inCat) {
          return false;
        }
      }

      // 5. Harga
      const tiers = c.ticket_tiers || [];
      const prices = [Number(c.price || 0), ...tiers.map((t) => Number(t.price || 0))].filter(
        (p) => p > 0
      );
      const minAvailable = prices.length > 0 ? Math.min(...prices) : Number(c.price || 0);
      const maxAvailable = prices.length > 0 ? Math.max(...prices) : Number(c.price || 0);

      if (f.min_price != null && maxAvailable < f.min_price) return false;
      if (f.max_price != null && minAvailable > f.max_price) return false;

      return true;
    }

    let filtered = concerts.filter((c) => matchConcert(c, filter));

    // Relaksasi filter cerdas agar permintaan user selalu menghasilkan data konser yang relevan
    let resultMessage = '';
    if (filtered.length > 0) {
      resultMessage = `Ditemukan ${filtered.length} konser yang sesuai dengan pencarian Anda.`;
    } else {
      // 1. Coba cari dengan kata kunci saja
      if (filter.keyword) {
        filtered = concerts.filter((c) => matchConcert(c, { keyword: filter.keyword }));
        if (filtered.length > 0) {
          resultMessage = `Menemukan ${filtered.length} konser terkait "${filter.keyword}".`;
        }
      }
      // 2. Jika masih 0, coba cari dengan lokasi saja
      if (filtered.length === 0 && filter.location) {
        filtered = concerts.filter((c) => matchConcert(c, { location: filter.location }));
        if (filtered.length > 0) {
          resultMessage = `Menemukan ${filtered.length} konser di area ${filter.location}.`;
        }
      }
      // 3. Jika masih 0, coba cari dengan genre saja
      if (filtered.length === 0 && filter.genre) {
        filtered = concerts.filter((c) => matchConcert(c, { genre: filter.genre }));
        if (filtered.length > 0) {
          resultMessage = `Menemukan ${filtered.length} konser genre ${filter.genre}.`;
        }
      }
      // 4. Jika masih 0 sama sekali atau query umum, tampilkan konser yang tersedia di platform
      if (filtered.length === 0) {
        filtered = concerts;
        resultMessage = `Tidak ada konser dengan kriteria persis tersebut. Menampilkan ${concerts.length} konser yang tersedia di LiveTix:`;
      }
    }

    return res.json({
      success: true,
      filter,
      total: filtered.length,
      results: filtered,
      message: resultMessage,
    });
  } catch (err) {
    console.error('[Fitur 2] Exception:', err);
    return res.status(500).json({
      success: false,
      message: 'Terjadi kendala saat memproses pencarian dengan AI.',
      error: err.message,
    });
  }
});

// ============================================================================
// FITUR 3: AI ASSISTANT DESKRIPSI (SISI PRODUSER)
// ============================================================================
/**
 * Alur:
 * 1. Produser menulis poin singkat di field deskripsi form Tambah Konser
 * 2. Tombol [AI Assistant] ditekan
 * 3. Dikirim ke backend beserta data form lain yang tersedia
 * 4. AI menghasilkan deskripsi singkat 1 paragraf (tanpa fakta fiktif)
 * 5. Teks menggantikan field deskripsi di Flutter dengan opsi Undo
 */
app.post('/api/ai/generate-description', async (req, res) => {
  try {
    const { prompt, title, genre, date, venue, artists } = req.body;

    if (!prompt || typeof prompt !== 'string' || prompt.trim().length < config.minPromptLength) {
      return res.status(400).json({
        success: false,
        message: `Tuliskan poin-poin atau instruksi deskripsi minimal ${config.minPromptLength} karakter terlebih dahulu.`,
      });
    }

    const cleanPrompt = prompt.trim();

    const systemInstruction = `Anda adalah asisten copywriter profesional untuk platform promotor konser LiveTix.
Tugas Anda adalah membantu produser membuat deskripsi konser yang menarik, profesional, dan menggugah emosi penonton di form "Tambah Konser".

ATURAN KETAT:
1. Gunakan HANYA informasi dan poin-poin yang diberikan oleh produser (judul, tema/genre, tanggal, lokasi, artis, serta poin-poin instruksi).
2. DILARANG KERAS menambahkan fakta baru yang TIDAK disebutkan oleh produser (DILARANG mengarang harga tiket, tanggal baru, atau nama artis/bintang tamu yang tidak ada di input).
3. Buat deskripsi SINGKAT dan PADAT: 1 paragraf saja, 3-4 kalimat, maksimal 60 kata, berbahasa Indonesia yang jelas dan memikat.
4. Langsung sebutkan hal paling menarik (penampil, suasana, pengalaman menonton) di kalimat pertama agar pembaca tertarik sejak awal. Jangan bertele-tele atau mengulang informasi yang sama.
5. Output HANYA berupa teks deskripsi konser saja. DILARANG menyertakan salam pembuka (seperti "Berikut adalah deskripsinya:") dan DILARANG menyertakan penutup atau penjelasan tambahan apa pun.`;

    const userPrompt = `DATA KONSER DARI PRODUSER:
- Judul Konser: ${title || 'Belum diisi'}
- Tema / Genre: ${genre || 'Belum diisi'}
- Tanggal & Waktu: ${date || 'Belum diisi'}
- Lokasi / Venue: ${venue || 'Belum diisi'}
- Daftar Artis / Penampil: ${artists || 'Belum diisi'}

POIN-POIN / INSTRUKSI PRODUSER DI FIELD DESKRIPSI:
"${cleanPrompt}"

Tolong buatkan deskripsi konser singkat (1 paragraf, 3-4 kalimat, maksimal 60 kata) yang padat, jelas, dan langsung membuat orang tertarik berdasarkan data di atas.`;

    const generatedDescription = await callGemini(systemInstruction, userPrompt, false);

    return res.json({
      success: true,
      description: generatedDescription.trim(),
    });
  } catch (err) {
    console.error('[Fitur 3] Exception:', err);
    return res.status(500).json({
      success: false,
      message: 'Terjadi kesalahan saat membuat deskripsi dengan AI.',
      error: err.message,
    });
  }
});

// ============================================================================
// FITUR 4: BADGES BANNER OTOMATIS DARI DESKRIPSI KONSER (SISI PRODUSER)
// ============================================================================
/**
 * Alur:
 * 1. Produser mengisi deskripsi konser di step 1 form Tambah Konser
 * 2. Saat masuk step ringkasan, Flutter mengirim deskripsi ke endpoint ini
 * 3. AI menilai apakah deskripsi memuat kata kunci yang cukup menarik
 * 4. Jika ada: badge singkat. Jika tidak: array kosong.
 */
app.post('/api/ai/generate-badges', async (req, res) => {
  try {
    const { description, title, genre, date, venue } = req.body || {};
    const cleanDescription = typeof description === 'string' ? description.trim() : '';

    // Deskripsi terlalu pendek untuk dinilai: badge dibiarkan kosong.
    if (cleanDescription.length < config.minBadgeDescriptionLength) {
      return res.json({ success: true, badges: [] });
    }

    const systemInstruction = `Anda adalah editor copywriting untuk platform promotor konser LiveTix.
Tugas Anda: menentukan apakah deskripsi konser memiliki kata kunci yang cukup menarik untuk dijadikan badge singkat pada banner konser.

ATURAN KETAT:
1. Balas HANYA dengan JSON valid berformat {"badges": ["...", "..."]} tanpa teks pembuka, penutup, atau markdown.
2. Jumlah badge 0 sampai ${config.maxBadges}. Kosongkan array ({"badges": []}) jika deskripsi generik, tidak spesifik, atau tidak punya kata kunci menarik.
3. Setiap badge MAKSIMAL ${config.maxBadgeLength} karakter, 1-3 kata, tanpa emoji, tanpa tanda kutip, tanpa titik di akhir.
4. Ambil HANYA fakta yang tertulis di deskripsi: genre/jenis musik, kata "festival", batas usia (mis. "17+"), suasana (mis. "Outdoor", "Akustik", "Intim"), jumlah penampil, atau nama artis utama.
5. DILARANG mengarang fakta yang tidak ada di deskripsi (harga, gratis, jumlah hari, kota, bintang tamu).
6. Prioritaskan kata yang memicu rasa penasaran atau keinginan menonton. Hindari kata pasif seperti "Acara", "Konser", atau "Musik" saja.
7. Contoh badge yang baik: "Festival Musik", "17+", "Outdoor", "Akustik", "Line-up 5 Band", "Satu Malam".`;

    const userPrompt = `DATA KONSER:
- Judul: ${title || 'Belum diisi'}
- Tema / Genre: ${genre || 'Tidak disebutkan'}
- Tanggal: ${date || 'Tidak disebutkan'}
- Venue: ${venue || 'Tidak disebutkan'}

DESKRIPSI KONSER:
"""${cleanDescription}"""

Tentukan badge banner yang layak ditampilkan. Jika tidak ada kata kunci yang cukup kuat, kembalikan {"badges": []}.`;

    let raw = await callGemini(systemInstruction, userPrompt, true);
    raw = String(raw)
      .trim()
      .replace(/^```(?:json)?/i, '')
      .replace(/```$/, '')
      .trim();

    let parsed = null;
    try {
      parsed = JSON.parse(raw);
    } catch (_) {
      parsed = null;
    }

    let candidates = [];
    if (Array.isArray(parsed)) {
      candidates = parsed;
    } else if (parsed && Array.isArray(parsed.badges)) {
      candidates = parsed.badges;
    }

    // Validasi ulang di server: jangan percaya output AI mentah.
    const badges = [];
    for (const item of candidates) {
      const text = String(item ?? '').replace(/\s+/g, ' ').trim();
      if (!text || text.length > config.maxBadgeLength) continue;
      if (badges.some((b) => b.toLowerCase() === text.toLowerCase())) continue;
      badges.push(text);
      if (badges.length === config.maxBadges) break;
    }

    return res.json({ success: true, badges });
  } catch (err) {
    console.error('[Fitur 4] Exception:', err);
    return res.status(500).json({
      success: false,
      badges: [],
      message: 'Terjadi kesalahan saat membuat badge dengan AI.',
      error: err.message,
    });
  }
});

app.listen(config.port, () => {
  console.log(`[LiveTix AI Backend] Berjalan di port ${config.port}`);
  console.log(`[Supabase] Terhubung ke: ${config.supabaseUrl}`);
  console.log(`[Gemini] Model utama: ${config.primaryModel}`);
  console.log(`[Gemini] Model fallback: ${config.fallbackModels.join(', ') || '(tidak ada)'}`);
});