# MT5 Price Action Master EA

🚀 Professional MetaTrader 5 Expert Advisor implementing multiple advanced Price Action trading strategies with full visual feedback, risk management, and session filtering.

---

## 📁 File Structure

```
MT5-PriceAction-EA/
├── PriceActionMaster.mq5          ← Main EA file
├── Include/
│   ├── SupportResistance.mqh      ← Auto S/R detection & chart drawing
│   ├── PinBarDetector.mqh         ← Pin bar identification & arrows
│   ├── BreakRetest.mqh            ← Break & Retest strategy
│   ├── TrendlineManager.mqh       ← Automatic trendline detection
│   ├── RiskManager.mqh            ← Risk & money management
│   ├── Dashboard.mqh              ← Real-time visual dashboard
│   └── TimeFilter.mqh             ← Trading session filter
├── README.md
└── UserManual.md                  ← Full manual in Bahasa Indonesia
```

---

## 🎯 Features

### Trading Strategies (Priority Order)
1. **Pin Bar at Support/Resistance** *(Highest Priority)*
   - Detects hammer / shooting star candles forming at key S/R levels
   - Requires wick-to-body ratio ≥ 2:1 and body ≤ 33% of candle range
   - H4 trend confirmation optional

2. **Break and Retest**
   - Detects strong breakouts through S/R levels
   - Waits for price to retest the broken level (role reversal)
   - Enters on rejection/confirmation candle

3. **Trendline Bounce**
   - Automatically identifies swing highs and lows
   - Draws and validates trendlines (minimum 3 touches)
   - Enters on bounce confirmation with additional S/R confluence

### Automatic Technical Analysis
- **Support/Resistance Detection**: Scans last 500 bars for swing highs/lows, merges nearby levels, and confirms with minimum 2 touches
- **Trendline Drawing**: Identifies uptrend (connects swing lows) and downtrend (connects swing highs) lines
- **Multi-Timeframe Confirmation**: Uses H4 for trend bias, H1 for entry signals

### Advanced Risk Management
| Feature | Default |
|---------|---------|
| Risk per trade | 2% of balance |
| Risk:Reward ratio | 1:2 |
| Max open trades | 1 |
| Max daily loss | 6% |
| Max drawdown | 20% |
| Break even trigger | +20 pips profit |
| Break even lock | +5 pips |
| Trailing stop start | +30 pips profit |
| Trailing step | 10 pips |

### Visual Dashboard (Top-Right Corner)
- Account balance and equity
- Today's P/L (amount and %)
- Open trades count
- Session win rate
- Current risk exposure %
- Active S/R levels count
- Current trading session
- Warning indicators for daily loss / drawdown limits

### Session Filter (GMT)
| Session | Hours (GMT) | Default |
|---------|------------|---------|
| Asian | 00:00 – 09:00 | ❌ Off |
| London | 08:00 – 17:00 | ✅ On |
| New York | 13:00 – 22:00 | ✅ On |
| London/NY Overlap | 13:00 – 17:00 | ✅ Prioritized |

---

## 📦 Installation

### Step 1: Copy Files
1. Open MetaTrader 5
2. Click **File → Open Data Folder**
3. Navigate to `MQL5/Experts/`
4. Copy `PriceActionMaster.mq5` into this folder
5. Create a subfolder `MQL5/Experts/Include/` and copy all `.mqh` files into it

### Step 2: Compile
1. Open **MetaEditor** (press F4 in MT5)
2. Open `PriceActionMaster.mq5`
3. Press **F7** to compile
4. Confirm: **0 errors, 0 warnings**

### Step 3: Attach to Chart
1. Open a chart (recommended: EURUSD H1)
2. Drag `PriceActionMaster` from the Navigator panel onto the chart
3. Configure input parameters (see Parameter Reference below)
4. Click **OK**

---

## ⚙️ Parameter Reference

### Risk Management
| Parameter | Default | Description |
|-----------|---------|-------------|
| `Risk_Percent` | 2.0 | Percentage of account balance to risk per trade |
| `Risk_Reward_Ratio` | 2.0 | Take profit = Stop loss × this ratio |
| `Max_Open_Trades` | 1 | Maximum concurrent open positions |
| `Max_Daily_Loss` | 6.0 | Stop trading if daily loss reaches this % |
| `Max_Drawdown` | 20.0 | Alert and stop if equity drawdown reaches this % |

