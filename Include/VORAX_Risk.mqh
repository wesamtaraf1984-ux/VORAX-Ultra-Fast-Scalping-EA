//+------------------------------------------------------------------+
//|                                                    VORAX_Risk.mqh |
//|                                   VORAX™ Ultra-Fast Scalping EA   |
//|                           Copyright 2024 - Professional Edition   |
//+------------------------------------------------------------------+

#ifndef VORAX_RISK_H
#define VORAX_RISK_H

#include "VORAX_Defines.mqh"
#include "VORAX_Utils.mqh"
#include "VORAX_SymbolConfig.mqh"

//--- Risk Manager Class
class CRiskManager
{
private:
    string symbol;
    double balance;
    double equity;
    double point;
    double tickValue;
    double contractSize;
    double minLot;
    double maxLot;
    double lotStep;
    SSymbolConfig *config;
    CLogger *logger;
    
    SAccountStats accountStats;
    datetime lastTradeTime;
    datetime dailyResetTime;
    double dailyProfitLoss;
    int dailyTradeCount;
    int consecutiveLosses;

public:
    CRiskManager(string sym, SSymbolConfig *cfg, CLogger *log)
        : symbol(sym), config(cfg), logger(log), 
          point(0), tickValue(0), contractSize(0),
          minLot(0), maxLot(0), lotStep(0),
          lastTradeTime(0), dailyResetTime(0),
          dailyProfitLoss(0), dailyTradeCount(0), consecutiveLosses(0)
    {
        UpdateSymbolProperties();
        UpdateAccountStats();
        dailyResetTime = TimeCurrent();
        
        if (logger) logger->Debug("Risk", "Risk Manager initialized for " + symbol);
    }
    
    void UpdateSymbolProperties()
    {
        point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
        minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
        lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    }
    
    void UpdateAccountStats()
    {
        accountStats.balance = AccountInfoDouble(ACCOUNT_BALANCE);
        accountStats.equity = AccountInfoDouble(ACCOUNT_EQUITY);
        accountStats.freeMargin = AccountInfoDouble(ACCOUNT_FREEMARGIN);
        accountStats.usedMargin = AccountInfoDouble(ACCOUNT_MARGIN);
        accountStats.totalTrades = HistoryDealsTotal();
        accountStats.openPositions = PositionsTotal();
    }
    
    void UpdateDailyStats()
    {
        // Reset if new day
        datetime currentDate = TimeCurrent();
        if (TimeDay(currentDate) != TimeDay(dailyResetTime)) {
            dailyResetTime = currentDate;
            dailyProfitLoss = 0;
            dailyTradeCount = 0;
            consecutiveLosses = 0;
        }
        
        UpdateAccountStats();
    }
    
    // ===== LOT SIZE CALCULATION =====
    double CalculateLotSize(double stopLossPoints)
    {
        if (stopLossPoints <= 0 || point <= 0) return minLot;
        
        UpdateAccountStats();
        
        double riskAmount = accountStats.equity * (config->maxRiskPerTrade / 100.0);
        
        // Calculate lot size based on SL distance
        double slDistance = stopLossPoints * point;
        double calculatedLot = 0;
        
        if (tickValue > 0) {
            calculatedLot = (riskAmount / (stopLossPoints * tickValue)) * contractSize;
        } else {
            calculatedLot = riskAmount / (slDistance * 100); // Fallback
        }
        
        // Apply constraints
        calculatedLot = CSymbolUtils::NormalizeLot(calculatedLot, minLot, maxLot, lotStep);
        
        // Additional safety: never exceed 2% account risk
        double maxSafeRiskPercent = 2.0;
        if ((config->maxRiskPerTrade * PositionsTotal()) > maxSafeRiskPercent) {
            calculatedLot = minLot;
        }
        
        return calculatedLot;
    }
    
    // ===== RISK/REWARD VALIDATION =====
    bool IsRiskRewardValid(double entry, double stopLoss, double takeProfit)
    {
        if (entry <= 0 || stopLoss <= 0 || takeProfit <= 0) return false;
        
        double slDistance = MathAbs(entry - stopLoss) / point;
        double tpDistance = MathAbs(takeProfit - entry) / point;
        
        if (slDistance <= 0) return false;
        
        double ratio = tpDistance / slDistance;
        
        return ratio >= config->tpRiskRewardRatio;
    }
    
