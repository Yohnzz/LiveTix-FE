import os
import base64
import subprocess

def get_base64_img(path):
    if not os.path.exists(path):
        return ''
    ext = os.path.splitext(path)[1].lower().replace('.', '')
    if ext == 'jpg': ext = 'jpeg'
    with open(path, 'rb') as f:
        data = base64.b64encode(f.read()).decode('utf-8')
    return f'data:image/{ext};base64,{data}'

script_dir = os.path.dirname(os.path.abspath(__file__))
img_dir = os.path.join(script_dir, 'images')

logo_b64 = get_base64_img(os.path.join(img_dir, 'livetix-logo.png'))
step2_b64 = get_base64_img(os.path.join(img_dir, 'step2_concert_detail.jpg'))
step3_b64 = get_base64_img(os.path.join(img_dir, 'step3_select_tier.jpg'))
step4_b64 = get_base64_img(os.path.join(img_dir, 'step4_checkout_stepper.jpg'))
step5_b64 = get_base64_img(os.path.join(img_dir, 'step5_payment_screen_qris.jpg'))
step5b_b64 = get_base64_img(os.path.join(img_dir, 'step5b_payment_breakdown.jpg'))
step6_b64 = get_base64_img(os.path.join(img_dir, 'step6_ticket_pending.jpg'))
step7_b64 = get_base64_img(os.path.join(img_dir, 'step7_eticket_qr.png'))

print('Compiling Flow Transaksi HTML...')

