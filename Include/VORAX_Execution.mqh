//+------------------------------------------------------------------+
//|                                               VORAX_Execution.mqh |
//|                                   VORAX™ Ultra-Fast Scalping EA   |
//|                           Copyright 2024 - Professional Edition   |
//+------------------------------------------------------------------+

#ifndef VORAX_EXECUTION_H
#define VORAX_EXECUTION_H

#include "VORAX_Defines.mqh"
#include "VORAX_Utils.mqh"
#include "VORAX_SymbolConfig.mqh"
#include "VORAX_Risk.mqh"

//--- Trade Execution Class
class CTradeExecutor
{
private:
    string symbol;
    SSymbolConfig *config;
    CRiskManager *riskManager;
    CLogger *logger;
    int digits;
    double point;
    int stopsLevel;
    int freezeLevel;
    
    CTrade trade;

public:
    CTradeExecutor(string sym, SSymbolConfig *cfg, CRiskManager *risk, CLogger *log)
        : symbol(sym), config(cfg), riskManager(risk), logger(log)
    {
        point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        stopsLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
        freezeLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
        
        trade.SetExpertMagicNumber(config->magicNumber);
        trade.SetDeviationInPoints(50);
        trade.LogLevel(logger->debugMode ? 2 : 0);
        
        if (logger) logger->Debug("Execution", "Trade Executor initialized for " + symbol);
    }
    
    // ===== VALIDATE SPREAD =====
    bool IsSpreadAcceptable()
    {
        double currentSpread = (SymbolInfoDouble(symbol, SYMBOL_ASK) - SymbolInfoDouble(symbol, SYMBOL_BID)) / point;
        
        if (currentSpread > config->maxSpread) {
            if (logger) logger->Warning("Execution", "Spread too high: " + DoubleToString(currentSpread, 1) + 
                                       " > Max: " + DoubleToString(config->maxSpread, 1));
            return false;
        }
        
        return true;
    }
    
    // ===== VALIDATE STOPS =====
    bool IsStopsValid(double entry, double &stopLoss, double &takeProfit, ENUM_POSITION_TYPE type)
    {
        // Normalize prices
        entry = NormalizeDouble(entry, digits);
        stopLoss = NormalizeDouble(stopLoss, digits);
        takeProfit = NormalizeDouble(takeProfit, digits);
        
        // Calculate minimum distances
        int minStopsDistance = MathMax(stopsLevel, 1);
        double minStopsPrice = minStopsDistance * point;
        
        if (type == POSITION_TYPE_BUY) {
            // SL must be below entry
            if (stopLoss >= entry) {
                if (logger) logger->Error("Execution", "Invalid BUY SL: SL >= Entry");
                return false;
            }
            
            // SL must be far enough
            if ((entry - stopLoss) < minStopsPrice) {
                stopLoss = entry - minStopsPrice;
                if (logger) logger->Warning("Execution", "SL adjusted to minimum distance");
            }
            
            // TP must be above entry
            if (takeProfit <= entry) {
                if (logger) logger->Error("Execution", "Invalid BUY TP: TP <= Entry");
                return false;
            }
            
            stopLoss = NormalizeDouble(stopLoss, digits);
            takeProfit = NormalizeDouble(takeProfit, digits);
            
        } else if (type == POSITION_TYPE_SELL) {
            // SL must be above entry
            if (stopLoss <= entry) {
                if (logger) logger->Error("Execution", "Invalid SELL SL: SL <= Entry");
                return false;
            }
            
            // SL must be far enough
            if ((stopLoss - entry) < minStopsPrice) {
                stopLoss = entry + minStopsPrice;
                if (logger) logger->Warning("Execution", "SL adjusted to minimum distance");
            }
            
            // TP must be below entry
            if (takeProfit >= entry) {
                if (logger) logger->Error("Execution", "Invalid SELL TP: TP >= Entry");
                return false;
            }
            
            stopLoss = NormalizeDouble(stopLoss, digits);
            takeProfit = NormalizeDouble(takeProfit, digits);
        }
        
        return true;
    }
    
    // ===== SEND BUY ORDER =====
    ulong SendBuyOrder(double entryPrice, double stopLoss, double takeProfit, double lot, string comment = "")
    {
        // Pre-execution checks
        if (!IsSpreadAcceptable()) return 0;
        
        ENUM_POSITION_TYPE type = POSITION_TYPE_BUY;
        if (!IsStopsValid(entryPrice, stopLoss, takeProfit, type)) return 0;
        
        if (!riskManager->IsTradeAllowed()) {
            if (logger) logger->Warning("Execution", "Trade not allowed by risk manager");
            return 0;
        }
        
        // Execute order
        trade.SetDeviationInPoints(50);
        
        if (trade.Buy(lot, symbol, entryPrice, stopLoss, takeProfit, 
                      comment.empty() ? ("VORAX_BUY_" + symbol) : comment)) {
            ulong ticket = trade.ResultOrder();
            
            if (logger) logger->Info("Execution", "BUY order sent - Ticket: " + IntegerToString((int)ticket) +
                                   " | Entry: " + DoubleToString(entryPrice, digits) +
                                   " | SL: " + DoubleToString(stopLoss, digits) +
                                   " | TP: " + DoubleToString(takeProfit, digits) +
                                   " | Lot: " + DoubleToString(lot, 2));
            
            return ticket;
        } else {
            uint errorCode = trade.ResultRetcode();
            if (logger) logger->Error("Execution", "BUY order failed - Error: " + IntegerToString(errorCode) +
                                     " | " + trade.ResultRetcodeDescription());
            return 0;
        }
    }
    
