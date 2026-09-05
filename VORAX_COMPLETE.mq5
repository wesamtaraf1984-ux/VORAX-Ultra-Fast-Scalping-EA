//+------------------------------------------------------------------+
//|                                                  VORAX_COMPLETE.mq5 |
//|                           VORAX™ Ultra-Fast Scalping EA - COMPLETE    |
//|                        All modules integrated in single file         |
//|                           Copyright 2024 - Professional Edition    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      "https://github.com/wesamtaraf1984-ux"
#property version   "2.0.1"
#property strict
#property description "VORAX™ Complete - Ultra-Fast Multi-Asset Scalping EA - All-in-One"

#include <Trade\Trade.mqh>

//===================================================================
//                    GLOBAL DEFINES & ENUMS
//===================================================================

enum ENUM_SIGNAL_TYPE { SIGNAL_NONE, SIGNAL_BUY, SIGNAL_SELL };
enum ENUM_VOLATILITY_REGIME { REGIME_LOW, REGIME_NORMAL, REGIME_HIGH, REGIME_EXTREME };
enum ENUM_EA_STATUS { EA_READY, EA_BUY_SIGNAL, EA_SELL_SIGNAL, EA_COOLDOWN, EA_NEWS_FILTER, EA_DAILY_LOSS_LIMIT, EA_EXTREME_VOLATILITY, EA_TRADING_DISABLED, EA_SPREAD_TOO_HIGH, EA_MAX_POSITIONS, EA_ERROR };

const int LOOKBACK_BARS = 50;
const int ATR_PERIOD = 14;
const int EMA_PERIOD = 20;

//===================================================================
//                    STRUCTURES
//===================================================================

struct SPressureData {
    double buyPressure;
    double sellPressure;
    double pressureDifference;
    double bullishRatio;
    double bearishRatio;
    double volumeAcceleration;
    bool confirmed;
    datetime timestamp;
};

struct SMomentumData {
    double value;
    double strength;
    double acceleration;
    bool isUptrend;
    bool isDowntrend;
    int consecutiveUpTicks;
    int consecutiveDownTicks;
    datetime timestamp;
};

struct SVolatilityData {
    double atr;
    double stdDev;
    ENUM_VOLATILITY_REGIME regime;
    double volatilityPercent;
    datetime timestamp;
    
    string GetRegimeString() {
        switch(regime) {
            case REGIME_LOW: return "LOW";
            case REGIME_NORMAL: return "NORMAL";
            case REGIME_HIGH: return "HIGH";
            case REGIME_EXTREME: return "EXTREME";
            default: return "UNKNOWN";
        }
    }
};

struct STradeSignal {
    ENUM_SIGNAL_TYPE signalType;
    double entryPrice;
    double stopLoss;
    double takeProfit;
    double pressure;
    double momentum;
    double confidence;
    string reason;
    datetime timestamp;
};

struct SAccountStats {
    double balance;
    double equity;
    double freeMargin;
    double usedMargin;
    int totalTrades;
    int openPositions;
};

struct SPositionData {
    ulong ticket;
    string symbol;
    ENUM_POSITION_TYPE type;
    double volume;
    double openPrice;
    double stopLoss;
    double takeProfit;
    double currentPrice;
    double currentProfit;
    double profitPercent;
    int magicNumber;
    datetime openTime;
    double slDistance;
    double tpDistance;
    bool isValid;
};

struct SSymbolConfig {
    string symbol;
    ulong magicNumber;
    double maxRiskPerTrade;
    double maxDailyLoss;
    double maxDrawdown;
    double maxSpread;
    double minimumPressure;
    double minimumPressureDifference;
    double minimumMomentumStrength;
    double minSLPoints;
    double maxSLPoints;
    double slVolatilityMultiplier;
    double tpRiskRewardRatio;
    string sessionStart;
    string sessionEnd;
    bool tradeOnSession;
    int maxPositions;
    int maxTradesPerDay;
    int maxTradesPerHour;
    bool allowReinforcement;
    int maxReinforcementTrades;
    double minTimeBetweenReinforcement;
};

//===================================================================
//                    UTILITY CLASSES
//===================================================================

class CLogger {
public:
    bool debugMode;
    
    CLogger(bool debug = false) : debugMode(debug) {}
    
    void Debug(string module, string message) {
        if (debugMode) Print("[" + module + "] DEBUG: " + message);
    }
    
    void Info(string module, string message) {
        Print("[" + module + "] INFO: " + message);
    }
    
    void Warning(string module, string message) {
        Print("[" + module + "] WARNING: " + message);
    }
    
    void Error(string module, string message) {
        Print("[" + module + "] ERROR: " + message);
        Alert("VORAX Error: " + message);
    }
};

class CMathUtils {
public:
    static double Normalize(double value, double min, double max) {
        if (value > max) return max;
        if (value < min) return min;
        return value;
    }
    
    static double NormalizePercent(double value) {
        return Normalize(value, 0.0, 100.0);
    }
};

