//+------------------------------------------------------------------+
//|                                           TrendlineManager.mqh  |
//|                   Price Action Master EA - Trendline Manager     |
//|                                                                  |
//| Automatically identifies swing highs and lows, draws trendlines,|
//| validates them by touch count, and detects trendline bounces     |
//| suitable for trade entry.                                        |
//+------------------------------------------------------------------+
#ifndef TRENDLINE_MANAGER_MQH
#define TRENDLINE_MANAGER_MQH

#define MAX_TRENDLINES 20
#define MAX_SWINGS     100

//+------------------------------------------------------------------+
//| Swing point data                                                 |
//+------------------------------------------------------------------+
struct SwingPoint
{
   double   price;
   datetime time;
   bool     is_high;  // True = swing high, False = swing low
};

//+------------------------------------------------------------------+
//| Trendline data                                                   |
//+------------------------------------------------------------------+
struct Trendline
{
   bool     is_active;
   bool     is_uptrend;    // True = connects swing lows (uptrend line)
   double   price1;        // Anchor point 1 (older)
   double   price2;        // Anchor point 2 (newer)
   datetime time1;
   datetime time2;
   int      touches;       // Confirmed touch count
   string   obj_name;
};

//+------------------------------------------------------------------+
//| Trendline bounce signal                                          |
//+------------------------------------------------------------------+
struct TrendlineSignal
{
   bool     valid;
   bool     is_bullish;     // True = buy at uptrend line
   double   trendline_price; // Level at current bar
   double   entry_price;
   double   stop_loss;
   int      trendline_index;
};

//+------------------------------------------------------------------+
//| CTrendlineManager - Automatic trendline detection and management |
//+------------------------------------------------------------------+
class CTrendlineManager
{
private:
   string          m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int             m_lookback_bars;
   int             m_min_touches;
   double          m_touch_tolerance_pips;
   bool            m_draw_trendlines;

   SwingPoint      m_swings[MAX_SWINGS];
   int             m_swing_count;
   Trendline       m_lines[MAX_TRENDLINES];
   int             m_line_count;

   // Helpers
   double   PipSize(void);
   bool     IsSwingHigh(int bar, int range = 3);
   bool     IsSwingLow(int bar, int range = 3);
   void     ScanSwingPoints(void);
   void     BuildTrendlines(void);
   double   TrendlinePrice(const Trendline &tl, datetime t);
   void     DrawTrendline(int idx);
   void     RemoveTrendline(int idx);
   bool     IsNearTrendline(int bar_index, int tl_idx);

public:
   CTrendlineManager(void);
   ~CTrendlineManager(void);

   void     Init(string symbol, ENUM_TIMEFRAMES tf, int lookback,
                 int min_touches, double tolerance_pips, bool draw);

   void     Update(void);  // Call on new bar
   bool     GetBounceSignal(TrendlineSignal &out_sig);

