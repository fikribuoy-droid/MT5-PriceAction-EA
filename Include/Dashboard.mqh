//+------------------------------------------------------------------+
//|                                                    Dashboard.mqh |
//|                       Price Action Master EA - Dashboard         |
//|                                                                  |
//| Draws a real-time information panel in the top-right corner of  |
//| the chart showing account stats, EA status, and risk info.      |
//+------------------------------------------------------------------+
#ifndef DASHBOARD_MQH
#define DASHBOARD_MQH

//+------------------------------------------------------------------+
//| CDashboard - Real-time chart dashboard                           |
//+------------------------------------------------------------------+
class CDashboard
{
private:
   string   m_prefix;        // Object name prefix for easy cleanup
   int      m_corner;        // Chart corner (CORNER_RIGHT_UPPER = 1)
   int      m_x_offset;      // Right offset in pixels
   int      m_y_start;       // Top offset in pixels
   int      m_line_height;   // Pixels between lines
   int      m_font_size;
   string   m_font;
   bool     m_visible;

   // Create or update a label object
   void     SetLabel(string name, string text, int x, int y, color clr, int font_size = 0);
   void     SetRect(string name, int x, int y, int w, int h, color clr, int transparency = 80);
   string   LabelName(int row) { return m_prefix + IntegerToString(row); }

public:
   CDashboard(void);
   ~CDashboard(void);

   void     Init(bool visible);
   void     Update(
               double balance,
               double equity,
               double daily_pl,
               double daily_pl_pct,
               int    open_trades,
               double win_rate,
               double risk_exposure,
               int    sr_levels_count,
               string session_name,
               bool   daily_limit_warning,
               bool   drawdown_warning
            );
   void     Clear(void);
   void     Show(void) { m_visible = true; }
   void     Hide(void) { m_visible = false; Clear(); }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CDashboard::CDashboard(void)
{
   m_prefix      = "PA_DB_";
   m_corner      = CORNER_RIGHT_UPPER;
   m_x_offset    = 10;
   m_y_start     = 20;
   m_line_height = 18;
   m_font_size   = 9;
   m_font        = "Consolas";
   m_visible     = true;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CDashboard::~CDashboard(void)
{
   Clear();
}

//+------------------------------------------------------------------+
//| Initialize dashboard visibility                                  |
//+------------------------------------------------------------------+
void CDashboard::Init(bool visible)
{
   m_visible = visible;
   if(!visible) Clear();
}

//+------------------------------------------------------------------+
//| Create or update a text label at a given row position            |
//+------------------------------------------------------------------+
void CDashboard::SetLabel(string name, string text, int x, int y, color clr, int font_size)
{
   if(font_size == 0) font_size = m_font_size;

   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER,    m_corner);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR,    ANCHOR_RIGHT_UPPER);
      ObjectSetString(0, name,  OBJPROP_FONT,      m_font);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  font_size);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN,    true);
   }
   ObjectSetString(0, name,  OBJPROP_TEXT,  text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
}

//+------------------------------------------------------------------+
//| Draw background rectangle                                        |
//+------------------------------------------------------------------+
void CDashboard::SetRect(string name, int x, int y, int w, int h, color clr, int transparency)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER,    m_corner);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR,    ANCHOR_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN,    true);
      ObjectSetInteger(0, name, OBJPROP_BACK,      false);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,    x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,    y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,        w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,        h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrGray);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE,  BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_TRANSPARENCY, transparency);
}

