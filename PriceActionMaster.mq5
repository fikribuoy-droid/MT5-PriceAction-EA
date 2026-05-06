//+------------------------------------------------------------------+
//|                                          PriceActionMaster.mq5   |
//|                         Price Action Master Expert Advisor        |
//|                                                                   |
//| Strategies:                                                       |
//|  1. Pin Bar at Support/Resistance (highest priority)             |
//|  2. Break and Retest                                              |
//|  3. Trendline Bounce                                              |
//|                                                                   |
//| Features:                                                         |
//|  - Multi-timeframe confirmation (H4 bias + H1 entry)             |
//|  - Auto S/R detection & visual drawing                            |
//|  - Auto lot sizing via risk %                                     |
//|  - Daily loss & max drawdown protection                           |
//|  - Break-even & trailing stop automation                          |
//|  - Trading session filter                                         |
//|  - Real-time visual dashboard                                     |
//+------------------------------------------------------------------+
#property copyright "Price Action Master EA"
#property link      "https://github.com/fikribuoy-droid/MT5-PriceAction-EA"
#property version   "1.00"
#property strict

#include "Include\RiskManager.mqh"
#include "Include\TimeFilter.mqh"
#include "Include\SupportResistance.mqh"
#include "Include\PinBarDetector.mqh"
#include "Include\BreakRetest.mqh"
#include "Include\TrendlineManager.mqh"
#include "Include\Dashboard.mqh"

//=== Magic number ===================================================
#define MAGIC_NUMBER 20240101

//=================================================================
//  INPUT PARAMETERS
//=================================================================

//--- Risk Management
input group             "=== Risk Management ==="
input double            Risk_Percent         = 2.0;   // Risk per trade (%)
input double            Risk_Reward_Ratio    = 2.0;   // Risk:Reward ratio
input int               Max_Open_Trades      = 1;     // Maximum open positions
input double            Max_Daily_Loss       = 6.0;   // Max daily loss (%)
input double            Max_Drawdown         = 20.0;  // Max drawdown (%)

//--- Pin Bar Settings
input group             "=== Pin Bar Settings ==="
input double            PinBar_Wick_Ratio    = 2.0;   // Wick to body ratio (min)
input double            PinBar_Body_Percent  = 33.0;  // Body size (% of total)

//--- Support / Resistance
input group             "=== Support / Resistance ==="
input int               SR_Lookback_Bars     = 500;   // Bars to scan for S/R
input int               SR_Touch_Distance    = 20;    // Touch tolerance (pips)
input int               SR_Min_Touches       = 2;     // Minimum touches required

//--- Trailing Stop & Break Even
input group             "=== Trailing Stop & Break Even ==="
input bool              Use_Trailing_Stop    = true;  // Enable trailing stop
input int               Trailing_Start       = 30;    // Start trailing (pips profit)
input int               Trailing_Step        = 10;    // Trailing step (pips)
input bool              Use_BreakEven        = true;  // Enable break even
input int               BreakEven_Profit     = 20;    // Move to BE at (pips)
input int               BreakEven_Plus       = 5;     // Lock profit (pips)

//--- Time Filter
input group             "=== Trading Sessions ==="
input bool              Trade_Asian_Session  = false; // Trade Asian session
input bool              Trade_London_Session = true;  // Trade London session
input bool              Trade_NewYork_Session= true;  // Trade NY session

//--- Multi-Timeframe
input group             "=== Multi-Timeframe ==="
input bool              Use_MTF_Confirmation = true;          // Use MTF confirmation
input ENUM_TIMEFRAMES   Higher_Timeframe     = PERIOD_H4;     // Higher TF (bias)
input ENUM_TIMEFRAMES   Entry_Timeframe      = PERIOD_H1;     // Entry TF

//--- Visual Settings
input group             "=== Visual Settings ==="
input bool              Show_Dashboard       = true;  // Show dashboard
input bool              Draw_SR_Lines        = true;  // Draw S/R lines
input bool              Draw_PinBar_Arrows   = true;  // Draw pin bar arrows
input bool              Draw_Trendlines      = true;  // Draw trendlines

//=================================================================
//  MODULE INSTANCES
//=================================================================
CRiskManager       g_risk;
CTimeFilter        g_time;
CSupportResistance g_sr;
CPinBarDetector    g_pinbar;
CBreakRetest       g_breakretest;
CTrendlineManager  g_trendline;
CDashboard         g_dashboard;

//=================================================================
//  STATE VARIABLES
//=================================================================
datetime g_lastH1Bar   = 0;   // Last processed H1 bar time
datetime g_lastH4Bar   = 0;   // Last processed H4 bar time
datetime g_lastDayBar  = 0;   // Last processed daily bar time
datetime g_lastTFDraw  = 0;   // Last session line draw

