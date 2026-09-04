//+------------------------------------------------------------------+
//|                                            VORAX_Reinforcement.mqh |
//|                                   VORAX™ Ultra-Fast Scalping EA   |
//|                           Copyright 2024 - Professional Edition   |
//+------------------------------------------------------------------+

#ifndef VORAX_REINFORCEMENT_H
#define VORAX_REINFORCEMENT_H

#include "VORAX_Defines.mqh"
#include "VORAX_Utils.mqh"
#include "VORAX_SymbolConfig.mqh"
#include "VORAX_Signal.mqh"
#include "VORAX_Execution.mqh"
#include "VORAX_PositionManager.mqh"

//--- Reinforcement (Add-On) Manager Class
class CReinforcementManager
{
private:
    string symbol;
    SSymbolConfig *config;
    CSignalEngine *signalEngine;
    CTradeExecutor *executor;
    CPositionManager *positionManager;
    CRiskManager *riskManager;
    CLogger *logger;
    
    struct SReinforcementState
    {
        ulong originalTicket;
        int addOnCount;
        datetime lastAddOnTime;
        double originalEntryPrice;
        double highestProfit;
    };
    
    SReinforcementState reinforcementState;
    int digits;
    double point;

public:
    CReinforcementManager(string sym, SSymbolConfig *cfg, CSignalEngine *sig,
                         CTradeExecutor *exec, CPositionManager *posMgr,
                         CRiskManager *risk, CLogger *log)
        : symbol(sym), config(cfg), signalEngine(sig), executor(exec),
          positionManager(posMgr), riskManager(risk), logger(log)
    {
        point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        
        reinforcementState.originalTicket = 0;
        reinforcementState.addOnCount = 0;
        reinforcementState.lastAddOnTime = 0;
        reinforcementState.originalEntryPrice = 0;
        reinforcementState.highestProfit = 0;
        
        if (logger) logger->Debug("Reinforcement", "Reinforcement Manager initialized");
    }
    
    // ===== CHECK IF REINFORCEMENT IS ALLOWED =====
    bool CanAddReinforcement(ulong originalTicket)
    {
        if (!config->allowReinforcement) return false;
        if (reinforcementState.addOnCount >= config->maxReinforcementTrades) return false;
        
        // Check time between add-ons
        int secondsSinceLast = CTimeUtils::SecondsSinceTime(TimeCurrent(), reinforcementState.lastAddOnTime);
        if (secondsSinceLast < config->minTimeBetweenReinforcement) return false;
        
        // Original position must exist and be profitable
        if (!PositionSelectByTicket(originalTicket)) return false;
        
        double profit = PositionGetDouble(POSITION_PROFIT);
        if (profit <= 0) {
            if (logger) logger->Debug("Reinforcement", "Original position not profitable - Add-on rejected");
            return false;
        }
        
        // Check risk limits
        if (!riskManager->IsTradeAllowed()) return false;
        
        return true;
    }
    
    // ===== EXECUTE REINFORCEMENT ADD-ON =====
    ulong ExecuteReinforcement(ulong originalTicket, STradeSignal &signal)
    {
        if (!CanAddReinforcement(originalTicket)) return 0;
        
        if (!PositionSelectByTicket(originalTicket)) return 0;
        
        ENUM_POSITION_TYPE originalType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double originalEntryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double originalProfit = PositionGetDouble(POSITION_PROFIT);
        
        // Reinforcement signal must match original direction
        if (originalType == POSITION_TYPE_BUY && signal.signalType != SIGNAL_BUY) return 0;
        if (originalType == POSITION_TYPE_SELL && signal.signalType != SIGNAL_SELL) return 0;
        
        // Calculate add-on lot (same as original)
        double originalVolume = PositionGetDouble(POSITION_VOLUME);
        double addOnLot = originalVolume;
        
        // Risk check: total risk must stay within limits
        double totalRisk = (addOnLot + originalVolume) * MathAbs(signal.entryPrice - signal.stopLoss);
        double maxRisk = riskManager->GetBalance() * (config->maxRiskPerTrade / 100.0) * 2.0;
        
        if (totalRisk > maxRisk) {
            if (logger) logger->Warning("Reinforcement", "Total risk too high for add-on");
            return 0;
        }
        
        // Execute add-on
        ulong addOnTicket = 0;
        
        if (originalType == POSITION_TYPE_BUY) {
            addOnTicket = executor->SendBuyOrder(signal.entryPrice, signal.stopLoss,
                                                signal.takeProfit, addOnLot, "VORAX_ADDON_BUY");
        } else {
            addOnTicket = executor->SendSellOrder(signal.entryPrice, signal.stopLoss,
                                                 signal.takeProfit, addOnLot, "VORAX_ADDON_SELL");
        }
        
        if (addOnTicket > 0) {
            reinforcementState.originalTicket = originalTicket;
            reinforcementState.addOnCount++;
            reinforcementState.lastAddOnTime = TimeCurrent();
            reinforcementState.originalEntryPrice = originalEntryPrice;
            
            if (logger) logger->Info("Reinforcement", "Add-on position opened - Ticket: " +
                                   IntegerToString((int)addOnTicket) + " | Count: " +
                                   IntegerToString(reinforcementState.addOnCount));
            
            return addOnTicket;
        }
        
        return 0;
    }
    
    // ===== RESET REINFORCEMENT STATE =====
    void ResetState()
    {
        reinforcementState.originalTicket = 0;
        reinforcementState.addOnCount = 0;
        reinforcementState.lastAddOnTime = 0;
        reinforcementState.originalEntryPrice = 0;
        reinforcementState.highestProfit = 0;
    }
    
    int GetAddOnCount() { return reinforcementState.addOnCount; }
};

#endif
