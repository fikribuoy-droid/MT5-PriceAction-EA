//+------------------------------------------------------------------+
//|                                              PinBarDetector.mqh |
//|                    Price Action Master EA - Pin Bar Detector     |
//|                                                                  |
//| Identifies pin bar (hammer / shooting star) candlestick patterns |
//| that form at or near Support/Resistance levels.                  |
//| Draws arrows on the chart and sends alerts on detection.         |
//+------------------------------------------------------------------+
#ifndef PIN_BAR_DETECTOR_MQH
#define PIN_BAR_DETECTOR_MQH

//+------------------------------------------------------------------+
//| Pin bar signal structure                                         |
//+------------------------------------------------------------------+
struct PinBarSignal
{
   bool     valid;          // True = confirmed pin bar signal
   bool     is_bullish;     // True = bullish (at support), False = bearish (at resistance)
   int      bar_index;      // Bar index on chart
   datetime bar_time;       // Bar open time
   double   entry_price;    // Suggested entry (close of pin bar or high/low)
   double   stop_loss;      // Suggested stop loss (below/above the wick)
   double   wick_ratio;     // Actual wick/body ratio
   double   body_percent;   // Body as % of total candle range
};

//+------------------------------------------------------------------+
//| CPinBarDetector - Detects pin bars at S/R levels                 |
//+------------------------------------------------------------------+
class CPinBarDetector
{
private:
   string          m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   double          m_min_wick_ratio;    // Minimum wick/body ratio
   double          m_max_body_percent;  // Maximum body % of total candle
   double          m_sr_tolerance_pips; // Distance to S/R level to qualify
   bool            m_draw_arrows;
   bool            m_send_alerts;
   datetime        m_last_alert_time;

   double   PipSize(void);
   string   ArrowName(int bar, bool bullish);
   void     DrawArrow(const PinBarSignal &sig);
   void     RemoveArrow(string name);

public:
   CPinBarDetector(void);
   ~CPinBarDetector(void);

   void     Init(string symbol, ENUM_TIMEFRAMES tf,
                 double wick_ratio, double body_pct, double sr_tol_pips,
                 bool draw_arrows, bool send_alerts);

   // Detection (bar_index = 1 means last closed bar)
   PinBarSignal Detect(int bar_index, bool at_support, bool at_resistance);
   bool         IsPinBar(int bar_index, bool &is_bullish, double &wick_ratio, double &body_pct);

