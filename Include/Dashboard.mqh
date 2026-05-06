//+------------------------------------------------------------------+
//|                                                  Dashboard.mqh   |
//|                        Price Action Master EA - Visual Dashboard  |
//|                                                                   |
//| Handles:                                                          |
//|  - Real-time statistics panel in top-right corner                 |
//|  - Account balance, daily P/L, win rate display                   |
//|  - Trading session, S/R level count                               |
//|  - Warning colours when approaching limits                        |
//+------------------------------------------------------------------+
#ifndef DASHBOARD_MQH
#define DASHBOARD_MQH

//+------------------------------------------------------------------+
//| Class: CDashboard                                                 |
//+------------------------------------------------------------------+
class CDashboard
{
private:
   string   m_prefix;
   int      m_corner;       // Chart corner (CORNER_RIGHT_UPPER = 1)
   int      m_x, m_y;       // Anchor pixel offsets
   int      m_lineHeight;
   int      m_fontSize;
   string   m_fontName;
   bool     m_enabled;

   // Dashboard line object names
   string m_names[];
   int    m_lineCount;

public:
   CDashboard() :
      m_prefix("DB_"),
      m_corner(CORNER_RIGHT_UPPER),
      m_x(10), m_y(20),
      m_lineHeight(18),
      m_fontSize(9),
      m_fontName("Courier New"),
      m_enabled(true),
      m_lineCount(0)
   {
      ArrayResize(m_names, 20);
   }

   ~CDashboard()
   {
      Remove();
   }

   //--- Initialise
   void Init(bool enabled)
   {
      m_enabled = enabled;
      if(!m_enabled) return;
      Print("[Dashboard] Initialized.");
   }

   //--- Update all dashboard fields each tick
   void Update(double balance,
               double equity,
               double dailyPL,
               double dailyPLPct,
               double drawdownPct,
               int    openTrades,
               double winRate,
               int    srLevels,
               string currentSession,
               string nextSession,
               bool   tradingHalted,
               double maxDailyLoss,
               double maxDrawdown)
   {
      if(!m_enabled) return;

      // Define colours
      color clrNormal  = clrWhite;
      color clrGood    = clrLimeGreen;
      color clrWarning = clrOrange;
      color clrBad     = clrRed;
      color clrTitle   = clrCyan;

      color clrPL      = (dailyPL >= 0)               ? clrGood    : clrBad;
      color clrDD      = (drawdownPct < maxDrawdown * 0.7) ? clrNormal :
                         (drawdownPct < maxDrawdown)   ? clrWarning : clrBad;
      color clrDL      = (MathAbs(dailyPLPct) < maxDailyLoss * 0.7) ? clrNormal :
                         (MathAbs(dailyPLPct) < maxDailyLoss)        ? clrWarning : clrBad;
      color clrHalted  = tradingHalted ? clrBad : clrGood;

      int row = 0;
      SetLabel(row++, "══ Price Action Master ══", clrTitle);
      SetLabel(row++, StringFormat("Balance:   %s %.2f",
               AccountInfoString(ACCOUNT_CURRENCY), balance),          clrNormal);
      SetLabel(row++, StringFormat("Equity:    %s %.2f",
               AccountInfoString(ACCOUNT_CURRENCY), equity),           clrNormal);
      SetLabel(row++, StringFormat("Daily P/L: %.2f (%.2f%%)",
               dailyPL, dailyPLPct),                                   clrPL);
      SetLabel(row++, StringFormat("Drawdown:  %.2f%%",
               drawdownPct),                                            clrDD);
      SetLabel(row++, "────────────────────────", clrDimGray);
      SetLabel(row++, StringFormat("Open Trades: %d", openTrades),    clrNormal);
      SetLabel(row++, StringFormat("Win Rate:    %.1f%%", winRate),    clrNormal);
      SetLabel(row++, StringFormat("S/R Levels:  %d", srLevels),      clrNormal);
      SetLabel(row++, "────────────────────────", clrDimGray);
      SetLabel(row++, StringFormat("Session: %s", currentSession),    clrNormal);
      SetLabel(row++, StringFormat("Next:    %s", nextSession),        clrDimGray);
      SetLabel(row++, "────────────────────────", clrDimGray);
      SetLabel(row++, StringFormat("Status: %s",
               tradingHalted ? "HALTED" : "TRADING"),                  clrHalted);

      ChartRedraw();
   }

   //--- Remove all dashboard objects
   void Remove()
   {
      int total = ObjectsTotal(0);
      for(int i = total - 1; i >= 0; i--)
      {
         string name = ObjectName(0, i);
         if(StringFind(name, m_prefix) == 0)
            ObjectDelete(0, name);
      }
   }

private:
   void SetLabel(int row, string text, color clr)
   {
      string name = m_prefix + IntegerToString(row);

      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER,    m_corner);
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, m_x);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, m_y + row * m_lineHeight);
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  m_fontSize);
         ObjectSetString(0,  name, OBJPROP_FONT,      m_fontName);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN,    true);
      }

      ObjectSetString(0,  name, OBJPROP_TEXT,  text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   }
};

#endif // DASHBOARD_MQH
