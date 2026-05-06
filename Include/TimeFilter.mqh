//+------------------------------------------------------------------+
//|                                                   TimeFilter.mqh |
//|                          Price Action Master EA - Time Filter    |
//|                                                                  |
//| Filters trades by trading session (Asian, London, New York).     |
//| All times are in GMT (broker server time assumed GMT).           |
//+------------------------------------------------------------------+
#ifndef TIME_FILTER_MQH
#define TIME_FILTER_MQH

//+------------------------------------------------------------------+
//| Session time constants (GMT hours)                               |
//+------------------------------------------------------------------+
#define ASIAN_SESSION_START   0    // 00:00 GMT
#define ASIAN_SESSION_END     9    // 09:00 GMT
#define LONDON_SESSION_START  8    // 08:00 GMT
#define LONDON_SESSION_END    17   // 17:00 GMT
#define NEWYORK_SESSION_START 13   // 13:00 GMT
#define NEWYORK_SESSION_END   22   // 22:00 GMT

//+------------------------------------------------------------------+
//| Session identifier enum                                          |
//+------------------------------------------------------------------+
enum ENUM_SESSION
{
   SESSION_NONE    = 0,
   SESSION_ASIAN   = 1,
   SESSION_LONDON  = 2,
   SESSION_NEWYORK = 4,
   SESSION_LONDON_NY_OVERLAP = 6   // London + NY combined (bits 2+4)
};

//+------------------------------------------------------------------+
//| CTimeFilter - Manages trading session filtering                  |
//+------------------------------------------------------------------+
class CTimeFilter
{
private:
   bool     m_trade_asian;
   bool     m_trade_london;
   bool     m_trade_newyork;
   bool     m_draw_session_lines;
   datetime m_last_draw_time;

   // Convert a datetime to hour in GMT
   int      HourGMT(datetime dt) { return (int)((dt % 86400) / 3600); }
   int      MinuteGMT(datetime dt) { return (int)((dt % 3600) / 60); }

public:
   CTimeFilter(void);
   ~CTimeFilter(void);

   // Configuration
   void     SetSessions(bool asian, bool london, bool newyork);
   void     SetDrawSessionLines(bool draw) { m_draw_session_lines = draw; }

   // Query
   bool     IsAllowedToTrade(void);
   bool     IsAllowedToTrade(datetime check_time);
   ENUM_SESSION GetCurrentSession(void);
   ENUM_SESSION GetCurrentSession(datetime check_time);
   bool     IsLondonNYOverlap(void);
   string   GetSessionName(ENUM_SESSION session);
   string   GetNextSessionInfo(void);

