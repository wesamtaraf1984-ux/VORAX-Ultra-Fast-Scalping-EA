//+------------------------------------------------------------------+
//|                                              VORAX_FINAL.mq5 |
//|                         VORAX™ Ultra-Fast Scalping EA - FINAL VERSION    |
//|                           Copyright 2024 - Professional Edition    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      "https://github.com/wesamtaraf1984-ux"
#property version   "2.0.3"
#property strict
#property description "VORAX™ - Ultra-Fast Multi-Asset Scalping EA"

#include <Trade\Trade.mqh>

//===================================================================
//                    ENUMS & DEFINES
//===================================================================

enum ENUM_SIGNAL_TYPE { SIGNAL_NONE = 0, SIGNAL_BUY = 1, SIGNAL_SELL = 2 };

const int LOOKBACK_BARS = 50;
const int ATR_PERIOD = 14;
const int EMA_PERIOD = 20;

//===================================================================
//                    STRUCTURES
//===================================================================

struct SPressureData {
    double buyPressure;
    double sellPressure;
    double bullishRatio;
    double bearishRatio;
    bool confirmed;
};

struct SMomentumData {
    double value;
    double strength;
    bool isUptrend;
    bool isDowntrend;
};

struct SVolatilityData {
    double atr;
    int regime;
};

struct STradeSignal {
    int signalType;
    double entryPrice;
    double stopLoss;
    double takeProfit;
    double confidence;
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
    int maxPositions;
};

//===================================================================
//                    LOGGER CLASS
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
    }
};

//===================================================================
//                    VOLATILITY ANALYZER
//===================================================================

class CVolatilityAnalyzer {
private:
    string symbol;
    double point;
    CLogger *logger;
    double atrBuffer[];
    double closeBuffer[];

public:
    CVolatilityAnalyzer(string sym, CLogger *log)
        : symbol(sym), logger(log) {
        point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        ArraySetAsSeries(atrBuffer, true);
        ArraySetAsSeries(closeBuffer, true);
    }
    
    bool Update() {
        int atrHandle = iATR(symbol, PERIOD_M1, ATR_PERIOD);
        if (atrHandle == INVALID_HANDLE) return false;
        
        if (CopyBuffer(atrHandle, 0, 0, LOOKBACK_BARS, atrBuffer) <= 0) {
            IndicatorRelease(atrHandle);
            return false;
        }
        
        if (CopyClose(symbol, PERIOD_M1, 0, LOOKBACK_BARS, closeBuffer) <= 0) {
            IndicatorRelease(atrHandle);
            return false;
        }
        
        IndicatorRelease(atrHandle);
        return true;
    }
    
    SVolatilityData GetData() {
        SVolatilityData vol;
        vol.atr = (ArraySize(atrBuffer) > 0) ? atrBuffer[0] : 0.1;
        
        if (vol.atr < 0.5) vol.regime = 0; // LOW
        else if (vol.atr > 2.0) vol.regime = 3; // EXTREME
        else vol.regime = 1; // NORMAL
        
        return vol;
    }
    
    bool IsExtremeVolatility() {
        SVolatilityData vol = GetData();
        return (vol.regime == 3);
    }
};

//===================================================================
//                    PRESSURE ANALYZER
//===================================================================

class CPressureAnalyzer {
private:
    string symbol;
    double point;
    CLogger *logger;

public:
    CPressureAnalyzer(string sym, CLogger *log)
        : symbol(sym), logger(log) {
        point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    }
    
    bool Update() {
        return true;
    }
    
    SPressureData GetData() {
        SPressureData pressure;
        
        double closeArray[];
        ArraySetAsSeries(closeArray, true);
        
        if (CopyClose(symbol, PERIOD_M1, 0, 5, closeArray) < 5) {
            pressure.buyPressure = 50.0;
            pressure.sellPressure = 50.0;
            pressure.bullishRatio = 0.5;
            pressure.bearishRatio = 0.5;
            pressure.confirmed = false;
            return pressure;
        }
        
        int upCandles = 0;
        for (int i = 0; i < 4; i++) {
            if (closeArray[i] > closeArray[i + 1]) upCandles++;
        }
        
        pressure.bullishRatio = (double)upCandles / 4.0;
        pressure.bearishRatio = (4.0 - (double)upCandles) / 4.0;
        pressure.buyPressure = pressure.bullishRatio * 100.0;
        pressure.sellPressure = pressure.bearishRatio * 100.0;
        pressure.confirmed = (upCandles >= 3 || upCandles <= 1);
        
        return pressure;
    }
};

