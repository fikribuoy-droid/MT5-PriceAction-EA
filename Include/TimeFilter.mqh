//+------------------------------------------------------------------+
//|                                               TimeFilter.mqh     |
//|                         Price Action Master EA - Session Filter   |
//|                                                                   |
//| Handles:                                                          |
//|  - Trading session enable/disable (Asian, London, New York)       |
//|  - Session overlap detection                                       |
//|  - Visual session background shading on the chart                 |
//+------------------------------------------------------------------+
#ifndef TIMEFILTER_MQH
#define TIMEFILTER_MQH

//+------------------------------------------------------------------+
//| Class: CTimeFilter                                                |
//+------------------------------------------------------------------+
class CTimeFilter
{
private:
   bool   m_tradeAsian;
   bool   m_tradeLondon;
   bool   m_tradeNewYork;

   // Session GMT times (hour, minute)
   int    m_asianStart;   // 00:00
   int    m_asianEnd;     //  9:00
   int    m_londonStart;  //  8:00
   int    m_londonEnd;    // 17:00
   int    m_nyStart;      // 13:00
   int    m_nyEnd;        // 22:00

   // Object name prefix for drawings
   string m_objPrefix;

public:
   CTimeFilter() :
      m_tradeAsian(false),
      m_tradeLondon(true),
      m_tradeNewYork(true),
      m_asianStart(0),   m_asianEnd(9),
      m_londonStart(8),  m_londonEnd(17),
      m_nyStart(13),     m_nyEnd(22),
      m_objPrefix("TF_")
   {}

   ~CTimeFilter()
   {
      RemoveSessionObjects();
   }

   //--- Initialise with external parameters
   void Init(bool tradeAsian, bool tradeLondon, bool tradeNewYork)
   {
      m_tradeAsian   = tradeAsian;
      m_tradeLondon  = tradeLondon;
      m_tradeNewYork = tradeNewYork;

      Print("[TimeFilter] Asian=", m_tradeAsian,
            " London=", m_tradeLondon,
            " NewYork=", m_tradeNewYork);
   }

   //--- Check if trading is allowed right now (GMT time)
   bool IsTradingAllowed()
   {
      datetime gmtNow  = TimeGMT();
      MqlDateTime dt;
      TimeToStruct(gmtNow, dt);
      int hour = dt.hour;

      // Weekend check
      if(dt.day_of_week == 0 || dt.day_of_week == 6)
         return false;

      if(m_tradeAsian   && IsInSession(hour, m_asianStart,  m_asianEnd))  return true;
      if(m_tradeLondon  && IsInSession(hour, m_londonStart, m_londonEnd)) return true;
      if(m_tradeNewYork && IsInSession(hour, m_nyStart,     m_nyEnd))     return true;

      return false;
   }

   //--- Return current session name for dashboard display
   string GetCurrentSession()
   {
      datetime gmtNow = TimeGMT();
      MqlDateTime dt;
      TimeToStruct(gmtNow, dt);
      int hour = dt.hour;

      bool inAsian  = IsInSession(hour, m_asianStart,  m_asianEnd);
      bool inLondon = IsInSession(hour, m_londonStart, m_londonEnd);
      bool inNY     = IsInSession(hour, m_nyStart,     m_nyEnd);

      if(inLondon && inNY)  return "London/NY Overlap";
      if(inLondon)          return "London";
      if(inNY)              return "New York";
      if(inAsian)           return "Asian";
      return "Closed";
   }

   //--- Return next active session start time string
   string GetNextSession()
   {
      datetime gmtNow = TimeGMT();
      MqlDateTime dt;
      TimeToStruct(gmtNow, dt);
      int hour = dt.hour;

      if(m_tradeLondon && hour < m_londonStart)
         return StringFormat("London at %02d:00 GMT", m_londonStart);
      if(m_tradeNewYork && hour < m_nyStart)
         return StringFormat("New York at %02d:00 GMT", m_nyStart);
      if(m_tradeLondon)
         return StringFormat("London at %02d:00 GMT (tomorrow)", m_londonStart);
      return "No session scheduled";
   }

   //--- Draw vertical lines marking session boundaries (call once per day)
   void DrawSessionLines()
   {
      datetime today = iTime(_Symbol, PERIOD_D1, 0);
      MqlDateTime dt;
      TimeToStruct(today, dt);

      // Build GMT base for today's date
      // Note: iTime returns broker time; we use TimeGMT offset
      int gmtOffset = (int)((TimeCurrent() - TimeGMT()) / 3600);

      if(m_tradeLondon)
      {
         DrawVLine("London_Open",  today + (m_londonStart - gmtOffset) * 3600, clrDodgerBlue);
         DrawVLine("London_Close", today + (m_londonEnd   - gmtOffset) * 3600, clrSteelBlue);
      }
      if(m_tradeNewYork)
      {
         DrawVLine("NY_Open",  today + (m_nyStart - gmtOffset) * 3600, clrOrange);
         DrawVLine("NY_Close", today + (m_nyEnd   - gmtOffset) * 3600, clrDarkOrange);
      }
      if(m_tradeAsian)
      {
         DrawVLine("Asian_Open",  today + (m_asianStart - gmtOffset) * 3600, clrGold);
         DrawVLine("Asian_Close", today + (m_asianEnd   - gmtOffset) * 3600, clrDarkGoldenrod);
      }

      ChartRedraw();
   }

private:
   bool IsInSession(int hour, int startHour, int endHour)
   {
      if(startHour < endHour)
         return (hour >= startHour && hour < endHour);
      // Wraps midnight
      return (hour >= startHour || hour < endHour);
   }

   void DrawVLine(string name, datetime time, color clr)
   {
      string objName = m_objPrefix + name;
      if(ObjectFind(0, objName) < 0)
         ObjectCreate(0, objName, OBJ_VLINE, 0, time, 0);
      ObjectSetInteger(0, objName, OBJPROP_TIME,  time);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
      ObjectSetString(0,  objName, OBJPROP_TOOLTIP, objName);
   }

   void RemoveSessionObjects()
   {
      int total = ObjectsTotal(0);
      for(int i = total - 1; i >= 0; i--)
      {
         string name = ObjectName(0, i);
         if(StringFind(name, m_objPrefix) == 0)
            ObjectDelete(0, name);
      }
   }
};

#endif // TIMEFILTER_MQH
