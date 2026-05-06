//+------------------------------------------------------------------+
//|                                          TrendlineManager.mqh    |
//|                   Price Action Master EA - Trendline Management   |
//|                                                                   |
//| Handles:                                                          |
//|  - Swing high/low identification                                  |
//|  - Automatic trendline drawing and validation                     |
//|  - Trendline bounce detection                                     |
//|  - Uptrend (green) / Downtrend (red) visual lines                 |
//+------------------------------------------------------------------+
#ifndef TRENDLINEMANAGER_MQH
#define TRENDLINEMANAGER_MQH

#include "PinBarDetector.mqh"

#define MAX_SWINGS     50
#define MAX_TRENDLINES 10

struct SwingPoint
{
   double   price;
   datetime time;
   int      barIndex;
   bool     isHigh;
};

struct Trendline
{
   double   price1, price2;
   datetime time1,  time2;
   bool     isUptrend;     // true = connect swing lows; false = connect swing highs
   int      touches;
   bool     isValid;
   string   objName;
};

enum ENUM_TL_SIGNAL
{
   TL_NONE    = 0,
   TL_BUY     = 1,
   TL_SELL    = -1
};

//+------------------------------------------------------------------+
//| Class: CTrendlineManager                                          |
//+------------------------------------------------------------------+
class CTrendlineManager
{
private:
   SwingPoint m_swings[];
   int        m_swingCount;

   Trendline  m_lines[];
   int        m_lineCount;

   bool       m_drawLines;
   double     m_pipSize;
   double     m_touchTol;     // Tolerance in price for touching a trendline
   string     m_objPrefix;
   int        m_swingLookback;

public:
   CTrendlineManager() :
      m_swingCount(0),
      m_lineCount(0),
      m_drawLines(true),
      m_touchTol(0),
      m_objPrefix("TL_"),
      m_swingLookback(100)
   {
      ArrayResize(m_swings, MAX_SWINGS);
      ArrayResize(m_lines,  MAX_TRENDLINES);
   }

   ~CTrendlineManager()
   {
      RemoveTrendlineObjects();
   }

   //--- Initialise
   void Init(bool drawLines, int swingLookback)
   {
      m_drawLines     = drawLines;
      m_swingLookback = swingLookback;
      m_pipSize       = GetPipSize();
      m_touchTol      = 10.0 * m_pipSize; // 10-pip tolerance for touch
      Print("[TrendlineManager] Init drawLines=", m_drawLines,
            " lookback=", m_swingLookback);
   }

   //--- Full recalculation on new bar
   void Refresh(ENUM_TIMEFRAMES tf)
   {
      m_pipSize  = GetPipSize();
      m_touchTol = 10.0 * m_pipSize;

      FindSwingPoints(tf);
      BuildTrendlines();
      if(m_drawLines) DrawAllTrendlines(tf);
   }

   //--- Check if price is touching a valid trendline
   //    Returns TL_BUY (at uptrend), TL_SELL (at downtrend), or TL_NONE
   ENUM_TL_SIGNAL CheckBounce(ENUM_TIMEFRAMES tf, int barIndex,
                               CPinBarDetector &pinbar)
   {
      if(m_lineCount == 0) return TL_NONE;

      double low  = iLow(_Symbol,  tf, barIndex);
      double high = iHigh(_Symbol, tf, barIndex);
      datetime t  = iTime(_Symbol, tf, barIndex);

      for(int i = 0; i < m_lineCount; i++)
      {
         if(!m_lines[i].isValid || m_lines[i].touches < 3) continue;

         double linePrice = GetPriceAtTime(m_lines[i], t);
         if(linePrice <= 0) continue;

         if(m_lines[i].isUptrend)
         {
            // Price dips to uptrend line -> potential BUY
            if(low <= linePrice + m_touchTol && low >= linePrice - m_touchTol)
            {
               // Require confirmation: bullish close or pin bar
               double close = iClose(_Symbol, tf, barIndex);
               double open  = iOpen(_Symbol,  tf, barIndex);
               ENUM_PINBAR_TYPE pb = pinbar.DetectRaw(tf, barIndex);
               if(close > open || pb == PINBAR_BULLISH)
               {
                  Print("[TrendlineManager] BUY bounce at uptrend line=", linePrice,
                        " touches=", m_lines[i].touches);
                  return TL_BUY;
               }
            }
         }
         else
         {
            // Price rises to downtrend line -> potential SELL
            if(high >= linePrice - m_touchTol && high <= linePrice + m_touchTol)
            {
               double close = iClose(_Symbol, tf, barIndex);
               double open  = iOpen(_Symbol,  tf, barIndex);
               ENUM_PINBAR_TYPE pb = pinbar.DetectRaw(tf, barIndex);
               if(close < open || pb == PINBAR_BEARISH)
               {
                  Print("[TrendlineManager] SELL bounce at downtrend line=", linePrice,
                        " touches=", m_lines[i].touches);
                  return TL_SELL;
               }
            }
         }
      }

      return TL_NONE;
   }