### Pin Bar Settings
| Parameter | Default | Description |
|-----------|---------|-------------|
| `PinBar_Wick_Ratio` | 2.0 | Minimum wick-to-body length ratio |
| `PinBar_Body_Percent` | 33.0 | Maximum body size as % of total candle range |

### Support/Resistance
| Parameter | Default | Description |
|-----------|---------|-------------|
| `SR_Lookback_Bars` | 500 | Number of historical bars to scan |
| `SR_Touch_Distance` | 20 | Pip tolerance for merging nearby levels |
| `SR_Min_Touches` | 2 | Minimum confirmed touches to validate a level |

### Trade Protection
| Parameter | Default | Description |
|-----------|---------|-------------|
| `Use_Trailing_Stop` | true | Enable automatic trailing stop |
| `Trailing_Start` | 30 | Pips of profit before trailing activates |
| `Trailing_Step` | 10 | Step size for each trailing adjustment |
| `Use_BreakEven` | true | Enable automatic break-even |
| `BreakEven_Profit` | 20 | Pips of profit to trigger break-even move |
| `BreakEven_Plus` | 5 | Extra pips locked in when break-even triggers |

### Trading Sessions (GMT)
| Parameter | Default | Description |
|-----------|---------|-------------|
| `Trade_Asian_Session` | false | Allow trading during Asian session |
| `Trade_London_Session` | true | Allow trading during London session |
| `Trade_NewYork_Session` | true | Allow trading during NY session |

### Multi-Timeframe
| Parameter | Default | Description |
|-----------|---------|-------------|
| `Use_MTF_Confirmation` | true | Require H4 trend alignment for entries |
| `Higher_Timeframe` | H4 | Timeframe used for trend bias check |
| `Entry_Timeframe` | H1 | Timeframe used for pattern detection |

### Visual Settings
| Parameter | Default | Description |
|-----------|---------|-------------|
| `Show_Dashboard` | true | Display the stats panel |
| `Draw_SR_Lines` | true | Draw S/R horizontal lines |
| `Draw_PinBar_Arrows` | true | Draw arrows on detected pin bars |
| `Draw_Trendlines` | true | Draw validated trendlines |
| `Draw_Session_Lines` | false | Draw session start/end vertical lines |

---

## 📊 Backtesting Recommendations

1. **Use tick data** (99% modelling quality) for best results
2. **Test period**: Minimum 1 year (recommend 2–3 years)
3. **Recommended pairs**: EURUSD, GBPUSD, XAUUSD (Gold)
4. **Timeframe**: H1 chart with H4 confirmation enabled
5. **Spread**: Use realistic spread (1–3 pips for major pairs)
6. Start with **default parameters** before optimizing
7. Optimize one parameter group at a time to avoid curve-fitting

### Key Metrics to Evaluate
- **Profit Factor** > 1.5 (target ≥ 2.0)
- **Max Drawdown** < 20%
- **Win Rate** > 40% (compensated by 1:2+ RR ratio)
- **Recovery Factor** > 3.0

---

## 🔧 Troubleshooting

| Issue | Solution |
|-------|----------|
| Compilation errors | Ensure all `.mqh` files are in the correct `Include/` subfolder |
| No trades placed | Check session filter, S/R detection, and H4 bias alignment |
| Dashboard not visible | Enable `Show_Dashboard` and check chart zoom level |
| Too many/few S/R levels | Adjust `SR_Lookback_Bars` and `SR_Min_Touches` |
| Lot size = 0 | Check minimum lot size for the broker; adjust `Risk_Percent` |

---

## ⚠️ Disclaimer

> Trading foreign exchange and CFDs involves significant risk and may not be suitable for all investors. Past performance is not indicative of future results. This Expert Advisor is provided for educational and research purposes. **Always test thoroughly on a demo account before risking real funds.** The developer assumes no responsibility for financial losses resulting from the use of this software.

---

**Version:** 1.0.0  
**Compatibility:** MetaTrader 5 (Build 3000+)  
**Language:** MQL5
