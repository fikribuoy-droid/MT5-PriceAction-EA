//+------------------------------------------------------------------+
//|                                               RiskManager.mqh    |
//|                         Price Action Master EA - Risk Management  |
//|                                                                   |
//| Handles:                                                          |
//|  - Position sizing based on risk percentage                       |
//|  - Risk-to-reward ratio management                                |
//|  - Daily loss & drawdown limits                                   |
//|  - Break-even & trailing stop automation                          |
//+------------------------------------------------------------------+
#ifndef RISKMANAGER_MQH
#define RISKMANAGER_MQH

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//+------------------------------------------------------------------+
//| Class: CRiskManager                                               |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   CTrade            m_trade;
   CPositionInfo     m_position;

   // Settings (set via Init)
   double            m_riskPercent;
   double            m_rrRatio;
   int               m_maxOpenTrades;
   double            m_maxDailyLoss;
   double            m_maxDrawdown;
   bool              m_useTrailingStop;
   int               m_trailingStart;
   int               m_trailingStep;
   bool              m_useBreakEven;
   int               m_breakEvenProfit;
   int               m_breakEvenPlus;

   // Internal state
   double            m_sessionStartBalance;
   double            m_dayStartBalance;
   datetime          m_lastDayReset;
   int               m_sessionWins;
   int               m_sessionLosses;
   bool              m_tradingHalted;
   ulong             m_magicNumber;

