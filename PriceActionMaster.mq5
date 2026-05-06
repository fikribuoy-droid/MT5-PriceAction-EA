//+------------------------------------------------------------------+
//|                                           PriceActionMaster.mq5 |
//|                          Price Action Master Expert Advisor      |
//|                                                                  |
//| Multi-strategy price action EA combining:                        |
//|   1. Pin Bar detection at Support/Resistance levels              |
//|   2. Break-and-Retest strategy                                   |
//|   3. Trendline Bounce trading                                    |
//|                                                                  |
//| With advanced risk management, multi-timeframe confirmation,     |
//| visual dashboard, and session-based time filtering.              |
//|                                                                  |
//| Strategy priority (entry evaluation order):                      |
//|   1. Pin Bar at S/R level (highest priority)                     |
//|   2. Break and Retest                                            |
//|   3. Trendline Bounce                                            |
//+------------------------------------------------------------------+
#property copyright "Price Action Master EA"
#property version   "1.00"
#property strict

#include "Include\RiskManager.mqh"
#include "Include\TimeFilter.mqh"
#include "Include\SupportResistance.mqh"
#include "Include\PinBarDetector.mqh"
#include "Include\BreakRetest.mqh"
#include "Include\TrendlineManager.mqh"
#include "Include\Dashboard.mqh"

// Note: Trade.mqh is included transitively via RiskManager.mqh

//==========================================================================
//  Input Parameters
//==========================================================================

//--- Risk Management
input group "=== Risk Management ==="
input double    Risk_Percent        = 2.0;   // Risk per trade (%)
input double    Risk_Reward_Ratio   = 2.0;   // Risk:Reward ratio
input int       Max_Open_Trades     = 1;     // Maximum open positions
input double    Max_Daily_Loss      = 6.0;   // Max daily loss (%)
input double    Max_Drawdown        = 20.0;  // Max drawdown (%)

//--- Pin Bar Settings
input group "=== Pin Bar Settings ==="
input double    PinBar_Wick_Ratio   = 2.0;  // Wick to body ratio (min)
input double    PinBar_Body_Percent = 33.0; // Body size (% of total candle)

//--- Support/Resistance
input group "=== Support/Resistance ==="
input int       SR_Lookback_Bars    = 500;  // Bars to scan for S/R
input int       SR_Touch_Distance   = 20;   // Touch tolerance (pips)
input int       SR_Min_Touches      = 2;    // Minimum touches required

//--- Trailing Stop & Break Even
input group "=== Trade Protection ==="
input bool      Use_Trailing_Stop   = true; // Enable trailing stop
input int       Trailing_Start      = 30;   // Start trailing at profit (pips)
input int       Trailing_Step       = 10;   // Trailing step size (pips)
input bool      Use_BreakEven       = true; // Enable break even
input int       BreakEven_Profit    = 20;   // Move SL to BE at profit (pips)
input int       BreakEven_Plus      = 5;    // Extra pips locked at BE

//--- Time Filter
input group "=== Trading Sessions (GMT) ==="
input bool      Trade_Asian_Session  = false; // Trade Asian session (00-09 GMT)
input bool      Trade_London_Session = true;  // Trade London session (08-17 GMT)
input bool      Trade_NewYork_Session= true;  // Trade New York session (13-22 GMT)

//--- Multi-Timeframe
input group "=== Multi-Timeframe ==="
input bool          Use_MTF_Confirmation = true;          // Use H4 trend confirmation
input ENUM_TIMEFRAMES Higher_Timeframe   = PERIOD_H4;     // Higher timeframe (bias)
input ENUM_TIMEFRAMES Entry_Timeframe    = PERIOD_H1;     // Entry timeframe

//--- Visual Settings
input group "=== Visual Settings ==="
input bool      Show_Dashboard      = true;  // Show dashboard panel
input bool      Draw_SR_Lines       = true;  // Draw S/R lines
input bool      Draw_PinBar_Arrows  = true;  // Draw pin bar arrows
input bool      Draw_Trendlines     = true;  // Draw trendlines
input bool      Draw_Session_Lines  = false; // Draw session start/end lines