   //--- Get H4 trend direction: +1 uptrend, -1 downtrend, 0 ranging
   int GetHTFTrend(ENUM_TIMEFRAMES htf)
   {
      int bars = MathMin(50, Bars(_Symbol, htf) - 1);
      if(bars < 10) return 0;

      double hh = iHigh(_Symbol, htf, 0);
      double ll = iLow(_Symbol,  htf, 0);
      double ph = iHigh(_Symbol, htf, bars);
      double pl = iLow(_Symbol,  htf, bars);

      bool higherHighs = hh > ph;
      bool higherLows  = ll > pl;
      bool lowerLows   = ll < pl;
      bool lowerHighs  = hh < ph;

      if(higherHighs && higherLows) return  1;  // Uptrend
      if(lowerLows  && lowerHighs)  return -1;  // Downtrend
      return 0;                                  // Ranging
   }

private:
   void FindSwingPoints(ENUM_TIMEFRAMES tf)
   {
      m_swingCount = 0;
      int bars = MathMin(m_swingLookback, Bars(_Symbol, tf) - 3);

      for(int i = 2; i < bars - 2; i++)
      {
         if(m_swingCount >= MAX_SWINGS) break;
         double h = iHigh(_Symbol, tf, i);
         double l = iLow(_Symbol,  tf, i);

         // Swing high
         if(h > iHigh(_Symbol, tf, i-1) && h > iHigh(_Symbol, tf, i-2) &&
            h > iHigh(_Symbol, tf, i+1) && h > iHigh(_Symbol, tf, i+2))
         {
            m_swings[m_swingCount].price    = h;
            m_swings[m_swingCount].time     = iTime(_Symbol, tf, i);
            m_swings[m_swingCount].barIndex = i;
            m_swings[m_swingCount].isHigh   = true;
            m_swingCount++;
         }
         // Swing low
         else if(l < iLow(_Symbol, tf, i-1) && l < iLow(_Symbol, tf, i-2) &&
                 l < iLow(_Symbol, tf, i+1) && l < iLow(_Symbol, tf, i+2))
         {
            m_swings[m_swingCount].price    = l;
            m_swings[m_swingCount].time     = iTime(_Symbol, tf, i);
            m_swings[m_swingCount].barIndex = i;
            m_swings[m_swingCount].isHigh   = false;
            m_swingCount++;
         }
      }
      Print("[TrendlineManager] Found ", m_swingCount, " swing points.");
   }

