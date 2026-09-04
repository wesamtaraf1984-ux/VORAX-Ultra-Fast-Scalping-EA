//+------------------------------------------------------------------+
//|                                          VORAX_SessionManager.mqh |
//|                                   VORAX™ Ultra-Fast Scalping EA   |
//|                           Copyright 2024 - Professional Edition   |
//+------------------------------------------------------------------+

#ifndef VORAX_SESSION_MANAGER_H
#define VORAX_SESSION_MANAGER_H

#include "VORAX_Defines.mqh"
#include "VORAX_Utils.mqh"
#include "VORAX_SymbolConfig.mqh"

//--- Session Manager Class
class CSessionManager
{
private:
    SSymbolConfig *config;
    CLogger *logger;

public:
    CSessionManager(SSymbolConfig *cfg, CLogger *log) : config(cfg), logger(log)
    {
        if (logger) logger->Debug("SessionManager", "Session Manager initialized");
    }
    
    // ===== CHECK IF CURRENT TIME IS WITHIN TRADING SESSION =====
    bool IsWithinTradingSession()
    {
        if (!config->tradeOnSession) return true;
        
        return CTimeUtils::IsWithinSession(TimeCurrent(), config->sessionStart, config->sessionEnd);
    }
    
    bool CanTrade()
    {
        if (!IsWithinTradingSession()) {
            if (logger) logger->Debug("SessionManager", "Outside trading session");
            return false;
        }
        
        // Check if market is open
        if (!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE)) {
            if (logger) logger->Warning("SessionManager", "Market is closed");
            return false;
        }
        
        return true;
    }
    
    string GetSessionInfo()
    {
        return "Session: " + config->sessionStart + "-" + config->sessionEnd +
               " | Status: " + (IsWithinTradingSession() ? "OPEN" : "CLOSED");
    }
};

#endif