//==========================================================================
//  Module instances
//==========================================================================
CRiskManager        g_risk;
CTimeFilter         g_time_filter;
CSupportResistance  g_sr;
CPinBarDetector     g_pinbar;
CBreakRetest        g_breakretest;
CTrendlineManager   g_trendline;
CDashboard          g_dashboard;
CTrade              g_trade;

//==========================================================================
//  Global state
//==========================================================================
datetime g_last_bar_time  = 0;       // Track new bars
bool     g_initialized    = false;   // Initialization flag
int      g_sr_update_bars = 0;       // Counter for S/R refresh (every 50 bars)
int      g_tl_update_bars = 0;       // Counter for trendline refresh

// Magic number used by all trades placed by this EA
#define EA_MAGIC 123456

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("PriceActionMaster: Initializing...");

   // Configure risk manager
   g_risk.SetMagicNumber(EA_MAGIC);
   g_risk.SetRiskPercent(Risk_Percent);
   g_risk.SetRRRatio(Risk_Reward_Ratio);
   g_risk.SetMaxOpenTrades(Max_Open_Trades);
   g_risk.SetMaxDailyLoss(Max_Daily_Loss);
   g_risk.SetMaxDrawdown(Max_Drawdown);
   g_risk.SetTrailingStop(Use_Trailing_Stop, Trailing_Start, Trailing_Step);
   g_risk.SetBreakEven(Use_BreakEven, BreakEven_Profit, BreakEven_Plus);
   if(!g_risk.Init(_Symbol))
   {
      Print("PriceActionMaster: RiskManager init failed!");
      return INIT_FAILED;
   }

   // Configure time filter
   g_time_filter.SetSessions(Trade_Asian_Session, Trade_London_Session, Trade_NewYork_Session);
   g_time_filter.SetDrawSessionLines(Draw_Session_Lines);

   // Configure S/R detector
   g_sr.Init(_Symbol, Entry_Timeframe, SR_Lookback_Bars, SR_Touch_Distance, SR_Min_Touches, Draw_SR_Lines);
   g_sr.ScanLevels();

   // Configure pin bar detector
   g_pinbar.Init(_Symbol, Entry_Timeframe,
                 PinBar_Wick_Ratio, PinBar_Body_Percent, SR_Touch_Distance,
                 Draw_PinBar_Arrows, true);

   // Configure break-and-retest
   g_breakretest.Init(_Symbol, Entry_Timeframe, SR_Touch_Distance, true);

   // Configure trendline manager
   g_trendline.Init(_Symbol, Entry_Timeframe, 200, 3, 10.0, Draw_Trendlines);
   g_trendline.Update();

   // Configure dashboard
   g_dashboard.Init(Show_Dashboard);

   // Configure trade object
   g_trade.SetExpertMagicNumber(EA_MAGIC);
   g_trade.SetDeviationInPoints(20);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);

   g_initialized = true;
   Print("PriceActionMaster: Initialization complete. Symbol=", _Symbol,
         " EntryTF=", EnumToString(Entry_Timeframe),
         " HigherTF=", EnumToString(Higher_Timeframe));

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("PriceActionMaster: Deinitializing (reason=", reason, ")");
   g_sr.ClearAllLines();
   g_pinbar.ClearArrows();
   g_breakretest.ClearMarkers();
   g_trendline.ClearAll();
   g_dashboard.Clear();
   g_time_filter.RemoveSessionLines();
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_initialized) return;

   // ----------------------------------------------------------------
   // 1. Manage existing open trades (trailing stop, break even)
   // ----------------------------------------------------------------
   g_risk.ManageOpenTrades();

   // ----------------------------------------------------------------
   // 2. Detect new bar on entry timeframe
   // ----------------------------------------------------------------
   datetime current_bar = iTime(_Symbol, Entry_Timeframe, 0);
   bool new_bar = (current_bar != g_last_bar_time);

   if(new_bar)
   {
      g_last_bar_time = current_bar;
      OnNewBar();
   }

   // ----------------------------------------------------------------
   // 3. Update dashboard on every tick
   // ----------------------------------------------------------------
   if(Show_Dashboard)
      UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Called on every new bar on the entry timeframe                   |