//===================================================================
//                    MOMENTUM ANALYZER
//===================================================================

class CMomentumAnalyzer {
private:
    string symbol;
    double point;
    CLogger *logger;

public:
    CMomentumAnalyzer(string sym, CLogger *log)
        : symbol(sym), logger(log) {
        point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    }
    
    bool Update() {
        return true;
    }
    
    SMomentumData GetData() {
        SMomentumData mom;
        
        double closeArray[];
        double emaArray[];
        ArraySetAsSeries(closeArray, true);
        ArraySetAsSeries(emaArray, true);
        
        if (CopyClose(symbol, PERIOD_M1, 0, 10, closeArray) < 10) {
            mom.value = 0;
            mom.strength = 0;
            mom.isUptrend = false;
            mom.isDowntrend = false;
            return mom;
        }
        
        int emaHandle = iMA(symbol, PERIOD_M1, 20, 0, MODE_EMA, PRICE_CLOSE);
        if (emaHandle != INVALID_HANDLE) {
            CopyBuffer(emaHandle, 0, 0, 10, emaArray);
            IndicatorRelease(emaHandle);
        } else {
            for (int i = 0; i < 10; i++) emaArray[i] = closeArray[i];
        }
        
        mom.value = closeArray[0] > emaArray[0] ? 50.0 : -50.0;
        mom.strength = MathAbs(mom.value);
        mom.isUptrend = (mom.value > 30 && closeArray[0] > closeArray[1]);
        mom.isDowntrend = (mom.value < -30 && closeArray[0] < closeArray[1]);
        
        return mom;
    }
};

//===================================================================
//                    RISK MANAGER
//===================================================================

class CRiskManager {
private:
    string symbol;
    double point;
    double tickValue;
    CLogger *logger;
    int maxPositions;

public:
    CRiskManager(string sym, CLogger *log, int maxPos)
        : symbol(sym), logger(log), maxPositions(maxPos) {
        point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    }
    
    double CalculateLotSize(double stopLossPoints, double riskPercent) {
        if (stopLossPoints <= 0) return 0.01;
        
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        double riskAmount = equity * (riskPercent / 100.0);
        double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
        
        if (tickValue <= 0) return minLot;
        
        double calculatedLot = riskAmount / (stopLossPoints * tickValue);
        
        if (calculatedLot < minLot) return minLot;
        if (calculatedLot > maxLot) return maxLot;
        
        return calculatedLot;
    }
    
    bool IsTradeAllowed(double maxDrawdown) {
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        
        if (balance <= 0) return false;
        
        double drawdown = (balance - equity) / balance * 100.0;
        if (drawdown >= maxDrawdown) return false;
        
        int posCount = GetOpenPositionsCount();
        if (posCount >= maxPositions) return false;
        
        return true;
    }
    
    int GetOpenPositionsCount() {
        int count = 0;
        for (int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if (ticket > 0) count++;
        }
        return count;
    }
};

//===================================================================
//                    SIGNAL ENGINE
//===================================================================

class CSignalEngine {
private:
    string symbol;
    CPressureAnalyzer *pressureAnalyzer;
    CMomentumAnalyzer *momentumAnalyzer;
    CVolatilityAnalyzer *volatilityAnalyzer;
    CLogger *logger;
    datetime lastSignalTime;

public:
    CSignalEngine(string sym, CPressureAnalyzer *pres,
                  CMomentumAnalyzer *mom, CVolatilityAnalyzer *vol, CLogger *log)
        : symbol(sym), pressureAnalyzer(pres), momentumAnalyzer(mom),
          volatilityAnalyzer(vol), logger(log), lastSignalTime(0) {}
    