class CTimeUtils {
public:
    static int SecondsSinceTime(datetime current, datetime past) {
        if (past == 0) return 999999;
        return (int)(current - past);
    }
    
    static bool IsWithinSession(datetime time, string startTime, string endTime) {
        int hour = Hour();
        int minute = Minute();
        int currentTime = hour * 100 + minute;
        
        int start = StringToTime(startTime);
        int end = StringToTime(endTime);
        
        return currentTime >= start && currentTime <= end;
    }
};

class CSymbolUtils {
public:
    static bool DetectSymbol(string &symbol) {
        if (SymbolInfoInteger(symbol, SYMBOL_DIGITS) > 0) return true;
        return false;
    }
    
    static double NormalizeLot(double lot, double minLot, double maxLot, double step) {
        if (lot < minLot) return minLot;
        if (lot > maxLot) return maxLot;
        return MathFloor(lot / step) * step;
    }
};

class CSymbolConfigManager {
private:
    SSymbolConfig goldConfig;
    SSymbolConfig bitcoinConfig;
    CLogger *logger;
    
public:
    CSymbolConfigManager(CLogger *log) : logger(log) {
        InitializeConfigs();
    }
    
    void InitializeConfigs() {
        // Gold Config
        goldConfig.symbol = "XAUUSD";
        goldConfig.magicNumber = 123456;
        goldConfig.maxRiskPerTrade = 0.50;
        goldConfig.maxDailyLoss = 2.00;
        goldConfig.maxDrawdown = 5.00;
        goldConfig.maxSpread = 1.5;
        goldConfig.minimumPressure = 65.0;
        goldConfig.minimumPressureDifference = 18.0;
        goldConfig.minimumMomentumStrength = 50.0;
        goldConfig.minSLPoints = 0.50;
        goldConfig.maxSLPoints = 2.50;
        goldConfig.slVolatilityMultiplier = 1.2;
        goldConfig.tpRiskRewardRatio = 1.50;
        goldConfig.sessionStart = "09:00";
        goldConfig.sessionEnd = "17:00";
        goldConfig.tradeOnSession = true;
        goldConfig.maxPositions = 2;
        goldConfig.maxTradesPerDay = 20;
        goldConfig.maxTradesPerHour = 5;
        goldConfig.allowReinforcement = true;
        goldConfig.maxReinforcementTrades = 1;
        goldConfig.minTimeBetweenReinforcement = 30.0;
        
        // Bitcoin Config
        bitcoinConfig.symbol = "BTCUSD";
        bitcoinConfig.magicNumber = 654321;
        bitcoinConfig.maxRiskPerTrade = 0.50;
        bitcoinConfig.maxDailyLoss = 2.00;
        bitcoinConfig.maxDrawdown = 5.00;
        bitcoinConfig.maxSpread = 75.0;
        bitcoinConfig.minimumPressure = 62.0;
        bitcoinConfig.minimumPressureDifference = 16.0;
        bitcoinConfig.minimumMomentumStrength = 48.0;
        bitcoinConfig.minSLPoints = 50.0;
        bitcoinConfig.maxSLPoints = 300.0;
        bitcoinConfig.slVolatilityMultiplier = 1.3;
        bitcoinConfig.tpRiskRewardRatio = 1.50;
        bitcoinConfig.sessionStart = "00:00";
        bitcoinConfig.sessionEnd = "23:59";
        bitcoinConfig.tradeOnSession = true;
        bitcoinConfig.maxPositions = 2;
        bitcoinConfig.maxTradesPerDay = 20;
        bitcoinConfig.maxTradesPerHour = 5;
        bitcoinConfig.allowReinforcement = true;
        bitcoinConfig.maxReinforcementTrades = 1;
        bitcoinConfig.minTimeBetweenReinforcement = 30.0;
    }
    
    SSymbolConfig* GetGoldConfig() { return &goldConfig; }
    SSymbolConfig* GetBitcoinConfig() { return &bitcoinConfig; }
};

//===================================================================
//                    VOLATILITY ANALYZER
//===================================================================

class CVolatilityAnalyzer {
private:
    string symbol;
    double point;
    SSymbolConfig *config;
    CLogger *logger;
    
    double atrBuffer[];
    double closeBuffer[];
    SVolatilityData currentVolatility;
    double atrValues[50];
    int atrIndex;

public:
    CVolatilityAnalyzer(string sym, SSymbolConfig *cfg, CLogger *log)
        : symbol(sym), config(cfg), logger(log), atrIndex(0) {
        point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        ArraySetAsSeries(atrBuffer, true);
        ArraySetAsSeries(closeBuffer, true);
        if (logger) logger->Debug("Volatility", "Analyzer initialized");
    }
    
    bool Update() {
        int atrHandle = iATR(symbol, PERIOD_M1, ATR_PERIOD);
        if (CopyBuffer(atrHandle, 0, 0, LOOKBACK_BARS, atrBuffer) <= 0) return false;
        if (CopyClose(symbol, PERIOD_M1, 0, LOOKBACK_BARS, closeBuffer) <= 0) return false;
        
        CalculateVolatility();
        currentVolatility.timestamp = TimeCurrent();
        
        IndicatorRelease(atrHandle);
        return true;
    }
    
