//+------------------------------------------------------------------+
//|                                                 BreakRetest.mqh |
//|                    Price Action Master EA - Break & Retest       |
//|                                                                  |
//| Detects when price breaks through a Support/Resistance level,   |
//| then retests the broken level (role reversal), and forms a       |
//| rejection/confirmation candle for entry.                         |
//+------------------------------------------------------------------+
#ifndef BREAK_RETEST_MQH
#define BREAK_RETEST_MQH

//+------------------------------------------------------------------+
//| States in the break-and-retest lifecycle                         |
//+------------------------------------------------------------------+
enum ENUM_BREAK_STATE
{
   BS_NONE      = 0,   // No active setup
   BS_BREAKOUT  = 1,   // Price has broken a level
   BS_RETEST    = 2,   // Price has returned to retest the level
   BS_CONFIRMED = 3    // Rejection candle confirmed - ready for entry
};

//+------------------------------------------------------------------+
//| Break-and-retest setup data                                      |
//+------------------------------------------------------------------+
struct BreakRetestSignal
{
   bool            valid;           // Signal is tradable
   bool            is_bullish;      // True = buy (support breakout retest)
   double          level_price;     // The broken S/R level
   double          entry_price;     // Suggested entry
   double          stop_loss;       // Suggested SL
   datetime        breakout_time;   // When the breakout candle closed
   datetime        retest_time;     // When the retest was confirmed
   ENUM_BREAK_STATE state;
};

//+------------------------------------------------------------------+
//| CBreakRetest - Manages break-and-retest strategy                 |
//+------------------------------------------------------------------+
class CBreakRetest
{
private:
   string          m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   double          m_tolerance_pips;  // Level proximity tolerance
   bool            m_draw_markers;

   // Track up to 10 active setups
   BreakRetestSignal m_setups[10];
   int               m_setup_count;

   // Helpers
   double   PipSize(void);
   bool     IsStrongBreakout(int bar, double level, bool upward);
   bool     IsRejectionCandle(int bar, bool expecting_buy);
   void     DrawBreakoutMarker(double level, datetime bt, bool upward);
   void     DrawRetestZone(double level, datetime rt);
   void     DrawEntryArrow(const BreakRetestSignal &sig);

public:
   CBreakRetest(void);
   ~CBreakRetest(void);

   void     Init(string symbol, ENUM_TIMEFRAMES tf, double tolerance_pips, bool draw_markers);

   // Update state machine for each S/R level on every new bar
   void     UpdateSetups(double sr_levels[], bool sr_is_support[], int sr_count);

   // Get best confirmed signal (returns false if none)
   bool     GetSignal(BreakRetestSignal &out_signal);

   // Reset all active setups
   void     Reset(void);