    STradeSignal AnalyzeSignal(double minPressure, double minPressureDiff, 
                                double minMomentum, double minSL, double maxSL,
                                double slMultiplier, double tpRatio) {
        STradeSignal signal;
        signal.signalType = SIGNAL_NONE;
        signal.confidence = 0;
        
        SVolatilityData volatility = volatilityAnalyzer->GetData();
        if (volatility.regime == 3) return signal; // EXTREME
        
        SPressureData pressure = pressureAnalyzer->GetData();
        SMomentumData momentum = momentumAnalyzer->GetData();
        
        double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
        double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        
        // BUY Signal
        if (momentum.isUptrend && pressure.buyPressure >= minPressure) {
            if ((pressure.buyPressure - pressure.sellPressure) >= minPressureDiff) {
                if (momentum.strength >= minMomentum) {
                    if (pressure.confirmed) {
                        double slDistance = minSL + (volatility.atr * slMultiplier);
                        if (slDistance > maxSL) slDistance = maxSL;
                        if (slDistance < minSL) slDistance = minSL;
                        
                        signal.signalType = SIGNAL_BUY;
                        signal.entryPrice = ask;
                        signal.stopLoss = ask - (slDistance * point);
                        signal.takeProfit = ask + (slDistance * tpRatio * point);
                        signal.confidence = 75.0;
                        
                        return signal;
                    }
                }
            }
        }
        
        // SELL Signal
        if (momentum.isDowntrend && pressure.sellPressure >= minPressure) {
            if ((pressure.sellPressure - pressure.buyPressure) >= minPressureDiff) {
                if (momentum.strength >= minMomentum) {
                    if (pressure.confirmed) {
                        double slDistance = minSL + (volatility.atr * slMultiplier);
                        if (slDistance > maxSL) slDistance = maxSL;
                        if (slDistance < minSL) slDistance = minSL;
                        
                        signal.signalType = SIGNAL_SELL;
                        signal.entryPrice = bid;
                        signal.stopLoss = bid + (slDistance * point);
                        signal.takeProfit = bid - (slDistance * tpRatio * point);
                        signal.confidence = 75.0;
                        
                        return signal;
                    }
                }
            }
        }
        
        return signal;
    }
    
    bool IsSignalNew(STradeSignal &signal) {
        if (signal.signalType == SIGNAL_NONE) return false;
        
        datetime currentTime = TimeCurrent();
        if (lastSignalTime == currentTime) return false;
        
        lastSignalTime = currentTime;
        return true;
    }
};

//===================================================================
//                    TRADE EXECUTOR
//===================================================================

class CTradeExecutor {
private:
    string symbol;
    ulong magicNumber;
    CLogger *logger;
    CTrade trade;

public:
    CTradeExecutor(string sym, ulong magic, CLogger *log)
        : symbol(sym), magicNumber(magic), logger(log) {
        trade.SetExpertMagicNumber(magicNumber);
    }
    
    bool IsSpreadAcceptable(double maxSpread) {
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        double spread = (SymbolInfoDouble(symbol, SYMBOL_ASK) - SymbolInfoDouble(symbol, SYMBOL_BID)) / point;
        return spread <= maxSpread;
    }
    
    ulong ExecuteSignal(STradeSignal &signal, double lot, ulong magic) {
        if (signal.signalType == SIGNAL_NONE) return 0;
        
        trade.SetExpertMagicNumber(magic);
        
        if (signal.signalType == SIGNAL_BUY) {
            if (trade.Buy(lot, symbol, signal.entryPrice, signal.stopLoss, signal.takeProfit, "VORAX_BUY")) {
                logger->Info("Execution", "BUY order sent");
                return trade.ResultOrder();
            }
        } else if (signal.signalType == SIGNAL_SELL) {
            if (trade.Sell(lot, symbol, signal.entryPrice, signal.stopLoss, signal.takeProfit, "VORAX_SELL")) {
                logger->Info("Execution", "SELL order sent");
                return trade.ResultOrder();
            }
        }
        
        return 0;
    }
};

//===================================================================
//                    POSITION MANAGER
//===================================================================

class CPositionManager {
private:
    string symbol;
    CVolatilityAnalyzer *volatility;
    CLogger *logger;
    ulong magicNumber;

public:
    CPositionManager(string sym, CVolatilityAnalyzer *vol, CLogger *log, ulong magic)
        : symbol(sym), volatility(vol), logger(log), magicNumber(magic) {}
    
    void UpdateAllPositions() {
        for (int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if (ticket == 0) continue;
            
            if (PositionSelectByTicket(ticket)) {
                string posSymbol = PositionGetString(POSITION_SYMBOL);
                ulong posMagic = PositionGetInteger(POSITION_MAGIC);
                
                if (posSymbol == symbol && posMagic == magicNumber) {
                    UpdateTrailingStop(ticket);
                }
            }
        }
    }
    
