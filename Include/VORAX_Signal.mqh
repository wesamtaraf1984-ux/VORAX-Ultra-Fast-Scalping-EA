//+------------------------------------------------------------------+
//|                                                   VORAX_Signal.mqh |
//|                                   VORAX™ Ultra-Fast Scalping EA   |
//|                           Copyright 2024 - Professional Edition   |
//+------------------------------------------------------------------+

#ifndef VORAX_SIGNAL_H
#define VORAX_SIGNAL_H

#include "VORAX_Defines.mqh"
#include "VORAX_Utils.mqh"
#include "VORAX_Pressure.mqh"
#include "VORAX_Momentum.mqh"
#include "VORAX_Volatility.mqh"

//--- Signal Engine Class
class CSignalEngine
{
private:
    string symbol;
    SSymbolConfig *config;
    CPressureAnalyzer *pressureAnalyzer;
    CMomentumAnalyzer *momentumAnalyzer;
    CVolatilityAnalyzer *volatilityAnalyzer;
    CLogger *logger;
    
    STradeSignal lastSignal;
    datetime lastSignalTime;
    double lastEntryPrice;
    int signalBarIndex;

public:
    CSignalEngine(string sym, SSymbolConfig *cfg, CPressureAnalyzer *pres,
                  CMomentumAnalyzer *mom, CVolatilityAnalyzer *vol, CLogger *log)
        : symbol(sym), config(cfg), pressureAnalyzer(pres), momentumAnalyzer(mom),
          volatilityAnalyzer(vol), logger(log), lastSignalTime(0),
          lastEntryPrice(0), signalBarIndex(-1)
    {
        lastSignal.signalType = SIGNAL_NONE;
        if (logger) logger->Debug("Signal", "Signal Engine initialized for " + symbol);
    }
    
    STradeSignal AnalyzeSignal()
    {
        // Initialize signal
        STradeSignal signal;
        signal.signalType = SIGNAL_NONE;
        signal.timestamp = TimeCurrent();
        signal.confidence = 0;
        signal.reason = "";
        
        // ===== PRE-FILTERS =====
        
        // Check volatility regime
        if (volatilityAnalyzer->IsExtremeVolatility()) {
            signal.reason = "Extreme volatility - SKIP";
            if (logger) logger->Debug("Signal", signal.reason);
            return signal;
        }
        
        if (volatilityAnalyzer->IsLowVolatility()) {
            signal.reason = "Low volatility - weak signals expected";
            if (logger) logger->Debug("Signal", signal.reason);
            return signal;
        }
        
        // Get current data
        SPressureData pressure = pressureAnalyzer->GetData();
        SMomentumData momentum = momentumAnalyzer->GetData();
        SVolatilityData volatility = volatilityAnalyzer->GetData();
        
        double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
        double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
        
        // ===== BUY SIGNAL ANALYSIS =====
        if (momentum.isUptrend && pressure.buyPressure >= config->minimumPressure) {
            
            if ((pressure.buyPressure - pressure.sellPressure) >= config->minimumPressureDifference) {
                
                if (momentum.strength >= config->minimumMomentumStrength) {
                    
                    if (pressure.confirmed) {
                        // Calculate entry price (use ask for buy)
                        double entryPrice = ask;
                        
                        // Calculate SL and TP
                        double slDistance = config->minSLPoints + (volatility.atr / SymbolInfoDouble(symbol, SYMBOL_POINT) * config->slVolatilityMultiplier);
                        slDistance = CMathUtils::Normalize(slDistance, config->minSLPoints, config->maxSLPoints);
                        
                        double slPrice = entryPrice - (slDistance * SymbolInfoDouble(symbol, SYMBOL_POINT));
                        double tpPrice = entryPrice + (slDistance * config->tpRiskRewardRatio * SymbolInfoDouble(symbol, SYMBOL_POINT));
                        
                        signal.signalType = SIGNAL_BUY;
                        signal.entryPrice = entryPrice;
                        signal.stopLoss = slPrice;
                        signal.takeProfit = tpPrice;
                        signal.pressure = pressure.buyPressure;
                        signal.momentum = momentum.value;
                        signal.confidence = (pressure.bullishRatio * 50.0) + (momentum.strength * 0.5);
                        signal.reason = "BUY: Bullish pressure + Strong momentum";
                        
                        if (logger) logger->Info("Signal", signal.reason + " | Pressure: " + 
                                               DoubleToString(pressure.buyPressure, 1) + " | Momentum: " +
                                               DoubleToString(momentum.value, 1) + " | Confidence: " +
                                               DoubleToString(signal.confidence, 1));
                        
                        return signal;
                    }
                }
            }
        }
        
        // ===== SELL SIGNAL ANALYSIS =====
        if (momentum.isDowntrend && pressure.sellPressure >= config->minimumPressure) {
            
            if ((pressure.sellPressure - pressure.buyPressure) >= config->minimumPressureDifference) {
                
                if (momentum.strength >= config->minimumMomentumStrength) {
                    
                    if (pressure.confirmed) {
                        // Calculate entry price (use bid for sell)
                        double entryPrice = bid;
                        
                        // Calculate SL and TP
                        double slDistance = config->minSLPoints + (volatility.atr / SymbolInfoDouble(symbol, SYMBOL_POINT) * config->slVolatilityMultiplier);
                        slDistance = CMathUtils::Normalize(slDistance, config->minSLPoints, config->maxSLPoints);
                        
                        double slPrice = entryPrice + (slDistance * SymbolInfoDouble(symbol, SYMBOL_POINT));
                        double tpPrice = entryPrice - (slDistance * config->tpRiskRewardRatio * SymbolInfoDouble(symbol, SYMBOL_POINT));
                        
                        signal.signalType = SIGNAL_SELL;
                        signal.entryPrice = entryPrice;
                        signal.stopLoss = slPrice;
                        signal.takeProfit = tpPrice;
                        signal.pressure = pressure.sellPressure;
                        signal.momentum = momentum.value;
                        signal.confidence = (pressure.bearishRatio * 50.0) + (momentum.strength * 0.5);
                        signal.reason = "SELL: Bearish pressure + Strong momentum";
                        
                        if (logger) logger->Info("Signal", signal.reason + " | Pressure: " + 
                                               DoubleToString(pressure.sellPressure, 1) + " | Momentum: " +
                                               DoubleToString(momentum.value, 1) + " | Confidence: " +
                                               DoubleToString(signal.confidence, 1));
                        
                        return signal;
                    }
                }
            }
        }
        
        signal.reason = "No valid signal";
        return signal;
    }
    
    bool IsSignalNew(STradeSignal &signal)
    {
        if (signal.signalType == SIGNAL_NONE) return false;
        if (lastSignalTime == signal.timestamp) return false;
        
        lastSignalTime = signal.timestamp;
        lastSignal = signal;
        
        return true;
    }
    
    bool IsSignalConfirmed(STradeSignal &signal)
    {
        if (signal.signalType == SIGNAL_NONE) return false;
        if (signal.confidence < 50.0) return false;
        
        return true;
    }
    
    STradeSignal GetLastSignal() { return lastSignal; }
};

#endif