html_flow = f'''<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<title>LiveTix - Dokumen Alur Transaksi & Customer Journey Midtrans</title>
<style>
  @page {{
    size: A4 portrait;
    margin: 12mm 15mm 15mm 15mm;
  }}
  * {{
    box-sizing: border-box;
    margin: 0;
    padding: 0;
  }}
  body {{
    font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, Helvetica, Arial, sans-serif;
    color: #1E293B;
    background-color: #FFFFFF;
    line-height: 1.5;
    font-size: 11pt;
  }}
  .page {{
    page-break-after: always;
    padding-bottom: 20px;
    position: relative;
    min-height: 270mm;
  }}
  .page:last-child {{
    page-break-after: avoid;
  }}
  
  /* Header & Footer */
  .doc-header {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 2px solid #1B2A8C;
    padding-bottom: 10px;
    margin-bottom: 20px;
  }}
  .doc-header .brand {{
    display: flex;
    align-items: center;
    gap: 12px;
  }}
  .doc-header img.logo {{
    height: 38px;
    object-fit: contain;
  }}
  .doc-header .brand-text h1 {{
    font-size: 16pt;
    font-weight: 800;
    color: #1B2A8C;
    letter-spacing: -0.5px;
  }}
  .doc-header .brand-text p {{
    font-size: 8.5pt;
    color: #64748B;
    font-weight: 500;
  }}
  .doc-badge {{
    background: #EFF6FF;
    color: #1D4ED8;
    border: 1px solid #BFDBFE;
    padding: 4px 10px;
    border-radius: 6px;
    font-size: 8.5pt;
    font-weight: 700;
  }}
  
  .footer-note {{
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    display: flex;
    justify-content: space-between;
    font-size: 8pt;
    color: #94A3B8;
    border-top: 1px solid #E2E8F0;
    padding-top: 6px;
  }}

  /* Cover Page */
  .cover-card {{
    background: linear-gradient(135deg, #0F172A 0%, #1B2A8C 100%);
    color: white;
    padding: 35px 30px;
    border-radius: 16px;
    margin-top: 25px;
    margin-bottom: 25px;
    box-shadow: 0 10px 25px rgba(27, 42, 140, 0.2);
  }}
  .cover-card .tag {{
    display: inline-block;
    background: rgba(255, 255, 255, 0.15);
    backdrop-filter: blur(4px);
    border: 1px solid rgba(255, 255, 255, 0.25);
    color: #F8FAFC;
    padding: 4px 12px;
    border-radius: 20px;
    font-size: 8.5pt;
    font-weight: 600;
    margin-bottom: 14px;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }}
  .cover-card h2 {{
    font-size: 21pt;
    font-weight: 800;
    line-height: 1.25;
    margin-bottom: 12px;
  }}
  .cover-card p {{
    font-size: 11pt;
    color: #CBD5E1;
    max-width: 90%;
    line-height: 1.5;
  }}

  .meta-grid {{
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 14px;
    margin-bottom: 25px;
  }}
  .meta-item {{
    background: #F8FAFC;
    border: 1px solid #E2E8F0;
    border-radius: 10px;
    padding: 12px 14px;
  }}
  .meta-item label {{
    font-size: 8.5pt;
    color: #64748B;
    text-transform: uppercase;
    font-weight: 700;
    display: block;
    margin-bottom: 2px;
  }}
  .meta-item span {{
    font-size: 10.5pt;
    font-weight: 700;
    color: #0F172A;
  }}

  /* Section Title */
  .section-title {{
    font-size: 13pt;
    font-weight: 800;
    color: #0F172A;
    border-left: 4px solid #1B2A8C;
    padding-left: 10px;
    margin-bottom: 14px;
    display: flex;
    align-items: center;
    gap: 8px;
  }}
  
  /* Step Layout */
  .step-box {{
    background: #FFFFFF;
    border: 1px solid #E2E8F0;
    border-radius: 14px;
    padding: 16px;
    margin-bottom: 18px;
    display: flex;
    gap: 18px;
    align-items: flex-start;
  }}
  .step-num {{
    background: #1B2A8C;
    color: white;
    width: 32px;
    height: 32px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 800;
    font-size: 12pt;
    flex-shrink: 0;
  }}
  .step-body {{
    flex: 1;
  }}
  .step-header {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 6px;
  }}
  .step-header h3 {{
    font-size: 11.5pt;
    font-weight: 700;
    color: #0F172A;
  }}
  .step-tag {{
    font-size: 8pt;
    font-weight: 700;
    padding: 2px 8px;
    border-radius: 4px;
    background: #F1F5F9;
    color: #475467;
  }}
  .step-desc {{
    font-size: 9.5pt;
    color: #475467;
    margin-bottom: 12px;
    line-height: 1.45;
  }}
  .step-highlight {{
    background: #F8FAFC;
    border-left: 3px solid #10B981;
    padding: 6px 10px;
    font-size: 8.5pt;
    color: #1E293B;
    margin-bottom: 10px;
    border-radius: 0 6px 6px 0;
  }}
  
  /* Mockup Frame */
  .mockup-container {{
    display: flex;
    justify-content: center;
    align-items: center;
    gap: 16px;
    margin-top: 8px;
  }}
  .phone-frame {{
    width: 210px;
    background: #0F172A;
    border: 5px solid #1E293B;
    border-radius: 20px;
    box-shadow: 0 6px 16px rgba(0,0,0,0.12);
    overflow: hidden;
    display: flex;
    flex-direction: column;
    align-items: center;
  }}
  .phone-screen {{
    width: 100%;
    height: auto;
    display: block;
    object-fit: cover;
  }}
  .img-caption {{
    font-size: 8pt;
    color: #64748B;
    text-align: center;
    margin-top: 4px;
    font-weight: 600;
  }}

  /* Diagram Flow */
  .flow-diagram {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    background: #F8FAFC;
    border: 1px solid #E2E8F0;
    border-radius: 12px;
    padding: 12px 14px;
    margin-bottom: 20px;
  }}
  .flow-node {{
    background: white;
    border: 1px solid #CBD5E1;
    border-radius: 8px;
    padding: 8px 10px;
    text-align: center;
    font-size: 8pt;
    font-weight: 700;
    color: #1E293B;
    width: 90px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.03);
  }}
  .flow-node.active {{
    border-color: #1B2A8C;
    background: #EFF6FF;
    color: #1B2A8C;
  }}
  .flow-arrow {{
    color: #94A3B8;
    font-size: 12pt;
    font-weight: 800;
  }}

  /* Spec Table */
  table.spec-table {{
    width: 100%;
    border-collapse: collapse;
    font-size: 9pt;
    margin-bottom: 16px;
  }}
  table.spec-table th, table.spec-table td {{
    border: 1px solid #E2E8F0;
    padding: 8px 10px;
    text-align: left;
  }}
  table.spec-table th {{
    background: #F8FAFC;
    color: #475467;
    font-weight: 700;
  }}
  table.spec-table tr:nth-child(even) {{
    background: #FAFAFA;
  }}
</style>
</head>
<body>

<!-- ================= PAGE 1: COVER & OVERVIEW ================= -->
<div class="page">
  <div class="doc-header">
    <div class="brand">
      <img src="{logo_b64}" class="logo" alt="LiveTix Logo">
      <div class="brand-text">
        <h1>LiveTix Official</h1>
        <p>Platform Pemesanan Tiket Konser & Manajemen Event</p>
      </div>
    </div>
    <div class="doc-badge">Dokumen Verifikasi Midtrans</div>
  </div>

  <div class="cover-card">
    <span class="tag">Dokumen Teknis & Alur Transaksi</span>
    <h2>Customer Journey & Payment Flow<br>Integrasi Midtrans Payment Gateway</h2>
    <p>Penjelasan lengkap alur pemesanan tiket konser dari sisi pengguna, mulai dari eksplorasi event, pemilihan tiket, kalkulasi harga transparan, hingga pembayaran otomatis melalui Midtrans Snap & Core API.</p>
  </div>

  <div class="meta-grid">
    <div class="meta-item">
      <label>Nama Brand / Aplikasi</label>
      <span>LiveTix (Mobile App & Cloud Backend)</span>
    </div>
    <div class="meta-item">
      <label>Tipe Entitas Merchant</label>
      <span>Usaha Perorangan (Individu / Non-Badan Hukum)</span>
    </div>
    <div class="meta-item">
      <label>Kategori Bisnis</label>
      <span>Ticketing / Tiket Hiburan & Konser Musik</span>
    </div>
    <div class="meta-item">
      <label>Metode Pembayaran Midtrans</label>
      <span>QRIS (Universal E-Wallet) & Virtual Account Bank</span>
    </div>
    <div class="meta-item">
      <label>Masa Berlaku Pembayaran</label>
      <span>15 Menit (Realtime Server Countdown & Auto-Release)</span>
    </div>
    <div class="meta-item">
      <label>Integrasi Keamanan</label>
      <span>Webhook Server-to-Server dengan SHA512 Signature Key</span>
    </div>
  </div>

  <div class="section-title">Ringkasan Alur Pembayaran Terintegrasi Midtrans</div>
  <div class="flow-diagram">
    <div class="flow-node active">1. Buka App<br>& Pilih Konser</div>
    <div class="flow-arrow">&rarr;</div>
    <div class="flow-node active">2. Pilih Kategori<br>& Jumlah Tiket</div>
    <div class="flow-arrow">&rarr;</div>
    <div class="flow-node active">3. Checkout<br>& Data Pemesan</div>
    <div class="flow-arrow">&rarr;</div>
    <div class="flow-node active">4. Pilih Metode<br>(QRIS / VA)</div>
    <div class="flow-arrow">&rarr;</div>
    <div class="flow-node active">5. Bayar di<br>Midtrans Page</div>
    <div class="flow-arrow">&rarr;</div>
    <div class="flow-node active">6. Webhook Lunas<br>& Terbit E-Ticket</div>
  </div>

  <table class="spec-table">
    <thead>
      <tr>
        <th style="width: 25%;">Komponen</th>
        <th style="width: 35%;">Spesifikasi / Implementasi</th>
        <th style="width: 40%;">Fungsi untuk Pengguna</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><b>Metode Bayar QRIS</b></td>
        <td>Midtrans Core API / Snap (GoPay, OVO, Dana, ShopeePay, BCA)</td>
        <td>Memudahkan penonton membayar instan lewat scan barcode standar Bank Indonesia.</td>
      </tr>
      <tr>
        <td><b>Virtual Account Bank</b></td>
        <td>BCA VA, Mandiri Multipayment, BRI BRIVA, SeaBank VA</td>
        <td>Nomor pembayaran unik otomatis dengan nominal terkunci per transaksi.</td>
      </tr>
      <tr>
        <td><b>Batas Waktu Bayar</b></td>
        <td>15 Menit Realtime Server Lock</td>
        <td>Stok tiket direservasi 15 menit. Jika lewat batas waktu, tiket otomatis kembali ke stok publik.</td>
      </tr>
      <tr>
        <td><b>Tiket Elektronik (E-Ticket)</b></td>
        <td>QR Code Digital Anti-Pemalsuan (Kuota scan maks. sesuai pax)</td>
        <td>Tiket terbit seketika di menu Tiket Saya setelah webhook Midtrans berstatus Settlement.</td>
      </tr>
    </tbody>
  </table>

  <div class="footer-note">
    <span>LiveTix - Customer Journey & Payment Flow Document</span>
    <span>Halaman 1 dari 4</span>
  </div>
</div>

<!-- ================= PAGE 2: STEPS 1 - 3 ================= -->
<div class="page">
  <div class="doc-header">
    <div class="brand">
      <img src="{logo_b64}" class="logo" alt="LiveTix Logo">
      <div class="brand-text">
        <h1>LiveTix Official</h1>
        <p>Alur Transaksi Customer Journey: Eksplorasi Hingga Pemilihan Tiket</p>
      </div>
    </div>
    <div class="doc-badge">Tahap 1 &mdash; 3</div>
  </div>

  <!-- Step 1 & 2 -->
  <div class="step-box">
    <div class="step-num">1</div>
    <div class="step-body">
      <div class="step-header">
        <h3>Langkah 1 & 2: Eksplorasi Konser & Membuka Halaman Detail Acara</h3>
        <span class="step-tag">User Journey &bull; Front-End</span>
      </div>
      <p class="step-desc">
        Customer membuka aplikasi LiveTix, menelusuri katalog konser musik terkini di menu Beranda atau Jelajah. Saat memilih konser yang diminati, customer diarahkan ke <b>Halaman Detail Konser</b> yang memuat poster acara 16:9, tanggal dan jam pertunjukan, lokasi gedung/venue terverifikasi peta digital, deskripsi lengkap, serta susunan artis penampil (line-up).
      </p>
      <div class="step-highlight">
        &bull; <b>Aksi Customer:</b> Membaca informasi konser lalu menekan tombol aksi utama <b>"Beli Tiket"</b> pada bilah navigasi bawah.
      </div>
    </div>
    <div class="phone-frame" style="width: 170px;">
      <img src="{step2_b64}" class="phone-screen" alt="Detail Konser">
      <div class="img-caption">Layar Detail Konser</div>
    </div>
  </div>

  <!-- Step 3 -->
  <div class="step-box">
    <div class="step-num">2</div>
    <div class="step-body">
      <div class="step-header">
        <h3>Langkah 3: Pemilihan Kategori / Tier Tiket & Jumlah Pembelian (Pax)</h3>
        <span class="step-tag">Pricing Engine &bull; Stock Check</span>
      </div>
      <p class="step-desc">
        Pada layar pemilihan tiket, customer memilih kategori tiket (seperti <b>VIP, Festival, atau Regular</b>) serta kuantitas jumlah tiket yang diinginkan (maksimal 4 tiket per akun guna mencegah calo).<br>
        Sistem secara transparan memperlihatkan rincian harga sesuai rumus resmi platform:
      </p>
      <ul style="font-size: 9pt; color: #475467; margin-left: 20px; margin-bottom: 8px;">
        <li><b>Harga Tiket Dasar (Nett):</b> Ditetapkan langsung oleh Produser konser.</li>
        <li><b>Pajak Hiburan Resmi:</b> 10% dari harga tiket dasar (kepatuhan regulasi daerah).</li>
        <li><b>Biaya Layanan Platform:</b> 2% (biaya operasional pemeliharaan sistem LiveTix).</li>
      </ul>
      <div class="step-highlight">
        &bull; <b>Validasi Stok:</b> Sistem mengecek ketersediaan kuota tier secara atomic di database agar tidak terjadi overbooking.
      </div>
    </div>
    <div class="phone-frame" style="width: 170px;">
      <img src="{step3_b64}" class="phone-screen" alt="Pilih Kategori Tiket">
      <div class="img-caption">Pilih Kategori Tiket</div>
    </div>
  </div>

  <div class="footer-note">
    <span>LiveTix - Customer Journey & Payment Flow Document</span>
    <span>Halaman 2 dari 4</span>
  </div>
</div>

<!-- ================= PAGE 3: STEPS 4 - 6 ================= -->
<div class="page">
  <div class="doc-header">
    <div class="brand">
      <img src="{logo_b64}" class="logo" alt="LiveTix Logo">
      <div class="brand-text">
        <h1>LiveTix Official</h1>
        <p>Alur Transaksi Customer Journey: Checkout & Halaman Pembayaran Midtrans</p>
      </div>
    </div>
    <div class="doc-badge">Tahap 4 &mdash; 6</div>
  </div>

  <!-- Step 4 -->
  <div class="step-box">
    <div class="step-num">3</div>
    <div class="step-body">
      <div class="step-header">
        <h3>Langkah 4: Konfirmasi Identitas Pemesan & Ringkasan Checkout (Stepper 1-2)</h3>
        <span class="step-tag">Customer Identification</span>
      </div>
      <p class="step-desc">
        Customer memeriksa identitas data diri pembeli (Nama Lengkap, Nomor NIK KTP, Alamat Email untuk pengiriman bukti tiket, dan Nomor Handphone/WhatsApp).<br>
        Seluruh pesanan dirangkum dalam kartu ringkasan sebelum pembuatan ID tagihan Midtrans.
      </p>
      <div class="step-highlight">
        &bull; <b>Keamanan Transaksi:</b> Menggunakan NIK resmi guna memastikan keaslian kepemilikan tiket saat proses check-in gate konser.
      </div>
    </div>
    <div class="phone-frame" style="width: 155px;">
      <img src="{step4_b64}" class="phone-screen" alt="Checkout Stepper">
      <div class="img-caption">Ringkasan Checkout</div>
    </div>
  </div>

  <!-- Step 5 & 6 -->
  <div class="step-box">
    <div class="step-num">4</div>
    <div class="step-body">
      <div class="step-header">
        <h3>Langkah 5 & 6: Pemilihan Kanal & Diarahkan ke Halaman Pembayaran Midtrans</h3>
        <span class="step-tag">Midtrans Charge &bull; Payment Page</span>
      </div>
      <p class="step-desc">
        Customer memilih kanal pembayaran (<b>QRIS</b> atau <b>Virtual Account Bank</b>). Aplikasi memanggil backend endpoint <code>create-payment</code> untuk menerbitkan tagihan Midtrans secara resmi.<br>
        Customer kemudian diarahkan ke <b>Halaman Pembayaran (Payment Screen)</b> yang memuat:
      </p>
      <ul style="font-size: 8.5pt; color: #475467; margin-left: 18px; margin-bottom: 8px;">
        <li><b>Barcode QRIS Resmi:</b> Berlogo QRIS Standar Bank Indonesia yang dapat di-scan dari aplikasi perbankan apa pun.</li>
        <li><b>Batas Waktu Pembayaran 15 Menit:</b> Dilengkapi waktu mulai dan waktu kedaluwarsa server yang realtime.</li>
        <li><b>Rincian Tagihan Terkunci:</b> Nominal pasti tanpa selisih.</li>
        <li><b>Panduan Pembayaran Lengkap:</b> Tata cara bayar langkah demi langkah.</li>
      </ul>
      <div class="step-highlight">
        &bull; <b>Status Pending:</b> Pesanan tersimpan di menu Tiket Saya dengan status <i>Menunggu Pembayaran</i> selama jendela 15 menit.
      </div>
    </div>
    <div class="mockup-container" style="gap: 10px;">
      <div class="phone-frame" style="width: 145px;">
        <img src="{step5_b64}" class="phone-screen" alt="Payment QRIS">
        <div class="img-caption">Halaman QRIS Midtrans</div>
      </div>
      <div class="phone-frame" style="width: 145px;">
        <img src="{step5b_b64}" class="phone-screen" alt="Payment Breakdown">
        <div class="img-caption">Rincian Pembayaran</div>
      </div>
    </div>
  </div>

  <div class="footer-note">
    <span>LiveTix - Customer Journey & Payment Flow Document</span>
    <span>Halaman 3 dari 4</span>
  </div>
</div>

<!-- ================= PAGE 4: STEP 7 & WEBHOOK VERIFICATION ================= -->
<div class="page">
  <div class="doc-header">
    <div class="brand">
      <img src="{logo_b64}" class="logo" alt="LiveTix Logo">
      <div class="brand-text">
        <h1>LiveTix Official</h1>
        <p>Alur Transaksi Customer Journey: Notifikasi Webhook & Penerbitan E-Ticket</p>
      </div>
    </div>
    <div class="doc-badge">Tahap 7 &mdash; Penyelesaian</div>
  </div>

  <!-- Step 7 -->
  <div class="step-box">
    <div class="step-num">5</div>
    <div class="step-body">
      <div class="step-header">
        <h3>Langkah 7: Verifikasi Webhook Otomatis & Penerbitan Tiket Elektronik (E-Ticket)</h3>
        <span class="step-tag">Webhook Notification &bull; E-Ticket Issued</span>
      </div>
      <p class="step-desc">
        Segera setelah customer menyelesaikan pembayaran di aplikasi m-banking atau e-wallet, Midtrans mengirimkan notifikasi HTTP POST (Webhook) ke backend LiveTix. Backend memvalidasi <code>signature_key</code> SHA512 dan status transaksi <code>settlement</code>.<br>
        Setelah valid, pesanan secara otomatis ditandai <b>Lunas (Paid)</b> dan sistem langsung menerbitkan <b>Tiket Elektronik Resmi</b>.
      </p>
      <div class="step-highlight">
        &bull; <b>Fitur Tiket Elektronik:</b> Kode QR Unik, Kuota Scan Gate Crew, Informasi Pintu Masuk (Gate), dan status <i>Aktif</i> yang siap ditunjukkan saat hari konser.
      </div>
    </div>
    <div class="mockup-container" style="gap: 12px;">
      <div class="phone-frame" style="width: 155px;">
        <img src="{step6_b64}" class="phone-screen" alt="Pending Ticket">
        <div class="img-caption">Status Menunggu di Tiket Saya</div>
      </div>
      <div class="phone-frame" style="width: 155px;">
        <img src="{step7_b64}" class="phone-screen" alt="E-Ticket QR">
        <div class="img-caption">Tiket Lunas & QR Code Aktif</div>
      </div>
    </div>
  </div>

  <div class="section-title">Arsitektur Keamanan & Webhook Idempotency</div>
  <table class="spec-table">
    <thead>
      <tr>
        <th>Aspek Keamanan</th>
        <th>Mekanisme Teknis Platform LiveTix</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><b>Validasi Signature Key</b></td>
        <td>Setiap notifikasi webhook diverifikasi dengan mencocokkan hash SHA512: <code>SHA512(order_id + status_code + gross_amount + ServerKey)</code>. Notifikasi tanpa signature yang cocok akan ditolak (HTTP 401).</td>
      </tr>
      <tr>
        <td><b>Anti Tiket Ganda (Idempotensi)</b></td>
        <td>Database menerapkan unique constraint pada <code>order_id</code> dan atomic update lock, mencegah tiket terbit ganda jika notifikasi webhook diterima lebih dari sekali.</td>
      </tr>
      <tr>
        <td><b>Penanganan Kadaluarsa (Expiry)</b></td>
        <td>Jika customer tidak menyelesaikan pembayaran dalam 15 menit, Midtrans mengirim status <code>expire</code> atau server auto-expire, mengembalikan stok tiket ke publik.</td>
      </tr>
      <tr>
        <td><b>Pemisahan Saldo Produser & Biaya Platform</b></td>
        <td>Dana hasil penjualan tiket dialokasikan secara ledger terpisah: Saldo Hasil Tiket untuk Produser konser dan Biaya Aplikasi 2% untuk Platform.</td>
      </tr>
    </tbody>
  </table>

  <div style="margin-top: 15px; background: #F8FAFC; border: 1px dashed #CBD5E1; border-radius: 8px; padding: 12px; font-size: 8.5pt; color: #475467;">
    <b>Pernyataan Merchant:</b> Seluruh alur transaksi di atas telah diuji dan berfungsi secara penuh pada aplikasi LiveTix terhubung dengan Midtrans Payment Gateway. Dokumen ini dilampirkan sebagai bukti alur customer journey resmi untuk kelengkapan aktivasi akun merchant Midtrans.
  </div>

  <div class="footer-note">
    <span>LiveTix - Customer Journey & Payment Flow Document</span>
    <span>Halaman 4 dari 4</span>
  </div>
</div>

</body>
</html>'''