    // ===== SEND SELL ORDER =====
    ulong SendSellOrder(double entryPrice, double stopLoss, double takeProfit, double lot, string comment = "")
    {
        // Pre-execution checks
        if (!IsSpreadAcceptable()) return 0;
        
        ENUM_POSITION_TYPE type = POSITION_TYPE_SELL;
        if (!IsStopsValid(entryPrice, stopLoss, takeProfit, type)) return 0;
        
        if (!riskManager->IsTradeAllowed()) {
            if (logger) logger->Warning("Execution", "Trade not allowed by risk manager");
            return 0;
        }
        
        // Execute order
        trade.SetDeviationInPoints(50);
        
        if (trade.Sell(lot, symbol, entryPrice, stopLoss, takeProfit,
                       comment.empty() ? ("VORAX_SELL_" + symbol) : comment)) {
            ulong ticket = trade.ResultOrder();
            
            if (logger) logger->Info("Execution", "SELL order sent - Ticket: " + IntegerToString((int)ticket) +
                                   " | Entry: " + DoubleToString(entryPrice, digits) +
                                   " | SL: " + DoubleToString(stopLoss, digits) +
                                   " | TP: " + DoubleToString(takeProfit, digits) +
                                   " | Lot: " + DoubleToString(lot, 2));
            
            return ticket;
        } else {
            uint errorCode = trade.ResultRetcode();
            if (logger) logger->Error("Execution", "SELL order failed - Error: " + IntegerToString(errorCode) +
                                     " | " + trade.ResultRetcodeDescription());
            return 0;
        }
    }
    
    // ===== EXECUTE SIGNAL =====
    ulong ExecuteSignal(STradeSignal &signal, double lot)
    {
        if (signal.signalType == SIGNAL_NONE) return 0;
        
        if (signal.signalType == SIGNAL_BUY) {
            return SendBuyOrder(signal.entryPrice, signal.stopLoss, signal.takeProfit, lot, "VORAX_BUY");
        } else if (signal.signalType == SIGNAL_SELL) {
            return SendSellOrder(signal.entryPrice, signal.stopLoss, signal.takeProfit, lot, "VORAX_SELL");
        }
        
        return 0;
    }
    
    // ===== MODIFY POSITION =====
    bool ModifyPosition(ulong ticket, double newSL, double newTP)
    {
        newSL = NormalizeDouble(newSL, digits);
        newTP = NormalizeDouble(newTP, digits);
        
        if (!PositionSelectByTicket(ticket)) {
            if (logger) logger->Error("Execution", "Position not found: " + IntegerToString((int)ticket));
            return false;
        }
        
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentTP = PositionGetDouble(POSITION_TP);
        
        // Only modify if values actually changed
        if (currentSL == newSL && currentTP == newTP) return true;
        
        if (trade.PositionModify(ticket, newSL, newTP)) {
            if (logger) logger->Debug("Execution", "Position modified - Ticket: " + IntegerToString((int)ticket) +
                                     " | New SL: " + DoubleToString(newSL, digits) +
                                     " | New TP: " + DoubleToString(newTP, digits));
            return true;
        } else {
            if (logger) logger->Error("Execution", "Position modification failed - Ticket: " + 
                                     IntegerToString((int)ticket) + " | Error: " + 
                                     trade.ResultRetcodeDescription());
            return false;
        }
    }
    
    // ===== CLOSE POSITION =====
    bool ClosePosition(ulong ticket, double closePrice, string reason = "")
    {
        if (!PositionSelectByTicket(ticket)) {
            if (logger) logger->Error("Execution", "Position not found: " + IntegerToString((int)ticket));
            return false;
        }
        
        double lot = PositionGetDouble(POSITION_VOLUME);
        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        
        if (trade.Close(ticket)) {
            if (logger) logger->Info("Execution", "Position closed - Ticket: " + IntegerToString((int)ticket) +
                                   " | Reason: " + (reason.empty() ? "Manual" : reason));
            return true;
        } else {
            if (logger) logger->Error("Execution", "Close failed - Ticket: " + IntegerToString((int)ticket) +
                                     " | Error: " + trade.ResultRetcodeDescription());
            return false;
        }
    }
};

#endif