//=================================================================
//  EVENT HANDLERS
//=================================================================

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("==============================================");
   Print("[EA] Price Action Master EA initializing...");
   Print("[EA] Symbol=", _Symbol, " Broker=", AccountInfoString(ACCOUNT_COMPANY));
   Print("==============================================");

   // Validate timeframe settings
   if(Entry_Timeframe >= Higher_Timeframe && Use_MTF_Confirmation)
   {
      Print("[EA] WARNING: Entry_Timeframe should be lower than Higher_Timeframe!");
   }

   // Initialise modules
   g_risk.Init(Risk_Percent, Risk_Reward_Ratio, Max_Open_Trades,
               Max_Daily_Loss, Max_Drawdown,
               Use_Trailing_Stop, Trailing_Start, Trailing_Step,
               Use_BreakEven, BreakEven_Profit, BreakEven_Plus,
               MAGIC_NUMBER);

   g_time.Init(Trade_Asian_Session, Trade_London_Session, Trade_NewYork_Session);

   g_sr.Init(SR_Lookback_Bars, (double)SR_Touch_Distance,
             SR_Min_Touches, Draw_SR_Lines);

   g_pinbar.Init(PinBar_Wick_Ratio, PinBar_Body_Percent,
                 (double)SR_Touch_Distance, Draw_PinBar_Arrows);

   g_breakretest.Init((double)SR_Touch_Distance);

   g_trendline.Init(Draw_Trendlines, 100);

   g_dashboard.Init(Show_Dashboard);

   // Force full recalculation on first tick
   g_lastH1Bar  = 0;
   g_lastH4Bar  = 0;
   g_lastDayBar = 0;

   Print("[EA] Initialization complete.");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_dashboard.Remove();
   Print("[EA] Deinitialized. Reason=", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // --- Daily reset check ---
   g_risk.CheckDayReset();

   // --- Detect new bars ---
   datetime currentH1Bar  = iTime(_Symbol, Entry_Timeframe,  0);
   datetime currentH4Bar  = iTime(_Symbol, Higher_Timeframe, 0);
   datetime currentDayBar = iTime(_Symbol, PERIOD_D1,        0);

   bool newH1Bar  = (currentH1Bar  != g_lastH1Bar);
   bool newH4Bar  = (currentH4Bar  != g_lastH4Bar);
   bool newDayBar = (currentDayBar != g_lastDayBar);

   // --- Process new day ---
   if(newDayBar)
   {
      g_lastDayBar = currentDayBar;
      g_time.DrawSessionLines();
      Print("[EA] New day detected. SessionLines redrawn.");
   }

   // --- Process new H4 bar (HTF analysis) ---
   if(newH4Bar && Use_MTF_Confirmation)
   {
      g_lastH4Bar = currentH4Bar;
      // H4 trend is computed on demand in NewH1Bar logic
      Print("[EA] New H4 bar. Higher TF bias recalculated.");
   }

   // --- Process new H1 bar (entry logic) ---
   if(newH1Bar)
   {
      g_lastH1Bar = currentH1Bar;
      ProcessNewBar();
   }

   // --- Manage open positions every tick ---
   g_risk.ManageOpenTrades();

   // --- Update dashboard every tick ---
   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Core logic executed on each new entry-TF bar                     |
//+------------------------------------------------------------------+
void ProcessNewBar()
{
   // 1. Refresh S/R and Trendlines periodically
   g_sr.Refresh(Entry_Timeframe);
   g_trendline.Refresh(Entry_Timeframe);

   // 2. Check session filter
   if(!g_time.IsTradingAllowed())
   {
      Print("[EA] Outside trading session. No trade.");
      return;
   }

   // 3. Check risk limits
   if(!g_risk.CanOpenTrade()) return;

   // 4. Get HTF trend direction
   int htfTrend = 0;
   if(Use_MTF_Confirmation)
   {
      htfTrend = g_trendline.GetHTFTrend(Higher_Timeframe);
      Print("[EA] HTF trend (", EnumToString(Higher_Timeframe), ")=", htfTrend);
   }

   // 5. Evaluate strategies in priority order
   // ----- STRATEGY 1: Pin Bar at S/R -----
   ENUM_PINBAR_TYPE pb = g_pinbar.Detect(Entry_Timeframe, 1, g_sr);

   if(pb == PINBAR_BULLISH && (htfTrend >= 0 || !Use_MTF_Confirmation))
   {
      Print("[EA] Strategy 1: Bullish Pin Bar signal -> BUY");
      ExecuteBuy("PinBar_Support");
      return;
   }
   if(pb == PINBAR_BEARISH && (htfTrend <= 0 || !Use_MTF_Confirmation))
   {
      Print("[EA] Strategy 1: Bearish Pin Bar signal -> SELL");
      ExecuteSell("PinBar_Resistance");
      return;
   }

   // ----- STRATEGY 2: Break & Retest -----
   ENUM_BR_SIGNAL br = g_breakretest.Evaluate(Entry_Timeframe, g_sr);

   if(br == BR_BULLISH && (htfTrend >= 0 || !Use_MTF_Confirmation))
   {
      Print("[EA] Strategy 2: Break & Retest BUY signal");
      ExecuteBuy("BreakRetest_Buy");
      return;
   }
   if(br == BR_BEARISH && (htfTrend <= 0 || !Use_MTF_Confirmation))
   {
      Print("[EA] Strategy 2: Break & Retest SELL signal");
      ExecuteSell("BreakRetest_Sell");
      return;
   }

   // ----- STRATEGY 3: Trendline Bounce -----
   ENUM_TL_SIGNAL tl = g_trendline.CheckBounce(Entry_Timeframe, 1, g_pinbar);

   if(tl == TL_BUY && (htfTrend >= 0 || !Use_MTF_Confirmation))
   {
      Print("[EA] Strategy 3: Trendline BUY bounce");
      ExecuteBuy("Trendline_Bounce_Buy");
      return;
   }
   if(tl == TL_SELL && (htfTrend <= 0 || !Use_MTF_Confirmation))
   {
      Print("[EA] Strategy 3: Trendline SELL bounce");
      ExecuteSell("Trendline_Bounce_Sell");
      return;
   }
}

//+------------------------------------------------------------------+
//| Execute a BUY order with auto SL / TP / lot size                 |
//+------------------------------------------------------------------+
void ExecuteBuy(string comment)
{
   double pipSize = GetPipSize();
   double ask     = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double low1    = iLow(_Symbol, Entry_Timeframe, 1);

   // SL below the last closed candle low + buffer
   double sl = low1 - 2.0 * pipSize;
   sl = NormalizeDouble(sl, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));

   double slPips = (ask - sl) / pipSize;
   if(slPips < 5)
   {
      Print("[EA] ExecuteBuy: SL too tight (", slPips, " pips). Skipping.");
      return;
   }

   double tp   = g_risk.CalcTakeProfit(ask, sl, ORDER_TYPE_BUY);
   double lots = g_risk.CalcLotSize(slPips);
   if(lots <= 0) return;

   g_risk.OpenBuy(sl, tp, lots, comment);
}

