//+------------------------------------------------------------------+
//|                                              VORAX_COMPLETE_FIXED.mq5 |
//|                         VORAX™ Ultra-Fast Scalping EA - FIXED VERSION    |
//|                           Copyright 2024 - Professional Edition    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      "https://github.com/wesamtaraf1984-ux"
#property version   "2.0.2"
#property strict
#property description "VORAX™ Complete - Ultra-Fast Multi-Asset Scalping EA"

#include <Trade\Trade.mqh>

//===================================================================
//                    ENUMS & DEFINES
//===================================================================

enum ENUM_SIGNAL_TYPE { SIGNAL_NONE, SIGNAL_BUY, SIGNAL_SELL };
enum ENUM_VOLATILITY_REGIME { REGIME_LOW, REGIME_NORMAL, REGIME_HIGH, REGIME_EXTREME };

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
    ENUM_VOLATILITY_REGIME regime;
};

struct STradeSignal {
    ENUM_SIGNAL_TYPE signalType;
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
    SSymbolConfig config;
    CLogger *logger;
    double atrBuffer[];
    double closeBuffer[];

public:
    CVolatilityAnalyzer(string sym, SSymbolConfig cfg, CLogger *log)
        : symbol(sym), config(cfg), logger(log) {
        point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        ArraySetAsSeries(atrBuffer, true);
        ArraySetAsSeries(closeBuffer, true);
    }
    
    bool Update() {
        int atrHandle = iATR(symbol, PERIOD_M1, ATR_PERIOD);
        if (atrHandle == INVALID_HANDLE) return false;
        if (CopyBuffer(atrHandle, 0, 0, LOOKBACK_BARS, atrBuffer) <= 0) return false;
        if (CopyClose(symbol, PERIOD_M1, 0, LOOKBACK_BARS, closeBuffer) <= 0) return false;
        IndicatorRelease(atrHandle);
        return true;
    }
    
    SVolatilityData GetData() {
        SVolatilityData vol;
        vol.atr = (ArraySize(atrBuffer) > 0) ? atrBuffer[0] : 0;
        
        if (vol.atr < 0.5) vol.regime = REGIME_LOW;
        else if (vol.atr > 2.0) vol.regime = REGIME_EXTREME;
        else vol.regime = REGIME_NORMAL;
        
        return vol;
    }
    
    bool IsExtremeVolatility() {
        return GetData().regime == REGIME_EXTREME;
    }
};

//===================================================================
//                    PRESSURE ANALYZER
//===================================================================

class CPressureAnalyzer {
private:
    string symbol;
    double point;
    SSymbolConfig config;
    CLogger *logger;

public:
    CPressureAnalyzer(string sym, SSymbolConfig cfg, CLogger *log)
        : symbol(sym), config(cfg), logger(log) {
        point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    }
    
    bool Update() {
        return true;
    }
    
