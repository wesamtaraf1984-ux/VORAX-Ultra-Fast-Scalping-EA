//+------------------------------------------------------------------+
//|                                          VORAX_PositionManager.mqh |
//|                                   VORAX™ Ultra-Fast Scalping EA   |
//|                           Copyright 2024 - Professional Edition   |
//+------------------------------------------------------------------+

#ifndef VORAX_POSITION_MANAGER_H
#define VORAX_POSITION_MANAGER_H

#include "VORAX_Defines.mqh"
#include "VORAX_Utils.mqh"
#include "VORAX_SymbolConfig.mqh"
#include "VORAX_Execution.mqh"
#include "VORAX_Volatility.mqh"

//--- Position Manager Class
class CPositionManager
{
private:
    string symbol;
    SSymbolConfig *config;
    CTradeExecutor *executor;
    CVolatilityAnalyzer *volatility;
    CLogger *logger;
    int digits;
    double point;
    
    struct STrailingState
    {
        ulong ticket;
        double entryPrice;
        double currentSL;
        double currentTP;
        double maxProfit;
        int stage;  // 1=Protection, 2=BreakEven, 3=LockProfit, 4=Trail
        datetime lastModified;
    };
    
    STrailingState trailingStates[];

public:
    CPositionManager(string sym, SSymbolConfig *cfg, CTradeExecutor *exec,
                    CVolatilityAnalyzer *vol, CLogger *log)
        : symbol(sym), config(cfg), executor(exec), volatility(vol), logger(log)
    {
        point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        
        if (logger) logger->Debug("PositionManager", "Position Manager initialized for " + symbol);
    }
    
    // ===== UPDATE ALL POSITIONS =====
    void UpdateAllPositions()
    {
        for (int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if (ticket == 0) continue;
            
            if (PositionSelectByTicket(ticket)) {
                string posSymbol = PositionGetString(POSITION_SYMBOL);
                int posMagic = (int)PositionGetInteger(POSITION_MAGIC);
                
                // Only manage positions from this EA and this symbol
                if (posSymbol == symbol && posMagic == config->magicNumber) {
                    UpdateTrailingStop(ticket);
                }
            }
        }
    }
    
    // ===== UPDATE TRAILING STOP FOR A POSITION =====
    void UpdateTrailingStop(ulong ticket)
    {
        if (!PositionSelectByTicket(ticket)) return;
        
        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentTP = PositionGetDouble(POSITION_TP);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        double profitInPoints = 0;
        double newSL = currentSL;
        
        if (type == POSITION_TYPE_BUY) {
            profitInPoints = (currentPrice - entryPrice) / point;
            
            // ===== STAGE 1: PROTECTION (Entry to +10 points) =====
            if (profitInPoints > 0 && profitInPoints <= 10) {
                // Try to lock entry or close
                newSL = entryPrice + (1 * point);
            }
            // ===== STAGE 2: BREAK-EVEN (10 to 25 points) =====
            else if (profitInPoints > 10 && profitInPoints <= 25) {
                newSL = entryPrice + (2 * point);
            }
            // ===== STAGE 3: LOCK PROFIT (25 to 50 points) =====
            else if (profitInPoints > 25 && profitInPoints <= 50) {
                double lockAmount = (profitInPoints / 2.0) * point;
                newSL = entryPrice + lockAmount;
            }
            // ===== STAGE 4: TRAILING (50+ points) =====
            else if (profitInPoints > 50) {
                double atr = volatility->GetATR();
                double trailDistance = (atr * 0.5) + (2 * point);
                newSL = currentPrice - trailDistance;
                
                // Don't trail down
                if (newSL < currentSL) {
                    newSL = currentSL;
                }
            }
            
        } else if (type == POSITION_TYPE_SELL) {
            profitInPoints = (entryPrice - currentPrice) / point;
            
            // ===== STAGE 1: PROTECTION (Entry to +10 points) =====
            if (profitInPoints > 0 && profitInPoints <= 10) {
                newSL = entryPrice - (1 * point);
            }
            // ===== STAGE 2: BREAK-EVEN (10 to 25 points) =====
            else if (profitInPoints > 10 && profitInPoints <= 25) {
                newSL = entryPrice - (2 * point);
            }
            // ===== STAGE 3: LOCK PROFIT (25 to 50 points) =====
            else if (profitInPoints > 25 && profitInPoints <= 50) {
                double lockAmount = (profitInPoints / 2.0) * point;
                newSL = entryPrice - lockAmount;
            }
            // ===== STAGE 4: TRAILING (50+ points) =====
            else if (profitInPoints > 50) {
                double atr = volatility->GetATR();
                double trailDistance = (atr * 0.5) + (2 * point);
                newSL = currentPrice + trailDistance;
                
                // Don't trail down
                if (newSL > currentSL) {
                    newSL = currentSL;
                }
            }
        }
        
        // Only modify if SL actually improved
        if (newSL != currentSL) {
            executor->ModifyPosition(ticket, newSL, currentTP);
        }
    }
    