    void CalculateVolatility() {
        if (ArraySize(atrBuffer) < 1) return;
        
        currentVolatility.atr = atrBuffer[0];
        
        // Store ATR for percentile calculation
        if (atrIndex < 50) {
            atrValues[atrIndex] = atrBuffer[0];
            atrIndex++;
        } else {
            for (int i = 0; i < 49; i++) atrValues[i] = atrValues[i + 1];
            atrValues[49] = atrBuffer[0];
        }
        
        // Calculate percentiles
        double p25 = CalculatePercentile(atrValues, atrIndex, 25);
        double p75 = CalculatePercentile(atrValues, atrIndex, 75);
        double p90 = CalculatePercentile(atrValues, atrIndex, 90);
        
        if (currentVolatility.atr < p25) {
            currentVolatility.regime = REGIME_LOW;
        } else if (currentVolatility.atr < p75) {
            currentVolatility.regime = REGIME_NORMAL;
        } else if (currentVolatility.atr < p90) {
            currentVolatility.regime = REGIME_HIGH;
        } else {
            currentVolatility.regime = REGIME_EXTREME;
        }
        
        currentVolatility.volatilityPercent = (currentVolatility.atr / closeBuffer[0]) * 100.0;
    }
    
    double CalculatePercentile(double &arr[], int size, int percentile) {
        if (size <= 0) return 0;
        double temp[];
        ArrayCopy(temp, arr, 0, 0, size);
        ArraySort(temp, WHOLE_ARRAY, 0, ORDER_ASCENDING);
        int index = (int)((percentile / 100.0) * size);
        if (index >= size) index = size - 1;
        return temp[index];
    }
    
    SVolatilityData GetData() { return currentVolatility; }
    double GetATR() { return currentVolatility.atr; }
    bool IsExtremeVolatility() { return currentVolatility.regime == REGIME_EXTREME; }
    bool IsLowVolatility() { return currentVolatility.regime == REGIME_LOW; }
};

//===================================================================
//                    PRESSURE ANALYZER
//===================================================================

class CPressureAnalyzer {
private:
    string symbol;
    double point;
    SSymbolConfig *config;
    CLogger *logger;
    
    double highArray[];
    double lowArray[];
    double closeArray[];
    SPressureData currentPressure;
    int consecutiveUpTicks;
    int consecutiveDownTicks;
    double lastClose;

public:
    CPressureAnalyzer(string sym, SSymbolConfig *cfg, CLogger *log)
        : symbol(sym), config(cfg), logger(log), consecutiveUpTicks(0), 
          consecutiveDownTicks(0), lastClose(0) {
        point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        ArraySetAsSeries(highArray, true);
        ArraySetAsSeries(lowArray, true);
        ArraySetAsSeries(closeArray, true);
    }
    
    bool Update() {
        if (CopyHigh(symbol, PERIOD_M1, 0, LOOKBACK_BARS, highArray) <= 0 ||
            CopyLow(symbol, PERIOD_M1, 0, LOOKBACK_BARS, lowArray) <= 0 ||
            CopyClose(symbol, PERIOD_M1, 0, LOOKBACK_BARS, closeArray) <= 0) {
            return false;
        }
        CalculatePressure();
        currentPressure.timestamp = TimeCurrent();
        currentPressure.confirmed = (currentPressure.bullishRatio > 0.55 || currentPressure.bearishRatio > 0.55);
        return true;
    }
    
    void CalculatePressure() {
        if (ArraySize(closeArray) < 5) return;
        
        double bullishScore = 0, bearishScore = 0;
        
        int upCandles = 0, downCandles = 0;
        for (int i = 0; i < 5; i++) {
            if (closeArray[i] > closeArray[i+1]) upCandles++;
            else if (closeArray[i] < closeArray[i+1]) downCandles++;
        }
        
        bullishScore += upCandles * 15.0;
        bearishScore += downCandles * 15.0;
        
        for (int i = 0; i < 3; i++) {
            double open = iOpen(symbol, PERIOD_M1, i);
            double close = closeArray[i];
            double high = highArray[i];
            double low = lowArray[i];
            double range = high - low;
            if (range == 0) continue;
            double bodyRatio = MathAbs(close - open) / range;
            if (close > open) bullishScore += bodyRatio * 100.0 * 0.8;
            else if (close < open) bearishScore += bodyRatio * 100.0 * 0.8;
        }
        
        double currentRange = highArray[0] - lowArray[0];
        double avgRange = (highArray[1] - lowArray[1] + highArray[2] - lowArray[2]) / 2.0;
        if (currentRange > avgRange * 1.2) {
            if (closeArray[0] > closeArray[1]) bullishScore += 10.0;
            else bearishScore += 10.0;
        }
        
        double tickDirection = GetTickDirection();
        if (tickDirection > 0) bullishScore += tickDirection * 20.0;
        else if (tickDirection < 0) bearishScore += MathAbs(tickDirection) * 20.0;
        
        bullishScore += consecutiveUpTicks * 5.0;
        bearishScore += consecutiveDownTicks * 5.0;
        
        double totalScore = bullishScore + bearishScore;
        if (totalScore == 0) totalScore = 1;
        
        currentPressure.bullishRatio = bullishScore / totalScore;
        currentPressure.bearishRatio = bearishScore / totalScore;
        currentPressure.buyPressure = CMathUtils::NormalizePercent(bullishScore / 2.0);
        currentPressure.sellPressure = CMathUtils::NormalizePercent(bearishScore / 2.0);
        currentPressure.pressureDifference = currentPressure.buyPressure - currentPressure.sellPressure;
    }
    