//+------------------------------------------------------------------+
void OnNewBar()
{
   // Periodic S/R rescan (every 50 bars)
   g_sr_update_bars++;
   if(g_sr_update_bars >= 50)
   {
      g_sr_update_bars = 0;
      g_sr.ScanLevels();
      Print("PriceActionMaster: S/R levels rescanned.");
   }
   else
   {
      g_sr.UpdateTouches();
   }

   // Periodic trendline update (every 20 bars)
   g_tl_update_bars++;
   if(g_tl_update_bars >= 20)
   {
      g_tl_update_bars = 0;
      g_trendline.Update();
   }

   // Draw session lines if enabled
   if(Draw_Session_Lines)
      g_time_filter.DrawSessionLines(iTime(_Symbol, Entry_Timeframe, 0));

   // Only look for new setups if a new trade is allowed
   if(!g_risk.IsNewTradeAllowed())
   {
      if(g_risk.IsDailyLossReached())
         Print("PriceActionMaster: Daily loss limit reached - no new trades.");
      if(g_risk.IsMaxDrawdownReached())
         Print("PriceActionMaster: Max drawdown reached - no new trades.");
      return;
   }

   // Check trading session
   if(!g_time_filter.IsAllowedToTrade())
   {
      Print("PriceActionMaster: Outside allowed trading session - skipping.");
      return;
   }

   // Check H4 trend bias (if MTF confirmation enabled)
   int h4_bias = 0; // +1 = uptrend, -1 = downtrend, 0 = neutral
   if(Use_MTF_Confirmation)
   {
      h4_bias = GetH4Bias();
      if(h4_bias == 0)
      {
         Print("PriceActionMaster: No clear H4 trend bias - skipping.");
         return;
      }
   }

   // ----------------------------------------------------------------
   // Strategy evaluation (priority order)
   // ----------------------------------------------------------------
   EvaluateStrategies(h4_bias);
}

//+------------------------------------------------------------------+
//| Determine H4 market structure bias                               |
//| Returns +1 (bullish), -1 (bearish), 0 (neutral/unclear)         |
//+------------------------------------------------------------------+
int GetH4Bias()
{
   // Get last 4 swing points on H4 to identify HH/HL or LH/LL
   int h4_bars = iBars(_Symbol, Higher_Timeframe);
   if(h4_bars < 20) return 0;

   // Simple approach: compare 4 recent H4 closes to detect trend
   double close0 = iClose(_Symbol, Higher_Timeframe, 1);
   double close4 = iClose(_Symbol, Higher_Timeframe, 5);
   double close8 = iClose(_Symbol, Higher_Timeframe, 9);

   // Moving average based trend (20-bar H4 simple trend check)
   double ma_fast = 0, ma_slow = 0;
   int fast_period = 8, slow_period = 20;

   for(int i = 1; i <= fast_period; i++)
      ma_fast += iClose(_Symbol, Higher_Timeframe, i);
   ma_fast /= fast_period;

   for(int i = 1; i <= slow_period; i++)
      ma_slow += iClose(_Symbol, Higher_Timeframe, i);
   ma_slow /= slow_period;

   // Higher highs/lows structure
   bool price_rising = (close0 > close4) && (close4 > close8);
   bool price_falling = (close0 < close4) && (close4 < close8);

   if(price_rising && ma_fast > ma_slow) return 1;   // Bullish bias
   if(price_falling && ma_fast < ma_slow) return -1; // Bearish bias
   return 0; // Neutral
}