   // Visual
   void     DrawSessionLines(datetime start_time, int bars_back = 100);
   void     RemoveSessionLines(void);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTimeFilter::CTimeFilter(void)
{
   m_trade_asian       = false;
   m_trade_london      = true;
   m_trade_newyork     = true;
   m_draw_session_lines = false;
   m_last_draw_time    = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTimeFilter::~CTimeFilter(void)
{
}

//+------------------------------------------------------------------+
//| Set session trading flags                                        |
//+------------------------------------------------------------------+
void CTimeFilter::SetSessions(bool asian, bool london, bool newyork)
{
   m_trade_asian   = asian;
   m_trade_london  = london;
   m_trade_newyork = newyork;
}

//+------------------------------------------------------------------+
//| Check if current time is within an allowed trading session       |
//+------------------------------------------------------------------+
bool CTimeFilter::IsAllowedToTrade(void)
{
   return IsAllowedToTrade(TimeGMT());
}

//+------------------------------------------------------------------+
//| Check if given time is within an allowed trading session         |
//+------------------------------------------------------------------+
bool CTimeFilter::IsAllowedToTrade(datetime check_time)
{
   int hour = HourGMT(check_time);

   bool in_asian   = (hour >= ASIAN_SESSION_START   && hour < ASIAN_SESSION_END);
   bool in_london  = (hour >= LONDON_SESSION_START  && hour < LONDON_SESSION_END);
   bool in_newyork = (hour >= NEWYORK_SESSION_START && hour < NEWYORK_SESSION_END);

   if(m_trade_asian   && in_asian)   return true;
   if(m_trade_london  && in_london)  return true;
   if(m_trade_newyork && in_newyork) return true;

   return false;
}

//+------------------------------------------------------------------+
//| Get current active session flags                                 |
//+------------------------------------------------------------------+
ENUM_SESSION CTimeFilter::GetCurrentSession(void)
{
   return GetCurrentSession(TimeGMT());
}

//+------------------------------------------------------------------+
//| Get session flags for a given time                               |
//+------------------------------------------------------------------+
ENUM_SESSION CTimeFilter::GetCurrentSession(datetime check_time)
{
   int hour = HourGMT(check_time);
   int flags = 0;

   if(hour >= ASIAN_SESSION_START   && hour < ASIAN_SESSION_END)   flags |= SESSION_ASIAN;
   if(hour >= LONDON_SESSION_START  && hour < LONDON_SESSION_END)  flags |= SESSION_LONDON;
   if(hour >= NEWYORK_SESSION_START && hour < NEWYORK_SESSION_END) flags |= SESSION_NEWYORK;

   return (ENUM_SESSION)flags;
}

//+------------------------------------------------------------------+
//| True if currently in the London/NY overlap (most volatile)       |
//+------------------------------------------------------------------+
bool CTimeFilter::IsLondonNYOverlap(void)
{
   int hour = HourGMT(TimeGMT());
   return (hour >= NEWYORK_SESSION_START && hour < LONDON_SESSION_END);
}

//+------------------------------------------------------------------+
//| Human-readable session name                                      |
//+------------------------------------------------------------------+
string CTimeFilter::GetSessionName(ENUM_SESSION session)
{
   if((session & SESSION_LONDON) && (session & SESSION_NEWYORK)) return "London/NY Overlap";
   if(session & SESSION_LONDON)  return "London";
   if(session & SESSION_NEWYORK) return "New York";
   if(session & SESSION_ASIAN)   return "Asian";
   return "Off-Session";
}

//+------------------------------------------------------------------+
//| Return info string about the next allowed session                |
//+------------------------------------------------------------------+
string CTimeFilter::GetNextSessionInfo(void)
{
   datetime now = TimeGMT();
   int hour     = HourGMT(now);

   // Calculate hours until each potential next session
   if(m_trade_london && hour < LONDON_SESSION_START)
      return StringFormat("London opens in %d hour(s)", LONDON_SESSION_START - hour);
   if(m_trade_newyork && hour < NEWYORK_SESSION_START)
      return StringFormat("New York opens in %d hour(s)", NEWYORK_SESSION_START - hour);
   if(m_trade_asian && hour < 24)
   {
      int hours_to_midnight = 24 - hour;
      return StringFormat("Asian session in %d hour(s)", hours_to_midnight);
   }

   return "No next session configured";
}

//+------------------------------------------------------------------+
//| Draw vertical lines on chart for session boundaries              |
//+------------------------------------------------------------------+
void CTimeFilter::DrawSessionLines(datetime start_time, int bars_back = 100)
{
   if(!m_draw_session_lines) return;

   // Remove old lines first
   RemoveSessionLines();

   string symbol = _Symbol;
   ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;

   for(int i = bars_back; i >= 0; i--)
   {
      datetime bar_time = iTime(symbol, tf, i);
      int hour = HourGMT(bar_time);
      int minute = MinuteGMT(bar_time);
      if(minute != 0) continue; // Only on exact hours

      color line_color = clrNONE;
      string label = "";

      if(hour == ASIAN_SESSION_START)
      {
         line_color = clrGold;
         label = "Asian Open";
      }
      else if(hour == ASIAN_SESSION_END)
      {
         line_color = clrGold;
         label = "Asian Close";
      }
      else if(hour == LONDON_SESSION_START)
      {
         line_color = clrDodgerBlue;
         label = "London Open";
      }
      else if(hour == LONDON_SESSION_END)
      {
         line_color = clrDodgerBlue;
         label = "London Close";
      }
      else if(hour == NEWYORK_SESSION_START)
      {
         line_color = clrOrangeRed;
         label = "NY Open";
      }
      else if(hour == NEWYORK_SESSION_END)
      {
         line_color = clrOrangeRed;
         label = "NY Close";
      }

      if(line_color == clrNONE) continue;

      string obj_name = StringFormat("TF_Line_%d_%d", hour, (int)bar_time);
      if(ObjectFind(0, obj_name) < 0)
      {
         ObjectCreate(0, obj_name, OBJ_VLINE, 0, bar_time, 0);
         ObjectSetInteger(0, obj_name, OBJPROP_COLOR, line_color);
         ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
         ObjectSetString(0, obj_name, OBJPROP_TOOLTIP, label);
         ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
      }
   }

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Remove all session vertical lines from chart                     |
//+------------------------------------------------------------------+
void CTimeFilter::RemoveSessionLines(void)
{
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, "TF_Line_") == 0)
         ObjectDelete(0, name);
   }
}

#endif // TIME_FILTER_MQH