    double GetTickDirection() {
        double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
        double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
        double mid = (bid + ask) / 2.0;
        if (lastClose == 0) lastClose = mid;
        double direction = (mid > lastClose) ? 1.0 : (mid < lastClose) ? -1.0 : 0;
        if (direction > 0) { consecutiveUpTicks++; consecutiveDownTicks = 0; }
        else if (direction < 0) { consecutiveDownTicks++; consecutiveUpTicks = 0; }
        lastClose = mid;
        return direction;
    }
    
    SPressureData GetData() { return currentPressure; }
    double GetBuyPressure() { return currentPressure.buyPressure; }
    double GetSellPressure() { return currentPressure.sellPressure; }
};

//===================================================================
//                    MOMENTUM ANALYZER
//===================================================================

class CMomentumAnalyzer {
private:
    string symbol;
    double point;
    SSymbolConfig *config;
    CLogger *logger;
    
    double emaBuffer[];
    double closeArray[];
    SMomentumData currentMomentum;

public:
    CMomentumAnalyzer(string sym, SSymbolConfig *cfg, CLogger *log)
        : symbol(sym), config(cfg), logger(log) {
        point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        ArraySetAsSeries(emaBuffer, true);
        ArraySetAsSeries(closeArray, true);
    }
    
    bool Update() {
        int emaHandle = iMA(symbol, PERIOD_M1, 20, 0, MODE_EMA, PRICE_CLOSE);
        if (CopyBuffer(emaHandle, 0, 0, LOOKBACK_BARS, emaBuffer) <= 0) return false;
        if (CopyClose(symbol, PERIOD_M1, 0, LOOKBACK_BARS, closeArray) <= 0) return false;
        CalculateMomentum();
        currentMomentum.timestamp = TimeCurrent();
        IndicatorRelease(emaHandle);
        return true;
    }
    
    void CalculateMomentum() {
        if (ArraySize(closeArray) < 5) return;
        
        double priceEmaDeviation = closeArray[0] - emaBuffer[0];
        double deviation_percent = (priceEmaDeviation / emaBuffer[0]) * 100.0;
        double roc = ((closeArray[0] - closeArray[4]) / closeArray[4]) * 100.0;
        double momentum_1bar = (closeArray[0] - closeArray[1]);
        double momentum_3bar = (closeArray[0] - closeArray[2]);
        double emaSlope = (emaBuffer[0] - emaBuffer[5]);
        double acceleration = momentum_1bar - momentum_3bar;
        
        double emaComponent = CMathUtils::Normalize(deviation_percent * 5.0, -100.0, 100.0);
        double rocComponent = CMathUtils::Normalize(roc * 2.0, -100.0, 100.0);
        double accelComponent = CMathUtils::Normalize(acceleration / point * 0.5, -100.0, 100.0);
        double slopeComponent = CMathUtils::Normalize(emaSlope / point * 0.1, -100.0, 100.0);
        
        double momentumValue = emaComponent * 0.4 + rocComponent * 0.3 + accelComponent * 0.2 + slopeComponent * 0.1;
        
        currentMomentum.value = CMathUtils::Normalize(momentumValue, -100.0, 100.0);
        currentMomentum.strength = MathAbs(currentMomentum.value);
        currentMomentum.acceleration = acceleration;
        currentMomentum.isUptrend = (currentMomentum.value > 30 && emaSlope > 0 && closeArray[0] > emaBuffer[0]);
        currentMomentum.isDowntrend = (currentMomentum.value < -30 && emaSlope < 0 && closeArray[0] < emaBuffer[0]);
    }
    
    SMomentumData GetData() { return currentMomentum; }
    double GetMomentum() { return currentMomentum.value; }
    bool IsUptrend() { return currentMomentum.isUptrend; }
    bool IsDowntrend() { return currentMomentum.isDowntrend; }
};

//===================================================================
//                    RISK MANAGER
//===================================================================

class CRiskManager {
private:
    string symbol;
    double point;
    double tickValue;
    SSymbolConfig *config;
    CLogger *logger;
    SAccountStats accountStats;
    int consecutiveLosses;

public:
    CRiskManager(string sym, SSymbolConfig *cfg, CLogger *log)
        : symbol(sym), config(cfg), logger(log), consecutiveLosses(0) {
        point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        UpdateAccountStats();
    }
    