//+------------------------------------------------------------------+
//| Update all dashboard labels with current data                    |
//+------------------------------------------------------------------+
void CDashboard::Update(
      double balance,
      double equity,
      double daily_pl,
      double daily_pl_pct,
      int    open_trades,
      double win_rate,
      double risk_exposure,
      int    sr_levels_count,
      string session_name,
      bool   daily_limit_warning,
      bool   drawdown_warning
   )
{
   if(!m_visible) return;

   int row = 0;
   int x   = m_x_offset;
   int y_base = m_y_start;

   // Background panel (approximately 220px wide, 220px tall)
   SetRect(m_prefix + "BG", x - 2, y_base - 5, 230, 240, clrBlack, 65);

   // Title
   SetLabel(m_prefix + "Title", "[ Price Action Master EA ]", x, y_base + (row++) * m_line_height,
            clrGold, 10);

   // Separator
   SetLabel(m_prefix + "Sep1", "─────────────────────", x, y_base + (row++) * m_line_height, clrDimGray, 8);

   // Balance
   SetLabel(m_prefix + "Bal",
            StringFormat("Balance : %10.2f", balance),
            x, y_base + (row++) * m_line_height, clrSilver);

   // Equity
   SetLabel(m_prefix + "Eq",
            StringFormat("Equity  : %10.2f", equity),
            x, y_base + (row++) * m_line_height, clrSilver);

   // Daily P/L
   color pl_color = (daily_pl >= 0) ? clrLimeGreen : clrTomato;
   if(daily_limit_warning) pl_color = clrOrange;
   SetLabel(m_prefix + "DPL",
            StringFormat("Day P/L : %+9.2f (%+.1f%%)", daily_pl, daily_pl_pct),
            x, y_base + (row++) * m_line_height, pl_color);

   // Separator
   SetLabel(m_prefix + "Sep2", "─────────────────────", x, y_base + (row++) * m_line_height, clrDimGray, 8);

   // Open trades
   color trades_color = (open_trades > 0) ? clrYellow : clrSilver;
   SetLabel(m_prefix + "Trades",
            StringFormat("Trades  : %d open", open_trades),
            x, y_base + (row++) * m_line_height, trades_color);

   // Win rate
   SetLabel(m_prefix + "WR",
            StringFormat("Win Rate: %.1f%%", win_rate),
            x, y_base + (row++) * m_line_height, clrSilver);

   // Risk exposure
   color risk_color = clrSilver;
   if(risk_exposure > 4.0) risk_color = clrOrange;
   if(risk_exposure > 6.0) risk_color = clrTomato;
   SetLabel(m_prefix + "Risk",
            StringFormat("Exposure: %.1f%%", risk_exposure),
            x, y_base + (row++) * m_line_height, risk_color);

   // S/R levels
   SetLabel(m_prefix + "SR",
            StringFormat("S/R Lvls: %d active", sr_levels_count),
            x, y_base + (row++) * m_line_height, clrSilver);

   // Session
   color sess_color = (session_name == "London/NY Overlap") ? clrGold :
                      (session_name == "Off-Session")        ? clrDimGray : clrDeepSkyBlue;
   SetLabel(m_prefix + "Session",
            StringFormat("Session : %s", session_name),
            x, y_base + (row++) * m_line_height, sess_color);

   // Separator
   SetLabel(m_prefix + "Sep3", "─────────────────────", x, y_base + (row++) * m_line_height, clrDimGray, 8);

   // Warning / status line
   string status_text = "Status  : OK";
   color  status_color = clrLimeGreen;

   if(drawdown_warning)
   {
      status_text  = "WARNING : MAX DRAWDOWN!";
      status_color = clrTomato;
   }
   else if(daily_limit_warning)
   {
      status_text  = "WARNING : DAILY LOSS!";
      status_color = clrOrange;
   }
   else if(open_trades > 0)
   {
      status_text  = "Status  : TRADE ACTIVE";
      status_color = clrYellow;
   }

   SetLabel(m_prefix + "Status", status_text, x, y_base + (row++) * m_line_height, status_color);

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Remove all dashboard objects from chart                          |
//+------------------------------------------------------------------+
void CDashboard::Clear(void)
{
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, m_prefix) == 0)
         ObjectDelete(0, name);
   }
   ChartRedraw(0);
}

#endif // DASHBOARD_MQH
