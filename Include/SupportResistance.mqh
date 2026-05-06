//+------------------------------------------------------------------+
//|                                          SupportResistance.mqh   |
//|                   Price Action Master EA - Support/Resistance     |
//|                                                                   |
//| Handles:                                                          |
//|  - Automatic detection of S/R zones from swing highs/lows        |
//|  - Drawing horizontal lines on the chart                         |
//|  - Zone invalidation & refresh                                    |
//+------------------------------------------------------------------+
#ifndef SUPPORTRESISTANCE_MQH
#define SUPPORTRESISTANCE_MQH

#define MAX_SR_LEVELS 100

struct SRLevel
{
   double   price;
   int      touches;
   bool     isResistance;   // true = resistance, false = support
   bool     isActive;
   datetime lastTouchTime;
};

//+------------------------------------------------------------------+
//| Class: CSupportResistance                                         |
//+------------------------------------------------------------------+
class CSupportResistance
{
private:
   SRLevel  m_levels[];
   int      m_levelCount;

   int      m_lookbackBars;
   double   m_touchDistPips;
   int      m_minTouches;
   bool     m_drawLines;

   string   m_objPrefix;
   double   m_pipSize;

public:
   CSupportResistance() :
      m_levelCount(0),
      m_lookbackBars(500),
      m_touchDistPips(20.0),
      m_minTouches(2),
      m_drawLines(true),
      m_objPrefix("SR_")
   {
      ArrayResize(m_levels, MAX_SR_LEVELS);
   }

   ~CSupportResistance()
   {
      RemoveSRObjects();
   }

   //--- Initialise parameters
   void Init(int lookback, double touchDist, int minTouches, bool drawLines)
   {
      m_lookbackBars  = lookback;
      m_touchDistPips = touchDist;
      m_minTouches    = minTouches;
      m_drawLines     = drawLines;
      m_pipSize       = GetPipSize();

      Print("[SR] Init lookback=", m_lookbackBars,
            " touchDist=", m_touchDistPips, "pips minTouches=", m_minTouches);
   }

   //--- Full recalculation (call periodically, e.g. on new H1 bar)
   void Refresh(ENUM_TIMEFRAMES tf)
   {
      m_levelCount = 0;
      m_pipSize    = GetPipSize();

      int bars = MathMin(m_lookbackBars, Bars(_Symbol, tf) - 1);

      // Collect swing highs and lows
      for(int i = 2; i < bars - 2; i++)
      {
         double h = iHigh(_Symbol, tf, i);
         double l = iLow(_Symbol,  tf, i);

         // Swing high
         if(h > iHigh(_Symbol, tf, i-1) && h > iHigh(_Symbol, tf, i-2) &&
            h > iHigh(_Symbol, tf, i+1) && h > iHigh(_Symbol, tf, i+2))
         {
            AddOrUpdateLevel(h, true, iTime(_Symbol, tf, i));
         }

         // Swing low
         if(l < iLow(_Symbol, tf, i-1) && l < iLow(_Symbol, tf, i-2) &&
            l < iLow(_Symbol, tf, i+1) && l < iLow(_Symbol, tf, i+2))
         {
            AddOrUpdateLevel(l, false, iTime(_Symbol, tf, i));
         }
      }

      // Keep only levels with enough touches
      CompactLevels();

      if(m_drawLines) DrawAllLevels();

      Print("[SR] Refresh done. Active levels=", m_levelCount);
   }

   //--- Check if price is at an active support level (within tolerance)
   bool IsAtSupport(double price, double &levelPrice)
   {
      double tol = m_touchDistPips * m_pipSize;
      for(int i = 0; i < m_levelCount; i++)
      {
         if(!m_levels[i].isActive || m_levels[i].isResistance) continue;
         if(MathAbs(price - m_levels[i].price) <= tol)
         {
            levelPrice = m_levels[i].price;
            return true;
         }
      }
      return false;
   }

   //--- Check if price is at an active resistance level
   bool IsAtResistance(double price, double &levelPrice)
   {
      double tol = m_touchDistPips * m_pipSize;
      for(int i = 0; i < m_levelCount; i++)
      {
         if(!m_levels[i].isActive || !m_levels[i].isResistance) continue;
         if(MathAbs(price - m_levels[i].price) <= tol)
         {
            levelPrice = m_levels[i].price;
            return true;
         }
      }
      return false;
   }

