# Price Action Master EA — MetaTrader 5

> **Professional MT5 Expert Advisor** implementing three complementary Price Action strategies with full risk management, visual drawing tools, and a real-time dashboard.

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Features](#features)
3. [File Structure](#file-structure)
4. [Installation](#installation)
5. [Quick Start](#quick-start)
6. [Parameter Reference](#parameter-reference)
7. [Strategy Logic](#strategy-logic)
8. [Backtesting](#backtesting)
9. [Disclaimer](#disclaimer)

---

## Overview

**Price Action Master EA** automatically identifies high-probability trade setups using three professional price action strategies:

| Priority | Strategy | Condition |
|----------|----------|-----------|
| 1 | Pin Bar at S/R | Valid pin bar touching a key S/R level |
| 2 | Break & Retest | S/R breakout followed by a retest rejection |
| 3 | Trendline Bounce | Price bouncing off a validated trendline |

All entries require **multi-timeframe confirmation** (H4 trend bias + H1 entry signal) and pass through strict risk filters before a trade is opened.

---

## Features

### 📊 Trading Strategies
- **Pin Bar Detection** — Identifies bullish (long lower wick) and bearish (long upper wick) pin bars at S/R levels with customisable wick/body ratio and body-size thresholds.
- **Break & Retest** — Detects clean S/R breakouts and waits for a role-reversal retest before entering in the direction of the break.
- **Trendline Bounce** — Draws uptrend and downtrend lines from swing highs/lows; enters on bounce confirmation with a minimum of 3 trendline touches.

### 🛡️ Risk Management
- Auto position sizing: `Lot = (Balance × Risk%) / (SL pips × Pip Value)`
- Configurable Risk:Reward ratio (default 1:2)
- Maximum 1 open trade at a time (configurable)
- **Daily loss limit** — stops trading if daily loss exceeds 6% (configurable)
- **Maximum drawdown** — alerts and halts if drawdown exceeds 20% (configurable)

### 🔒 Trade Protection
- **Break Even** — moves SL to entry + X pips once a configurable profit target is reached
- **Trailing Stop** — trails price by a configurable step once profit exceeds the start threshold

### 🕐 Session Filter
- Asian: 00:00–09:00 GMT (off by default)
- London: 08:00–17:00 GMT (on by default)
- New York: 13:00–22:00 GMT (on by default)
- London/NY overlap is automatically prioritised

### 📈 Visuals
- Horizontal S/R lines (blue = support, red = resistance)
- Pin bar arrows (green = bullish, red = bearish)
- Trendlines (green = uptrend, red = downtrend)
- Session boundary vertical lines
- Real-time dashboard (top-right corner)

---

## File Structure

```
MT5-PriceAction-EA/
├── PriceActionMaster.mq5          ← Main EA file
├── Include/
│   ├── RiskManager.mqh            ← Position sizing, BE, trailing stop
│   ├── TimeFilter.mqh             ← Session filter
│   ├── SupportResistance.mqh      ← S/R detection & drawing
│   ├── PinBarDetector.mqh         ← Pin bar identification
│   ├── BreakRetest.mqh            ← Break & retest logic
│   ├── TrendlineManager.mqh       ← Trendline detection & drawing
│   └── Dashboard.mqh              ← On-chart statistics panel
├── README.md
└── UserManual.md                  ← Full guide in Bahasa Indonesia
```

---

## Installation

### Requirements
- MetaTrader 5 platform (build 2800 or newer)
- A broker account (demo or live)

### Steps

1. **Download or clone** this repository.
2. Open the **MT5 Data Folder**: `File → Open Data Folder`.
3. Copy all files keeping the same directory structure:
   - `PriceActionMaster.mq5` → `MQL5/Experts/PriceActionMaster/`
   - All `Include/*.mqh` files → `MQL5/Experts/PriceActionMaster/Include/`
4. In MetaEditor, open `PriceActionMaster.mq5` and press **F7** to compile.
5. Attach the EA to a chart (recommended: EURUSD H1).
6. Enable **AutoTrading** in MetaTrader.

---

## Quick Start

1. Attach EA to an **H1 chart** of your preferred symbol.
2. Set `Entry_Timeframe = PERIOD_H1` and `Higher_Timeframe = PERIOD_H4`.
3. Set `Risk_Percent = 1.0` for conservative risk while testing.
4. Enable **Allow Auto Trading** and **Allow DLL Imports** in EA properties.
5. Watch the dashboard appear in the top-right corner.

---

## Parameter Reference

### Risk Management

| Parameter | Default | Description |
|-----------|---------|-------------|
| `Risk_Percent` | `2.0` | % of account balance risked per trade |
| `Risk_Reward_Ratio` | `2.0` | Take Profit = Stop Loss × RR |
| `Max_Open_Trades` | `1` | Maximum simultaneous open positions |
| `Max_Daily_Loss` | `6.0` | Daily loss % limit (stops trading if hit) |
| `Max_Drawdown` | `20.0` | Max drawdown % (alerts and halts trading) |

### Pin Bar Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `PinBar_Wick_Ratio` | `2.0` | Minimum wick-to-body ratio |
| `PinBar_Body_Percent` | `33.0` | Maximum body as % of total candle range |

### Support / Resistance

| Parameter | Default | Description |
|-----------|---------|-------------|
| `SR_Lookback_Bars` | `500` | Number of bars scanned for S/R levels |
| `SR_Touch_Distance` | `20` | Pip tolerance for a level "touch" |
| `SR_Min_Touches` | `2` | Minimum touches to activate a level |

### Trailing Stop & Break Even

| Parameter | Default | Description |
|-----------|---------|-------------|
| `Use_Trailing_Stop` | `true` | Enable trailing stop |
| `Trailing_Start` | `30` | Pips profit before trailing activates |
| `Trailing_Step` | `10` | Pips the trail follows price |
| `Use_BreakEven` | `true` | Enable break-even automation |
| `BreakEven_Profit` | `20` | Pips profit before BE activates |
| `BreakEven_Plus` | `5` | Pips locked above entry at BE |

### Trading Sessions

| Parameter | Default | Description |
|-----------|---------|-------------|
| `Trade_Asian_Session` | `false` | Enable Asian session (00:00–09:00 GMT) |
| `Trade_London_Session` | `true` | Enable London session (08:00–17:00 GMT) |
| `Trade_NewYork_Session` | `true` | Enable New York session (13:00–22:00 GMT) |

### Multi-Timeframe

| Parameter | Default | Description |
|-----------|---------|-------------|
| `Use_MTF_Confirmation` | `true` | Require H4 trend to align with entry |
| `Higher_Timeframe` | `PERIOD_H4` | Timeframe used for trend bias |
| `Entry_Timeframe` | `PERIOD_H1` | Timeframe used for entry signals |

### Visual Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `Show_Dashboard` | `true` | Show real-time statistics panel |
| `Draw_SR_Lines` | `true` | Draw S/R horizontal lines on chart |
| `Draw_PinBar_Arrows` | `true` | Draw arrows on detected pin bars |
| `Draw_Trendlines` | `true` | Draw trendlines on chart |

---

## Strategy Logic

### 1. Pin Bar at S/R
```
IF pin bar detected on Entry_TF (closed candle)
   AND price within SR_Touch_Distance pips of active S/R level
   AND (HTF trend aligned OR MTF confirmation disabled)
THEN open trade (BUY for bullish pin, SELL for bearish pin)
```

### 2. Break & Retest
```
IF S/R level broken with close beyond level
THEN register breakout event
   
IF price returns to broken level (within tolerance)
   AND rejection candle forms (closes away from level)
   AND (HTF trend aligned OR MTF confirmation disabled)
THEN open trade in breakout direction
```

### 3. Trendline Bounce
```
IF valid trendline with >= 3 touches
   AND price touches trendline
   AND confirmation: bullish/bearish close or pin bar
   AND (HTF trend aligned OR MTF confirmation disabled)
THEN open trade in trend direction
```

### Stop Loss & Take Profit
- **BUY**: SL = Low of last closed candle − 2 pips buffer
- **SELL**: SL = High of last closed candle + 2 pips buffer
- **TP**: Calculated as `SL distance × Risk_Reward_Ratio`

---

## Backtesting

### Recommended Settings
| Setting | Value |
|---------|-------|
| Spread | Typical (not fixed) |
| Model | Every tick based on real ticks |
| Period | Minimum 6 months |
| Start balance | $10,000 |

### Optimisation Notes
- Start with default parameters before optimising
- Most impactful parameters: `PinBar_Wick_Ratio`, `SR_Touch_Distance`, `SR_Min_Touches`
- Test across multiple symbols: EURUSD, GBPUSD, XAUUSD
- Forward test on demo for minimum 1 month before live trading

---

## ⚠️ Disclaimer

> **Trading foreign exchange and CFDs carries significant risk of loss and may not be suitable for all investors. Past performance is not indicative of future results. Always test on a demo account before using real funds. The authors of this EA accept no responsibility for financial losses incurred through its use.**
