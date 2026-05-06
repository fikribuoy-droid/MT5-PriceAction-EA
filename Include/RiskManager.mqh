//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//|                       Price Action Master EA - Risk Manager      |
//|                                                                  |
//| Handles position sizing, trade protection (trailing stop, break  |
//| even), and money management rules (daily loss, drawdown limits). |
//+------------------------------------------------------------------+
#ifndef RISK_MANAGER_MQH
#define RISK_MANAGER_MQH

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| CRiskManager - All risk and money management logic               |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   // External references
   CTrade        m_trade;
   CPositionInfo m_position;
   CAccountInfo  m_account;
   CSymbolInfo   m_symbol;

   // Configuration
   long          m_magic;               // EA magic number
   double        m_risk_percent;        // Risk per trade (%)
   double        m_rr_ratio;            // Risk:Reward ratio
   int           m_max_open_trades;     // Max simultaneous positions
   double        m_max_daily_loss_pct;  // Max daily loss (%)
   double        m_max_drawdown_pct;    // Max drawdown (%)
   bool          m_use_trailing_stop;
   int           m_trailing_start_pips; // Profit pips before trailing starts
   int           m_trailing_step_pips;  // Trailing step size in pips
   bool          m_use_break_even;
   int           m_break_even_profit_pips; // Pips profit to trigger BE
   int           m_break_even_plus_pips;   // Extra pips to lock when BE triggers

   // Daily tracking
   double        m_day_start_balance;   // Balance at start of trading day
   datetime      m_day_start_time;      // Timestamp of current trading day
   double        m_session_wins;
   double        m_session_losses;

   // Internal helpers
   double        PipValue(string symbol);
   double        PipSize(string symbol);
   void          UpdateDayStart(void);
   int           CountOpenTrades(void);

public:
   CRiskManager(void);
   ~CRiskManager(void);

   // Configuration
   void     SetMagicNumber(long magic)          { m_magic = magic; }
   void     SetRiskPercent(double pct)          { m_risk_percent = pct; }
   void     SetRRRatio(double rr)               { m_rr_ratio = rr; }
   void     SetMaxOpenTrades(int n)             { m_max_open_trades = n; }
   void     SetMaxDailyLoss(double pct)         { m_max_daily_loss_pct = pct; }
   void     SetMaxDrawdown(double pct)          { m_max_drawdown_pct = pct; }
   void     SetTrailingStop(bool use, int start_pips, int step_pips);
   void     SetBreakEven(bool use, int profit_pips, int plus_pips);

   // Initialization
   bool     Init(string symbol);

   // Lot size calculation
   double   CalculateLotSize(string symbol, double sl_price, double entry_price);
   double   CalculateLotSizePips(string symbol, double sl_pips);

   // Take-profit calculation
   double   CalculateTakeProfit(string symbol, double entry_price, double sl_price, int direction);

   // Money management guards
   bool     IsNewTradeAllowed(void);
   bool     IsDailyLossReached(void);
   bool     IsMaxDrawdownReached(void);
   double   GetDailyPL(void);
   double   GetDailyPLPercent(void);

   // Trade management (called on every tick)
   void     ManageOpenTrades(void);

   // Statistics
   double   GetWinRate(void)     { return (m_session_wins + m_session_losses > 0) ?
                                   m_session_wins / (m_session_wins + m_session_losses) * 100.0 : 0.0; }
   double   GetSessionWins(void) { return m_session_wins; }
   double   GetSessionLosses(void){ return m_session_losses; }
   void     RecordWin(void)      { m_session_wins++; }
   void     RecordLoss(void)     { m_session_losses++; }
   int      GetOpenTradeCount(void) { return CountOpenTrades(); }
   double   GetCurrentRiskExposure(void);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager(void)
{
   m_magic                  = 123456;
   m_risk_percent           = 2.0;
   m_rr_ratio               = 2.0;
   m_max_open_trades        = 1;
   m_max_daily_loss_pct     = 6.0;
   m_max_drawdown_pct       = 20.0;
   m_use_trailing_stop      = true;
   m_trailing_start_pips    = 30;
   m_trailing_step_pips     = 10;
   m_use_break_even         = true;
   m_break_even_profit_pips = 20;
   m_break_even_plus_pips   = 5;
   m_day_start_balance      = 0.0;
   m_day_start_time         = 0;
   m_session_wins           = 0;
   m_session_losses         = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager(void)
{
}

//+------------------------------------------------------------------+
//| Configure trailing stop parameters                               |
//+------------------------------------------------------------------+
void CRiskManager::SetTrailingStop(bool use, int start_pips, int step_pips)
{
   m_use_trailing_stop   = use;
   m_trailing_start_pips = start_pips;
   m_trailing_step_pips  = step_pips;
}

//+------------------------------------------------------------------+
//| Configure break even parameters                                  |
//+------------------------------------------------------------------+
void CRiskManager::SetBreakEven(bool use, int profit_pips, int plus_pips)
{
   m_use_break_even         = use;
   m_break_even_profit_pips = profit_pips;
   m_break_even_plus_pips   = plus_pips;
}

//+------------------------------------------------------------------+
//| Initialize with account balance for day tracking                 |
//+------------------------------------------------------------------+
bool CRiskManager::Init(string symbol)
{
   if(!m_symbol.Name(symbol))
   {
      Print("RiskManager: Failed to initialize symbol info for ", symbol);
      return false;
   }
   m_trade.SetExpertMagicNumber(m_magic);
   m_trade.SetDeviationInPoints(20);
   UpdateDayStart();
   Print("RiskManager: Initialized. Balance=", m_account.Balance(),
         " DayStartBalance=", m_day_start_balance);
   return true;
}

//+------------------------------------------------------------------+
//| Return pip size (point value adjusted for 5-digit brokers)       |
//+------------------------------------------------------------------+
double CRiskManager::PipSize(string symbol)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   // For 5-digit symbols (EURUSD=1.23456), 1 pip = 10 points
   if(digits == 5 || digits == 3)
      return point * 10.0;
   return point;
}