   // Visual cleanup
   void     ClearMarkers(void);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CBreakRetest::CBreakRetest(void)
{
   m_symbol         = _Symbol;
   m_timeframe      = PERIOD_H1;
   m_tolerance_pips = 10.0;
   m_draw_markers   = true;
   m_setup_count    = 0;
   ArrayInitialize(m_setups, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CBreakRetest::~CBreakRetest(void)
{
   ClearMarkers();
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
void CBreakRetest::Init(string symbol, ENUM_TIMEFRAMES tf, double tolerance_pips, bool draw_markers)
{
   m_symbol         = symbol;
   m_timeframe      = tf;
   m_tolerance_pips = tolerance_pips;
   m_draw_markers   = draw_markers;
}

//+------------------------------------------------------------------+
//| Pip size                                                         |
//+------------------------------------------------------------------+
double CBreakRetest::PipSize(void)
{
   double point  = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   return (digits == 5 || digits == 3) ? point * 10.0 : point;
}

//+------------------------------------------------------------------+
//| Check if bar[bar_index] is a strong breakout candle through level|
//+------------------------------------------------------------------+
bool CBreakRetest::IsStrongBreakout(int bar, double level, bool upward)
{
   double close_prev = iClose(m_symbol, m_timeframe, bar + 1);
   double close_curr = iClose(m_symbol, m_timeframe, bar);
   double tol        = m_tolerance_pips * PipSize();

   if(upward)
      return (close_prev < level + tol) && (close_curr > level + tol);
   else
      return (close_prev > level - tol) && (close_curr < level - tol);
}

//+------------------------------------------------------------------+
//| Check if a bar is a rejection candle (confirms retest)           |
//+------------------------------------------------------------------+
bool CBreakRetest::IsRejectionCandle(int bar, bool expecting_buy)
{
   double open  = iOpen(m_symbol, m_timeframe, bar);
   double close = iClose(m_symbol, m_timeframe, bar);
   double high  = iHigh(m_symbol, m_timeframe, bar);
   double low   = iLow(m_symbol, m_timeframe, bar);
   double range = high - low;
   if(range < PipSize()) return false;

   if(expecting_buy)
   {
      // Bullish rejection: close > open, and close in upper half of range
      double body_mid = (open + close) / 2.0;
      return (close > open) && (body_mid > (high + low) / 2.0);
   }
   else
   {
      // Bearish rejection: close < open, close in lower half of range
      double body_mid = (open + close) / 2.0;
      return (close < open) && (body_mid < (high + low) / 2.0);
   }
}

//+------------------------------------------------------------------+
//| Draw a vertical line at a breakout candle                        |
//+------------------------------------------------------------------+
void CBreakRetest::DrawBreakoutMarker(double level, datetime bt, bool upward)
{
   if(!m_draw_markers) return;
   string name = StringFormat("BR_Brk_%d_%d", (int)level, (int)bt);
   if(ObjectFind(0, name) >= 0) return;
   ObjectCreate(0, name, OBJ_VLINE, 0, bt, 0);
   ObjectSetInteger(0, name, OBJPROP_COLOR, upward ? clrLimeGreen : clrOrangeRed);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASHDOT);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, StringFormat("Breakout at %.5f", level));
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Draw a rectangle zone around the retest area                     |
//+------------------------------------------------------------------+
void CBreakRetest::DrawRetestZone(double level, datetime rt)
{
   if(!m_draw_markers) return;
   string name = StringFormat("BR_Ret_%d_%d", (int)level, (int)rt);
   if(ObjectFind(0, name) >= 0) return;
   double tol = m_tolerance_pips * PipSize();
   datetime end_time = rt + PeriodSeconds(m_timeframe) * 5;
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, rt, level + tol, end_time, level - tol);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_TRANSPARENCY, 80);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, StringFormat("Retest zone %.5f", level));
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Draw an entry arrow for a confirmed signal                       |
//+------------------------------------------------------------------+
void CBreakRetest::DrawEntryArrow(const BreakRetestSignal &sig)
{
   if(!m_draw_markers) return;
   string name  = StringFormat("BR_Entry_%d", (int)sig.retest_time);
   double price = sig.is_bullish ?
                  iLow(m_symbol, m_timeframe, 1) - 3 * PipSize() :
                  iHigh(m_symbol, m_timeframe, 1) + 3 * PipSize();
   int    arrow = sig.is_bullish ? 233 : 234;
   color  clr   = sig.is_bullish ? clrAqua : clrMagenta;
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_ARROW, 0, sig.retest_time, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrow);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, "Break & Retest Entry");
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Update all setups using current S/R level list                   |
//| Call on each new bar.                                            |
//+------------------------------------------------------------------+
void CBreakRetest::UpdateSetups(double sr_levels[], bool sr_is_support[], int sr_count)
{
   double tol = m_tolerance_pips * PipSize();
   double curr_close = iClose(m_symbol, m_timeframe, 1);
   double curr_low   = iLow(m_symbol, m_timeframe, 1);
   double curr_high  = iHigh(m_symbol, m_timeframe, 1);
   datetime bar_time = iTime(m_symbol, m_timeframe, 1);

   // Step 1: Check existing setups for new state transitions
   for(int i = 0; i < m_setup_count; i++)
   {
      if(m_setups[i].state == BS_CONFIRMED) continue; // Already done

      if(m_setups[i].state == BS_BREAKOUT)
      {
         // Wait for retest: price returns to level
         // For bullish setup (resistance breakout): check if low touches the broken level from above
         // For bearish setup (support breakout): check if high touches the broken level from below
         bool retest_detected = false;
         if(m_setups[i].is_bullish)
            retest_detected = (MathAbs(curr_low - m_setups[i].level_price) <= tol);
         else
            retest_detected = (MathAbs(curr_high - m_setups[i].level_price) <= tol);

         if(retest_detected)
            m_setups[i].state       = BS_RETEST;
            m_setups[i].retest_time = bar_time;
            DrawRetestZone(m_setups[i].level_price, bar_time);
            Print("BreakRetest: Retest detected at level ", m_setups[i].level_price);
         }
      }
      else if(m_setups[i].state == BS_RETEST)
      {
         // Look for rejection/confirmation candle
         if(IsRejectionCandle(1, m_setups[i].is_bullish))
         {
            m_setups[i].state         = BS_CONFIRMED;
            m_setups[i].valid         = true;
            m_setups[i].retest_time   = bar_time;
            m_setups[i].entry_price   = m_setups[i].is_bullish ?
                                        iHigh(m_symbol, m_timeframe, 1) :
                                        iLow(m_symbol, m_timeframe, 1);
            m_setups[i].stop_loss     = m_setups[i].is_bullish ?
                                        iLow(m_symbol, m_timeframe, 1) - tol :
                                        iHigh(m_symbol, m_timeframe, 1) + tol;
            DrawEntryArrow(m_setups[i]);
            Print("BreakRetest: Signal confirmed at level ", m_setups[i].level_price,
                  " Direction=", m_setups[i].is_bullish ? "BUY" : "SELL");
         }
      }
   }

   // Step 2: Check each S/R level for new breakouts
   for(int j = 0; j < sr_count; j++)
   {
      double level      = sr_levels[j];
      bool   is_support = sr_is_support[j];

      // Resistance breakout: bullish (price goes up through resistance)
      if(!is_support && IsStrongBreakout(1, level, true))
      {
         if(m_setup_count < 10)
         {
            BreakRetestSignal s;
            ZeroMemory(s);
            s.state         = BS_BREAKOUT;
            s.level_price   = level;
            s.is_bullish    = true; // Will look for buy on retest
            s.breakout_time = bar_time;
            m_setups[m_setup_count++] = s;
            DrawBreakoutMarker(level, bar_time, true);
            Print("BreakRetest: Resistance breakout at ", level);
         }
      }

      // Support breakout: bearish (price breaks below support)
      if(is_support && IsStrongBreakout(1, level, false))
      {
         if(m_setup_count < 10)
         {
            BreakRetestSignal s;
            ZeroMemory(s);
            s.state         = BS_BREAKOUT;
            s.level_price   = level;
            s.is_bullish    = false; // Will look for sell on retest
            s.breakout_time = bar_time;
            m_setups[m_setup_count++] = s;
            DrawBreakoutMarker(level, bar_time, false);
            Print("BreakRetest: Support breakout at ", level);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get the most recently confirmed signal; returns false if none    |
//+------------------------------------------------------------------+
bool CBreakRetest::GetSignal(BreakRetestSignal &out_signal)
{
   for(int i = m_setup_count - 1; i >= 0; i--)
   {
      if(m_setups[i].state == BS_CONFIRMED && m_setups[i].valid)
      {
         out_signal = m_setups[i];
         m_setups[i].valid = false; // Consume the signal
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Clear all setups                                                 |
//+------------------------------------------------------------------+
void CBreakRetest::Reset(void)
{
   m_setup_count = 0;
   ArrayInitialize(m_setups, 0);
}

//+------------------------------------------------------------------+
//| Remove all break/retest markers from chart                       |
//+------------------------------------------------------------------+
void CBreakRetest::ClearMarkers(void)
{
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, "BR_") == 0)
         ObjectDelete(0, name);
   }
   ChartRedraw(0);
}

#endif // BREAK_RETEST_MQH