    SPressureData GetData() {
        SPressureData pressure;
        
        double closeArray[];
        ArraySetAsSeries(closeArray, true);
        CopyClose(symbol, PERIOD_M1, 0, 5, closeArray);
        
        int upCandles = 0;
        for (int i = 0; i < 4; i++) {
            if (closeArray[i] > closeArray[i+1]) upCandles++;
        }
        
        pressure.bullishRatio = upCandles / 4.0;
        pressure.bearishRatio = (4 - upCandles) / 4.0;
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
    SSymbolConfig config;
    CLogger *logger;

public:
    CMomentumAnalyzer(string sym, SSymbolConfig cfg, CLogger *log)
        : symbol(sym), config(cfg), logger(log) {
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
        
        CopyClose(symbol, PERIOD_M1, 0, 10, closeArray);
        
        int emaHandle = iMA(symbol, PERIOD_M1, 20, 0, MODE_EMA, PRICE_CLOSE);
        if (emaHandle != INVALID_HANDLE) {
            CopyBuffer(emaHandle, 0, 0, 10, emaArray);
            IndicatorRelease(emaHandle);
        }
        
        mom.value = closeArray[0] > emaArray[0] ? 50 : -50;
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
    SSymbolConfig config;
    CLogger *logger;

public:
    CRiskManager(string sym, SSymbolConfig cfg, CLogger *log)
        : symbol(sym), config(cfg), logger(log) {
        point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    }
    
    double CalculateLotSize(double stopLossPoints) {
        if (stopLossPoints <= 0) return 0.01;
        
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        double riskAmount = equity * (config.maxRiskPerTrade / 100.0);
        double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
        
        if (tickValue <= 0) return minLot;
        
        double calculatedLot = riskAmount / (stopLossPoints * tickValue);
        
        if (calculatedLot < minLot) return minLot;
        if (calculatedLot > maxLot) return maxLot;
        
        return calculatedLot;
    }
    
    bool IsTradeAllowed() {
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        
        if (balance <= 0) return false;
        
        double drawdown = (balance - equity) / balance * 100.0;
        if (drawdown >= config.maxDrawdown) return false;
        
        if (PositionsTotal() >= config.maxPositions) return false;
        
        return true;
    }
};

//===================================================================
//                    SIGNAL ENGINE
//===================================================================

class CSignalEngine {
private:
    string symbol;
    SSymbolConfig config;
    CPressureAnalyzer *pressureAnalyzer;
    CMomentumAnalyzer *momentumAnalyzer;
    CVolatilityAnalyzer *volatilityAnalyzer;
    CLogger *logger;
    datetime lastSignalTime;

public:
    CSignalEngine(string sym, SSymbolConfig cfg, CPressureAnalyzer *pres,
                  CMomentumAnalyzer *mom, CVolatilityAnalyzer *vol, CLogger *log)
        : symbol(sym), config(cfg), pressureAnalyzer(pres), momentumAnalyzer(mom),
          volatilityAnalyzer(vol), logger(log), lastSignalTime(0) {}
    
    STradeSignal AnalyzeSignal() {
        STradeSignal signal;
        signal.signalType = SIGNAL_NONE;
        signal.confidence = 0;
        
        SVolatilityData volatility = volatilityAnalyzer->GetData();
        if (volatility.regime == REGIME_EXTREME) return signal;
        
        SPressureData pressure = pressureAnalyzer->GetData();
        SMomentumData momentum = momentumAnalyzer->GetData();
        
        double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
        double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
        
        // BUY Signal
        if (momentum.isUptrend && pressure.buyPressure >= config.minimumPressure) {
            if ((pressure.buyPressure - pressure.sellPressure) >= config.minimumPressureDifference) {
                if (momentum.strength >= config.minimumMomentumStrength) {
                    if (pressure.confirmed) {
                        double slDistance = config.minSLPoints + (volatility.atr * config.slVolatilityMultiplier);
                        slDistance = MathMin(slDistance, config.maxSLPoints);
                        slDistance = MathMax(slDistance, config.minSLPoints);
                        
                        signal.signalType = SIGNAL_BUY;
                        signal.entryPrice = ask;
                        signal.stopLoss = ask - (slDistance * SymbolInfoDouble(symbol, SYMBOL_POINT));
                        signal.takeProfit = ask + (slDistance * config.tpRiskRewardRatio * SymbolInfoDouble(symbol, SYMBOL_POINT));
                        signal.confidence = 75.0;
                        
                        return signal;
                    }
                }
            }
        }
        
        // SELL Signal
        if (momentum.isDowntrend && pressure.sellPressure >= config.minimumPressure) {
            if ((pressure.sellPressure - pressure.buyPressure) >= config.minimumPressureDifference) {
                if (momentum.strength >= config.minimumMomentumStrength) {
                    if (pressure.confirmed) {
                        double slDistance = config.minSLPoints + (volatility.atr * config.slVolatilityMultiplier);
                        slDistance = MathMin(slDistance, config.maxSLPoints);
                        slDistance = MathMax(slDistance, config.minSLPoints);
                        
                        signal.signalType = SIGNAL_SELL;
                        signal.entryPrice = bid;
                        signal.stopLoss = bid + (slDistance * SymbolInfoDouble(symbol, SYMBOL_POINT));
                        signal.takeProfit = bid - (slDistance * config.tpRiskRewardRatio * SymbolInfoDouble(symbol, SYMBOL_POINT));
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
        if (lastSignalTime == TimeCurrent()) return false;
        lastSignalTime = TimeCurrent();
        return true;
    }
};

//===================================================================
//                    TRADE EXECUTOR
//===================================================================

class CTradeExecutor {
private:
    string symbol;
    SSymbolConfig config;
    CRiskManager *riskManager;
    CLogger *logger;
    CTrade trade;

public:
    CTradeExecutor(string sym, SSymbolConfig cfg, CRiskManager *risk, CLogger *log)
        : symbol(sym), config(cfg), riskManager(risk), logger(log) {
        trade.SetExpertMagicNumber(config.magicNumber);
    }
    
    bool IsSpreadAcceptable() {
        double spread = (SymbolInfoDouble(symbol, SYMBOL_ASK) - SymbolInfoDouble(symbol, SYMBOL_BID)) / SymbolInfoDouble(symbol, SYMBOL_POINT);
        return spread <= config.maxSpread;
    }
    
    ulong ExecuteSignal(STradeSignal &signal, double lot) {
        if (signal.signalType == SIGNAL_NONE) return 0;
        if (!IsSpreadAcceptable()) return 0;
        if (!riskManager->IsTradeAllowed()) return 0;
        
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
    SSymbolConfig config;
    CTradeExecutor *executor;
    CVolatilityAnalyzer *volatility;
    CLogger *logger;

public:
    CPositionManager(string sym, SSymbolConfig cfg, CTradeExecutor *exec,
                    CVolatilityAnalyzer *vol, CLogger *log)
        : symbol(sym), config(cfg), executor(exec), volatility(vol), logger(log) {}
    
    void UpdateAllPositions() {
        for (int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if (ticket == 0) continue;
            
            if (PositionSelectByTicket(ticket)) {
                string posSymbol = PositionGetString(POSITION_SYMBOL);
                ulong posMagic = PositionGetInteger(POSITION_MAGIC);
                
                if (posSymbol == symbol && posMagic == config.magicNumber) {
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
                    trade.SetExpertMagicNumber(config.magicNumber);
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
                
                if (posSymbol == symbol && posMagic == config.magicNumber) {
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

CRiskManager *goldRiskManager;
CVolatilityAnalyzer *goldVolatility;
CPressureAnalyzer *goldPressure;
CMomentumAnalyzer *goldMomentum;
CSignalEngine *goldSignal;
CTradeExecutor *goldExecutor;
CPositionManager *goldPositionManager;

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
    logger->Info("EA", "VORAX™ v2.0.2 Initializing");
    
    // Gold Configuration
    if (TradeGold) {
        SSymbolConfig goldConfig;
        goldConfig.symbol = goldSymbol;
        goldConfig.magicNumber = 123456;
        goldConfig.maxRiskPerTrade = Gold_RiskPercentPerTrade;
        goldConfig.maxDailyLoss = Gold_MaxDailyLoss;
        goldConfig.maxDrawdown = 5.00;
        goldConfig.maxSpread = Gold_MaxSpread;
        goldConfig.minimumPressure = Gold_MinimumPressure;
        goldConfig.minimumPressureDifference = Gold_MinimumPressureDiff;
        goldConfig.minimumMomentumStrength = Gold_MinimumMomentumStrength;
        goldConfig.minSLPoints = Gold_MinSLPoints;
        goldConfig.maxSLPoints = Gold_MaxSLPoints;
        goldConfig.slVolatilityMultiplier = Gold_SLVolatilityMultiplier;
        goldConfig.tpRiskRewardRatio = Gold_TPRiskRewardRatio;
        goldConfig.maxPositions = MaxOpenPositions;
        
        goldRiskManager = new CRiskManager(goldSymbol, goldConfig, logger);
        goldVolatility = new CVolatilityAnalyzer(goldSymbol, goldConfig, logger);
        goldPressure = new CPressureAnalyzer(goldSymbol, goldConfig, logger);
        goldMomentum = new CMomentumAnalyzer(goldSymbol, goldConfig, logger);
        goldSignal = new CSignalEngine(goldSymbol, goldConfig, goldPressure, goldMomentum, goldVolatility, logger);
        goldExecutor = new CTradeExecutor(goldSymbol, goldConfig, goldRiskManager, logger);
        goldPositionManager = new CPositionManager(goldSymbol, goldConfig, goldExecutor, goldVolatility, logger);
        
        logger->Info("Init", "Gold initialized successfully");
    }
    
    // Bitcoin Configuration
    if (TradeBitcoin) {
        SSymbolConfig bitcoinConfig;
        bitcoinConfig.symbol = bitcoinSymbol;
        bitcoinConfig.magicNumber = 654321;
        bitcoinConfig.maxRiskPerTrade = Bitcoin_RiskPercentPerTrade;
        bitcoinConfig.maxDailyLoss = Bitcoin_MaxDailyLoss;
        bitcoinConfig.maxDrawdown = 5.00;
        bitcoinConfig.maxSpread = Bitcoin_MaxSpread;
        bitcoinConfig.minimumPressure = Bitcoin_MinimumPressure;
        bitcoinConfig.minimumPressureDifference = Bitcoin_MinimumPressureDiff;
        bitcoinConfig.minimumMomentumStrength = Bitcoin_MinimumMomentumStrength;
        bitcoinConfig.minSLPoints = Bitcoin_MinSLPoints;
        bitcoinConfig.maxSLPoints = Bitcoin_MaxSLPoints;
        bitcoinConfig.slVolatilityMultiplier = Bitcoin_SLVolatilityMultiplier;
        bitcoinConfig.tpRiskRewardRatio = Bitcoin_TPRiskRewardRatio;
        bitcoinConfig.maxPositions = MaxOpenPositions;
        
        bitcoinRiskManager = new CRiskManager(bitcoinSymbol, bitcoinConfig, logger);
        bitcoinVolatility = new CVolatilityAnalyzer(bitcoinSymbol, bitcoinConfig, logger);
        bitcoinPressure = new CPressureAnalyzer(bitcoinSymbol, bitcoinConfig, logger);
        bitcoinMomentum = new CMomentumAnalyzer(bitcoinSymbol, bitcoinConfig, logger);
        bitcoinSignal = new CSignalEngine(bitcoinSymbol, bitcoinConfig, bitcoinPressure, bitcoinMomentum, bitcoinVolatility, logger);
        bitcoinExecutor = new CTradeExecutor(bitcoinSymbol, bitcoinConfig, bitcoinRiskManager, logger);
        bitcoinPositionManager = new CPositionManager(bitcoinSymbol, bitcoinConfig, bitcoinExecutor, bitcoinVolatility, logger);
        
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
    
    goldVolatility->Update();
    goldPressure->Update();
    goldMomentum->Update();
    
    goldPositionManager->UpdateAllPositions();
    
    STradeSignal signal = goldSignal->AnalyzeSignal();
    
    if (signal.signalType != SIGNAL_NONE && goldSignal->IsSignalNew(signal)) {
        if (goldPositionManager->GetOpenPositionsCount() < MaxOpenPositions) {
            double slPoints = MathAbs(signal.entryPrice - signal.stopLoss) / SymbolInfoDouble(goldSymbol, SYMBOL_POINT);
            double lot = goldRiskManager->CalculateLotSize(slPoints);
            if (lot > 0) goldExecutor->ExecuteSignal(signal, lot);
        }
    }
}

void ProcessBitcoin() {
    if (!bitcoinVolatility || !bitcoinPressure || !bitcoinMomentum || !bitcoinSignal) return;
    
    bitcoinVolatility->Update();
    bitcoinPressure->Update();
    bitcoinMomentum->Update();
    
    bitcoinPositionManager->UpdateAllPositions();
    
    STradeSignal signal = bitcoinSignal->AnalyzeSignal();
    
    if (signal.signalType != SIGNAL_NONE && bitcoinSignal->IsSignalNew(signal)) {
        if (bitcoinPositionManager->GetOpenPositionsCount() < MaxOpenPositions) {
            double slPoints = MathAbs(signal.entryPrice - signal.stopLoss) / SymbolInfoDouble(bitcoinSymbol, SYMBOL_POINT);
            double lot = bitcoinRiskManager->CalculateLotSize(slPoints);
            if (lot > 0) bitcoinExecutor->ExecuteSignal(signal, lot);
        }
    }
}

//+------------------------------------------------------------------+
// END OF VORAX_COMPLETE_FIXED.mq5
//+------------------------------------------------------------------+
