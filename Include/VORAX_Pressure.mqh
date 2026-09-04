//+------------------------------------------------------------------+
//|                                                VORAX_Pressure.mqh |
//|                                   VORAX™ Ultra-Fast Scalping EA   |
//|                           Copyright 2024 - Professional Edition   |
//+------------------------------------------------------------------+

#ifndef VORAX_PRESSURE_H
#define VORAX_PRESSURE_H

#include "VORAX_Defines.mqh"
#include "VORAX_Utils.mqh"
#include "VORAX_SymbolConfig.mqh"

//--- Pressure Calculator Class
class CPressureAnalyzer
{
private:
    string symbol;
    int digits;
    double point;
    SSymbolConfig *config;
    CLogger *logger;
    
    double highArray[];
    double lowArray[];
    double closeArray[];
    double volumeArray[];
    long tickVolumeArray[];
    
    SPressureData currentPressure;
    int consecutiveUpTicks;
    int consecutiveDownTicks;
    double lastClose;

public:
    CPressureAnalyzer(string sym, SSymbolConfig *cfg, CLogger *log)
        : symbol(sym), config(cfg), logger(log), consecutiveUpTicks(0), 
          consecutiveDownTicks(0), lastClose(0)
    {
        point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        
        ArraySetAsSeries(highArray, true);
        ArraySetAsSeries(lowArray, true);
        ArraySetAsSeries(closeArray, true);
        ArraySetAsSeries(volumeArray, true);
        ArraySetAsSeries(tickVolumeArray, true);
        
        if (logger) logger->Debug("Pressure", "Analyzer initialized for " + symbol);
    }
    
    bool Update()
    {
        // Copy price data
        if (CopyHigh(symbol, PERIOD_M1, 0, LOOKBACK_BARS, highArray) <= 0 ||
            CopyLow(symbol, PERIOD_M1, 0, LOOKBACK_BARS, lowArray) <= 0 ||
            CopyClose(symbol, PERIOD_M1, 0, LOOKBACK_BARS, closeArray) <= 0) {
            if (logger) logger->Error("Pressure", "Failed to copy price data");
            return false;
        }
        
        // Copy volume data
        if (CopyTickVolume(symbol, PERIOD_M1, 0, LOOKBACK_BARS, tickVolumeArray) <= 0) {
            if (logger) logger->Warning("Pressure", "Tick volume not available, using close volume");
        }
        
        // Calculate pressure
        CalculatePressure();
        currentPressure.timestamp = TimeCurrent();
        currentPressure.confirmed = (currentPressure.bullishRatio > 0.55 || currentPressure.bearishRatio > 0.55);
        
        return true;
    }
    