   //--- Return total active level count
   int GetActiveCount()
   {
      int cnt = 0;
      for(int i = 0; i < m_levelCount; i++)
         if(m_levels[i].isActive) cnt++;
      return cnt;
   }

   //--- Expose levels for break/retest module
   int GetLevelCount() { return m_levelCount; }
   SRLevel GetLevel(int idx)
   {
      SRLevel empty; ZeroMemory(empty);
      if(idx < 0 || idx >= m_levelCount) return empty;
      return m_levels[idx];
   }

   //--- Mark a level as broken (for break-retest logic)
   void MarkBroken(int idx)
   {
      if(idx >= 0 && idx < m_levelCount)
      {
         m_levels[idx].isActive      = false;
         m_levels[idx].isResistance  = !m_levels[idx].isResistance; // Role reversal
         m_levels[idx].isActive      = true;
         Print("[SR] Level broken/reversed at ", m_levels[idx].price);
         if(m_drawLines) DrawAllLevels();
      }
   }

private:
   void AddOrUpdateLevel(double price, bool isRes, datetime t)
   {
      double tol = m_touchDistPips * m_pipSize;

      // Try to merge with existing level
      for(int i = 0; i < m_levelCount; i++)
      {
         if(m_levels[i].isResistance == isRes &&
            MathAbs(m_levels[i].price - price) <= tol)
         {
            m_levels[i].touches++;
            if(t > m_levels[i].lastTouchTime)
            {
               m_levels[i].lastTouchTime = t;
               // Refine price to average
               m_levels[i].price = (m_levels[i].price + price) / 2.0;
            }
            return;
         }
      }

      // New level
      if(m_levelCount < MAX_SR_LEVELS)
      {
         m_levels[m_levelCount].price         = price;
         m_levels[m_levelCount].isResistance  = isRes;
         m_levels[m_levelCount].touches       = 1;
         m_levels[m_levelCount].isActive      = false; // Activated after touch filter
         m_levels[m_levelCount].lastTouchTime = t;
         m_levelCount++;
      }
   }

   void CompactLevels()
   {
      int newCount = 0;
      for(int i = 0; i < m_levelCount; i++)
      {
         if(m_levels[i].touches >= m_minTouches)
         {
            m_levels[i].isActive = true;
            m_levels[newCount++] = m_levels[i];
         }
      }
      m_levelCount = newCount;
   }

   void DrawAllLevels()
   {
      RemoveSRObjects();
      for(int i = 0; i < m_levelCount; i++)
      {
         if(!m_levels[i].isActive) continue;
         string name  = m_objPrefix + IntegerToString(i);
         color  clr   = m_levels[i].isResistance ? clrRed : clrDodgerBlue;
         string label = (m_levels[i].isResistance ? "R: " : "S: ") +
                        DoubleToString(m_levels[i].price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) +
                        " (" + IntegerToString(m_levels[i].touches) + "x)";

         if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
         ObjectCreate(0, name, OBJ_HLINE, 0, 0, m_levels[i].price);
         ObjectSetInteger(0, name, OBJPROP_COLOR,    clr);
         ObjectSetInteger(0, name, OBJPROP_STYLE,    STYLE_DASH);
         ObjectSetInteger(0, name, OBJPROP_WIDTH,    1);
         ObjectSetString(0,  name, OBJPROP_TOOLTIP,  label);
         ObjectSetString(0,  name, OBJPROP_TEXT,     label);
      }
      ChartRedraw();
   }

   void RemoveSRObjects()
   {
      int total = ObjectsTotal(0);
      for(int i = total - 1; i >= 0; i--)
      {
         string name = ObjectName(0, i);
         if(StringFind(name, m_objPrefix) == 0)
            ObjectDelete(0, name);
      }
   }

   double GetPipSize()
   {
      double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      return (digits == 3 || digits == 5) ? point * 10.0 : point;
   }
};

#endif // SUPPORTRESISTANCE_MQH