//+------------------------------------------------------------------+
//| Execute a SELL order with auto SL / TP / lot size                |
//+------------------------------------------------------------------+
void ExecuteSell(string comment)
{
   double pipSize = GetPipSize();
   double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double high1   = iHigh(_Symbol, Entry_Timeframe, 1);

   // SL above the last closed candle high + buffer
   double sl = high1 + 2.0 * pipSize;
   sl = NormalizeDouble(sl, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));

   double slPips = (sl - bid) / pipSize;
   if(slPips < 5)
   {
      Print("[EA] ExecuteSell: SL too tight (", slPips, " pips). Skipping.");
      return;
   }

   double tp   = g_risk.CalcTakeProfit(bid, sl, ORDER_TYPE_SELL);
   double lots = g_risk.CalcLotSize(slPips);
   if(lots <= 0) return;

   g_risk.OpenSell(sl, tp, lots, comment);
}

//+------------------------------------------------------------------+
//| Update dashboard with current statistics                         |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(!Show_Dashboard) return;

   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity     = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyPL    = g_risk.GetDailyPL();
   double dailyPLPct = g_risk.GetDailyPLPercent();
   double ddPct      = g_risk.GetDrawdownPercent();
   int    openTrades = g_risk.CountOpenPositions();
   double winRate    = g_risk.GetWinRate();
   int    srLevels   = g_sr.GetActiveCount();
   string session    = g_time.GetCurrentSession();
   string nextSess   = g_time.GetNextSession();
   bool   halted     = g_risk.IsTradingHalted();

   g_dashboard.Update(balance, equity, dailyPL, dailyPLPct, ddPct,
                      openTrades, winRate, srLevels,
                      session, nextSess, halted,
                      Max_Daily_Loss, Max_Drawdown);
}

//+------------------------------------------------------------------+
//| Helper: get pip size for the current symbol                      |
//+------------------------------------------------------------------+
double GetPipSize()
{
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return (digits == 3 || digits == 5) ? point * 10.0 : point;
}

//+------------------------------------------------------------------+
//| Trade transaction handler (track wins/losses)                    |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      ulong dealTicket = trans.deal;
      if(HistoryDealSelect(dealTicket))
      {
         long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
         if(magic != MAGIC_NUMBER) return;

         long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         if(entry == DEAL_ENTRY_OUT)
         {
            double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            if(profit >= 0)
               g_risk.RecordWin();
            else
               g_risk.RecordLoss();

            Print("[EA] Trade closed. Profit=", profit,
                  " WinRate=", g_risk.GetWinRate(), "%");
         }
      }
   }
}