flow_html_path = os.path.join(script_dir, 'LiveTix_Flow_Transaksi_Midtrans.html')
with open(flow_html_path, 'w', encoding='utf-8') as f:
    f.write(html_flow)
print('Flow Transaksi HTML saved to:', flow_html_path)

# ================= DOCUMENT 2: SURAT PERNYATAAN USAHA PERORANGAN =================
print('Compiling Surat Pernyataan HTML...')

html_surat = f'''<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<title>Surat Pernyataan Usaha Perorangan - LiveTix</title>
<style>
  @page {{
    size: A4 portrait;
    margin: 20mm 20mm 20mm 20mm;
  }}
  * {{
    box-sizing: border-box;
    margin: 0;
    padding: 0;
  }}
  body {{
    font-family: 'Times New Roman', Times, serif;
    color: #111827;
    background: #FFFFFF;
    line-height: 1.6;
    font-size: 11.5pt;
  }}
  .kop {{
    text-align: center;
    border-bottom: 2.5px solid #111827;
    padding-bottom: 12px;
    margin-bottom: 22px;
    display: flex;
    flex-direction: column;
    align-items: center;
  }}
  .kop img {{
    height: 48px;
    margin-bottom: 6px;
  }}
  .kop h1 {{
    font-size: 15pt;
    font-weight: bold;
    text-transform: uppercase;
    letter-spacing: 1px;
    color: #111827;
  }}
  .kop p {{
    font-size: 10pt;
    color: #374151;
  }}
  
  .title {{
    text-align: center;
    margin-bottom: 20px;
  }}
  .title h2 {{
    font-size: 13pt;
    font-weight: bold;
    text-decoration: underline;
    text-transform: uppercase;
  }}
  .title p {{
    font-size: 10.5pt;
    margin-top: 3px;
  }}

  .content-table {{
    width: 100%;
    margin-left: 15px;
    margin-bottom: 16px;
    border-collapse: collapse;
  }}
  .content-table td {{
    padding: 4px 6px;
    vertical-align: top;
    font-size: 11pt;
  }}

  ol.points {{
    margin-left: 28px;
    margin-bottom: 18px;
    text-align: justify;
  }}
  ol.points li {{
    padding-left: 6px;
    margin-bottom: 8px;
  }}

  .signature-section {{
    margin-top: 30px;
    display: flex;
    justify-content: flex-end;
  }}
  .signature-box {{
    width: 250px;
    text-align: center;
    font-size: 11pt;
  }}
  .materai-box {{
    margin: 12px auto;
    width: 110px;
    height: 55px;
    border: 1px dashed #9CA3AF;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 8pt;
    color: #6B7280;
    border-radius: 4px;
    background: #F9FAFB;
  }}
  .signer-name {{
    font-weight: bold;
    text-decoration: underline;
    margin-top: 6px;
  }}
</style>
</head>
<body>

<div class="kop">
  <img src="{logo_b64}" alt="LiveTix Logo">
  <h1>LIVETIX OFFICIAL</h1>
  <p>Layanan Pemesanan & Penjualan Tiket Konser Musik Online</p>
  <p style="font-size: 9pt; color: #4B5563;">Email: support@livetix.com &bull; Website: livetix.com &bull; Indonesia</p>
</div>

<div class="title">
  <h2>SURAT PERNYATAAN USAHA PERORANGAN</h2>
  <p>Nomor: 001/SP-LTX/XI/2026</p>
</div>

<p style="margin-bottom: 12px; text-align: justify;">
Yang bertanda tangan di bawah ini, selaku Pemilik dan Pengelola Aplikasi <b>LiveTix</b>:
</p>

<table class="content-table">
  <tr>
    <td style="width: 28%;">Nama Lengkap</td>
    <td style="width: 3%;">:</td>
    <td style="width: 69%; font-weight: bold;">[NAMA LENGKAP PEMILIK SESUAI KTP]</td>
  </tr>
  <tr>
    <td>Nomor Induk Kependudukan (NIK)</td>
    <td>:</td>
    <td>[NOMOR NIK KTP PEMILIK]</td>
  </tr>
  <tr>
    <td>Nomor Pokok Wajib Pajak (NPWP)</td>
    <td>:</td>
    <td>[NOMOR NPWP PRIBADI / TERLAMPIR]</td>
  </tr>
  <tr>
    <td>Alamat Domisili</td>
    <td>:</td>
    <td>[ALAMAT LENGKAP SESUAI KTP]</td>
  </tr>
  <tr>
    <td>Nomor Telepon / WhatsApp</td>
    <td>:</td>
    <td>[NOMOR HANDPHONE AKTIF]</td>
  </tr>
  <tr>
    <td>Email Terdaftar di Midtrans</td>
    <td>:</td>
    <td>[EMAIL MERCHANT MIDTRANS]</td>
  </tr>
  <tr>
    <td>Nama Usaha / Aplikasi</td>
    <td>:</td>
    <td><b>LiveTix (Platform Tiket Konser Online)</b></td>
  </tr>
  <tr>
    <td>Bentuk Badan Usaha</td>
    <td>:</td>
    <td><b>Usaha Perorangan (Individu / Non-Badan Hukum)</b></td>
  </tr>
</table>

<p style="margin-bottom: 10px; text-align: justify;">
Dengan ini menerangkan dan menyatakan dengan sebenar-benarnya bahwa:
</p>

<ol class="points">
  <li>
    Usaha <b>LiveTix</b> merupakan kegiatan usaha yang didirikan, dimiliki, dan dijalankan secara mandiri dalam bentuk <b>Usaha Perorangan (Individu / Usaha Mikro)</b> dan <b>bukan</b> merupakan entitas badan usaha yang berbadan hukum (bukan PT, CV, Yayasan, Firma, maupun Koperasi).
  </li>
  <li>
    Sehubungan dengan status usaha yang bersifat perorangan tersebut, usaha kami saat ini <b>belum memiliki Nomor Induk Berusaha (NIB) Badan Usaha</b>, dan seluruh tanggung jawab hukum, operasional bisnis, serta transaksi keuangan sepenuhnya berada di bawah nama pemilik perorangan sebagaimana identitas KTP yang dilampirkan.
  </li>
  <li>
    Segala bentuk transaksi pembayaran yang masuk melalui layanan <b>Midtrans Payment Gateway</b> adalah pembayaran yang sah untuk pemesanan tiket konser musik resmi yang diselenggarakan melalui platform LiveTix, dan disalurkan ke rekening bank atas nama pemilik pribadi terdaftar.
  </li>
  <li>
    Seluruh dokumen identitas diri yang dilampirkan (KTP, NPWP Pribadi, dan Rekening Tabungan) adalah sah, valid, dan dapat dipertanggungjawabkan kebenarannya sesuai hukum yang berlaku di Republik Indonesia.
  </li>
</ol>

<p style="margin-bottom: 12px; text-align: justify;">
Demikian Surat Pernyataan ini saya buat dengan sadar, jujur, dan penuh tanggung jawab untuk digunakan sebagai kelengkapan dokumen pendukung proses verifikasi dan aktivasi merchant pada layanan <b>PT Midtrans (Midtrans Payment Gateway)</b>.
</p>

<div class="signature-section">
  <div class="signature-box">
    <p>Indonesia, 25 November 2026</p>
    <p style="margin-bottom: 6px;">Yang membuat pernyataan,</p>
    <div class="materai-box">
      Meterai Rp10.000
    </div>
    <p class="signer-name">[NAMA LENGKAP PEMILIK]</p>
    <p style="font-size: 9.5pt; color: #4B5563;">Pemilik / Pengelola LiveTix</p>
  </div>
</div>

</body>
</html>'''