   void     ClearAll(void);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTrendlineManager::CTrendlineManager(void)
{
   m_symbol               = _Symbol;
   m_timeframe            = PERIOD_H1;
   m_lookback_bars        = 200;
   m_min_touches          = 3;
   m_touch_tolerance_pips = 10.0;
   m_draw_trendlines      = true;
   m_swing_count          = 0;
   m_line_count           = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTrendlineManager::~CTrendlineManager(void)
{
   ClearAll();
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
void CTrendlineManager::Init(string symbol, ENUM_TIMEFRAMES tf, int lookback,
                              int min_touches, double tolerance_pips, bool draw)
{
   m_symbol               = symbol;
   m_timeframe            = tf;
   m_lookback_bars        = lookback;
   m_min_touches          = min_touches;
   m_touch_tolerance_pips = tolerance_pips;
   m_draw_trendlines      = draw;
}

//+------------------------------------------------------------------+
//| Pip size                                                         |
//+------------------------------------------------------------------+
double CTrendlineManager::PipSize(void)
{
   double point  = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   return (digits == 5 || digits == 3) ? point * 10.0 : point;
}

//+------------------------------------------------------------------+
//| Swing high detection                                             |
//+------------------------------------------------------------------+
bool CTrendlineManager::IsSwingHigh(int bar, int range)
{
   double high = iHigh(m_symbol, m_timeframe, bar);
   for(int i = 1; i <= range; i++)
   {
      if(iHigh(m_symbol, m_timeframe, bar + i) >= high) return false;
      if(bar - i >= 0 && iHigh(m_symbol, m_timeframe, bar - i) >= high) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Swing low detection                                              |
//+------------------------------------------------------------------+
bool CTrendlineManager::IsSwingLow(int bar, int range)
{
   double low = iLow(m_symbol, m_timeframe, bar);
   for(int i = 1; i <= range; i++)
   {
      if(iLow(m_symbol, m_timeframe, bar + i) <= low) return false;
      if(bar - i >= 0 && iLow(m_symbol, m_timeframe, bar - i) <= low) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Scan historical data for swing points                            |
//+------------------------------------------------------------------+
void CTrendlineManager::ScanSwingPoints(void)
{
   m_swing_count = 0;
   int bars = MathMin(m_lookback_bars, iBars(m_symbol, m_timeframe) - 5);

   for(int i = 3; i < bars - 3 && m_swing_count < MAX_SWINGS; i++)
   {
      if(IsSwingHigh(i))
      {
         m_swings[m_swing_count].price   = iHigh(m_symbol, m_timeframe, i);
         m_swings[m_swing_count].time    = iTime(m_symbol, m_timeframe, i);
         m_swings[m_swing_count].is_high = true;
         m_swing_count++;
      }
      else if(IsSwingLow(i))
      {
         m_swings[m_swing_count].price   = iLow(m_symbol, m_timeframe, i);
         m_swings[m_swing_count].time    = iTime(m_symbol, m_timeframe, i);
         m_swings[m_swing_count].is_high = false;
         m_swing_count++;
      }
   }
}

//+------------------------------------------------------------------+
//| Build trendlines by connecting consecutive swing points          |
//+------------------------------------------------------------------+
void CTrendlineManager::BuildTrendlines(void)
{
   // Clear existing trendlines
   for(int i = 0; i < m_line_count; i++)
      RemoveTrendline(i);
   m_line_count = 0;

   double tol = m_touch_tolerance_pips * PipSize();

   // Uptrend lines: connect swing lows (higher lows)
   for(int i = 0; i < m_swing_count - 1 && m_line_count < MAX_TRENDLINES; i++)
   {
      if(m_swings[i].is_high) continue;

      for(int j = i + 1; j < m_swing_count && m_line_count < MAX_TRENDLINES; j++)
      {
         if(m_swings[j].is_high) continue;
         // Higher low: swing[j] (newer, smaller bar index) > swing[i] (older)
         // Swings are stored in bar-index order so index i > j in time... 
         // actually we store from bar=3 forward so i=0 is most recent in time
         // i comes before j, so m_swings[i].time > m_swings[j].time means i is more recent
         // For an uptrend we need older low (j) < newer low (i), i.e. rising lows over time
         // swings are stored oldest last (bar 3 = most recent)
         // Let's just connect if price difference suggests an uptrend
         if(m_swings[i].price > m_swings[j].price) // newer(i) > older(j) -> upward slope
         {
            Trendline tl;
            tl.is_active  = true;
            tl.is_uptrend = true;
            tl.price1     = m_swings[j].price;
            tl.price2     = m_swings[i].price;
            tl.time1      = m_swings[j].time;
            tl.time2      = m_swings[i].time;
            tl.touches    = 2;
            tl.obj_name   = StringFormat("TL_Up_%d_%d", m_line_count, (int)tl.time1);

            // Count additional touches
            for(int k = 0; k < m_swing_count; k++)
            {
               if(k == i || k == j || m_swings[k].is_high) continue;
               double proj = TrendlinePrice(tl, m_swings[k].time);
               if(MathAbs(m_swings[k].price - proj) <= tol)
                  tl.touches++;
            }

            if(tl.touches >= m_min_touches)
            {
               m_lines[m_line_count++] = tl;
               DrawTrendline(m_line_count - 1);
            }
         }
      }
   }

   // Downtrend lines: connect swing highs (lower highs)
   for(int i = 0; i < m_swing_count - 1 && m_line_count < MAX_TRENDLINES; i++)
   {
      if(!m_swings[i].is_high) continue;

      for(int j = i + 1; j < m_swing_count && m_line_count < MAX_TRENDLINES; j++)
      {
         if(!m_swings[j].is_high) continue;
         if(m_swings[i].price < m_swings[j].price) // newer(i) < older(j) -> downward slope
         {
            Trendline tl;
            tl.is_active  = true;
            tl.is_uptrend = false;
            tl.price1     = m_swings[j].price;
            tl.price2     = m_swings[i].price;
            tl.time1      = m_swings[j].time;
            tl.time2      = m_swings[i].time;
            tl.touches    = 2;
            tl.obj_name   = StringFormat("TL_Dn_%d_%d", m_line_count, (int)tl.time1);

            for(int k = 0; k < m_swing_count; k++)
            {
               if(k == i || k == j || !m_swings[k].is_high) continue;
               double proj = TrendlinePrice(tl, m_swings[k].time);
               if(MathAbs(m_swings[k].price - proj) <= tol)
                  tl.touches++;
            }

            if(tl.touches >= m_min_touches)
            {
               m_lines[m_line_count++] = tl;
               DrawTrendline(m_line_count - 1);
            }
         }
      }
   }

   Print("TrendlineManager: Built ", m_line_count, " valid trendlines");
}

//+------------------------------------------------------------------+
//| Project trendline price at a given time                          |
//+------------------------------------------------------------------+
double CTrendlineManager::TrendlinePrice(const Trendline &tl, datetime t)
{
   if(tl.time2 == tl.time1) return tl.price1;
   double slope = (tl.price2 - tl.price1) / (double)(tl.time2 - tl.time1);
   return tl.price1 + slope * (double)(t - tl.time1);
}

//+------------------------------------------------------------------+
//| Draw a trendline on the chart                                    |
//+------------------------------------------------------------------+
void CTrendlineManager::DrawTrendline(int idx)
{
   if(!m_draw_trendlines) return;
   Trendline &tl = m_lines[idx];
   if(!tl.is_active) return;

   color clr = tl.is_uptrend ? clrLimeGreen : clrTomato;
   ObjectDelete(0, tl.obj_name);
   ObjectCreate(0, tl.obj_name, OBJ_TREND, 0, tl.time1, tl.price1, tl.time2, tl.price2);
   ObjectSetInteger(0, tl.obj_name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, tl.obj_name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, tl.obj_name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, tl.obj_name, OBJPROP_RAY_RIGHT, true);
   ObjectSetString(0, tl.obj_name, OBJPROP_TOOLTIP,
                   StringFormat("%s Trendline (%d touches)", tl.is_uptrend ? "Uptrend" : "Downtrend",
                                tl.touches));
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Remove trendline from chart                                      |
//+------------------------------------------------------------------+
void CTrendlineManager::RemoveTrendline(int idx)
{
   ObjectDelete(0, m_lines[idx].obj_name);
}

//+------------------------------------------------------------------+
//| Check if bar is near a trendline                                 |
//+------------------------------------------------------------------+
bool CTrendlineManager::IsNearTrendline(int bar_index, int tl_idx)
{
   datetime bar_time = iTime(m_symbol, m_timeframe, bar_index);
   double   proj     = TrendlinePrice(m_lines[tl_idx], bar_time);
   double   tol      = m_touch_tolerance_pips * PipSize();

   double low  = iLow(m_symbol, m_timeframe, bar_index);
   double high = iHigh(m_symbol, m_timeframe, bar_index);

   if(m_lines[tl_idx].is_uptrend)
      return (MathAbs(low - proj) <= tol || MathAbs(iClose(m_symbol, m_timeframe, bar_index) - proj) <= tol);
   else
      return (MathAbs(high - proj) <= tol || MathAbs(iClose(m_symbol, m_timeframe, bar_index) - proj) <= tol);
}

//+------------------------------------------------------------------+
//| Full update: rescan swings and rebuild trendlines                |
//+------------------------------------------------------------------+
void CTrendlineManager::Update(void)
{
   ScanSwingPoints();
   BuildTrendlines();
}

//+------------------------------------------------------------------+
//| Check for trendline bounce signal on last closed bar             |
//+------------------------------------------------------------------+
bool CTrendlineManager::GetBounceSignal(TrendlineSignal &out_sig)
{
   double pip = PipSize();

   for(int i = 0; i < m_line_count; i++)
   {
      if(!m_lines[i].is_active) continue;
      if(!IsNearTrendline(1, i)) continue;

      // Confirmation: check if price bounced (bar 1 reversal)
      double open1  = iOpen(m_symbol, m_timeframe, 1);
      double close1 = iClose(m_symbol, m_timeframe, 1);
      double low1   = iLow(m_symbol, m_timeframe, 1);
      double high1  = iHigh(m_symbol, m_timeframe, 1);
      datetime bt   = iTime(m_symbol, m_timeframe, 1);

      bool bounce = false;
      bool bullish = false;

      if(m_lines[i].is_uptrend && close1 > open1) // Bullish bounce off uptrend line
      {
         bounce  = true;
         bullish = true;
      }
      else if(!m_lines[i].is_uptrend && close1 < open1) // Bearish bounce off downtrend line
      {
         bounce  = true;
         bullish = false;
      }

      if(bounce)
      {
         out_sig.valid           = true;
         out_sig.is_bullish      = bullish;
         out_sig.trendline_index = i;
         out_sig.trendline_price = TrendlinePrice(m_lines[i], bt);
         out_sig.entry_price     = bullish ? high1 : low1;
         out_sig.stop_loss       = bullish ?
                                   low1  - 3.0 * pip :
                                   high1 + 3.0 * pip;

         Print("TrendlineManager: Bounce signal. Direction=", bullish ? "BUY" : "SELL",
               " TL_Price=", out_sig.trendline_price);
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Remove all trendline objects from chart                          |
//+------------------------------------------------------------------+
void CTrendlineManager::ClearAll(void)
{
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, "TL_") == 0)
         ObjectDelete(0, name);
   }
   m_line_count  = 0;
   m_swing_count = 0;
   ChartRedraw(0);
}

#endif // TRENDLINE_MANAGER_MQH