    void UpdateTrailingStop(ulong ticket) {
        if (!PositionSelectByTicket(ticket)) return;
        
        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double entry = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentTP = PositionGetDouble(POSITION_TP);
        double current = PositionGetDouble(POSITION_PRICE_CURRENT);
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        
        if (type == POSITION_TYPE_BUY) {
            double profit = (current - entry) / point;
            if (profit > 50) {
                SVolatilityData vol = volatility->GetData();
                double newSL = current - (vol.atr * 0.5);
                if (newSL > currentSL) {
                    CTrade trade;
                    trade.SetExpertMagicNumber(PositionGetInteger(POSITION_MAGIC));
                    trade.PositionModify(ticket, newSL, currentTP);
                }
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
                ulong posMagic = PositionGetInteger(POSITION_MAGIC);
                
                if (posSymbol == symbol && posMagic == magicNumber) {
                    count++;
                }
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

input group "=== GOLD (XAUUSD) ==="
input double Gold_RiskPercentPerTrade = 0.50;
input double Gold_MaxDailyLoss = 2.00;
input double Gold_MaxSpread = 1.5;
input double Gold_MinimumPressure = 65.0;
input double Gold_MinimumPressureDiff = 18.0;
input double Gold_MinimumMomentumStrength = 50.0;
input double Gold_MinSLPoints = 0.50;
input double Gold_MaxSLPoints = 2.50;
input double Gold_SLVolatilityMultiplier = 1.2;
input double Gold_TPRiskRewardRatio = 1.50;

input group "=== BITCOIN (BTCUSD) ==="
input double Bitcoin_RiskPercentPerTrade = 0.50;
input double Bitcoin_MaxDailyLoss = 2.00;
input double Bitcoin_MaxSpread = 75.0;
input double Bitcoin_MinimumPressure = 62.0;
input double Bitcoin_MinimumPressureDiff = 16.0;
input double Bitcoin_MinimumMomentumStrength = 48.0;
input double Bitcoin_MinSLPoints = 50.0;
input double Bitcoin_MaxSLPoints = 300.0;
input double Bitcoin_SLVolatilityMultiplier = 1.3;
input double Bitcoin_TPRiskRewardRatio = 1.50;

input group "=== GENERAL SETTINGS ==="
input int MaxOpenPositions = 2;

//===================================================================
//                    GLOBAL VARIABLES
//===================================================================

CLogger *logger;

// Gold
CRiskManager *goldRiskManager;
CVolatilityAnalyzer *goldVolatility;
CPressureAnalyzer *goldPressure;
CMomentumAnalyzer *goldMomentum;
CSignalEngine *goldSignal;
CTradeExecutor *goldExecutor;
CPositionManager *goldPositionManager;

// Bitcoin
CRiskManager *bitcoinRiskManager;
CVolatilityAnalyzer *bitcoinVolatility;
CPressureAnalyzer *bitcoinPressure;
CMomentumAnalyzer *bitcoinMomentum;
CSignalEngine *bitcoinSignal;
CTradeExecutor *bitcoinExecutor;
CPositionManager *bitcoinPositionManager;

string goldSymbol = "XAUUSD";
string bitcoinSymbol = "BTCUSD";

//===================================================================
//                    INITIALIZATION
//===================================================================

int OnInit() {
    logger = new CLogger(DebugMode);
    logger->Info("EA", "VORAX™ v2.0.3 Initializing");
    
    // Gold Initialization
    if (TradeGold) {
        goldRiskManager = new CRiskManager(goldSymbol, logger, MaxOpenPositions);
        goldVolatility = new CVolatilityAnalyzer(goldSymbol, logger);
        goldPressure = new CPressureAnalyzer(goldSymbol, logger);
        goldMomentum = new CMomentumAnalyzer(goldSymbol, logger);
        goldSignal = new CSignalEngine(goldSymbol, goldPressure, goldMomentum, goldVolatility, logger);
        goldExecutor = new CTradeExecutor(goldSymbol, 123456, logger);
        goldPositionManager = new CPositionManager(goldSymbol, goldVolatility, logger, 123456);
        
        logger->Info("Init", "Gold initialized successfully");
    }
    
    // Bitcoin Initialization
    if (TradeBitcoin) {
        bitcoinRiskManager = new CRiskManager(bitcoinSymbol, logger, MaxOpenPositions);
        bitcoinVolatility = new CVolatilityAnalyzer(bitcoinSymbol, logger);
        bitcoinPressure = new CPressureAnalyzer(bitcoinSymbol, logger);
        bitcoinMomentum = new CMomentumAnalyzer(bitcoinSymbol, logger);
        bitcoinSignal = new CSignalEngine(bitcoinSymbol, bitcoinPressure, bitcoinMomentum, bitcoinVolatility, logger);
        bitcoinExecutor = new CTradeExecutor(bitcoinSymbol, 654321, logger);
        bitcoinPositionManager = new CPositionManager(bitcoinSymbol, bitcoinVolatility, logger, 654321);
        
        logger->Info("Init", "Bitcoin initialized successfully");
    }
    
    logger->Info("EA", "VORAX™ Ready for Trading");
    return INIT_SUCCEEDED;
}

//===================================================================
//                    DEINITIALIZATION
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
    if (!goldRiskManager || !goldExecutor || !goldPositionManager) return;
    
    goldVolatility->Update();
    goldPressure->Update();
    goldMomentum->Update();
    
    goldPositionManager->UpdateAllPositions();
    
    STradeSignal signal = goldSignal->AnalyzeSignal(
        Gold_MinimumPressure,
        Gold_MinimumPressureDiff,
        Gold_MinimumMomentumStrength,
        Gold_MinSLPoints,
        Gold_MaxSLPoints,
        Gold_SLVolatilityMultiplier,
        Gold_TPRiskRewardRatio
    );
    
    if (signal.signalType != SIGNAL_NONE && goldSignal->IsSignalNew(signal)) {
        if (goldPositionManager->GetOpenPositionsCount() < MaxOpenPositions) {
            if (goldRiskManager->IsTradeAllowed(Gold_MaxDailyLoss)) {
                double point = SymbolInfoDouble(goldSymbol, SYMBOL_POINT);
                double slPoints = MathAbs(signal.entryPrice - signal.stopLoss) / point;
                double lot = goldRiskManager->CalculateLotSize(slPoints, Gold_RiskPercentPerTrade);
                
                if (lot > 0 && goldExecutor->IsSpreadAcceptable(Gold_MaxSpread)) {
                    goldExecutor->ExecuteSignal(signal, lot, 123456);
                }
            }
        }
    }
}

void ProcessBitcoin() {
    if (!bitcoinVolatility || !bitcoinPressure || !bitcoinMomentum || !bitcoinSignal) return;
    if (!bitcoinRiskManager || !bitcoinExecutor || !bitcoinPositionManager) return;
    
    bitcoinVolatility->Update();
    bitcoinPressure->Update();
    bitcoinMomentum->Update();
    
    bitcoinPositionManager->UpdateAllPositions();
    
    STradeSignal signal = bitcoinSignal->AnalyzeSignal(
        Bitcoin_MinimumPressure,
        Bitcoin_MinimumPressureDiff,
        Bitcoin_MinimumMomentumStrength,
        Bitcoin_MinSLPoints,
        Bitcoin_MaxSLPoints,
        Bitcoin_SLVolatilityMultiplier,
        Bitcoin_TPRiskRewardRatio
    );
    
    if (signal.signalType != SIGNAL_NONE && bitcoinSignal->IsSignalNew(signal)) {
        if (bitcoinPositionManager->GetOpenPositionsCount() < MaxOpenPositions) {
            if (bitcoinRiskManager->IsTradeAllowed(Bitcoin_MaxDailyLoss)) {
                double point = SymbolInfoDouble(bitcoinSymbol, SYMBOL_POINT);
                double slPoints = MathAbs(signal.entryPrice - signal.stopLoss) / point;
                double lot = bitcoinRiskManager->CalculateLotSize(slPoints, Bitcoin_RiskPercentPerTrade);
                
                if (lot > 0 && bitcoinExecutor->IsSpreadAcceptable(Bitcoin_MaxSpread)) {
                    bitcoinExecutor->ExecuteSignal(signal, lot, 654321);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
// END OF VORAX_FINAL.mq5
//+------------------------------------------------------------------+