//+------------------------------------------------------------------+
//| Return monetary value of 1 pip for 1 standard lot                |
//+------------------------------------------------------------------+
double CRiskManager::PipValue(string symbol)
{
   double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point      = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double pip_size   = PipSize(symbol);

   if(tick_size <= 0) return 0;
   return tick_value * pip_size / tick_size;
}

//+------------------------------------------------------------------+
//| Update the day-start balance (called at start and on new day)    |
//+------------------------------------------------------------------+
void CRiskManager::UpdateDayStart(void)
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime today_start = StructToTime(dt);

   if(m_day_start_time < today_start)
   {
      m_day_start_time    = today_start;
      m_day_start_balance = m_account.Balance();
      Print("RiskManager: New trading day started. Day start balance=", m_day_start_balance);
   }
}

//+------------------------------------------------------------------+
//| Count open positions belonging to this EA (by magic number)      |
//+------------------------------------------------------------------+
int CRiskManager::CountOpenTrades(void)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Magic() == m_magic)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Calculate lot size based on account risk and stop loss distance  |
//| Parameters: sl_price and entry_price define the SL distance      |
//+------------------------------------------------------------------+
double CRiskManager::CalculateLotSize(string symbol, double sl_price, double entry_price)
{
   double sl_pips = MathAbs(entry_price - sl_price) / PipSize(symbol);
   return CalculateLotSizePips(symbol, sl_pips);
}

//+------------------------------------------------------------------+
//| Calculate lot size given SL in pips                              |
//+------------------------------------------------------------------+
double CRiskManager::CalculateLotSizePips(string symbol, double sl_pips)
{
   if(sl_pips <= 0)
   {
      Print("RiskManager: Invalid SL pips (", sl_pips, "), using minimum lot");
      return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   }

   double balance   = m_account.Balance();
   double risk_amt  = balance * m_risk_percent / 100.0;
   double pip_val   = PipValue(symbol);

   if(pip_val <= 0)
   {
      Print("RiskManager: Cannot calculate pip value for ", symbol);
      return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   }

   double lot = risk_amt / (sl_pips * pip_val);

   // Normalize to broker specifications
   double min_lot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double max_lot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   lot = MathFloor(lot / lot_step) * lot_step;
   lot = MathMax(lot, min_lot);
   lot = MathMin(lot, max_lot);

   Print(StringFormat("RiskManager: LotSize=%.2f  Risk=%.2f  SL_Pips=%.1f  PipVal=%.4f",
         lot, risk_amt, sl_pips, pip_val));
   return lot;
}

//+------------------------------------------------------------------+
//| Calculate TP price based on RR ratio                             |
//| direction: +1 = buy, -1 = sell                                   |
//+------------------------------------------------------------------+
double CRiskManager::CalculateTakeProfit(string symbol, double entry_price, double sl_price, int direction)
{
   double sl_dist = MathAbs(entry_price - sl_price);
   double tp_dist = sl_dist * m_rr_ratio;
   double tp      = entry_price + direction * tp_dist;

   // Validate minimum distance
   double min_sl = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) *
                   SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(MathAbs(tp - entry_price) < min_sl)
   {
      Print("RiskManager: Calculated TP too close to entry, adjusting");
      tp = entry_price + direction * min_sl;
   }

   return tp;
}