    void UpdateAccountStats() {
        accountStats.balance = AccountInfoDouble(ACCOUNT_BALANCE);
        accountStats.equity = AccountInfoDouble(ACCOUNT_EQUITY);
        accountStats.freeMargin = AccountInfoDouble(ACCOUNT_FREEMARGIN);
        accountStats.usedMargin = AccountInfoDouble(ACCOUNT_MARGIN);
        accountStats.openPositions = PositionsTotal();
    }
    
    double CalculateLotSize(double stopLossPoints) {
        if (stopLossPoints <= 0) return 0.01;
        UpdateAccountStats();
        double riskAmount = accountStats.equity * (config->maxRiskPerTrade / 100.0);
        if (tickValue <= 0) return 0.01;
        double calculatedLot = (riskAmount / (stopLossPoints * tickValue));
        double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
        if (calculatedLot < minLot) return minLot;
        if (calculatedLot > maxLot) return maxLot;
        return calculatedLot;
    }
    
    bool IsTradeAllowed() {
        UpdateAccountStats();
        if (accountStats.balance <= 0) return false;
        double drawdownPercent = (accountStats.balance - accountStats.equity) / accountStats.balance * 100.0;
        if (drawdownPercent >= config->maxDrawdown) return false;
        if (accountStats.openPositions >= (int)config->maxPositions) return false;
        return true;
    }
    
    void RecordTrade(double profitLoss) {
        if (profitLoss < 0) consecutiveLosses++;
        else consecutiveLosses = 0;
    }
    
    SAccountStats GetAccountStats() { return accountStats; }
    double GetBalance() { return accountStats.balance; }
};

//===================================================================
//                    SIGNAL ENGINE
//===================================================================

class CSignalEngine {
private:
    string symbol;
    SSymbolConfig *config;
    CPressureAnalyzer *pressureAnalyzer;
    CMomentumAnalyzer *momentumAnalyzer;
    CVolatilityAnalyzer *volatilityAnalyzer;
    CLogger *logger;
    datetime lastSignalTime;

public:
    CSignalEngine(string sym, SSymbolConfig *cfg, CPressureAnalyzer *pres,
                  CMomentumAnalyzer *mom, CVolatilityAnalyzer *vol, CLogger *log)
        : symbol(sym), config(cfg), pressureAnalyzer(pres), momentumAnalyzer(mom),
          volatilityAnalyzer(vol), logger(log), lastSignalTime(0) {}
    
    STradeSignal AnalyzeSignal() {
        STradeSignal signal;
        signal.signalType = SIGNAL_NONE;
        signal.timestamp = TimeCurrent();
        signal.confidence = 0;
        
        if (volatilityAnalyzer->IsExtremeVolatility()) return signal;
        if (volatilityAnalyzer->IsLowVolatility()) return signal;
        
        SPressureData pressure = pressureAnalyzer->GetData();
        SMomentumData momentum = momentumAnalyzer->GetData();
        SVolatilityData volatility = volatilityAnalyzer->GetData();
        
        double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
        double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
        
        if (momentum.isUptrend && pressure.buyPressure >= config->minimumPressure) {
            if ((pressure.buyPressure - pressure.sellPressure) >= config->minimumPressureDifference) {
                if (momentum.strength >= config->minimumMomentumStrength) {
                    if (pressure.confirmed) {
                        double slDistance = config->minSLPoints + (volatility.atr / SymbolInfoDouble(symbol, SYMBOL_POINT) * config->slVolatilityMultiplier);
                        slDistance = CMathUtils::Normalize(slDistance, config->minSLPoints, config->maxSLPoints);
                        
                        signal.signalType = SIGNAL_BUY;
                        signal.entryPrice = ask;
                        signal.stopLoss = ask - (slDistance * SymbolInfoDouble(symbol, SYMBOL_POINT));
                        signal.takeProfit = ask + (slDistance * config->tpRiskRewardRatio * SymbolInfoDouble(symbol, SYMBOL_POINT));
                        signal.pressure = pressure.buyPressure;
                        signal.momentum = momentum.value;
                        signal.confidence = (pressure.bullishRatio * 50.0) + (momentum.strength * 0.5);
                        signal.reason = "BUY Signal";
                        return signal;
                    }
                }
            }
        }
        
        if (momentum.isDowntrend && pressure.sellPressure >= config->minimumPressure) {
            if ((pressure.sellPressure - pressure.buyPressure) >= config->minimumPressureDifference) {
                if (momentum.strength >= config->minimumMomentumStrength) {
                    if (pressure.confirmed) {
                        double slDistance = config->minSLPoints + (volatility.atr / SymbolInfoDouble(symbol, SYMBOL_POINT) * config->slVolatilityMultiplier);
                        slDistance = CMathUtils::Normalize(slDistance, config->minSLPoints, config->maxSLPoints);
                        
                        signal.signalType = SIGNAL_SELL;
                        signal.entryPrice = bid;
                        signal.stopLoss = bid + (slDistance * SymbolInfoDouble(symbol, SYMBOL_POINT));
                        signal.takeProfit = bid - (slDistance * config->tpRiskRewardRatio * SymbolInfoDouble(symbol, SYMBOL_POINT));
                        signal.pressure = pressure.sellPressure;
                        signal.momentum = momentum.value;
                        signal.confidence = (pressure.bearishRatio * 50.0) + (momentum.strength * 0.5);
                        signal.reason = "SELL Signal";
                        return signal;
                    }
                }
            }
        }
        
        return signal;
    }
    
