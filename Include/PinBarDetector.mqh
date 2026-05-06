//+------------------------------------------------------------------+
//|                                            PinBarDetector.mqh    |
//|                      Price Action Master EA - Pin Bar Detection   |
//|                                                                   |
//| Handles:                                                          |
//|  - Identification of bullish and bearish pin bars                 |
//|  - Validation at S/R levels                                       |
//|  - Visual arrow drawing on chart                                  |
//|  - Alert notification                                             |
//+------------------------------------------------------------------+
#ifndef PINBARDETECTOR_MQH
#define PINBARDETECTOR_MQH

#include "SupportResistance.mqh"

enum ENUM_PINBAR_TYPE
{
   PINBAR_NONE     = 0,
   PINBAR_BULLISH  = 1,   // Long lower wick at support
   PINBAR_BEARISH  = -1   // Long upper wick at resistance
};

//+------------------------------------------------------------------+
//| Class: CPinBarDetector                                            |
//+------------------------------------------------------------------+
class CPinBarDetector
{
private:
   double   m_wickRatio;        // Min wick/body ratio (default 2.0)
   double   m_bodyPercent;      // Max body % of total candle (default 33.0)
   double   m_srTolerance;      // Tolerance to S/R in pips
   bool     m_drawArrows;
   string   m_objPrefix;
   double   m_pipSize;

public:
   CPinBarDetector() :
      m_wickRatio(2.0),
      m_bodyPercent(33.0),
      m_srTolerance(20.0),
      m_drawArrows(true),
      m_objPrefix("PB_")
   {}

   ~CPinBarDetector()
   {
      RemovePinBarObjects();
   }

   //--- Initialise parameters
   void Init(double wickRatio, double bodyPct, double srTol, bool drawArrows)
   {
      m_wickRatio   = wickRatio;
      m_bodyPercent = bodyPct;
      m_srTolerance = srTol;
      m_drawArrows  = drawArrows;
      m_pipSize     = GetPipSize();

      Print("[PinBar] Init wickRatio=", m_wickRatio,
            " bodyPct=", m_bodyPercent, "% srTol=", m_srTolerance, "pips");
   }

   //--- Detect pin bar on the closed candle (index >= 1)
   //    Pass CSupportResistance to validate S/R context
   //    Returns PINBAR_BULLISH, PINBAR_BEARISH, or PINBAR_NONE
   ENUM_PINBAR_TYPE Detect(ENUM_TIMEFRAMES tf, int barIndex,
                            CSupportResistance &sr)
   {
      if(barIndex < 1) return PINBAR_NONE;

      double open  = iOpen(_Symbol,  tf, barIndex);
      double high  = iHigh(_Symbol,  tf, barIndex);
      double low   = iLow(_Symbol,   tf, barIndex);
      double close = iClose(_Symbol, tf, barIndex);

      double totalRange = high - low;
      if(totalRange <= 0) return PINBAR_NONE;

      double bodySize  = MathAbs(close - open);
      double upperWick = high - MathMax(open, close);
      double lowerWick = MathMin(open, close) - low;

      // Body must be small relative to total range
      if(bodySize / totalRange * 100.0 > m_bodyPercent) return PINBAR_NONE;

      // --- Bearish pin bar (upper wick dominant) ---
      if(upperWick >= m_wickRatio * bodySize && upperWick > lowerWick)
      {
         // Must be at or near a resistance level
         double levelPrice = 0;
         if(sr.IsAtResistance(high, levelPrice))
         {
            datetime barTime = iTime(_Symbol, tf, barIndex);
            Print("[PinBar] BEARISH pin at ", barTime, " High=", high,
                  " near R=", levelPrice);
            if(m_drawArrows)
               DrawArrow(barTime, high, PINBAR_BEARISH, barIndex);
            Alert("[PinBar] Bearish Pin Bar on ", _Symbol, " ", EnumToString(tf),
                  " at ", TimeToString(barTime));
            return PINBAR_BEARISH;
         }
      }

      // --- Bullish pin bar (lower wick dominant) ---
      if(lowerWick >= m_wickRatio * bodySize && lowerWick > upperWick)
      {
         // Must be at or near a support level
         double levelPrice = 0;
         if(sr.IsAtSupport(low, levelPrice))
         {
            datetime barTime = iTime(_Symbol, tf, barIndex);
            Print("[PinBar] BULLISH pin at ", barTime, " Low=", low,
                  " near S=", levelPrice);
            if(m_drawArrows)
               DrawArrow(barTime, low, PINBAR_BULLISH, barIndex);
            Alert("[PinBar] Bullish Pin Bar on ", _Symbol, " ", EnumToString(tf),
                  " at ", TimeToString(barTime));
            return PINBAR_BULLISH;
         }
      }

      return PINBAR_NONE;
   }

   //--- Check for pin bar without S/R requirement (used in trendline context)
   ENUM_PINBAR_TYPE DetectRaw(ENUM_TIMEFRAMES tf, int barIndex)
   {
      if(barIndex < 1) return PINBAR_NONE;

      double open  = iOpen(_Symbol,  tf, barIndex);
      double high  = iHigh(_Symbol,  tf, barIndex);
      double low   = iLow(_Symbol,   tf, barIndex);
      double close = iClose(_Symbol, tf, barIndex);

      double totalRange = high - low;
      if(totalRange <= 0) return PINBAR_NONE;

      double bodySize  = MathAbs(close - open);
      double upperWick = high - MathMax(open, close);
      double lowerWick = MathMin(open, close) - low;

      if(bodySize / totalRange * 100.0 > m_bodyPercent) return PINBAR_NONE;

      if(upperWick >= m_wickRatio * bodySize && upperWick > lowerWick)
         return PINBAR_BEARISH;

      if(lowerWick >= m_wickRatio * bodySize && lowerWick > upperWick)
         return PINBAR_BULLISH;

      return PINBAR_NONE;
   }

private:
   void DrawArrow(datetime time, double price, ENUM_PINBAR_TYPE type, int barIndex)
   {
      string name = m_objPrefix + IntegerToString((int)time);
      if(ObjectFind(0, name) >= 0) return; // Already drawn

      double offset = 5.0 * m_pipSize;
      int    arrowCode;
      color  arrowColor;
      double arrowPrice;

      if(type == PINBAR_BULLISH)
      {
         arrowCode  = 233; // Arrow up
         arrowColor = clrLime;
         arrowPrice = price - offset;
      }
      else
      {
         arrowCode  = 234; // Arrow down
         arrowColor = clrRed;
         arrowPrice = price + offset;
      }

      ObjectCreate(0, name, OBJ_ARROW, 0, time, arrowPrice);
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
      ObjectSetInteger(0, name, OBJPROP_COLOR,     arrowColor);
      ObjectSetInteger(0, name, OBJPROP_WIDTH,     2);
      ObjectSetString(0,  name, OBJPROP_TOOLTIP,
                      (type == PINBAR_BULLISH ? "Bullish Pin Bar" : "Bearish Pin Bar"));
      ChartRedraw();
   }

   void RemovePinBarObjects()
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

#endif // PINBARDETECTOR_MQH