    // ===== DAILY LOSS LIMIT CHECK =====
    bool IsDailyLossLimitOK()
    {
        UpdateDailyStats();
        
        double dailyLossPercent = (accountStats.balance - accountStats.equity) / accountStats.balance * 100.0;
        
        if (dailyLossPercent >= config->maxDailyLoss) {
            if (logger) logger->Warning("Risk", "Daily loss limit reached: " + 
                                       DoubleToString(dailyLossPercent, 2) + "%");
            return false;
        }
        
        return true;
    }
    
    // ===== DRAWDOWN CHECK =====
    bool IsDrawdownOK()
    {
        UpdateAccountStats();
        
        if (accountStats.balance <= 0) return false;
        
        double drawdownPercent = (accountStats.balance - accountStats.equity) / accountStats.balance * 100.0;
        
        if (drawdownPercent >= config->maxDrawdown) {
            if (logger) logger->Warning("Risk", "Drawdown limit reached: " + 
                                       DoubleToString(drawdownPercent, 2) + "%");
            return false;
        }
        
        return true;
    }
    
    // ===== MAX POSITIONS CHECK =====
    bool IsMaxPositionsReached()
    {
        UpdateAccountStats();
        
        if (accountStats.openPositions >= config->maxPositions) {
            if (logger) logger->Debug("Risk", "Max positions reached: " + 
                                      IntegerToString((int)config->maxPositions));
            return true;
        }
        
        return false;
    }
    
    // ===== DAILY TRADES LIMIT CHECK =====
    bool IsDailyTradeCountOK()
    {
        UpdateDailyStats();
        
        if (dailyTradeCount >= config->maxTradesPerDay) {
            if (logger) logger->Warning("Risk", "Daily trades limit reached");
            return false;
        }
        
        return true;
    }
    
    // ===== HOURLY TRADES LIMIT CHECK =====
    bool IsHourlyTradeCountOK()
    {
        datetime currentTime = TimeCurrent();
        int tradesInLastHour = 0;
        
        for (int i = HistoryDealsTotal() - 1; i >= 0; i--) {
            ulong dealTicket = HistoryDealGetTicket(i);
            if (HistoryDealSelect(dealTicket)) {
                datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
                if (currentTime - dealTime < 3600) { // Last 60 minutes
                    tradesInLastHour++;
                }
            }
        }
        
        if (tradesInLastHour >= config->maxTradesPerHour) {
            if (logger) logger->Debug("Risk", "Hourly trades limit reached");
            return false;
        }
        
        return true;
    }
    
    // ===== MINIMUM TIME BETWEEN TRADES CHECK =====
    bool IsMinTimeBetweenTradesOK()
    {
        int secondsSinceLast = CTimeUtils::SecondsSinceTime(TimeCurrent(), lastTradeTime);
        return (secondsSinceLast >= 10); // Minimum 10 seconds between trades
    }
    
    void RecordTrade(double profitLoss)
    {
        lastTradeTime = TimeCurrent();
        dailyTradeCount++;
        dailyProfitLoss += profitLoss;
        
        if (profitLoss < 0) {
            consecutiveLosses++;
        } else {
            consecutiveLosses = 0;
        }
    }
    
    // ===== CONSECUTIVE LOSSES CHECK =====
    bool IsTooManyConsecutiveLosses()
    {
        return (consecutiveLosses >= 3);
    }
    
    // ===== COMPREHENSIVE PRE-TRADE CHECK =====
    bool IsTradeAllowed()
    {
        if (!IsDrawdownOK()) return false;
        if (!IsDailyLossLimitOK()) return false;
        if (!IsMaxPositionsReached()) {
            if (!IsDailyTradeCountOK()) return false;
            if (!IsHourlyTradeCountOK()) return false;
            if (!IsMinTimeBetweenTradesOK()) return false;
            if (IsTooManyConsecutiveLosses()) {
                if (logger) logger->Warning("Risk", "Too many consecutive losses");
                return false;
            }
            return true;
        }
        return false;
    }
    
    // ===== GETTERS =====
    SAccountStats GetAccountStats() { return accountStats; }
    double GetEquity() { return accountStats.equity; }
    double GetBalance() { return accountStats.balance; }
    double GetDailyProfitLoss() { return dailyProfitLoss; }
    int GetDailyTradeCount() { return dailyTradeCount; }
    int GetConsecutiveLosses() { return consecutiveLosses; }
};

#endif