    bool IsSignalNew(STradeSignal &signal) {
        if (signal.signalType == SIGNAL_NONE) return false;
        if (lastSignalTime == signal.timestamp) return false;
        lastSignalTime = signal.timestamp;
        return true;
    }
};

//===================================================================
//                    TRADE EXECUTOR
//===================================================================

class CTradeExecutor {
private:
    string symbol;
    SSymbolConfig *config;
    CRiskManager *riskManager;
    CLogger *logger;
    int digits;
    double point;
    CTrade trade;

public:
    CTradeExecutor(string sym, SSymbolConfig *cfg, CRiskManager *risk, CLogger *log)
        : symbol(sym), config(cfg), riskManager(risk), logger(log) {
        point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        trade.SetExpertMagicNumber(config->magicNumber);
    }
    
    bool IsSpreadAcceptable() {
        double currentSpread = (SymbolInfoDouble(symbol, SYMBOL_ASK) - SymbolInfoDouble(symbol, SYMBOL_BID)) / point;
        return currentSpread <= config->maxSpread;
    }
    
    ulong ExecuteSignal(STradeSignal &signal, double lot) {
        if (signal.signalType == SIGNAL_NONE) return 0;
        if (!IsSpreadAcceptable()) return 0;
        if (!riskManager->IsTradeAllowed()) return 0;
        
        if (signal.signalType == SIGNAL_BUY) {
            if (trade.Buy(lot, symbol, signal.entryPrice, signal.stopLoss, signal.takeProfit, "VORAX_BUY")) {
                if (logger) logger->Info("Execution", "BUY order sent");
                return trade.ResultOrder();
            }
        } else if (signal.signalType == SIGNAL_SELL) {
            if (trade.Sell(lot, symbol, signal.entryPrice, signal.stopLoss, signal.takeProfit, "VORAX_SELL")) {
                if (logger) logger->Info("Execution", "SELL order sent");
                return trade.ResultOrder();
            }
        }
        
        return 0;
    }
    
    bool ModifyPosition(ulong ticket, double newSL, double newTP) {
        if (!PositionSelectByTicket(ticket)) return false;
        return trade.PositionModify(ticket, newSL, newTP);
    }
};

//===================================================================
//                    POSITION MANAGER
//===================================================================

class CPositionManager {
private:
    string symbol;
    SSymbolConfig *config;
    CTradeExecutor *executor;
    CVolatilityAnalyzer *volatility;
    CLogger *logger;
    int digits;
    double point;

public:
    CPositionManager(string sym, SSymbolConfig *cfg, CTradeExecutor *exec,
                    CVolatilityAnalyzer *vol, CLogger *log)
        : symbol(sym), config(cfg), executor(exec), volatility(vol), logger(log) {
        point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    }
    
    void UpdateAllPositions() {
        for (int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if (ticket == 0) continue;
            if (PositionSelectByTicket(ticket)) {
                string posSymbol = PositionGetString(POSITION_SYMBOL);
                int posMagic = (int)PositionGetInteger(POSITION_MAGIC);
                if (posSymbol == symbol && posMagic == config->magicNumber) {
                    UpdateTrailingStop(ticket);
                }
            }
        }
    }
    
    void UpdateTrailingStop(ulong ticket) {
        if (!PositionSelectByTicket(ticket)) return;
        
        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentTP = PositionGetDouble(POSITION_TP);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        
        if (type == POSITION_TYPE_BUY) {
            double profitInPoints = (currentPrice - entryPrice) / point;
            double newSL = currentSL;
            
            if (profitInPoints > 50) {
                double atr = volatility->GetATR();
                double trailDistance = (atr * 0.5) + (2 * point);
                newSL = currentPrice - trailDistance;
                if (newSL > currentSL) executor->ModifyPosition(ticket, newSL, currentTP);
            }
        } else if (type == POSITION_TYPE_SELL) {
            double profitInPoints = (entryPrice - currentPrice) / point;
            double newSL = currentSL;
            
            if (profitInPoints > 50) {
                double atr = volatility->GetATR();
                double trailDistance = (atr * 0.5) + (2 * point);
                newSL = currentPrice + trailDistance;
                if (newSL < currentSL) executor->ModifyPosition(ticket, newSL, currentTP);
            }
        }
    }
    