    // ===== CHECK FOR EARLY EXIT CONDITIONS =====
    bool ShouldClosePosition(ulong ticket)
    {
        if (!PositionSelectByTicket(ticket)) return false;
        
        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
        
        int secondsOpen = (int)(TimeCurrent() - openTime);
        
        // Close if trade has been open too long (max 5 minutes for scalping)
        if (secondsOpen > 300) {
            if (logger) logger->Info("PositionManager", "Closing position due to max duration - Ticket: " + 
                                    IntegerToString((int)ticket));
            return true;
        }
        
        return false;
    }
    
    // ===== GET POSITION INFO =====
    bool GetPositionData(ulong ticket, SPositionData &data)
    {
        if (!PositionSelectByTicket(ticket)) return false;
        
        data.ticket = ticket;
        data.symbol = PositionGetString(POSITION_SYMBOL);
        data.type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        data.volume = PositionGetDouble(POSITION_VOLUME);
        data.openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        data.stopLoss = PositionGetDouble(POSITION_SL);
        data.takeProfit = PositionGetDouble(POSITION_TP);
        data.currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        data.currentProfit = PositionGetDouble(POSITION_PROFIT);
        data.profitPercent = (data.currentProfit / (AccountInfoDouble(ACCOUNT_BALANCE) + 0.01)) * 100.0;
        data.magicNumber = (int)PositionGetInteger(POSITION_MAGIC);
        data.openTime = (datetime)PositionGetInteger(POSITION_TIME);
        
        if (data.type == POSITION_TYPE_BUY) {
            data.slDistance = (data.openPrice - data.stopLoss) / point;
            data.tpDistance = (data.takeProfit - data.openPrice) / point;
        } else {
            data.slDistance = (data.stopLoss - data.openPrice) / point;
            data.tpDistance = (data.openPrice - data.takeProfit) / point;
        }
        
        data.isValid = true;
        return true;
    }
    
    // ===== COUNT OPEN POSITIONS FOR THIS SYMBOL =====
    int GetOpenPositionsCount()
    {
        int count = 0;
        for (int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if (ticket == 0) continue;
            
            if (PositionSelectByTicket(ticket)) {
                string posSymbol = PositionGetString(POSITION_SYMBOL);
                int posMagic = (int)PositionGetInteger(POSITION_MAGIC);
                
                if (posSymbol == symbol && posMagic == config->magicNumber) {
                    count++;
                }
            }
        }
        return count;
    }
    
    // ===== GET FIRST BUY POSITION =====
    ulong GetFirstBuyPosition()
    {
        for (int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if (ticket == 0) continue;
            
            if (PositionSelectByTicket(ticket)) {
                string posSymbol = PositionGetString(POSITION_SYMBOL);
                int posMagic = (int)PositionGetInteger(POSITION_MAGIC);
                ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                
                if (posSymbol == symbol && posMagic == config->magicNumber && posType == POSITION_TYPE_BUY) {
                    return ticket;
                }
            }
        }
        return 0;
    }
    
    // ===== GET FIRST SELL POSITION =====
    ulong GetFirstSellPosition()
    {
        for (int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if (ticket == 0) continue;
            
            if (PositionSelectByTicket(ticket)) {
                string posSymbol = PositionGetString(POSITION_SYMBOL);
                int posMagic = (int)PositionGetInteger(POSITION_MAGIC);
                ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                
                if (posSymbol == symbol && posMagic == config->magicNumber && posType == POSITION_TYPE_SELL) {
                    return ticket;
                }
            }
        }
        return 0;
    }
};

#endif