    void CalculatePressure()
    {
        if (ArraySize(closeArray) < 5) return;
        
        double bullishScore = 0;
        double bearishScore = 0;
        double totalScore = 0;
        
        // ===== 1. DIRECTIONAL ANALYSIS =====
        // Count up and down candles
        int upCandles = 0, downCandles = 0;
        for (int i = 0; i < 5; i++) {
            if (closeArray[i] > closeArray[i+1]) {
                upCandles++;
            } else if (closeArray[i] < closeArray[i+1]) {
                downCandles++;
            }
        }
        
        // Weight directional analysis
        bullishScore += upCandles * 15.0;
        bearishScore += downCandles * 15.0;
        
        // ===== 2. BODY STRENGTH ANALYSIS =====
        // Analyze current and last 2 candles
        for (int i = 0; i < 3; i++) {
            double open = iOpen(symbol, PERIOD_M1, i);
            double close = closeArray[i];
            double high = highArray[i];
            double low = lowArray[i];
            double range = high - low;
            
            if (range == 0) continue;
            
            double bodyRatio = MathAbs(close - open) / range;
            double bodyStrength = bodyRatio * 100.0;
            
            if (close > open) {
                bullishScore += bodyStrength * 0.8;
            } else if (close < open) {
                bearishScore += bodyStrength * 0.8;
            }
        }
        
        // ===== 3. RANGE EXPANSION =====
        double currentRange = highArray[0] - lowArray[0];
        double avgRange = (highArray[1] - lowArray[1] + highArray[2] - lowArray[2]) / 2.0;
        
        if (currentRange > avgRange * 1.2) {
            // Range expanded
            if (closeArray[0] > closeArray[1]) {
                bullishScore += 10.0;
            } else {
                bearishScore += 10.0;
            }
        }
        
        // ===== 4. TICK DIRECTION ANALYSIS =====
        double tickDirection = GetTickDirection();
        if (tickDirection > 0) {
            bullishScore += tickDirection * 20.0;
        } else if (tickDirection < 0) {
            bearishScore += MathAbs(tickDirection) * 20.0;
        }
        
        // ===== 5. CONSECUTIVE DIRECTIONAL TICKS =====
        bullishScore += consecutiveUpTicks * 5.0;
        bearishScore += consecutiveDownTicks * 5.0;
        
        // ===== 6. VOLUME ANALYSIS =====
        if (ArraySize(tickVolumeArray) > 1) {
            double volumeAccel = (tickVolumeArray[0] - tickVolumeArray[1]) / (tickVolumeArray[1] + 1.0);
            currentPressure.volumeAcceleration = CMathUtils::Normalize(volumeAccel * 100.0, -100.0, 100.0);
            
            if (volumeAccel > 0.1) {
                if (closeArray[0] > closeArray[1]) {
                    bullishScore += 10.0;
                } else {
                    bearishScore += 10.0;
                }
            }
        }
        
        // ===== NORMALIZE SCORES =====
        totalScore = bullishScore + bearishScore;
        if (totalScore == 0) totalScore = 1;
        
        currentPressure.bullishRatio = bullishScore / totalScore;
        currentPressure.bearishRatio = bearishScore / totalScore;
        
        currentPressure.buyPressure = CMathUtils::NormalizePercent(bullishScore / 2.0);
        currentPressure.sellPressure = CMathUtils::NormalizePercent(bearishScore / 2.0);
        
        // Ensure sum to 100
        double sum = currentPressure.buyPressure + currentPressure.sellPressure;
        if (sum > 0) {
            currentPressure.buyPressure = (currentPressure.buyPressure / sum) * 100.0;
            currentPressure.sellPressure = (currentPressure.sellPressure / sum) * 100.0;
        }
        
        currentPressure.pressureDifference = currentPressure.buyPressure - currentPressure.sellPressure;
    }
    
    double GetTickDirection()
    {
        double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
        double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
        double mid = (bid + ask) / 2.0;
        
        if (lastClose == 0) lastClose = mid;
        
        double direction = 0;
        if (mid > lastClose) direction = 1.0;
        else if (mid < lastClose) direction = -1.0;
        
        lastClose = mid;
        
        if (direction > 0) {
            consecutiveUpTicks++;
            consecutiveDownTicks = 0;
        } else if (direction < 0) {
            consecutiveDownTicks++;
            consecutiveUpTicks = 0;
        }
        
        return direction;
    }
    
    SPressureData GetData() { return currentPressure; }
    
    double GetBuyPressure() { return currentPressure.buyPressure; }
    double GetSellPressure() { return currentPressure.sellPressure; }
    double GetPressureDifference() { return currentPressure.pressureDifference; }
    
    bool IsBullish() { return currentPressure.buyPressure > currentPressure.sellPressure; }
    bool IsBearish() { return currentPressure.sellPressure > currentPressure.buyPressure; }
    bool IsConfirmed() { return currentPressure.confirmed; }
    
    int GetConsecutiveUpTicks() { return consecutiveUpTicks; }
    int GetConsecutiveDownTicks() { return consecutiveDownTicks; }
};

#endif
