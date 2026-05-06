//+------------------------------------------------------------------+
//|                                           SupportResistance.mqh |
//|                  Price Action Master EA - Support/Resistance     |
//|                                                                  |
//| Automatically detects significant support and resistance levels  |
//| by scanning historical price data and counting touch events.     |
//| Draws horizontal lines on the chart with color coding.          |
//+------------------------------------------------------------------+
#ifndef SUPPORT_RESISTANCE_MQH
#define SUPPORT_RESISTANCE_MQH

//--- Maximum number of S/R levels to store
#define MAX_SR_LEVELS 50

//+------------------------------------------------------------------+
//| Single S/R level data                                            |
//+------------------------------------------------------------------+
struct SRLevel
{
   double   price;        // Level price
   int      touches;      // Number of times price touched this level
   bool     is_support;   // True = support, False = resistance
   bool     is_active;    // True = still valid
   datetime last_touch;   // Timestamp of last touch
   string   obj_name;     // Chart object name
};

//+------------------------------------------------------------------+
//| CSupportResistance - Detects and manages S/R levels              |
//+------------------------------------------------------------------+
class CSupportResistance
{
private:
   SRLevel  m_levels[MAX_SR_LEVELS];
   int      m_level_count;

   // Configuration
   string   m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int      m_lookback_bars;    // Bars to scan
   double   m_tolerance_pips;   // Merge distance in pips
   int      m_min_touches;      // Minimum touches to confirm level
   bool     m_draw_lines;

   // Helpers
   double   PipSize(void);
   bool     IsNearExistingLevel(double price, int &index);
   void     MergeLevel(int index, double price, datetime touch_time);
   void     AddLevel(double price, bool is_support, datetime touch_time);
   void     DrawLevel(int index);
   void     RemoveLevelLine(int index);
   bool     IsSwingHigh(int bar, int range = 3);
   bool     IsSwingLow(int bar, int range = 3);

public:
   CSupportResistance(void);
   ~CSupportResistance(void);

   // Setup
   void     Init(string symbol, ENUM_TIMEFRAMES tf, int lookback, double tolerance_pips,
                 int min_touches, bool draw_lines);

   // Detection
   void     ScanLevels(void);
   void     UpdateTouches(void);
   void     RemoveStaleLines(void);

   // Query
   bool     IsAtSupportLevel(double price, double tolerance_pips = -1);
   bool     IsAtResistanceLevel(double price, double tolerance_pips = -1);
   bool     IsAtSRLevel(double price, bool &is_support, double tolerance_pips = -1);
   int      GetLevelCount(void)        { return m_level_count; }
   SRLevel  GetLevel(int index)        { return m_levels[index]; }