   void BuildTrendlines()
   {
      m_lineCount = 0;

      // --- Uptrend lines: connect swing lows ---
      for(int i = 0; i < m_swingCount && m_lineCount < MAX_TRENDLINES; i++)
      {
         if(m_swings[i].isHigh) continue;
         for(int j = i + 1; j < m_swingCount && m_lineCount < MAX_TRENDLINES; j++)
         {
            if(m_swings[j].isHigh) continue;
            // Require ascending lows
            if(m_swings[j].price >= m_swings[i].price) continue;

            int touches = CountTouches(i, j, false);
            if(touches >= 3)
            {
               m_lines[m_lineCount].price1    = m_swings[i].price;
               m_lines[m_lineCount].price2    = m_swings[j].price;
               m_lines[m_lineCount].time1     = m_swings[i].time;
               m_lines[m_lineCount].time2     = m_swings[j].time;
               m_lines[m_lineCount].isUptrend = true;
               m_lines[m_lineCount].touches   = touches;
               m_lines[m_lineCount].isValid   = true;
               m_lines[m_lineCount].objName   = m_objPrefix + "UP_" + IntegerToString(m_lineCount);
               m_lineCount++;
            }
         }
      }

      // --- Downtrend lines: connect swing highs ---
      for(int i = 0; i < m_swingCount && m_lineCount < MAX_TRENDLINES; i++)
      {
         if(!m_swings[i].isHigh) continue;
         for(int j = i + 1; j < m_swingCount && m_lineCount < MAX_TRENDLINES; j++)
         {
            if(!m_swings[j].isHigh) continue;
            // Require descending highs
            if(m_swings[j].price >= m_swings[i].price) continue;

            int touches = CountTouches(i, j, true);
            if(touches >= 3)
            {
               m_lines[m_lineCount].price1    = m_swings[i].price;
               m_lines[m_lineCount].price2    = m_swings[j].price;
               m_lines[m_lineCount].time1     = m_swings[i].time;
               m_lines[m_lineCount].time2     = m_swings[j].time;
               m_lines[m_lineCount].isUptrend = false;
               m_lines[m_lineCount].touches   = touches;
               m_lines[m_lineCount].isValid   = true;
               m_lines[m_lineCount].objName   = m_objPrefix + "DN_" + IntegerToString(m_lineCount);
               m_lineCount++;
            }
         }
      }

      Print("[TrendlineManager] Built ", m_lineCount, " valid trendlines.");
   }

   int CountTouches(int idx1, int idx2, bool useHighs)
   {
      int count = 2; // The two anchor points already count
      SwingPoint a = m_swings[idx1];
      SwingPoint b = m_swings[idx2];

      if(a.time == b.time) return 0;

      double slope = (b.price - a.price) / (double)(b.time - a.time);

      for(int k = 0; k < m_swingCount; k++)
      {
         if(k == idx1 || k == idx2) continue;
         if(m_swings[k].isHigh != useHighs) continue;

         double linePrice = a.price + slope * (double)(m_swings[k].time - a.time);
         if(MathAbs(m_swings[k].price - linePrice) <= m_touchTol)
            count++;
      }
      return count;
   }

   double GetPriceAtTime(const Trendline &tl, datetime t)
   {
      if(tl.time1 == tl.time2) return 0;
      double slope = (tl.price2 - tl.price1) / (double)(tl.time2 - tl.time1);
      return tl.price1 + slope * (double)(t - tl.time1);
   }

   void DrawAllTrendlines(ENUM_TIMEFRAMES tf)
   {
      RemoveTrendlineObjects();
      datetime now = iTime(_Symbol, tf, 0);

      for(int i = 0; i < m_lineCount; i++)
      {
         if(!m_lines[i].isValid) continue;

         // Extend line to current bar
         double extPrice = GetPriceAtTime(m_lines[i], now + PeriodSeconds(tf) * 20);
         color clr = m_lines[i].isUptrend ? clrLime : clrRed;

         string name = m_lines[i].objName;
         if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
         ObjectCreate(0, name, OBJ_TREND, 0,
                      m_lines[i].time1, m_lines[i].price1,
                      m_lines[i].time2, m_lines[i].price2);
         ObjectSetInteger(0, name, OBJPROP_COLOR,   clr);
         ObjectSetInteger(0, name, OBJPROP_STYLE,   STYLE_SOLID);
         ObjectSetInteger(0, name, OBJPROP_WIDTH,   2);
         ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
         ObjectSetString(0,  name, OBJPROP_TOOLTIP,
                         (m_lines[i].isUptrend ? "Uptrend " : "Downtrend ") +
                         IntegerToString(m_lines[i].touches) + " touches");
      }
      ChartRedraw();
   }

   void RemoveTrendlineObjects()
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

#endif // TRENDLINEMANAGER_MQH