    int GetOpenPositionsCount() {
        int count = 0;
        for (int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if (ticket == 0) continue;
            if (PositionSelectByTicket(ticket)) {
                string posSymbol = PositionGetString(POSITION_SYMBOL);
                int posMagic = (int)PositionGetInteger(POSITION_MAGIC);
                if (posSymbol == symbol && posMagic == config->magicNumber) count++;
            }
        }
        return count;
    }
};

//===================================================================
//                    INPUT PARAMETERS
//===================================================================

input group "=== GENERAL ==="
input bool TradeGold = true;
input bool TradeBitcoin = true;
input bool DebugMode = false;
input bool ShowDashboard = true;

input group "=== GOLD (XAUUSD) ==="
input double Gold_RiskPercentPerTrade = 0.50;
input double Gold_MaxDailyLoss = 2.00;
input double Gold_MaxSpread = 1.5;
input double Gold_MinimumPressure = 65.0;
input double Gold_MinimumMomentumStrength = 50.0;
input double Gold_MinSLPoints = 0.50;
input double Gold_MaxSLPoints = 2.50;

input group "=== BITCOIN (BTCUSD) ==="
input double Bitcoin_RiskPercentPerTrade = 0.50;
input double Bitcoin_MaxDailyLoss = 2.00;
input double Bitcoin_MaxSpread = 75.0;
input double Bitcoin_MinimumPressure = 62.0;
input double Bitcoin_MinimumMomentumStrength = 48.0;
input double Bitcoin_MinSLPoints = 50.0;
input double Bitcoin_MaxSLPoints = 300.0;

input group "=== GENERAL SETTINGS ==="
input bool AllowReinforcement = true;
input int MaxOpenPositions = 2;

//===================================================================
//                    GLOBAL VARIABLES
//===================================================================

CLogger *logger;
CSymbolConfigManager *configManager;
CRiskManager *goldRiskManager;
CRiskManager *bitcoinRiskManager;
CVolatilityAnalyzer *goldVolatility;
CPressureAnalyzer *goldPressure;
CMomentumAnalyzer *goldMomentum;
CSignalEngine *goldSignal;
CTradeExecutor *goldExecutor;
CPositionManager *goldPositionManager;
CVolatilityAnalyzer *bitcoinVolatility;
CPressureAnalyzer *bitcoinPressure;
CMomentumAnalyzer *bitcoinMomentum;
CSignalEngine *bitcoinSignal;
CTradeExecutor *bitcoinExecutor;
CPositionManager *bitcoinPositionManager;

string goldSymbol = "XAUUSD";
string bitcoinSymbol = "BTCUSD";
ENUM_EA_STATUS eaStatus = EA_READY;

//===================================================================
//                    INIT
//===================================================================

int OnInit() {
    logger = new CLogger(DebugMode);
    logger->Info("EA", "VORAX™ v2.0.1 STARTING");
    
    configManager = new CSymbolConfigManager(logger);
    
    if (!CSymbolUtils::DetectSymbol(goldSymbol) || !CSymbolUtils::DetectSymbol(bitcoinSymbol)) {
        logger->Error("Init", "Symbols not found");
        return INIT_FAILED;
    }
    
    // Gold Setup
    if (TradeGold) {
        SSymbolConfig *goldConfig = configManager->GetGoldConfig();
        goldConfig->maxRiskPerTrade = Gold_RiskPercentPerTrade;
        goldConfig->maxDailyLoss = Gold_MaxDailyLoss;
        goldConfig->maxSpread = Gold_MaxSpread;
        goldConfig->minimumPressure = Gold_MinimumPressure;
        goldConfig->minimumMomentumStrength = Gold_MinimumMomentumStrength;
        goldConfig->minSLPoints = Gold_MinSLPoints;
        goldConfig->maxSLPoints = Gold_MaxSLPoints;
        goldConfig->maxPositions = MaxOpenPositions;
        
        goldRiskManager = new CRiskManager(goldSymbol, goldConfig, logger);
        goldVolatility = new CVolatilityAnalyzer(goldSymbol, goldConfig, logger);
        goldPressure = new CPressureAnalyzer(goldSymbol, goldConfig, logger);
        goldMomentum = new CMomentumAnalyzer(goldSymbol, goldConfig, logger);
        goldSignal = new CSignalEngine(goldSymbol, goldConfig, goldPressure, goldMomentum, goldVolatility, logger);
        goldExecutor = new CTradeExecutor(goldSymbol, goldConfig, goldRiskManager, logger);
        goldPositionManager = new CPositionManager(goldSymbol, goldConfig, goldExecutor, goldVolatility, logger);
        logger->Info("Init", "Gold initialized");
    }
    
    // Bitcoin Setup
    if (TradeBitcoin) {
        SSymbolConfig *bitcoinConfig = configManager->GetBitcoinConfig();
        bitcoinConfig->maxRiskPerTrade = Bitcoin_RiskPercentPerTrade;
        bitcoinConfig->maxDailyLoss = Bitcoin_MaxDailyLoss;
        bitcoinConfig->maxSpread = Bitcoin_MaxSpread;
        bitcoinConfig->minimumPressure = Bitcoin_MinimumPressure;
        bitcoinConfig->minimumMomentumStrength = Bitcoin_MinimumMomentumStrength;
        bitcoinConfig->minSLPoints = Bitcoin_MinSLPoints;
        bitcoinConfig->maxSLPoints = Bitcoin_MaxSLPoints;
        bitcoinConfig->maxPositions = MaxOpenPositions;
        
        bitcoinRiskManager = new CRiskManager(bitcoinSymbol, bitcoinConfig, logger);
        bitcoinVolatility = new CVolatilityAnalyzer(bitcoinSymbol, bitcoinConfig, logger);
        bitcoinPressure = new CPressureAnalyzer(bitcoinSymbol, bitcoinConfig, logger);
        bitcoinMomentum = new CMomentumAnalyzer(bitcoinSymbol, bitcoinConfig, logger);
        bitcoinSignal = new CSignalEngine(bitcoinSymbol, bitcoinConfig, bitcoinPressure, bitcoinMomentum, bitcoinVolatility, logger);
        bitcoinExecutor = new CTradeExecutor(bitcoinSymbol, bitcoinConfig, bitcoinRiskManager, logger);
        bitcoinPositionManager = new CPositionManager(bitcoinSymbol, bitcoinConfig, bitcoinExecutor, bitcoinVolatility, logger);
        logger->Info("Init", "Bitcoin initialized");
    }
    
    logger->Info("EA", "VORAX™ Ready to Trade");
    eaStatus = EA_READY;
    return INIT_SUCCEEDED;
}

