//+------------------------------------------------------------------+
//|                                                VORAX_Momentum.mqh |
//|                                   VORAX™ Ultra-Fast Scalping EA   |
//|                           Copyright 2024 - Professional Edition   |
//+------------------------------------------------------------------+

#ifndef VORAX_MOMENTUM_H
#define VORAX_MOMENTUM_H

#include "VORAX_Defines.mqh"
#include "VORAX_Utils.mqh"
#include "VORAX_SymbolConfig.mqh"

//--- Momentum Analyzer Class
class CMomentumAnalyzer
{
private:
    string symbol;
    int emaHandle;
    int adxHandle;
    double point;
    int digits;
    SSymbolConfig *config;
    CLogger *logger;
    
    double emaBuffer[];
    double adxBuffer[];
    double closeArray[];
    double priceChangeHistory[];
    
    SMomentumData currentMomentum;
    double lastPrice;
    int lookbackPeriod;

public:
    CMomentumAnalyzer(string sym, SSymbolConfig *cfg, CLogger *log)
        : symbol(sym), config(cfg), logger(log), lastPrice(0), lookbackPeriod(LOOKBACK_BARS)
    {
        point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        
        emaHandle = iMA(symbol, PERIOD_M1, 20, 0, MODE_EMA, PRICE_CLOSE);
        adxHandle = iADX(symbol, PERIOD_M1, 14);
        
        ArraySetAsSeries(emaBuffer, true);
        ArraySetAsSeries(adxBuffer, true);
        ArraySetAsSeries(closeArray, true);
        ArraySetAsSeries(priceChangeHistory, true);
        ArrayResize(priceChangeHistory, lookbackPeriod);
        
        if (logger) logger->Debug("Momentum", "Analyzer initialized for " + symbol);
    }
    
    ~CMomentumAnalyzer()
    {
        if (emaHandle != INVALID_HANDLE) IndicatorRelease(emaHandle);
        if (adxHandle != INVALID_HANDLE) IndicatorRelease(adxHandle);
    }
    
    bool Update()
    {
        // Copy EMA
        if (CopyBuffer(emaHandle, 0, 0, lookbackPeriod, emaBuffer) <= 0) {
            if (logger) logger->Error("Momentum", "Failed to copy EMA buffer");
            return false;
        }
        
        // Copy ADX
        if (CopyBuffer(adxHandle, 0, 0, lookbackPeriod, adxBuffer) <= 0) {
            if (logger) logger->Warning("Momentum", "ADX buffer not available");
        }
        
        // Copy Close prices
        if (CopyClose(symbol, PERIOD_M1, 0, lookbackPeriod, closeArray) <= 0) {
            if (logger) logger->Error("Momentum", "Failed to copy close prices");
            return false;
        }
        
        // Calculate momentum
        CalculateMomentum();
        currentMomentum.timestamp = TimeCurrent();
        
        return true;
    }
    
    void CalculateMomentum()
    {
        if (ArraySize(closeArray) < 5) return;
        
        // ===== 1. PRICE POSITION RELATIVE TO EMA =====
        double priceEmaDeviation = closeArray[0] - emaBuffer[0];
        double emaValue = emaBuffer[0];
        double deviation_percent = (priceEmaDeviation / emaValue) * 100.0;
        
        // ===== 2. RATE OF CHANGE (ROC) =====
        double roc = ((closeArray[0] - closeArray[4]) / closeArray[4]) * 100.0;
        
        // ===== 3. ACCELERATION =====
        double momentum_5bar = (closeArray[0] - closeArray[4]);
        double momentum_3bar = (closeArray[0] - closeArray[2]);
        double momentum_1bar = (closeArray[0] - closeArray[1]);
        double acceleration = momentum_1bar - momentum_3bar;
        
        // ===== 4. EMA SLOPE =====
        double emaSlope = (emaBuffer[0] - emaBuffer[5]);
        
        // ===== 5. ADX STRENGTH =====
        double adxStrength = 0;
        if (ArraySize(adxBuffer) > 0) {
            adxStrength = adxBuffer[0];
        } else {
            adxStrength = 25; // Default if ADX not available
        }
        
        // ===== CALCULATE MOMENTUM VALUE (-100 to +100) =====
        double momentumValue = 0;
        
        // Component 1: Price vs EMA (weight 40%)
        double emaComponent = CMathUtils::Normalize(deviation_percent * 5.0, -100.0, 100.0);
        momentumValue += emaComponent * 0.4;
        
        // Component 2: Rate of Change (weight 30%)
        double rocComponent = CMathUtils::Normalize(roc * 2.0, -100.0, 100.0);
        momentumValue += rocComponent * 0.3;
        
        // Component 3: Acceleration (weight 20%)
        double accelComponent = CMathUtils::Normalize(acceleration / point * 0.5, -100.0, 100.0);
        momentumValue += accelComponent * 0.2;
        
        // Component 4: EMA Slope (weight 10%)
        double slopeComponent = CMathUtils::Normalize(emaSlope / point * 0.1, -100.0, 100.0);
        momentumValue += slopeComponent * 0.1;
        
        currentMomentum.value = CMathUtils::Normalize(momentumValue, -100.0, 100.0);
        
        // ===== MOMENTUM STRENGTH (0-100) =====
        currentMomentum.strength = MathAbs(currentMomentum.value);
        
        // ===== MOMENTUM ACCELERATION =====
        if (ArraySize(priceChangeHistory) > 1) {
            ArrayCopy(priceChangeHistory, priceChangeHistory, 1, 0, lookbackPeriod - 1);
        }
        priceChangeHistory[0] = momentum_1bar;
        currentMomentum.acceleration = priceChangeHistory[0] - priceChangeHistory[1];
        
        // ===== TREND DETERMINATION =====
        currentMomentum.isUptrend = (currentMomentum.value > 30 && emaSlope > 0 && closeArray[0] > emaBuffer[0]);
        currentMomentum.isDowntrend = (currentMomentum.value < -30 && emaSlope < 0 && closeArray[0] < emaBuffer[0]);
        
        // ===== CONSECUTIVE TICKS (from price movement) =====
        currentMomentum.consecutiveUpTicks = 0;
        currentMomentum.consecutiveDownTicks = 0;
        for (int i = 0; i < 5; i++) {
            if (closeArray[i] > closeArray[i+1]) {
                currentMomentum.consecutiveUpTicks++;
            } else {
                currentMomentum.consecutiveDownTicks++;
            }
        }
    }
    
    SMomentumData GetData() { return currentMomentum; }
    double GetMomentum() { return currentMomentum.value; }
    double GetStrength() { return currentMomentum.strength; }
    double GetAcceleration() { return currentMomentum.acceleration; }
    bool IsUptrend() { return currentMomentum.isUptrend; }
    bool IsDowntrend() { return currentMomentum.isDowntrend; }
    bool IsStrongBullish() { return currentMomentum.value > 60; }
    bool IsStrongBearish() { return currentMomentum.value < -60; }
    bool IsWeakMomentum() { return currentMomentum.strength < 25; }
    
    string GetTrendString()
    {
        if (currentMomentum.value > 60) return "STRONG UP";
        if (currentMomentum.value > 30) return "MODERATE UP";
        if (currentMomentum.value < -60) return "STRONG DOWN";
        if (currentMomentum.value < -30) return "MODERATE DOWN";
        return "NEUTRAL";
    }
};

#endif