//+------------------------------------------------------------------+
//| Check all money management rules before allowing a new trade     |
//+------------------------------------------------------------------+
bool CRiskManager::IsNewTradeAllowed(void)
{
   UpdateDayStart();

   if(CountOpenTrades() >= m_max_open_trades)
   {
      Print("RiskManager: Max open trades reached (", m_max_open_trades, ")");
      return false;
   }
   if(IsDailyLossReached())
   {
      Print("RiskManager: Daily loss limit reached");
      return false;
   }
   if(IsMaxDrawdownReached())
   {
      Print("RiskManager: Max drawdown reached");
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| True if daily loss limit has been breached                       |
//+------------------------------------------------------------------+
bool CRiskManager::IsDailyLossReached(void)
{
   UpdateDayStart();
   if(m_day_start_balance <= 0) return false;
   double daily_loss_pct = GetDailyPLPercent();
   return (daily_loss_pct < -m_max_daily_loss_pct);
}

//+------------------------------------------------------------------+
//| True if max drawdown from balance peak has been exceeded         |
//+------------------------------------------------------------------+
bool CRiskManager::IsMaxDrawdownReached(void)
{
   double equity  = m_account.Equity();
   double balance = m_account.Balance();
   if(balance <= 0) return false;
   double drawdown_pct = (balance - equity) / balance * 100.0;
   return (drawdown_pct >= m_max_drawdown_pct);
}

//+------------------------------------------------------------------+
//| Current day P/L in account currency                              |
//+------------------------------------------------------------------+
double CRiskManager::GetDailyPL(void)
{
   UpdateDayStart();
   return m_account.Equity() - m_day_start_balance;
}

//+------------------------------------------------------------------+
//| Current day P/L as percentage of day-start balance               |
//+------------------------------------------------------------------+
double CRiskManager::GetDailyPLPercent(void)
{
   UpdateDayStart();
   if(m_day_start_balance <= 0) return 0.0;
   return GetDailyPL() / m_day_start_balance * 100.0;
}

//+------------------------------------------------------------------+
//| Total risk exposure of all open EA trades as % of balance        |
//+------------------------------------------------------------------+
double CRiskManager::GetCurrentRiskExposure(void)
{
   double total_risk = 0;
   double balance    = m_account.Balance();
   if(balance <= 0) return 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Magic() != m_magic) continue;

      double sl    = m_position.StopLoss();
      double open  = m_position.PriceOpen();
      double lots  = m_position.Volume();
      string sym   = m_position.Symbol();

      if(sl <= 0) continue;
      double sl_pips = MathAbs(open - sl) / PipSize(sym);
      double risk_val = sl_pips * PipValue(sym) * lots;
      total_risk += risk_val;
   }
   return total_risk / balance * 100.0;
}

//+------------------------------------------------------------------+
//| Manage all open trades: apply trailing stop and break even       |
//+------------------------------------------------------------------+
void CRiskManager::ManageOpenTrades(void)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Magic() != m_magic) continue;

      string sym      = m_position.Symbol();
      long   type     = m_position.PositionType();
      double open     = m_position.PriceOpen();
      double current  = m_position.PriceCurrent();
      double sl       = m_position.StopLoss();
      double tp       = m_position.TakeProfit();
      double pip      = PipSize(sym);

      double profit_pips = 0;
      if(type == POSITION_TYPE_BUY)
         profit_pips = (current - open) / pip;
      else
         profit_pips = (open - current) / pip;

      // --- Break Even ---
      if(m_use_break_even && profit_pips >= m_break_even_profit_pips)
      {
         double be_sl = (type == POSITION_TYPE_BUY) ?
                        open + m_break_even_plus_pips * pip :
                        open - m_break_even_plus_pips * pip;

         bool should_update = false;
         if(type == POSITION_TYPE_BUY  && sl < be_sl)  should_update = true;
         if(type == POSITION_TYPE_SELL && (sl == 0 || sl > be_sl)) should_update = true;

         if(should_update)
         {
            if(m_trade.PositionModify(m_position.Ticket(), be_sl, tp))
               Print("RiskManager: Break even applied for ticket ", m_position.Ticket(),
                     " SL=", be_sl);
            else
               Print("RiskManager: Break even failed. Error=", GetLastError());
         }
      }

      // --- Trailing Stop ---
      if(m_use_trailing_stop && profit_pips >= m_trailing_start_pips)
      {
         double trail_dist = m_trailing_step_pips * pip;
         double new_sl = 0;

         if(type == POSITION_TYPE_BUY)
         {
            new_sl = current - trail_dist;
            if(sl > 0 && new_sl > sl)
            {
               if(m_trade.PositionModify(m_position.Ticket(), new_sl, tp))
                  Print("RiskManager: Trailing stop updated for ticket ", m_position.Ticket(),
                        " new SL=", new_sl);
            }
         }
         else // SELL
         {
            new_sl = current + trail_dist;
            if(sl > 0 && new_sl < sl)
            {
               if(m_trade.PositionModify(m_position.Ticket(), new_sl, tp))
                  Print("RiskManager: Trailing stop updated for ticket ", m_position.Ticket(),
                        " new SL=", new_sl);
            }
         }
      }
   }
}

#endif // RISK_MANAGER_MQH
