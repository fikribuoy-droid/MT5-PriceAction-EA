# Manual Pengguna - Price Action Master EA
## Panduan Lengkap Bahasa Indonesia

---

## 📋 Daftar Isi

1. [Pengenalan EA](#1-pengenalan-ea)
2. [Persyaratan Sistem](#2-persyaratan-sistem)
3. [Instalasi Lengkap](#3-instalasi-lengkap)
4. [Penjelasan Strategi](#4-penjelasan-strategi)
5. [Panduan Setting Parameter](#5-panduan-setting-parameter)
6. [Panduan Backtesting](#6-panduan-backtesting)
7. [Tips Optimasi](#7-tips-optimasi)
8. [Setup untuk Pair Berbeda](#8-setup-untuk-pair-berbeda)
9. [FAQ & Troubleshooting](#9-faq--troubleshooting)
10. [Disclaimer](#10-disclaimer)

---

## 1. Pengenalan EA

**Price Action Master EA** adalah Expert Advisor (robot trading) untuk MetaTrader 5 yang mengkombinasikan tiga strategi price action profesional:

| Strategi | Prioritas | Deskripsi |
|----------|-----------|-----------|
| Pin Bar di S/R Level | ⭐ Tertinggi | Candle dengan ekor panjang di area support/resistance |
| Break & Retest | ⭐⭐ Menengah | Breakout level lalu retest area yang sama |
| Trendline Bounce | ⭐⭐⭐ Pelengkap | Pantul dari garis trendline yang valid |

### Fitur Utama:
- ✅ Deteksi Support/Resistance otomatis
- ✅ Gambar otomatis di chart (garis, panah, dashboard)
- ✅ Manajemen risiko otomatis (lot size, SL, TP)
- ✅ Trailing stop & break even otomatis
- ✅ Filter sesi trading (London, New York)
- ✅ Konfirmasi multi-timeframe (H4 + H1)
- ✅ Dashboard statistik real-time
- ✅ Proteksi harian (max loss, max drawdown)

---

## 2. Persyaratan Sistem

| Komponen | Minimum | Rekomendasi |
|----------|---------|-------------|
| MetaTrader | MT5 Build 2000+ | MT5 Build 3000+ |
| OS | Windows 7 | Windows 10/11 |
| RAM | 2 GB | 4 GB+ |
| Internet | Koneksi stabil | VPS dedicated |
| Akun | Demo | Demo dulu, lalu live |

---

## 3. Instalasi Lengkap

### Langkah 1: Download File EA

Download semua file berikut dari repository GitHub:
```
PriceActionMaster.mq5
Include/SupportResistance.mqh
Include/PinBarDetector.mqh
Include/BreakRetest.mqh
Include/TrendlineManager.mqh
Include/RiskManager.mqh
Include/Dashboard.mqh
Include/TimeFilter.mqh
```

### Langkah 2: Temukan Folder Data MT5

1. Buka **MetaTrader 5**
2. Klik menu **File** → **Open Data Folder**
3. Akan terbuka folder seperti:
   ```
   C:\Users\[NamaAnda]\AppData\Roaming\MetaQuotes\Terminal\[ID]\
   ```

### Langkah 3: Salin File EA

1. Masuk ke folder: `MQL5\Experts\`
2. **Salin** file `PriceActionMaster.mq5` ke dalam folder ini
3. Buat subfolder baru: `MQL5\Experts\Include\`
4. **Salin** semua file `.mqh` ke dalam folder `Include\` tersebut

Struktur akhir yang benar:
```
MQL5\
└── Experts\
    ├── PriceActionMaster.mq5
    └── Include\
        ├── SupportResistance.mqh
        ├── PinBarDetector.mqh
        ├── BreakRetest.mqh
        ├── TrendlineManager.mqh
        ├── RiskManager.mqh
        ├── Dashboard.mqh
        └── TimeFilter.mqh
```

### Langkah 4: Kompilasi EA

1. Di MetaTrader 5, tekan **F4** untuk buka MetaEditor
2. Di panel kiri (Navigator), cari dan klik 2x file `PriceActionMaster.mq5`
3. Tekan **F7** untuk kompilasi
4. Pastikan pesan di bagian bawah: **"0 errors, 0 warnings"**
5. Jika ada error, periksa apakah file `.mqh` sudah di folder yang benar

### Langkah 5: Pasang di Chart

1. Buka chart yang diinginkan (misalnya EURUSD H1)
2. Di panel **Navigator** MT5 (biasanya kiri), buka **Expert Advisors**
3. Cari **PriceActionMaster**
4. Drag & drop ke chart
5. Akan muncul jendela pengaturan:
   - Tab **Common**: Centang "Allow live trading" dan "Allow DLL imports"
   - Tab **Inputs**: Atur parameter (lihat Bagian 5)
6. Klik **OK**

### Langkah 6: Verifikasi

Setelah EA terpasang, Anda seharusnya melihat:
- ✅ Logo smiley face (😊) di pojok kanan atas chart
- ✅ Dashboard statistik di pojok kanan atas
- ✅ Garis horizontal S/R di chart (warna biru = support, merah = resistance)
- ✅ Trendline otomatis (jika sudah cukup data)

---

## 4. Penjelasan Strategi

### 4.1 Pin Bar di Support/Resistance

**Apa itu Pin Bar?**

Pin bar adalah candle dengan body kecil dan ekor (wick/shadow) yang sangat panjang. Menunjukkan bahwa harga mencoba menembus level tertentu tapi ditolak kembali.

```
Bullish Pin Bar (di Support):     Bearish Pin Bar (di Resistance):
         |                                    ─────
         |  ← Ekor atas kecil              |||||| ← Body kecil
       |||||  ← Body                          |
       |||||                                  |
─────────────────────── SUPPORT              | ← Ekor panjang ke bawah
```

**Kriteria Valid:**
- Panjang ekor ≥ 2× panjang body (wick ratio)
- Ukuran body ≤ 33% dari total range candle
- Terbentuk di area Support/Resistance (dalam 20 pips)
- Untuk bullish: ekor bawah lebih panjang (di support)
- Untuk bearish: ekor atas lebih panjang (di resistance)

**Cara Entry:**
- Bullish: Buy saat harga menembus HIGH pin bar
- Bearish: Sell saat harga menembus LOW pin bar
- Stop Loss: Di luar ujung ekor pin bar (+ buffer 3 pips)

---

### 4.2 Break and Retest

**Konsep Dasar:**

Ketika harga menembus (breakout) sebuah level S/R, level tersebut berganti peran:
- **Resistance** yang ditembus ke atas → menjadi **Support** baru
- **Support** yang ditembus ke bawah → menjadi **Resistance** baru

Setelah breakout, harga sering "kembali" (retest) ke level tersebut sebelum melanjutkan arah breakout. Di sinilah kita masuk!

```
Contoh Bullish Break & Retest:

  ─────────────────────── Resistance lama
  ↑ BREAKOUT ke atas
  
  ↓ RETEST (kembali ke level)
  ─────────────────────── Support baru (dulunya resistance)
  ↑ ENTRY BUY di sini
```

**Fase Sinyal:**
1. **Breakout**: Candle close di atas/bawah level dengan jelas
2. **Retest**: Harga kembali menyentuh level yang ditembus
3. **Konfirmasi**: Candle rejection terbentuk (candle bearish di resistance, bullish di support)
4. **Entry**: Masuk setelah konfirmasi

---

### 4.3 Trendline Bounce

**Konsep Dasar:**

Dalam tren yang kuat, harga bergerak dalam "channel" - sering kembali ke garis trendline sebelum melanjutkan arah tren.

```
Uptrend Line:                    Downtrend Line:

              *                  *
          *       ← Entry         *
      *                               *
  ────────────────── Trendline           ── Trendline
```

**Kriteria Valid Trendline:**
- Menghubungkan minimal 2 swing point (otomatis ditetapkan ke 3 untuk konfirmasi)
- Uptrend line: swing lows yang semakin naik
- Downtrend line: swing highs yang semakin turun
- Minimal 3 kali harga menyentuh/memantul

**Entry:**
- Uptrend: Buy ketika harga menyentuh uptrend line + candle bullish terbentuk
- Downtrend: Sell ketika harga menyentuh downtrend line + candle bearish terbentuk
- Perlu confluence tambahan (misal: juga di S/R level)

---

### 4.4 Multi-Timeframe Confirmation (H4 + H1)

EA menggunakan **H4** sebagai timeframe bias dan **H1** sebagai timeframe entry.

**Cara Kerja:**
1. Periksa tren di H4:
   - H4 bullish (harga naik, MA cepat > MA lambat) → hanya ambil BUY di H1
   - H4 bearish (harga turun, MA cepat < MA lambat) → hanya ambil SELL di H1
   - H4 neutral → skip (tidak ada trade)

2. Ini mencegah trading melawan tren utama yang lebih kuat

**Tip:** Jika ingin lebih banyak trade, matikan konfirmasi H4 dengan `Use_MTF_Confirmation = false` (risiko lebih tinggi).

---

## 5. Panduan Setting Parameter

### 5.1 Risk Management

**`Risk_Percent` = 2.0**
- Artinya: setiap trade mengambil risiko 2% dari balance
- Contoh: Balance $10,000 → risiko per trade = $200
- **Konservatif**: 1.0%  |  **Normal**: 2.0%  |  **Agresif**: 3.0%
- ⚠️ Jangan melebihi 3% untuk pemula

**`Risk_Reward_Ratio` = 2.0**
- TP = SL × 2.0 (setiap 1 pip risiko, target 2 pip profit)
- Dengan win rate 40% dan RR 1:2, sistem tetap profit
- **Konservatif**: 1.5  |  **Normal**: 2.0  |  **Agresif**: 3.0

**`Max_Daily_Loss` = 6.0**
- EA berhenti trading jika loss harian mencapai 6% balance
- Melindungi dari hari-hari buruk
- Rekomendasi: 2× `Risk_Percent` s.d 3× `Risk_Percent`

**`Max_Drawdown` = 20.0**
- EA berhenti dan memberi alert jika drawdown mencapai 20%
- Ini adalah jaring pengaman terakhir

---

### 5.2 Pin Bar Settings

**`PinBar_Wick_Ratio` = 2.0**
- Minimum panjang ekor dibanding body
- Nilai lebih tinggi = pin bar lebih "sempurna" tapi lebih jarang
- **Ketat**: 3.0  |  **Normal**: 2.0  |  **Longgar**: 1.5

**`PinBar_Body_Percent` = 33.0**
- Body maksimal = 33% dari total range candle
- Semakin kecil = pin bar semakin bersih
- **Ketat**: 25.0  |  **Normal**: 33.0  |  **Longgar**: 40.0

---

### 5.3 Support/Resistance

**`SR_Lookback_Bars` = 500**
- Berapa bar kebelakang untuk mendeteksi S/R
- Lebih banyak = level S/R lebih "kuat" (lebih lama teruji)
- **Jangka pendek**: 200  |  **Normal**: 500  |  **Jangka panjang**: 1000

**`SR_Touch_Distance` = 20**
- Toleransi (dalam pips) untuk menggabungkan level yang berdekatan
- Untuk GOLD, gunakan 200–500 karena range pergerakannya lebih besar
- **Pair major**: 15–25 pips  |  **GOLD**: 200–500 pips

**`SR_Min_Touches` = 2**
- Minimal berapa kali harga harus menyentuh level sebelum valid
- Lebih banyak = level lebih kuat tapi lebih jarang
- Rekomendasi: 2–3

---

### 5.4 Trade Protection

**`BreakEven_Profit` = 20 pips**
- Setelah profit mencapai 20 pips, SL dipindah ke entry + 5 pips
- Posisi menjadi "risk-free" (sudah pasti tidak rugi)
- Sesuaikan dengan volatilitas pair

**`Trailing_Start` = 30 pips**
- Trailing stop mulai aktif setelah profit 30 pips
- Mengunci profit ketika trade berjalan baik

**`Trailing_Step` = 10 pips**
- SL digeser tiap 10 pips profit tambahan
- Lebih kecil = SL lebih ketat (bisa kena stop lebih awal)

---

### 5.5 Sesi Trading

Rekomendasi default sudah optimal untuk sebagian besar trader:
- **London** (08:00–17:00 GMT): Sesi paling aktif untuk pair EUR/GBP
- **New York** (13:00–22:00 GMT): Sesi paling aktif untuk pair USD
- **London+NY Overlap** (13:00–17:00 GMT): Sesi paling volatile, banyak sinyal

Aktifkan **Asian Session** hanya untuk pair JPY (USDJPY, GBPJPY, dll).

---

## 6. Panduan Backtesting

### Langkah-langkah Backtesting

1. **Buka Strategy Tester**: Tekan Ctrl+R di MT5
2. **Pilih EA**: PriceActionMaster
3. **Pengaturan**:
   - Symbol: EURUSD (atau pair lain)
   - Period: H1
   - Model: **Every tick based on real ticks** (terbaik)
   - Date: Minimal 1 tahun (rekomendasi 2–3 tahun)
   - Deposit: $10,000 (untuk kalkulasi yang realistis)
   - Leverage: 1:100
4. **Aktifkan visual**: Centang "Visualization" untuk melihat trading secara visual
5. **Klik Start**

### Hasil yang Diharapkan (Target)

| Metrik | Minimum | Target Ideal |
|--------|---------|--------------|
| Profit Factor | 1.3 | ≥ 1.8 |
| Max Drawdown | < 25% | < 15% |
| Win Rate | 35% | 45–55% |
| Total Trades | > 50 | > 100 |
| Recovery Factor | > 2.0 | > 3.5 |
| Sharpe Ratio | > 0.5 | > 1.0 |

> ⚠️ **Penting**: Hasil backtest yang terlalu bagus (profit factor > 5, drawdown < 5%) biasanya menandakan **overfitting** atau **look-ahead bias**. Hasil wajar lebih dapat dipercaya.

---

## 7. Tips Optimasi

### Urutan Optimasi yang Benar

Optimalkan satu grup parameter per sesi, jangan sekaligus semua:

1. **Tahap 1**: Optimalkan `SR_Lookback_Bars` dan `SR_Min_Touches`
2. **Tahap 2**: Optimalkan `PinBar_Wick_Ratio` dan `PinBar_Body_Percent`
3. **Tahap 3**: Optimalkan `Risk_Reward_Ratio`
4. **Tahap 4**: Optimalkan `BreakEven_Profit` dan `Trailing_Start`

### Range Optimasi yang Disarankan

| Parameter | Min | Max | Step |
|-----------|-----|-----|------|
| SR_Lookback_Bars | 200 | 800 | 100 |
| SR_Min_Touches | 2 | 4 | 1 |
| PinBar_Wick_Ratio | 1.5 | 3.5 | 0.5 |
| Risk_Reward_Ratio | 1.5 | 3.0 | 0.5 |
| BreakEven_Profit | 15 | 35 | 5 |
| Trailing_Start | 20 | 50 | 10 |

### Tips Penting

- ✅ Selalu **forward test** hasil optimasi di demo minimal 1–3 bulan sebelum live
- ✅ Pisahkan data: 70% untuk optimasi, 30% untuk validasi
- ✅ Hindari optimasi berlebihan (too many parameters)
- ❌ Jangan optimasi berdasarkan 1 tahun data saja
- ❌ Jangan langsung live setelah backtest bagus

---

## 8. Setup untuk Pair Berbeda

### EURUSD (Default)
Pair paling likuid, spread rendah, cocok untuk semua strategi.

```
SR_Touch_Distance   = 20 pips
SR_Lookback_Bars    = 500
PinBar_Wick_Ratio   = 2.0
Trailing_Start      = 30 pips
Trade_Asian_Session = false
Trade_London_Session = true
Trade_NewYork_Session = true
```

---

### GBPUSD
Lebih volatile dari EURUSD, perlu toleransi lebih besar.

```
SR_Touch_Distance   = 25 pips    ← Lebih besar karena lebih volatile
SR_Lookback_Bars    = 400
PinBar_Wick_Ratio   = 2.5        ← Lebih ketat (banyak false signal)
Risk_Percent        = 1.5        ← Kurangi risk karena volatilitas
Trailing_Start      = 40 pips    ← Lebih lebar
BreakEven_Profit    = 25 pips
```

---

### XAUUSD (GOLD)
Gold bergerak ratusan hingga ribuan pip, semua parameter perlu disesuaikan secara signifikan.

```
SR_Touch_Distance   = 300 pips   ← Sangat besar! (gold bergerak $3-5 per candle)
SR_Lookback_Bars    = 300        ← Lebih sedikit (level lebih sering berubah)
SR_Min_Touches      = 2
PinBar_Wick_Ratio   = 2.0
Risk_Percent        = 1.0        ← Konservatif karena spread gold tinggi
Risk_Reward_Ratio   = 2.5
BreakEven_Profit    = 150 pips
Trailing_Start      = 200 pips
Trailing_Step       = 50 pips
Trade_Asian_Session = true       ← Gold aktif di sesi Asia juga
```

> 💡 **Catatan Gold**: Karena spread gold biasanya $2–5 per lot, pastikan akun Anda cukup untuk menampung margin. Gunakan leverage yang wajar (1:20 – 1:50).

---

### USDJPY
Aktif di sesi Asia, pair yang relatif stabil.

```
SR_Touch_Distance   = 30 pips
Trade_Asian_Session = true       ← Aktifkan Asian session!
PinBar_Wick_Ratio   = 2.0
Risk_Percent        = 2.0
```

---

## 9. FAQ & Troubleshooting

### ❓ EA tidak membuka trade sama sekali

**Kemungkinan penyebab:**
1. **Di luar sesi trading** → Periksa jam GMT saat ini vs setting sesi
2. **Tidak ada sinyal** → Normal jika tidak ada setup yang memenuhi semua kriteria
3. **H4 trend tidak jelas** → Coba set `Use_MTF_Confirmation = false` sementara untuk test
4. **Daily loss limit tercapai** → Cek tab Journal di MT5, lihat pesan dari EA
5. **AutoTrading dimatikan** → Pastikan tombol AutoTrading MT5 hijau (aktif)

---

### ❓ Lot size terlalu kecil atau 0

**Solusi:**
- Periksa `Risk_Percent` (mungkin terlalu kecil)
- Periksa minimum lot broker Anda (biasanya 0.01)
- Untuk balance kecil (< $500), lot 0.01 mungkin yang terkecil yang tersedia
- Pastikan SL tidak terlalu jauh (SL besar = lot lebih kecil)

---

### ❓ Dashboard tidak muncul

**Solusi:**
1. Pastikan `Show_Dashboard = true`
2. Klik kanan chart → Properties → Common → centang "Show object description"
3. Coba zoom out chart atau ubah ukuran jendela

---

### ❓ Terlalu banyak garis S/R di chart

**Solusi:**
- Naikkan `SR_Min_Touches` (misalnya ke 3 atau 4)
- Naikkan `SR_Touch_Distance` untuk menggabungkan level yang berdekatan
- Kurangi `SR_Lookback_Bars` (misalnya ke 200–300)

---

### ❓ EA membuka trade tapi langsung kena stop loss

**Kemungkinan penyebab:**
1. **SL terlalu ketat** → Periksa `PinBar_Wick_Ratio`, mungkin pin bar tidak valid secara visual
2. **Spread terlalu besar** → Beberapa broker punya spread > SL distance
3. **Volatilitas tinggi** → Gunakan pair dengan spread lebih rendah
4. **Slippage** → Normal terjadi di kondisi news, pertimbangkan news filter

---

### ❓ Bagaimana cara reset statistik win/loss?

- Statistik direset otomatis saat EA di-restart (remove + attach kembali)
- Atau restart MT5

---

### ❓ Kompilasi error: "cannot open include file"

**Solusi:**
- Pastikan file `.mqh` ada di folder `Include/` yang tepat
- Path yang benar: `MQL5\Experts\Include\` (bukan `MQL5\Include\`)
- Atau salin ke `MQL5\Include\` jika pakai path `<Include\...>`

---

### ❓ Apakah EA ini cocok untuk scalping?

**Tidak**. EA ini dirancang untuk **swing trading** di H1/H4. Untuk scalping, Anda perlu EA yang berbeda dengan parameter yang sangat berbeda (timeframe M5/M15, SL kecil, dll).

---

## 10. Disclaimer

> **⚠️ PERINGATAN RISIKO PENTING**
>
> Trading forex, komoditas, dan instrumen keuangan lainnya **mengandung risiko tinggi** dan tidak cocok untuk semua investor. Anda bisa kehilangan sebagian atau seluruh modal yang diinvestasikan.
>
> - EA ini disediakan **"sebagaimana adanya"** untuk tujuan edukasi dan penelitian
> - **Hasil backtest tidak menjamin** hasil trading masa depan
> - **Selalu test di akun demo** minimal 3–6 bulan sebelum menggunakan di akun live
> - Pastikan Anda memahami cara kerja EA sebelum menggunakannya
> - Pengembang **tidak bertanggung jawab** atas kerugian finansial akibat penggunaan software ini
>
> Trading yang bertanggung jawab: Gunakan dana yang siap Anda rugikan sepenuhnya.

---

*Dokumen ini dibuat untuk versi EA 1.0.0*  
*Untuk pertanyaan teknis, silakan buka Issue di repository GitHub*