//+------------------------------------------------------------------+
//| Evaluate all strategies and execute the highest-priority setup   |
//+------------------------------------------------------------------+
void EvaluateStrategies(int h4_bias)
{
   // Build S/R level arrays for break-retest module
   double sr_prices[MAX_SR_LEVELS];
   bool   sr_is_support[MAX_SR_LEVELS];
   int    sr_count = 0;

   for(int i = 0; i < g_sr.GetLevelCount() && sr_count < MAX_SR_LEVELS; i++)
   {
      SRLevel lvl = g_sr.GetLevel(i);
      if(!lvl.is_active) continue;
      sr_prices[sr_count]     = lvl.price;
      sr_is_support[sr_count] = lvl.is_support;
      sr_count++;
   }

   // Update break-retest state machine
   g_breakretest.UpdateSetups(sr_prices, sr_is_support, sr_count);

   // Last closed bar context
   double bar1_low  = iLow(_Symbol, Entry_Timeframe, 1);
   double bar1_high = iHigh(_Symbol, Entry_Timeframe, 1);
   double bar1_close = iClose(_Symbol, Entry_Timeframe, 1);

   bool at_support    = g_sr.IsAtSupportLevel(bar1_low);
   bool at_resistance = g_sr.IsAtResistanceLevel(bar1_high);

   // ----------------------------------------------------------------
   // Priority 1: Pin Bar at S/R level
   // ----------------------------------------------------------------
   if(at_support || at_resistance)
   {
      PinBarSignal pb = g_pinbar.Detect(1, at_support, at_resistance);
      if(pb.valid)
      {
         // MTF check: bullish pin bar needs bullish H4 bias (or neutral allowed)
         bool mtf_ok = !Use_MTF_Confirmation ||
                       (pb.is_bullish  && h4_bias >= 0) ||
                       (!pb.is_bullish && h4_bias <= 0);
         if(mtf_ok)
         {
            Print("PriceActionMaster: Pin Bar signal at S/R! Direction=",
                  pb.is_bullish ? "BUY" : "SELL");
            ExecuteTrade(pb.is_bullish ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                         pb.entry_price, pb.stop_loss, "PinBar_SR");
            return; // One setup per bar
         }
      }
   }

   // ----------------------------------------------------------------
   // Priority 2: Break and Retest
   // ----------------------------------------------------------------
   BreakRetestSignal br;
   if(g_breakretest.GetSignal(br))
   {
      bool mtf_ok = !Use_MTF_Confirmation ||
                    (br.is_bullish  && h4_bias >= 0) ||
                    (!br.is_bullish && h4_bias <= 0);
      if(mtf_ok)
      {
         Print("PriceActionMaster: Break & Retest signal! Direction=",
               br.is_bullish ? "BUY" : "SELL");
         ExecuteTrade(br.is_bullish ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                      br.entry_price, br.stop_loss, "BreakRetest");
         return;
      }
   }

   // ----------------------------------------------------------------
   // Priority 3: Trendline Bounce
   // ----------------------------------------------------------------
   TrendlineSignal tl_sig;
   if(g_trendline.GetBounceSignal(tl_sig))
   {
      // Confluence: must also be near S/R or aligned with H4 trend
      bool has_confluence = at_support || at_resistance;
      bool mtf_ok = !Use_MTF_Confirmation ||
                    (tl_sig.is_bullish  && h4_bias >= 0) ||
                    (!tl_sig.is_bullish && h4_bias <= 0);

      if(mtf_ok && has_confluence)
      {
         Print("PriceActionMaster: Trendline Bounce signal! Direction=",
               tl_sig.is_bullish ? "BUY" : "SELL");
         ExecuteTrade(tl_sig.is_bullish ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                      tl_sig.entry_price, tl_sig.stop_loss, "TrendlineBounce");
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Execute a trade with calculated lot size and take profit         |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE order_type, double entry_price, double sl_price, string strategy)
{
   string symbol   = _Symbol;
   int    direction = (order_type == ORDER_TYPE_BUY) ? 1 : -1;

   // Validate SL distance
   double sl_dist_pips = MathAbs(entry_price - sl_price) /
                         (SymbolInfoDouble(symbol, SYMBOL_POINT) *
                          ((SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 5 ||
                            SymbolInfoInteger(symbol, SYMBOL_DIGITS) == 3) ? 10.0 : 1.0));

   if(sl_dist_pips < 5.0)
   {
      Print("PriceActionMaster: SL too tight (", sl_dist_pips, " pips) - trade rejected.");
      return;
   }

   // Calculate lot size
   double lots = g_risk.CalculateLotSize(symbol, sl_price, entry_price);
   if(lots <= 0)
   {
      Print("PriceActionMaster: Invalid lot size calculated.");
      return;
   }

   // Calculate take profit
   double tp_price = g_risk.CalculateTakeProfit(symbol, entry_price, sl_price, direction);

   // Get current spread-adjusted price
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double exec_price = (order_type == ORDER_TYPE_BUY) ? ask : bid;

   // Adjust SL/TP by spread for market order
   // (entry_price is suggestive; we use market price for execution)
   double adjusted_sl = sl_price;
   double adjusted_tp = tp_price + (exec_price - entry_price) * direction;

   Print(StringFormat("PriceActionMaster: Executing %s trade. Strategy=%s  Lots=%.2f  Entry=%.5f  SL=%.5f  TP=%.5f",
         (order_type == ORDER_TYPE_BUY) ? "BUY" : "SELL",
         strategy, lots, exec_price, adjusted_sl, adjusted_tp));

   bool result = false;
   if(order_type == ORDER_TYPE_BUY)
      result = g_trade.Buy(lots, symbol, exec_price, adjusted_sl, adjusted_tp,
                           StringFormat("PA_EA_%s", strategy));
   else
      result = g_trade.Sell(lots, symbol, exec_price, adjusted_sl, adjusted_tp,
                            StringFormat("PA_EA_%s", strategy));

   if(result)
   {
      Print(StringFormat("PriceActionMaster: Trade opened successfully. Ticket=%d",
            (int)g_trade.ResultOrder()));
   }
   else
   {
      Print(StringFormat("PriceActionMaster: Trade FAILED. Error=%d RetCode=%d",
            GetLastError(), g_trade.ResultRetcode()));
   }
}

//+------------------------------------------------------------------+
//| Refresh the dashboard with current statistics                    |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity     = AccountInfoDouble(ACCOUNT_EQUITY);
   double daily_pl   = g_risk.GetDailyPL();
   double daily_pct  = g_risk.GetDailyPLPercent();
   int    open_trades= g_risk.GetOpenTradeCount();
   double win_rate   = g_risk.GetWinRate();
   double exposure   = g_risk.GetCurrentRiskExposure();
   int    sr_count   = 0;

   for(int i = 0; i < g_sr.GetLevelCount(); i++)
      if(g_sr.GetLevel(i).is_active) sr_count++;

   string session_name = g_time_filter.GetSessionName(g_time_filter.GetCurrentSession());
   bool   dl_warning   = g_risk.IsDailyLossReached() || (daily_pct < -(Max_Daily_Loss * 0.8));
   bool   dd_warning   = g_risk.IsMaxDrawdownReached();

   g_dashboard.Update(balance, equity, daily_pl, daily_pct,
                      open_trades, win_rate, exposure,
                      sr_count, session_name, dl_warning, dd_warning);
}

//+------------------------------------------------------------------+
//| Track closed trades for win/loss statistics                      |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   // Only process deal-add events
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;

   ulong deal = trans.deal;
   if(!HistoryDealSelect(deal)) return;

   // Only track our EA's deals
   if(HistoryDealGetInteger(deal, DEAL_MAGIC) != EA_MAGIC) return;

   ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT) return; // Only count closed positions

   double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);
   if(profit > 0)
      g_risk.RecordWin();
   else
      g_risk.RecordLoss();

   Print(StringFormat("PriceActionMaster: Trade closed. Profit=%.2f  WinRate=%.1f%%",
         profit, g_risk.GetWinRate()));
}
