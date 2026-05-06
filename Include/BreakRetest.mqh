//+------------------------------------------------------------------+
//|                                              BreakRetest.mqh     |
//|                    Price Action Master EA - Break & Retest        |
//|                                                                   |
//| Handles:                                                          |
//|  - Detection of S/R breakouts                                     |
//|  - Identification of retest of the broken level                   |
//|  - Role-reversal confirmation                                      |
//|  - Visual markers for breakout, retest zone, and entry            |
//+------------------------------------------------------------------+
#ifndef BREAKRETEST_MQH
#define BREAKRETEST_MQH

#include "SupportResistance.mqh"

#define MAX_BREAKOUT_EVENTS 20

enum ENUM_BR_SIGNAL
{
   BR_NONE     = 0,
   BR_BULLISH  = 1,   // Broke resistance, retest as support -> BUY
   BR_BEARISH  = -1   // Broke support, retest as resistance -> SELL
};

struct BreakoutEvent
{
   double   level;
   bool     wasResistance;  // true if the ORIGINAL level was resistance
   datetime breakTime;
   bool     isActive;       // waiting for retest
};

//+------------------------------------------------------------------+
//| Class: CBreakRetest                                               |
//+------------------------------------------------------------------+
class CBreakRetest
{
private:
   BreakoutEvent m_events[];
   int           m_eventCount;

   double        m_tolerancePips;
   string        m_objPrefix;
   double        m_pipSize;

public:
   CBreakRetest() :
      m_eventCount(0),
      m_tolerancePips(10.0),
      m_objPrefix("BR_")
   {
      ArrayResize(m_events, MAX_BREAKOUT_EVENTS);
   }

   ~CBreakRetest()
   {
      RemoveBreakRetestObjects();
   }

   //--- Initialise
   void Init(double tolerancePips)
   {
      m_tolerancePips = tolerancePips;
      m_pipSize       = GetPipSize();
      Print("[BreakRetest] Init tolerance=", m_tolerancePips, "pips");
   }

   //--- Called each new bar: check for new breakouts and retests
   //    Returns BR_BULLISH / BR_BEARISH on a valid retest entry, else BR_NONE
   ENUM_BR_SIGNAL Evaluate(ENUM_TIMEFRAMES tf, CSupportResistance &sr)
   {
      m_pipSize = GetPipSize();
      double tol = m_tolerancePips * m_pipSize;

      double close1 = iClose(_Symbol, tf, 1); // Last closed bar
      double high1  = iHigh(_Symbol,  tf, 1);
      double low1   = iLow(_Symbol,   tf, 1);

      // 1. Check for new breakouts across all active S/R levels
      int srCount = sr.GetLevelCount();
      for(int i = 0; i < srCount; i++)
      {
         SRLevel lv = sr.GetLevel(i);
         if(!lv.isActive) continue;

         if(lv.isResistance && close1 > lv.price + tol)
         {
            // Resistance broken to the upside
            RegisterBreakout(lv.price, true, iTime(_Symbol, tf, 1));
            sr.MarkBroken(i);
            DrawBreakoutMark(iTime(_Symbol, tf, 1), high1, clrOrange, "Breakout UP");
         }
         else if(!lv.isResistance && close1 < lv.price - tol)
         {
            // Support broken to the downside
            RegisterBreakout(lv.price, false, iTime(_Symbol, tf, 1));
            sr.MarkBroken(i);
            DrawBreakoutMark(iTime(_Symbol, tf, 1), low1, clrOrangeRed, "Breakout DN");
         }
      }

      // 2. Check for retests of pending breakout events
      for(int i = 0; i < m_eventCount; i++)
      {
         if(!m_events[i].isActive) continue;

         double lvl = m_events[i].level;

         if(m_events[i].wasResistance)
         {
            // Previously resistance, now broken upward -> expect retest from above
            // Price pulls back to level and bounces up
            if(low1 <= lvl + tol && close1 > lvl)
            {
               // Rejection candle at level (bullish)
               if(close1 > iOpen(_Symbol, tf, 1)) // Bullish close
               {
                  m_events[i].isActive = false;
                  datetime barTime = iTime(_Symbol, tf, 1);
                  DrawRetestMark(barTime, low1, BR_BULLISH);
                  Print("[BreakRetest] BULLISH retest at ", lvl, " time=", barTime);
                  return BR_BULLISH;
               }
            }
         }
         else
         {
            // Previously support, now broken downward -> expect retest from below
            if(high1 >= lvl - tol && close1 < lvl)
            {
               // Rejection candle at level (bearish)
               if(close1 < iOpen(_Symbol, tf, 1)) // Bearish close
               {
                  m_events[i].isActive = false;
                  datetime barTime = iTime(_Symbol, tf, 1);
                  DrawRetestMark(barTime, high1, BR_BEARISH);
                  Print("[BreakRetest] BEARISH retest at ", lvl, " time=", barTime);
                  return BR_BEARISH;
               }
            }
         }

         // Expire old events (> 50 bars old)
         int barsAgo = iBarShift(_Symbol, tf, m_events[i].breakTime, false);
         if(barsAgo > 50)
         {
            m_events[i].isActive = false;
            Print("[BreakRetest] Event expired at level ", lvl);
         }
      }

      return BR_NONE;
   }

private:
   void RegisterBreakout(double level, bool wasResistance, datetime breakTime)
   {
      // Check if already registered
      for(int i = 0; i < m_eventCount; i++)
      {
         if(m_events[i].isActive &&
            MathAbs(m_events[i].level - level) < m_tolerancePips * m_pipSize)
            return;
      }

      // Find a free slot
      int slot = -1;
      for(int i = 0; i < m_eventCount; i++)
         if(!m_events[i].isActive) { slot = i; break; }

      if(slot < 0 && m_eventCount < MAX_BREAKOUT_EVENTS)
         slot = m_eventCount++;

      if(slot < 0)
      {
         Print("[BreakRetest] No free event slot.");
         return;
      }

      m_events[slot].level         = level;
      m_events[slot].wasResistance = wasResistance;
      m_events[slot].breakTime     = breakTime;
      m_events[slot].isActive      = true;

      Print("[BreakRetest] Registered breakout at ", level,
            " wasResistance=", wasResistance);
   }

   void DrawBreakoutMark(datetime time, double price, color clr, string tip)
   {
      string name = m_objPrefix + "BO_" + IntegerToString((int)time);
      if(ObjectFind(0, name) >= 0) return;
      ObjectCreate(0, name, OBJ_ARROW, 0, time, price);
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 251);
      ObjectSetInteger(0, name, OBJPROP_COLOR,     clr);
      ObjectSetInteger(0, name, OBJPROP_WIDTH,     2);
      ObjectSetString(0,  name, OBJPROP_TOOLTIP,   tip);
      ChartRedraw();
   }

   void DrawRetestMark(datetime time, double price, ENUM_BR_SIGNAL sig)
   {
      string name = m_objPrefix + "RT_" + IntegerToString((int)time);
      if(ObjectFind(0, name) >= 0) return;
      color clr = (sig == BR_BULLISH) ? clrLime : clrRed;
      int   code = (sig == BR_BULLISH) ? 233 : 234;
      ObjectCreate(0, name, OBJ_ARROW, 0, time, price);
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, code);
      ObjectSetInteger(0, name, OBJPROP_COLOR,     clr);
      ObjectSetInteger(0, name, OBJPROP_WIDTH,     2);
      ObjectSetString(0,  name, OBJPROP_TOOLTIP,   "Break & Retest Entry");
      ChartRedraw();
   }

   void RemoveBreakRetestObjects()
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

#endif // BREAKRETEST_MQH