   // Visual
   void     RedrawAllLevels(void);
   void     ClearAllLines(void);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSupportResistance::CSupportResistance(void)
{
   m_level_count    = 0;
   m_lookback_bars  = 500;
   m_tolerance_pips = 20;
   m_min_touches    = 2;
   m_draw_lines     = true;
   m_symbol         = _Symbol;
   m_timeframe      = PERIOD_H1;
   ArrayInitialize(m_levels, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSupportResistance::~CSupportResistance(void)
{
   ClearAllLines();
}

//+------------------------------------------------------------------+
//| Initialize with settings                                         |
//+------------------------------------------------------------------+
void CSupportResistance::Init(string symbol, ENUM_TIMEFRAMES tf, int lookback,
                              double tolerance_pips, int min_touches, bool draw_lines)
{
   m_symbol         = symbol;
   m_timeframe      = tf;
   m_lookback_bars  = lookback;
   m_tolerance_pips = tolerance_pips;
   m_min_touches    = min_touches;
   m_draw_lines     = draw_lines;
}

//+------------------------------------------------------------------+
//| Pip size for the configured symbol                               |
//+------------------------------------------------------------------+
double CSupportResistance::PipSize(void)
{
   double point  = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   return (digits == 5 || digits == 3) ? point * 10.0 : point;
}

//+------------------------------------------------------------------+
//| Detect if a bar is a local swing high                            |
//+------------------------------------------------------------------+
bool CSupportResistance::IsSwingHigh(int bar, int range)
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
//| Detect if a bar is a local swing low                             |
//+------------------------------------------------------------------+
bool CSupportResistance::IsSwingLow(int bar, int range)
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
//| Check if price is near an existing level (within tolerance)      |
//| Returns true and sets index if found                             |
//+------------------------------------------------------------------+
bool CSupportResistance::IsNearExistingLevel(double price, int &index)
{
   double tol = m_tolerance_pips * PipSize();
   for(int i = 0; i < m_level_count; i++)
   {
      if(!m_levels[i].is_active) continue;
      if(MathAbs(m_levels[i].price - price) <= tol)
      {
         index = i;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Update an existing level with a new touch                        |
//+------------------------------------------------------------------+
void CSupportResistance::MergeLevel(int index, double price, datetime touch_time)
{
   // Average the level price for precision
   m_levels[index].price = (m_levels[index].price * m_levels[index].touches + price) /
                            (m_levels[index].touches + 1);
   m_levels[index].touches++;
   m_levels[index].last_touch = touch_time;
   if(m_draw_lines) DrawLevel(index);
}

//+------------------------------------------------------------------+
//| Add a new S/R level                                              |
//+------------------------------------------------------------------+
void CSupportResistance::AddLevel(double price, bool is_support, datetime touch_time)
{
   if(m_level_count >= MAX_SR_LEVELS) return;

   int i = m_level_count;
   m_levels[i].price      = price;
   m_levels[i].touches    = 1;
   m_levels[i].is_support = is_support;
   m_levels[i].is_active  = true;
   m_levels[i].last_touch = touch_time;
   m_levels[i].obj_name   = StringFormat("SR_%s_%d", is_support ? "S" : "R", i);
   m_level_count++;
}

//+------------------------------------------------------------------+
//| Scan historical bars to build S/R level list                     |
//+------------------------------------------------------------------+
void CSupportResistance::ScanLevels(void)
{
   // Clear existing levels and lines
   ClearAllLines();
   m_level_count = 0;
   ArrayInitialize(m_levels, 0);

   int bars = MathMin(m_lookback_bars, iBars(m_symbol, m_timeframe) - 5);
   if(bars < 10)
   {
      Print("SupportResistance: Not enough bars to scan (", bars, ")");
      return;
   }

   Print("SupportResistance: Scanning ", bars, " bars for S/R levels...");

   for(int i = 3; i < bars - 3; i++)
   {
      // Check for swing lows (potential support)
      if(IsSwingLow(i))
      {
         double low_price = iLow(m_symbol, m_timeframe, i);
         datetime bar_time = iTime(m_symbol, m_timeframe, i);
         int existing_idx = -1;
         if(IsNearExistingLevel(low_price, existing_idx))
            MergeLevel(existing_idx, low_price, bar_time);
         else
            AddLevel(low_price, true, bar_time);
      }

      // Check for swing highs (potential resistance)
      if(IsSwingHigh(i))
      {
         double high_price = iHigh(m_symbol, m_timeframe, i);
         datetime bar_time = iTime(m_symbol, m_timeframe, i);
         int existing_idx = -1;
         if(IsNearExistingLevel(high_price, existing_idx))
            MergeLevel(existing_idx, high_price, bar_time);
         else
            AddLevel(high_price, false, bar_time);
      }
   }

   // Deactivate levels with insufficient touches
   int active = 0;
   for(int i = 0; i < m_level_count; i++)
   {
      if(m_levels[i].touches < m_min_touches)
         m_levels[i].is_active = false;
      else
         active++;
   }

   Print("SupportResistance: Found ", active, " confirmed S/R levels (min ", m_min_touches, " touches)");

   // Draw active levels
   if(m_draw_lines) RedrawAllLevels();
}

//+------------------------------------------------------------------+
//| Scan most recent bars for new touches on existing levels         |
//+------------------------------------------------------------------+
void CSupportResistance::UpdateTouches(void)
{
   int check_bars = 5; // Only check recent bars
   double tol     = m_tolerance_pips * PipSize();

   for(int i = 0; i < check_bars; i++)
   {
      double low  = iLow(m_symbol, m_timeframe, i);
      double high = iHigh(m_symbol, m_timeframe, i);
      datetime bt = iTime(m_symbol, m_timeframe, i);

      for(int j = 0; j < m_level_count; j++)
      {
         if(!m_levels[j].is_active) continue;
         if(bt == m_levels[j].last_touch) continue; // Already counted

         if(m_levels[j].is_support && MathAbs(low - m_levels[j].price) <= tol)
            MergeLevel(j, low, bt);
         else if(!m_levels[j].is_support && MathAbs(high - m_levels[j].price) <= tol)
            MergeLevel(j, high, bt);
      }
   }
}

//+------------------------------------------------------------------+
//| Draw a single S/R level on the chart                             |
//+------------------------------------------------------------------+
void CSupportResistance::DrawLevel(int index)
{
   if(!m_draw_lines) return;
   if(!m_levels[index].is_active) return;

   string name    = m_levels[index].obj_name;
   double price   = m_levels[index].price;
   color  clr     = m_levels[index].is_support ? clrDodgerBlue : clrTomato;
   string label   = StringFormat("%s %.5f (%d)", m_levels[index].is_support ? "S" : "R",
                                  price, m_levels[index].touches);

   // Delete and redraw
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, label);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Remove a level's chart line                                      |
//+------------------------------------------------------------------+
void CSupportResistance::RemoveLevelLine(int index)
{
   ObjectDelete(0, m_levels[index].obj_name);
}

//+------------------------------------------------------------------+
//| Redraw all active levels                                         |
//+------------------------------------------------------------------+
void CSupportResistance::RedrawAllLevels(void)
{
   for(int i = 0; i < m_level_count; i++)
   {
      if(m_levels[i].is_active)
         DrawLevel(i);
   }
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Remove all S/R lines from the chart                              |
//+------------------------------------------------------------------+
void CSupportResistance::ClearAllLines(void)
{
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, "SR_") == 0)
         ObjectDelete(0, name);
   }
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Remove S/R lines that haven't been touched recently              |
//+------------------------------------------------------------------+
void CSupportResistance::RemoveStaleLines(void)
{
   datetime cutoff = TimeCurrent() - 7 * 24 * 3600; // 7 days
   for(int i = 0; i < m_level_count; i++)
   {
      if(m_levels[i].is_active && m_levels[i].last_touch < cutoff)
      {
         m_levels[i].is_active = false;
         RemoveLevelLine(i);
      }
   }
}

//+------------------------------------------------------------------+
//| Check if price is within tolerance of any support level          |
//+------------------------------------------------------------------+
bool CSupportResistance::IsAtSupportLevel(double price, double tolerance_pips)
{
   double tol = (tolerance_pips < 0) ? m_tolerance_pips : tolerance_pips;

   for(int i = 0; i < m_level_count; i++)
   {
      if(!m_levels[i].is_active || !m_levels[i].is_support) continue;
      if(MathAbs(m_levels[i].price - price) <= tol * PipSize())
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check if price is within tolerance of any resistance level       |
//+------------------------------------------------------------------+
bool CSupportResistance::IsAtResistanceLevel(double price, double tolerance_pips)
{
   double tol = (tolerance_pips < 0) ? m_tolerance_pips : tolerance_pips;
   for(int i = 0; i < m_level_count; i++)
   {
      if(!m_levels[i].is_active || m_levels[i].is_support) continue;
      if(MathAbs(m_levels[i].price - price) <= tol * PipSize())
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check if price is near any S/R level; returns type via is_support|
//+------------------------------------------------------------------+
bool CSupportResistance::IsAtSRLevel(double price, bool &is_support, double tolerance_pips)
{
   double tol = (tolerance_pips < 0) ? m_tolerance_pips : tolerance_pips;
   double best_dist = 1e10;
   int    best_idx  = -1;

   for(int i = 0; i < m_level_count; i++)
   {
      if(!m_levels[i].is_active) continue;
      double dist = MathAbs(m_levels[i].price - price);
      if(dist <= tol * PipSize() && dist < best_dist)
      {
         best_dist = dist;
         best_idx  = i;
      }
   }

   if(best_idx >= 0)
   {
      is_support = m_levels[best_idx].is_support;
      return true;
   }
   return false;
}

#endif // SUPPORT_RESISTANCE_MQH