public:
   //--- Constructor / Destructor
   CRiskManager() :
      m_riskPercent(2.0),
      m_rrRatio(2.0),
      m_maxOpenTrades(1),
      m_maxDailyLoss(6.0),
      m_maxDrawdown(20.0),
      m_useTrailingStop(true),
      m_trailingStart(30),
      m_trailingStep(10),
      m_useBreakEven(true),
      m_breakEvenProfit(20),
      m_breakEvenPlus(5),
      m_sessionStartBalance(0),
      m_dayStartBalance(0),
      m_lastDayReset(0),
      m_sessionWins(0),
      m_sessionLosses(0),
      m_tradingHalted(false),
      m_magicNumber(0)
   {}

   ~CRiskManager() {}

   //--- Initialise with external parameters
   void Init(double riskPct, double rrRatio, int maxTrades,
             double maxDailyLoss, double maxDrawdown,
             bool useTS, int tsStart, int tsStep,
             bool useBE, int beProfit, int bePlus,
             ulong magicNumber)
   {
      m_riskPercent     = riskPct;
      m_rrRatio         = rrRatio;
      m_maxOpenTrades   = maxTrades;
      m_maxDailyLoss    = maxDailyLoss;
      m_maxDrawdown     = maxDrawdown;
      m_useTrailingStop = useTS;
      m_trailingStart   = tsStart;
      m_trailingStep    = tsStep;
      m_useBreakEven    = useBE;
      m_breakEvenProfit = beProfit;
      m_breakEvenPlus   = bePlus;
      m_magicNumber     = magicNumber;

      m_trade.SetExpertMagicNumber(magicNumber);
      m_trade.SetDeviationInPoints(10);
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);

      m_sessionStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      m_dayStartBalance     = AccountInfoDouble(ACCOUNT_BALANCE);
      m_lastDayReset        = iTime(_Symbol, PERIOD_D1, 0);

      Print("[RiskManager] Initialized. Risk=", m_riskPercent, "% RR=1:", m_rrRatio,
            " MaxTrades=", m_maxOpenTrades);
   }

   //--- Reset daily counters at the start of a new day
   void CheckDayReset()
   {
      datetime currentDay = iTime(_Symbol, PERIOD_D1, 0);
      if(currentDay > m_lastDayReset)
      {
         m_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
         m_lastDayReset    = currentDay;
         m_tradingHalted   = false;
         Print("[RiskManager] New day – daily counters reset. Balance=", m_dayStartBalance);
      }
   }

   //--- Calculate lot size from risk % and stop-loss distance
   //    slPips: stop-loss distance in pips
   double CalcLotSize(double slPips)
   {
      if(slPips <= 0)
      {
         Print("[RiskManager] CalcLotSize: invalid slPips=", slPips);
         return 0;
      }

      double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmt  = balance * (m_riskPercent / 100.0);
      double pipValue = GetPipValue();

      if(pipValue <= 0)
      {
         Print("[RiskManager] CalcLotSize: pipValue<=0, symbol=", _Symbol);
         return 0;
      }

      double lotSize = riskAmt / (slPips * pipValue);

      // Normalise to broker step
      double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double lotMin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double lotMax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

      lotSize = MathFloor(lotSize / lotStep) * lotStep;
      lotSize = MathMax(lotMin, MathMin(lotMax, lotSize));

      Print("[RiskManager] LotSize=", lotSize, " (Balance=", balance,
            " Risk=", riskAmt, " SL=", slPips, "pips PipVal=", pipValue, ")");
      return lotSize;
   }

   //--- Calculate Take Profit price from entry and SL distance
   double CalcTakeProfit(double entryPrice, double slPrice, ENUM_ORDER_TYPE orderType)
   {
      double slDist = MathAbs(entryPrice - slPrice);
      double tpDist = slDist * m_rrRatio;
      double tp     = (orderType == ORDER_TYPE_BUY)
                      ? entryPrice + tpDist
                      : entryPrice - tpDist;
      return NormalizeDouble(tp, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
   }

   //--- Check whether we can open a new trade
   bool CanOpenTrade()
   {
      CheckDayReset();

      if(m_tradingHalted)
      {
         Print("[RiskManager] Trading halted (daily/drawdown limit reached).");
         return false;
      }

      // Count open positions with our magic
      if(CountOpenPositions() >= m_maxOpenTrades)
      {
         Print("[RiskManager] Max open trades (", m_maxOpenTrades, ") already reached.");
         return false;
      }

      // Daily loss check
      double balance     = AccountInfoDouble(ACCOUNT_BALANCE);
      double dailyLossPct = (m_dayStartBalance - balance) / m_dayStartBalance * 100.0;
      if(dailyLossPct >= m_maxDailyLoss)
      {
         Print("[RiskManager] Daily loss limit hit: ", dailyLossPct, "% >= ", m_maxDailyLoss, "%. Halting.");
         m_tradingHalted = true;
         return false;
      }

      // Max drawdown check
      double equity       = AccountInfoDouble(ACCOUNT_EQUITY);
      double drawdownPct  = (m_sessionStartBalance - equity) / m_sessionStartBalance * 100.0;
      if(drawdownPct >= m_maxDrawdown)
      {
         Print("[RiskManager] Max drawdown hit: ", drawdownPct, "% >= ", m_maxDrawdown, "%. Halting.");
         m_tradingHalted = true;
         Alert("[RiskManager] MAX DRAWDOWN REACHED! Trading halted.");
         return false;
      }

      return true;
   }

   //--- Manage open trades: break-even & trailing stop
   void ManageOpenTrades()
   {
      double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      int    digits  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      double pipSize = GetPipSize();

      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!m_position.SelectByIndex(i)) continue;
         if(m_position.Magic() != m_magicNumber) continue;
         if(m_position.Symbol() != _Symbol) continue;

         double openPrice = m_position.PriceOpen();
         double currentSL = m_position.StopLoss();
         double currentTP = m_position.TakeProfit();
         double bidAsk    = (m_position.PositionType() == POSITION_TYPE_BUY)
                            ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                            : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double profitPips = (m_position.PositionType() == POSITION_TYPE_BUY)
                             ? (bidAsk - openPrice) / pipSize
                             : (openPrice - bidAsk) / pipSize;

         double newSL = currentSL;
         bool   modifyNeeded = false;

         // --- Break Even ---
         if(m_useBreakEven && profitPips >= m_breakEvenProfit)
         {
            double beSL = (m_position.PositionType() == POSITION_TYPE_BUY)
                          ? openPrice + m_breakEvenPlus * pipSize
                          : openPrice - m_breakEvenPlus * pipSize;
            beSL = NormalizeDouble(beSL, digits);

            if(m_position.PositionType() == POSITION_TYPE_BUY && (currentSL < beSL || currentSL == 0))
            {
               newSL = beSL;
               modifyNeeded = true;
               Print("[RiskManager] BE: Moving SL to ", newSL, " for ticket ", m_position.Ticket());
            }
            else if(m_position.PositionType() == POSITION_TYPE_SELL && (currentSL > beSL || currentSL == 0))
            {
               newSL = beSL;
               modifyNeeded = true;
               Print("[RiskManager] BE: Moving SL to ", newSL, " for ticket ", m_position.Ticket());
            }
         }

         // --- Trailing Stop ---
         if(m_useTrailingStop && profitPips >= m_trailingStart)
         {
            double trailSL;
            if(m_position.PositionType() == POSITION_TYPE_BUY)
            {
               trailSL = NormalizeDouble(bidAsk - m_trailingStep * pipSize, digits);
               if(trailSL > newSL)
               {
                  newSL = trailSL;
                  modifyNeeded = true;
               }
            }
            else
            {
               trailSL = NormalizeDouble(bidAsk + m_trailingStep * pipSize, digits);
               if(newSL == 0 || trailSL < newSL)
               {
                  newSL = trailSL;
                  modifyNeeded = true;
               }
            }
         }

         if(modifyNeeded && newSL != currentSL)
         {
            if(!m_trade.PositionModify(m_position.Ticket(), newSL, currentTP))
               Print("[RiskManager] PositionModify failed: ", m_trade.ResultRetcodeDescription());
         }
      }
   }

   //--- Open a BUY trade
   bool OpenBuy(double slPrice, double tpPrice, double lotSize, string comment)
   {
      if(!CanOpenTrade()) return false;
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      bool result = m_trade.Buy(lotSize, _Symbol, ask, slPrice, tpPrice, comment);
      if(result)
         Print("[RiskManager] BUY opened. Ask=", ask, " SL=", slPrice, " TP=", tpPrice, " Lots=", lotSize);
      else
         Print("[RiskManager] BUY failed: ", m_trade.ResultRetcodeDescription());
      return result;
   }

   //--- Open a SELL trade
   bool OpenSell(double slPrice, double tpPrice, double lotSize, string comment)
   {
      if(!CanOpenTrade()) return false;
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      bool result = m_trade.Sell(lotSize, _Symbol, bid, slPrice, tpPrice, comment);
      if(result)
         Print("[RiskManager] SELL opened. Bid=", bid, " SL=", slPrice, " TP=", tpPrice, " Lots=", lotSize);
      else
         Print("[RiskManager] SELL failed: ", m_trade.ResultRetcodeDescription());
      return result;
   }

   //--- Getters for dashboard
   double GetDailyPL()
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      return balance - m_dayStartBalance;
   }

   double GetDailyPLPercent()
   {
      if(m_dayStartBalance <= 0) return 0;
      return GetDailyPL() / m_dayStartBalance * 100.0;
   }

   double GetDrawdownPercent()
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(m_sessionStartBalance <= 0) return 0;
      return (m_sessionStartBalance - equity) / m_sessionStartBalance * 100.0;
   }

   bool IsTradingHalted() { return m_tradingHalted; }

   int CountOpenPositions()
   {
      int count = 0;
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(m_position.SelectByIndex(i))
         {
            if(m_position.Magic() == m_magicNumber &&
               m_position.Symbol() == _Symbol)
               count++;
         }
      }
      return count;
   }

   void RecordWin()  { m_sessionWins++;   }
   void RecordLoss() { m_sessionLosses++; }

   double GetWinRate()
   {
      int total = m_sessionWins + m_sessionLosses;
      if(total <= 0) return 0;
      return (double)m_sessionWins / total * 100.0;
   }

   int GetSessionWins()   { return m_sessionWins;   }
   int GetSessionLosses() { return m_sessionLosses; }

private:
   //--- Return pip value for 1 standard lot in account currency
   double GetPipValue()
   {
      double tickValue  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double pipSize    = GetPipSize();
      if(tickSize <= 0) return 0;
      return tickValue * (pipSize / tickSize);
   }

   //--- Return the size of one pip for the current symbol
   double GetPipSize()
   {
      double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      return (digits == 3 || digits == 5) ? point * 10.0 : point;
   }
};

#endif // RISKMANAGER_MQH