//===================================================================
//                    DEINIT
//===================================================================

void OnDeinit(const int reason) {
    if (TradeGold) {
        if (goldRiskManager) delete goldRiskManager;
        if (goldVolatility) delete goldVolatility;
        if (goldPressure) delete goldPressure;
        if (goldMomentum) delete goldMomentum;
        if (goldSignal) delete goldSignal;
        if (goldExecutor) delete goldExecutor;
        if (goldPositionManager) delete goldPositionManager;
    }
    if (TradeBitcoin) {
        if (bitcoinRiskManager) delete bitcoinRiskManager;
        if (bitcoinVolatility) delete bitcoinVolatility;
        if (bitcoinPressure) delete bitcoinPressure;
        if (bitcoinMomentum) delete bitcoinMomentum;
        if (bitcoinSignal) delete bitcoinSignal;
        if (bitcoinExecutor) delete bitcoinExecutor;
        if (bitcoinPositionManager) delete bitcoinPositionManager;
    }
    if (configManager) delete configManager;
    if (logger) delete logger;
}

//===================================================================
//                    MAIN TICK
//===================================================================

void OnTick() {
    if (TradeGold) ProcessGold();
    if (TradeBitcoin) ProcessBitcoin();
}

void ProcessGold() {
    if (!goldVolatility || !goldPressure || !goldMomentum || !goldSignal) return;
    
    if (!goldVolatility->Update() || !goldPressure->Update() || !goldMomentum->Update()) return;
    
    goldPositionManager->UpdateAllPositions();
    
    STradeSignal signal = goldSignal->AnalyzeSignal();
    
    if (signal.signalType != SIGNAL_NONE && goldSignal->IsSignalNew(signal)) {
        if (goldPositionManager->GetOpenPositionsCount() < (int)MaxOpenPositions) {
            double slPoints = MathAbs(signal.entryPrice - signal.stopLoss) / SymbolInfoDouble(goldSymbol, SYMBOL_POINT);
            double lot = goldRiskManager->CalculateLotSize(slPoints);
            if (lot > 0) goldExecutor->ExecuteSignal(signal, lot);
        }
    }
}

void ProcessBitcoin() {
    if (!bitcoinVolatility || !bitcoinPressure || !bitcoinMomentum || !bitcoinSignal) return;
    
    if (!bitcoinVolatility->Update() || !bitcoinPressure->Update() || !bitcoinMomentum->Update()) return;
    
    bitcoinPositionManager->UpdateAllPositions();
    
    STradeSignal signal = bitcoinSignal->AnalyzeSignal();
    
    if (signal.signalType != SIGNAL_NONE && bitcoinSignal->IsSignalNew(signal)) {
        if (bitcoinPositionManager->GetOpenPositionsCount() < (int)MaxOpenPositions) {
            double slPoints = MathAbs(signal.entryPrice - signal.stopLoss) / SymbolInfoDouble(bitcoinSymbol, SYMBOL_POINT);
            double lot = bitcoinRiskManager->CalculateLotSize(slPoints);
            if (lot > 0) bitcoinExecutor->ExecuteSignal(signal, lot);
        }
    }
}

//+------------------------------------------------------------------+
// END OF VORAX_COMPLETE.mq5
//+------------------------------------------------------------------+