surat_html_path = os.path.join(script_dir, 'Surat_Pernyataan_Usaha_Perorangan_LiveTix.html')
with open(surat_html_path, 'w', encoding='utf-8') as f:
    f.write(html_surat)
print('Surat Pernyataan HTML saved to:', surat_html_path)

# ================= RENDER TO PDF VIA CHROME HEADLESS =================
chrome_path = r'C:\Program Files\Google\Chrome\Application\chrome.exe'
if not os.path.exists(chrome_path):
    chrome_path = r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'

print('Rendering PDFs with:', chrome_path)

flow_pdf_path = os.path.join(script_dir, 'LiveTix_Flow_Transaksi_Midtrans.pdf')
cmd_flow = [
    chrome_path,
    '--headless=new',
    '--disable-gpu',
    '--no-pdf-header-footer',
    f'--print-to-pdf={flow_pdf_path}',
    flow_html_path
]
subprocess.run(cmd_flow, check=True)
print('Successfully generated:', flow_pdf_path)

surat_pdf_path = os.path.join(script_dir, 'Surat_Pernyataan_Usaha_Perorangan_LiveTix.pdf')
cmd_surat = [
    chrome_path,
    '--headless=new',
    '--disable-gpu',
    '--no-pdf-header-footer',
    f'--print-to-pdf={surat_pdf_path}',
    surat_html_path
]
subprocess.run(cmd_surat, check=True)
print('Successfully generated:', surat_pdf_path)
