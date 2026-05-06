# Panduan Pengguna — Price Action Master EA

> **Expert Advisor MetaTrader 5** yang mengimplementasikan tiga strategi price action profesional secara bersamaan, dilengkapi manajemen risiko otomatis dan tampilan dashboard real-time.

---

## 📋 Daftar Isi

1. [Pengenalan EA](#pengenalan-ea)
2. [Cara Instalasi](#cara-instalasi)
3. [Panduan Setting Parameter Optimal](#panduan-setting-parameter-optimal)
4. [Penjelasan Setiap Strategi](#penjelasan-setiap-strategi)
5. [Manajemen Risiko](#manajemen-risiko)
6. [Fitur Perlindungan Trade](#fitur-perlindungan-trade)
7. [Filter Sesi Trading](#filter-sesi-trading)
8. [Multi-Timeframe Confirmation](#multi-timeframe-confirmation)
9. [Tips Backtesting dan Optimasi](#tips-backtesting-dan-optimasi)
10. [Contoh Setup untuk Berbagai Pair](#contoh-setup-untuk-berbagai-pair)
11. [FAQ Troubleshooting](#faq-troubleshooting)
12. [Disclaimer](#disclaimer)

---

## Pengenalan EA

**Price Action Master EA** adalah Expert Advisor (EA) untuk platform MetaTrader 5 yang secara otomatis menganalisis chart dan membuka posisi trading berdasarkan tiga strategi price action yang saling melengkapi:

| Prioritas | Nama Strategi | Kondisi Entry |
|-----------|--------------|---------------|
| 1 (Tertinggi) | Pin Bar di S/R | Candle pin bar valid yang terbentuk tepat di level Support/Resistance |
| 2 | Break & Retest | Level S/R ditembus, kemudian price kembali menguji level tersebut |
| 3 | Trendline Bounce | Price memantul dari garis trendline yang sudah tervalidasi |

EA ini dirancang untuk digunakan pada **timeframe H1** sebagai entry, dengan **H4** sebagai konfirmasi arah trend. Semua trade menggunakan manajemen risiko otomatis sehingga aman digunakan bahkan oleh trader pemula.

---

## Cara Instalasi

### Persyaratan Sistem
- Platform MetaTrader 5 (build 2800 atau yang lebih baru)
- Akun broker (demo atau live)
- Koneksi internet stabil

### Langkah Instalasi

**1. Unduh File EA**
```
Unduh seluruh file dari repository:
https://github.com/fikribuoy-droid/MT5-PriceAction-EA
```

**2. Buka Folder Data MT5**
```
Di MetaTrader 5: klik menu File → Open Data Folder
```

**3. Salin File**
```
Salin file dengan struktur berikut:

📁 MQL5/Experts/PriceActionMaster/
    ├── PriceActionMaster.mq5
    └── Include/
        ├── RiskManager.mqh
        ├── TimeFilter.mqh
        ├── SupportResistance.mqh
        ├── PinBarDetector.mqh
        ├── BreakRetest.mqh
        ├── TrendlineManager.mqh
        └── Dashboard.mqh
```

**4. Kompilasi EA**
```
1. Buka MetaEditor (tekan F4 dari MetaTrader)
2. Buka file PriceActionMaster.mq5
3. Tekan F7 untuk kompilasi
4. Pastikan tidak ada error (warning bisa diabaikan)
```

**5. Pasang EA ke Chart**
```
1. Di MetaTrader, buka chart EURUSD H1
2. Drag EA dari panel Navigator ke chart
3. Di tab "Common": centang "Allow Auto Trading"
4. Di tab "Inputs": sesuaikan parameter jika perlu
5. Klik OK
```

**6. Aktifkan Auto Trading**
```
Klik tombol "AutoTrading" di toolbar MetaTrader (pastikan berwarna hijau)
```

---

## Panduan Setting Parameter Optimal

### Kelompok 1: Manajemen Risiko

```
Risk_Percent = 1.0 - 2.0
```
> **Rekomendasi**: Mulai dengan 1% untuk akun baru, naikkan ke 2% setelah 3 bulan profitable.
> Rumus: Jika balance $1000 dan Risk 2%, maka risiko per trade = $20

```
Risk_Reward_Ratio = 2.0
```
> Artinya: jika Stop Loss = 20 pips, maka Take Profit = 40 pips (1:2 RR)
> Dengan RR 1:2, cukup 34% win rate untuk tetap profit

```
Max_Open_Trades = 1
```
> **Sangat disarankan**: Tetap di 1 agar tidak over-exposed

```
Max_Daily_Loss = 5.0 - 6.0
```
> EA akan berhenti trading jika kerugian harian mencapai persentase ini
> Contoh: Balance $1000, Max_Daily_Loss = 6% → Stop trading jika rugi $60 hari ini

```
Max_Drawdown = 15.0 - 20.0
```
> Alert dan berhenti trading jika drawdown mencapai level ini

### Kelompok 2: Pin Bar Settings

```
PinBar_Wick_Ratio = 2.0 - 3.0
```
> Minimum panjang wick dibanding body candle
> - Nilai 2.0 = wick minimal 2x panjang body (lebih banyak sinyal)
> - Nilai 3.0 = wick minimal 3x panjang body (sinyal lebih selektif)

```
PinBar_Body_Percent = 25.0 - 33.0
```
> Body candle maksimal berapa % dari total range candle
> Nilai lebih kecil = candle harus lebih "bersih" / tipis

### Kelompok 3: Support/Resistance

```
SR_Lookback_Bars = 300 - 500
```
> Berapa candle ke belakang untuk mencari level S/R
> Nilai lebih besar = lebih banyak level terdeteksi

```
SR_Touch_Distance = 15 - 25
```
> Toleransi "sentuhan" ke level S/R dalam pips
> Untuk Gold (XAUUSD): gunakan 50-100
> Untuk Forex pairs: 15-25 pips sudah cukup

```
SR_Min_Touches = 2
```
> Level baru aktif setelah minimal 2 kali "disentuh" harga

### Kelompok 4: Trailing Stop & Break Even

```
Use_BreakEven = true
BreakEven_Profit = 15 - 20
BreakEven_Plus = 3 - 5
```
> Contoh: Profit sudah 20 pips → pindahkan SL ke entry + 5 pips
> Ini "mengunci" minimal 5 pips profit

```
Use_Trailing_Stop = true
Trailing_Start = 25 - 30
Trailing_Step = 8 - 10
```
> Contoh: Profit sudah 30 pips → trailing stop aktif, ikuti harga dengan jarak 10 pips

---

## Penjelasan Setiap Strategi

### Strategi 1: Pin Bar di Support/Resistance

**Apa itu Pin Bar?**
Pin Bar adalah candle dengan body kecil dan wick (ekor) yang panjang. Menunjukkan penolakan harga dari level tertentu.

```
Bullish Pin Bar (Signal BUY):
   ─── Upper wick (pendek)
   ─── Body (kecil, maks 33% range)
   │
   │
   │   Lower wick (panjang, minimal 2x body)
   ─── 
```

```
Bearish Pin Bar (Signal SELL):
   ───
   │
   │   Upper wick (panjang, minimal 2x body)
   │
   ─── Body (kecil)
   ─── Lower wick (pendek)
```

**Kondisi Entry:**
- ✅ Pin bar valid terdeteksi di H1
- ✅ Pin bar terbentuk di dekat level S/R (dalam toleransi)
- ✅ Trend H4 searah dengan sinyal
- ✅ Berada di dalam jam sesi trading

**Contoh Skenario:**
```
Price turun ke level Support 1.0850
→ Terbentuk Bullish Pin Bar di H1
→ H4 masih uptrend (higher highs, higher lows)
→ Saat ini jam 10:00 GMT (London session aktif)
→ EA membuka posisi BUY
→ SL: di bawah low pin bar
→ TP: SL distance × 2 (RR 1:2)
```

---

### Strategi 2: Break & Retest

**Konsep:**
Ketika harga menembus level S/R, level tersebut berganti peran:
- Resistance yang ditembus → menjadi Support baru
- Support yang ditembus → menjadi Resistance baru

**Alur Sinyal:**
```
1. Level Resistance terdeteksi di 1.1000
2. Candle close di atas 1.1000 (breakout)
3. EA menandai event breakout
4. Harga pullback ke area 1.1000
5. Terbentuk rejection candle (candle bullish) di 1.1000
6. EA membuka posisi BUY
```

**Kondisi Entry:**
- ✅ Clean breakout (close di luar level)
- ✅ Retest ke level yang sama
- ✅ Rejection candle terbentuk
- ✅ H4 trend mendukung arah trade
- ✅ Breakout event tidak lebih dari 50 bar yang lalu

---

### Strategi 3: Trendline Bounce

**Konsep:**
EA secara otomatis menggambar trendline dari swing high dan swing low, kemudian mendeteksi ketika harga memantul dari trendline tersebut.

**Jenis Trendline:**
- **Uptrend Line (Hijau)**: Menghubungkan swing low yang semakin tinggi
- **Downtrend Line (Merah)**: Menghubungkan swing high yang semakin rendah

**Kondisi Validitas Trendline:**
- Minimal **3 titik sentuhan** untuk dianggap valid
- Semakin banyak sentuhan = semakin kuat trendlinenya

**Kondisi Entry:**
- ✅ Trendline valid (minimal 3 touches)
- ✅ Harga menyentuh trendline
- ✅ Candle konfirmasi: close berlawanan arah atau pin bar
- ✅ H4 trend searah

---

## Manajemen Risiko

### Formula Perhitungan Lot Size

```
Lot = (Balance × Risk%) ÷ (SL dalam pips × Pip Value)

Contoh:
- Balance: $10,000
- Risk: 2% = $200
- SL: 30 pips
- Pip Value untuk 1 lot EURUSD ≈ $10/pip

Lot = $200 ÷ (30 × $10) = $200 ÷ $300 = 0.67 lot
```

### Batasan Risiko Harian

```
Max_Daily_Loss = 6%
Artinya: Jika balance awal hari ini $10,000
         Kerugian maksimum = $600
         Setelah rugi $600, EA berhenti trading sampai hari berikutnya
```

### Proteksi Maximum Drawdown

```
Max_Drawdown = 20%
Artinya: Jika equity turun 20% dari balance awal sesi
         EA berhenti trading dan menampilkan alert
         Contoh: Balance awal $10,000 → Stop jika equity < $8,000
```

---

## Fitur Perlindungan Trade

### Break Even (BE)

Secara otomatis memindahkan Stop Loss ke level entry + bonus ketika profit mencapai target:

```
Kondisi: Profit mencapai BreakEven_Profit (default: 20 pips)
Aksi: SL dipindahkan ke Entry Price + BreakEven_Plus (default: +5 pips)

Contoh BUY:
- Entry: 1.0850
- SL awal: 1.0820 (30 pips di bawah entry)
- Setelah profit 20 pips (harga di 1.0870)
- SL otomatis pindah ke 1.0855 (entry + 5 pips)
- Trade tidak bisa lagi rugi, minimal profit 5 pips
```

### Trailing Stop

Mengikuti pergerakan harga secara otomatis untuk mengunci profit maksimal:

```
Kondisi: Profit mencapai Trailing_Start (default: 30 pips)
Aksi: SL mengikuti harga dengan jarak Trailing_Step (default: 10 pips)

Contoh BUY:
- Entry: 1.0850
- Saat harga di 1.0880 (profit 30 pips) → Trailing aktif
- SL = 1.0870 (10 pips di bawah harga)
- Saat harga naik ke 1.0890 → SL naik ke 1.0880
- Saat harga naik ke 1.0900 → SL naik ke 1.0890
- Jika harga turun ke 1.0890 → SL tersentuh, profit 40 pips terkunci
```

---

## Filter Sesi Trading

EA hanya trading dalam sesi yang dipilih:

| Sesi | Jam GMT | Default | Karakteristik |
|------|---------|---------|---------------|
| Asian | 00:00–09:00 | **OFF** | Volume rendah, range sempit |
| London | 08:00–17:00 | **ON** | Volume tinggi, banyak breakout |
| New York | 13:00–22:00 | **ON** | Volume sangat tinggi |
| London+NY Overlap | 13:00–17:00 | **ON** | Paling volatile, sinyal terkuat |

> **Tips**: Untuk trader di Indonesia (WIB = GMT+7):
> - London session: 15:00–00:00 WIB
> - New York session: 20:00–05:00 WIB
> - Overlap: 20:00–00:00 WIB

---

## Multi-Timeframe Confirmation

### Cara Kerja

```
H4 (Higher Timeframe) → Menentukan arah trend utama
H1 (Entry Timeframe) → Tempat mencari sinyal entry

Logika:
- H4 Uptrend → Hanya ambil sinyal BUY di H1
- H4 Downtrend → Hanya ambil sinyal SELL di H1
- H4 Ranging → EA lebih selektif (atau dinonaktifkan)
```

### Deteksi Trend H4

```
Uptrend: Swing High baru lebih tinggi dari sebelumnya
         DAN Swing Low baru lebih tinggi dari sebelumnya
         (Higher High + Higher Low)

Downtrend: Swing High baru lebih rendah dari sebelumnya
           DAN Swing Low baru lebih rendah dari sebelumnya
           (Lower High + Lower Low)
```

### Menonaktifkan MTF

Jika ingin EA lebih agresif dan mengambil semua sinyal tanpa filter trend:
```
Use_MTF_Confirmation = false
```
> **Catatan**: Menonaktifkan MTF akan meningkatkan jumlah trade tetapi dapat menurunkan kualitas sinyal

---

## Tips Backtesting dan Optimasi

### Pengaturan Backtest yang Direkomendasikan

```
Model: Every tick based on real ticks (paling akurat)
Spread: Current (gunakan spread nyata dari broker)
Period: Minimal 1-2 tahun data historis
Balance awal: $10,000 (untuk kalkulasi lot yang akurat)
```

### Langkah Backtesting

```
1. Buka MetaTrader Strategy Tester (Ctrl+R)
2. Pilih EA: PriceActionMaster
3. Pilih Symbol: EURUSD
4. Pilih Timeframe: H1 (Entry_Timeframe)
5. Model: Every tick based on real ticks
6. Period: 2022.01.01 – 2023.12.31
7. Deposit: 10000 USD
8. Klik Start
```

### Parameter untuk Optimasi

Fokus optimasi pada parameter berikut (berurutan dari yang paling berpengaruh):

| Parameter | Range Optimasi | Step |
|-----------|---------------|------|
| `PinBar_Wick_Ratio` | 1.5 – 3.0 | 0.5 |
| `SR_Touch_Distance` | 10 – 30 | 5 |
| `SR_Min_Touches` | 2 – 4 | 1 |
| `BreakEven_Profit` | 15 – 30 | 5 |
| `Trailing_Start` | 20 – 40 | 5 |

### Kriteria Hasil Backtest yang Baik

```
✅ Profit Factor > 1.5
✅ Win Rate > 35% (karena RR 1:2, cukup 34%)
✅ Maximum Drawdown < 20%
✅ Total trades > 100 (sampel statistik yang cukup)
✅ Recovery Factor > 2
```

---

## Contoh Setup untuk Berbagai Pair

### EURUSD (Standard)
```
SR_Touch_Distance    = 20
PinBar_Wick_Ratio    = 2.0
PinBar_Body_Percent  = 33.0
Trailing_Start       = 30
Trailing_Step        = 10
Risk_Percent         = 2.0
```

### GBPUSD (Lebih Volatile)
```
SR_Touch_Distance    = 25      ← lebih besar karena lebih volatile
PinBar_Wick_Ratio    = 2.5     ← lebih ketat untuk kualitas lebih baik
PinBar_Body_Percent  = 30.0
Trailing_Start       = 35      ← trail lebih jauh
Trailing_Step        = 12
Risk_Percent         = 1.5     ← risiko lebih kecil karena volatile
```

### XAUUSD / Gold (Paling Volatile)
```
SR_Touch_Distance    = 100     ← dalam pips (Gold pip ≈ $0.01)
PinBar_Wick_Ratio    = 2.0
PinBar_Body_Percent  = 33.0
SR_Lookback_Bars     = 300
Trailing_Start       = 50
Trailing_Step        = 20
Risk_Percent         = 1.0     ← risiko minimal untuk Gold
BreakEven_Profit     = 30
```

> **Catatan untuk Gold**: 1 pip untuk XAUUSD = $0.01 (bukan $10 seperti forex). Spread Gold biasanya 20-30 pips, jadi pastikan `SR_Touch_Distance` disesuaikan.

---

## FAQ Troubleshooting

### ❓ EA tidak membuka trade sama sekali

**Kemungkinan penyebab dan solusi:**

```
1. AutoTrading tidak aktif
   → Klik tombol "AutoTrading" di toolbar MT5 (harus hijau)

2. Di luar jam sesi trading
   → Cek pengaturan Trade_London_Session / Trade_NewYork_Session
   → Verifikasi jam broker vs GMT

3. Max_Open_Trades sudah tercapai
   → Tutup trade yang sedang buka, atau naikkan Max_Open_Trades

4. Daily loss limit sudah hit
   → Cek apakah sudah rugi > Max_Daily_Loss% hari ini
   → Tunggu hari berikutnya (reset otomatis)

5. Tidak ada sinyal yang memenuhi semua kondisi
   → Normal, EA hanya trade pada setup berkualitas tinggi
   → Verifikasi dengan mengecek chart apakah ada level S/R yang aktif
```

### ❓ Dashboard tidak muncul

```
Solusi:
1. Pastikan Show_Dashboard = true
2. Refresh chart (tekan F5)
3. Coba detach dan attach ulang EA
4. Pastikan EA berjalan (smiley face di pojok kanan atas chart)
```

### ❓ Garis S/R tidak tergambar

```
Solusi:
1. Pastikan Draw_SR_Lines = true
2. Tunggu beberapa saat (S/R dikalkulasi saat bar baru terbentuk)
3. Cek Log tab untuk error message
4. Pastikan ada cukup data historis (SR_Lookback_Bars bar)
```

### ❓ Error "Not enough money"

```
Penyebab: Lot size yang dikalkulasi melebihi margin yang tersedia

Solusi:
1. Kurangi Risk_Percent (coba 1% atau 0.5%)
2. Tambah deposit akun
3. Gunakan akun dengan leverage lebih tinggi
```

### ❓ Error di kompilasi

```
Jika ada error kompilasi:
1. Pastikan SEMUA file .mqh ada di folder Include/
2. Cek path: MQL5/Experts/PriceActionMaster/Include/
3. Restart MetaEditor dan compile ulang
```

### ❓ EA terlalu banyak membuka trade

```
Penyebab: Parameter terlalu longgar

Solusi:
1. Naikkan PinBar_Wick_Ratio ke 2.5-3.0
2. Kurangi SR_Touch_Distance ke 10-15 pips
3. Naikkan SR_Min_Touches ke 3
4. Pastikan Use_MTF_Confirmation = true
```

### ❓ Win rate sangat rendah (< 30%)

```
Analisis:
1. Cek apakah trading berlawanan dengan H4 trend
   → Aktifkan Use_MTF_Confirmation = true

2. SR level tidak akurat
   → Naikkan SR_Min_Touches ke 3
   → Sesuaikan SR_Touch_Distance untuk pair tersebut

3. Pin bar terlalu sering trigger
   → Naikkan PinBar_Wick_Ratio ke 2.5
   → Kurangi PinBar_Body_Percent ke 25%

4. Trading di sesi yang salah
   → Aktifkan hanya London dan NY session
```

---

## Disclaimer

> ⚠️ **PERINGATAN RISIKO**
>
> Trading forex dan CFD mengandung risiko kerugian yang signifikan dan tidak cocok untuk semua investor. Nilai investasi dapat turun maupun naik, dan Anda mungkin tidak mendapatkan kembali seluruh modal yang diinvestasikan.
>
> **Performa masa lalu tidak menjamin hasil di masa depan.**
>
> Expert Advisor ini adalah alat bantu trading, bukan jaminan profit. Selalu:
> - ✅ Test di akun demo minimal 1-3 bulan sebelum ke akun live
> - ✅ Gunakan modal yang Anda mampu untuk kehilangan
> - ✅ Pahami setiap strategi sebelum menggunakannya
> - ✅ Monitor EA secara berkala, jangan ditinggal tanpa pengawasan
>
> Pembuat EA ini tidak bertanggung jawab atas kerugian finansial yang terjadi akibat penggunaan EA ini.

---

*Versi Dokumen: 1.0 | Bahasa: Indonesia | Terakhir diupdate: 2024*