   // Visual management
   void     ClearArrows(void);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPinBarDetector::CPinBarDetector(void)
{
   m_symbol             = _Symbol;
   m_timeframe          = PERIOD_H1;
   m_min_wick_ratio     = 2.0;
   m_max_body_percent   = 33.0;
   m_sr_tolerance_pips  = 20.0;
   m_draw_arrows        = true;
   m_send_alerts        = true;
   m_last_alert_time    = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CPinBarDetector::~CPinBarDetector(void)
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
void CPinBarDetector::Init(string symbol, ENUM_TIMEFRAMES tf,
                           double wick_ratio, double body_pct, double sr_tol_pips,
                           bool draw_arrows, bool send_alerts)
{
   m_symbol             = symbol;
   m_timeframe          = tf;
   m_min_wick_ratio     = wick_ratio;
   m_max_body_percent   = body_pct;
   m_sr_tolerance_pips  = sr_tol_pips;
   m_draw_arrows        = draw_arrows;
   m_send_alerts        = send_alerts;
}

//+------------------------------------------------------------------+
//| Pip size helper                                                  |
//+------------------------------------------------------------------+
double CPinBarDetector::PipSize(void)
{
   double point  = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   return (digits == 5 || digits == 3) ? point * 10.0 : point;
}

//+------------------------------------------------------------------+
//| Arrow chart object name                                          |
//+------------------------------------------------------------------+
string CPinBarDetector::ArrowName(int bar, bool bullish)
{
   return StringFormat("PB_%s_%d", bullish ? "Bull" : "Bear", bar);
}

//+------------------------------------------------------------------+
//| Draw arrow on chart                                              |
//+------------------------------------------------------------------+
void CPinBarDetector::DrawArrow(const PinBarSignal &sig)
{
   if(!m_draw_arrows) return;

   string name  = ArrowName(sig.bar_index, sig.is_bullish);
   double price = sig.is_bullish ?
                  iLow(m_symbol, m_timeframe, sig.bar_index)  - 5 * PipSize() :
                  iHigh(m_symbol, m_timeframe, sig.bar_index) + 5 * PipSize();
   int    arrow = sig.is_bullish ? 233 : 234; // Wingdings up/down arrow
   color  clr   = sig.is_bullish ? clrLime : clrRed;

   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_ARROW, 0, sig.bar_time, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrow);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetString(0, name, OBJPROP_TOOLTIP,
                   StringFormat("%s Pin Bar  Wick:Body=%.1f  Body%%=%.1f",
                                sig.is_bullish ? "Bullish" : "Bearish",
                                sig.wick_ratio, sig.body_percent));
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Remove an arrow                                                  |
//+------------------------------------------------------------------+
void CPinBarDetector::RemoveArrow(string name)
{
   ObjectDelete(0, name);
}

//+------------------------------------------------------------------+
//| Core pin bar identification logic                                |
//| Returns true if bar qualifies; fills is_bullish, wick_ratio,     |
//| and body_pct output parameters.                                  |
//+------------------------------------------------------------------+
bool CPinBarDetector::IsPinBar(int bar_index, bool &is_bullish, double &wick_ratio, double &body_pct)
{
   double open  = iOpen(m_symbol, m_timeframe, bar_index);
   double high  = iHigh(m_symbol, m_timeframe, bar_index);
   double low   = iLow(m_symbol, m_timeframe, bar_index);
   double close = iClose(m_symbol, m_timeframe, bar_index);

   double total_range = high - low;
   if(total_range < PipSize()) return false; // Doji / zero-range candle

   double body      = MathAbs(close - open);
   double upper_wick = high - MathMax(open, close);
   double lower_wick = MathMin(open, close) - low;

   body_pct = (body / total_range) * 100.0;

   // Body must be small enough
   if(body_pct > m_max_body_percent) return false;

   // Determine pin bar direction and calculate wick ratio
   // Bullish pin bar: long lower wick (hammer)
   if(lower_wick > upper_wick)
   {
      if(body <= 0) return false;
      wick_ratio = lower_wick / MathMax(body, PipSize());
      if(wick_ratio < m_min_wick_ratio) return false;
      is_bullish = true;
      return true;
   }
   // Bearish pin bar: long upper wick (shooting star)
   else
   {
      if(body <= 0) return false;
      wick_ratio = upper_wick / MathMax(body, PipSize());
      if(wick_ratio < m_min_wick_ratio) return false;
      is_bullish = false;
      return true;
   }
}

//+------------------------------------------------------------------+
//| Full pin bar detection including S/R context check               |
//| Returns a PinBarSignal struct; check .valid before using         |
//+------------------------------------------------------------------+
PinBarSignal CPinBarDetector::Detect(int bar_index, bool at_support, bool at_resistance)
{
   PinBarSignal sig;
   ZeroMemory(sig);
   sig.bar_index = bar_index;
   sig.bar_time  = iTime(m_symbol, m_timeframe, bar_index);

   bool   is_bullish  = false;
   double wick_ratio  = 0;
   double body_pct    = 0;

   if(!IsPinBar(bar_index, is_bullish, wick_ratio, body_pct))
      return sig;

   // Validate S/R context
   // Bullish pin bar must be at support; bearish must be at resistance
   if(is_bullish  && !at_support)    return sig;
   if(!is_bullish && !at_resistance) return sig;

   sig.valid        = true;
   sig.is_bullish   = is_bullish;
   sig.wick_ratio   = wick_ratio;
   sig.body_percent = body_pct;

   double pip = PipSize();

   if(is_bullish)
   {
      // Entry: high of pin bar (break of high for confirmation)
      sig.entry_price = iHigh(m_symbol, m_timeframe, bar_index);
      // Stop loss: below the low of pin bar with buffer
      sig.stop_loss   = iLow(m_symbol, m_timeframe, bar_index) - 3.0 * pip;
   }
   else
   {
      // Entry: low of pin bar
      sig.entry_price = iLow(m_symbol, m_timeframe, bar_index);
      // Stop loss: above the high of pin bar with buffer
      sig.stop_loss   = iHigh(m_symbol, m_timeframe, bar_index) + 3.0 * pip;
   }

   // Draw arrow on chart
   DrawArrow(sig);

   // Send alert (once per bar)
   if(m_send_alerts && sig.bar_time != m_last_alert_time)
   {
      m_last_alert_time = sig.bar_time;
      string msg = StringFormat("%s %s Pin Bar detected! W:B=%.1f  Body%%=%.1f",
                                m_symbol,
                                is_bullish ? "Bullish" : "Bearish",
                                wick_ratio, body_pct);
      Alert(msg);
      Print("PinBarDetector: ", msg);
   }

   return sig;
}

//+------------------------------------------------------------------+
//| Remove all pin bar arrows from the chart                         |
//+------------------------------------------------------------------+
void CPinBarDetector::ClearArrows(void)
{
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, "PB_") == 0)
         ObjectDelete(0, name);
   }
   ChartRedraw(0);
}

#endif // PIN_BAR_DETECTOR_MQH
