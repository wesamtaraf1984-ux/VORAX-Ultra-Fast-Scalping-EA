//+------------------------------------------------------------------+
//|                                                       VORAX_EA.mq5 |
//|                                   VORAX™ Ultra-Fast Scalping EA   |
//|                           Copyright 2024 - Professional Edition   |
//|                                                                    |
//|  HUNT VOLATILITY. EXPLOIT MOMENTUM.                              |
//+------------------------------------------------------------------+

#property copyright "Copyright 2024"
#property link      "https://github.com/wesamtaraf1984-ux"
#property version   "2.0.1"
#property strict
#property description "VORAX™ - Ultra-Fast Multi-Asset Scalping EA"

//--- Includes
#include <Trade\Trade.mqh>
#include "Include/VORAX_Defines.mqh"
#include "Include/VORAX_Utils.mqh"
#include "Include/VORAX_SymbolConfig.mqh"
#include "Include/VORAX_Volatility.mqh"
#include "Include/VORAX_Pressure.mqh"
#include "Include/VORAX_Momentum.mqh"
#include "Include/VORAX_Risk.mqh"
#include "Include/VORAX_Signal.mqh"
#include "Include/VORAX_Execution.mqh"
#include "Include/VORAX_PositionManager.mqh"
#include "Include/VORAX_Reinforcement.mqh"
#include "Include/VORAX_Dashboard.mqh"
#include "Include/VORAX_News.mqh"
#include "Include/VORAX_SessionManager.mqh"

//===================================================================
//                      INPUT PARAMETERS
//===================================================================

input group "=== GENERAL SETTINGS ==="
input bool TradeGold = true;                              // Trade XAUUSD
input bool TradeBitcoin = true;                           // Trade BTCUSD
input bool DebugMode = false;                             // Enable Debug Logging
input bool ShowDashboard = true;                          // Show Dashboard on Chart

input group "=== GOLD (XAUUSD) - RISK MANAGEMENT ==="
input double Gold_RiskPercentPerTrade = 0.50;             // Risk % per trade (Gold)
input double Gold_MaxDailyLoss = 2.00;                    // Max Daily Loss % (Gold)
input double Gold_MaxDrawdown = 5.00;                     // Max Drawdown % (Gold)
input double Gold_MaxSpread = 1.5;                        // Max Spread Points (Gold)

input group "=== GOLD (XAUUSD) - ENTRY SIGNALS ==="
input double Gold_MinimumPressure = 65.0;                 // Minimum Pressure Level (Gold)
input double Gold_MinimumPressureDiff = 18.0;             // Min Pressure Difference (Gold)
input double Gold_MinimumMomentumStrength = 50.0;         // Min Momentum Strength (Gold)

input group "=== GOLD (XAUUSD) - STOP LOSS & TP ==="
input double Gold_MinSLPoints = 0.50;                     // Min SL Points (Gold)
input double Gold_MaxSLPoints = 2.50;                     // Max SL Points (Gold)
input double Gold_SLVolatilityMultiplier = 1.2;           // SL Volatility Multiplier (Gold)
input double Gold_TPRiskRewardRatio = 1.50;               // TP Risk/Reward Ratio (Gold)

input group "=== GOLD (XAUUSD) - SESSION ==="
input string Gold_SessionStart = "09:00";                 // Session Start (Gold)
input string Gold_SessionEnd = "17:00";                   // Session End (Gold)
input bool Gold_TradeOnSession = true;                    // Trade on Session (Gold)

input group "=== BITCOIN (BTCUSD) - RISK MANAGEMENT ==="
input double Bitcoin_RiskPercentPerTrade = 0.50;          // Risk % per trade (Bitcoin)
input double Bitcoin_MaxDailyLoss = 2.00;                 // Max Daily Loss % (Bitcoin)
input double Bitcoin_MaxDrawdown = 5.00;                  // Max Drawdown % (Bitcoin)
input double Bitcoin_MaxSpread = 75.0;                    // Max Spread Points (Bitcoin)

input group "=== BITCOIN (BTCUSD) - ENTRY SIGNALS ==="
input double Bitcoin_MinimumPressure = 62.0;              // Minimum Pressure Level (Bitcoin)
input double Bitcoin_MinimumPressureDiff = 16.0;          // Min Pressure Difference (Bitcoin)
input double Bitcoin_MinimumMomentumStrength = 48.0;      // Min Momentum Strength (Bitcoin)

input group "=== BITCOIN (BTCUSD) - STOP LOSS & TP ==="
input double Bitcoin_MinSLPoints = 50.0;                  // Min SL Points (Bitcoin)
input double Bitcoin_MaxSLPoints = 300.0;                 // Max SL Points (Bitcoin)
input double Bitcoin_SLVolatilityMultiplier = 1.3;        // SL Volatility Multiplier (Bitcoin)
input double Bitcoin_TPRiskRewardRatio = 1.50;            // TP Risk/Reward Ratio (Bitcoin)

input group "=== BITCOIN (BTCUSD) - SESSION ==="
input string Bitcoin_SessionStart = "00:00";              // Session Start (Bitcoin)
input string Bitcoin_SessionEnd = "23:59";                // Session End (Bitcoin)
input bool Bitcoin_TradeOnSession = true;                 // Trade on Session (Bitcoin)

input group "=== REINFORCEMENT (ADD-ON) ==="
input bool AllowReinforcement = true;                     // Allow Position Add-Ons
input int MaxReinforcementTrades = 1;                     // Max Add-On Count
input double MinTimeBetweenReinforcement = 30.0;          // Min Seconds Between Add-Ons

input group "=== NEWS FILTER ==="
input bool NewsFilterEnabled = false;                     // Enable News Filter
input int NewsMinutesBefore = 5;                          // Minutes Before News
input int NewsMinutesAfter = 10;                          // Minutes After News

input group "=== EXECUTION ==="
input int MaxTradesPerDay = 20;                           // Max Trades Per Day
input int MaxTradesPerHour = 5;                           // Max Trades Per Hour
input int MaxOpenPositions = 2;                           // Max Open Positions

//===================================================================
//                      GLOBAL VARIABLES
//===================================================================

// Managers
CLogger *logger;
CSymbolConfigManager *configManager;
CRiskManager *goldRiskManager;
CRiskManager *bitcoinRiskManager;

// Gold Analyzers
CVolatilityAnalyzer *goldVolatility;
CPressureAnalyzer *goldPressure;
CMomentumAnalyzer *goldMomentum;
CSignalEngine *goldSignal;
CTradeExecutor *goldExecutor;
CPositionManager *goldPositionManager;
CReinforcementManager *goldReinforcement;
CSessionManager *goldSession;

// Bitcoin Analyzers
CVolatilityAnalyzer *bitcoinVolatility;
CPressureAnalyzer *bitcoinPressure;
CMomentumAnalyzer *bitcoinMomentum;
CSignalEngine *bitcoinSignal;
CTradeExecutor *bitcoinExecutor;
CPositionManager *bitcoinPositionManager;
CReinforcementManager *bitcoinReinforcement;
CSessionManager *bitcoinSession;

// Dashboard
CDashboard *goldDashboard;
CDashboard *bitcoinDashboard;

// News Filter
CNewsFilter *newsFilter;

// State Variables
datetime lastGoldSignalTime = 0;
datetime lastBitcoinSignalTime = 0;
string goldSymbol = "XAUUSD";
string bitcoinSymbol = "BTCUSD";
ENUM_EA_STATUS eaStatus = EA_READY;

//===================================================================
//                    INITIALIZATION
//===================================================================

int OnInit()
{
    // Initialize Logger
    logger = new CLogger(DebugMode);
    logger->Info("EA", "=" + string('=', 60) + "=");
    logger->Info("EA", "VORAX™ Ultra-Fast Scalping EA v2.0.1 INITIALIZING");
    logger->Info("EA", "=" + string('=', 60) + "=");
    
    // Initialize Config Manager
    configManager = new CSymbolConfigManager(logger);
    
    // Initialize News Filter
    newsFilter = new CNewsFilter(NewsFilterEnabled, NewsMinutesBefore, NewsMinutesAfter, logger);
    
    // Detect and initialize symbols
    if (!CSymbolUtils::DetectSymbol(goldSymbol)) {
        logger->Error("Init", "Gold symbol not found: " + goldSymbol);
        return INIT_FAILED;
    }
    
    if (!CSymbolUtils::DetectSymbol(bitcoinSymbol)) {
        logger->Error("Init", "Bitcoin symbol not found: " + bitcoinSymbol);
        return INIT_FAILED;
    }
    
    logger->Info("Init", "Detected Gold Symbol: " + goldSymbol);
    logger->Info("Init", "Detected Bitcoin Symbol: " + bitcoinSymbol);
    
    // ===== INITIALIZE GOLD =====
    if (TradeGold) {
        SSymbolConfig *goldConfig = configManager->GetGoldConfig();
        goldConfig->symbol = goldSymbol;
        goldConfig->maxRiskPerTrade = Gold_RiskPercentPerTrade;
        goldConfig->maxDailyLoss = Gold_MaxDailyLoss;
        goldConfig->maxDrawdown = Gold_MaxDrawdown;
        goldConfig->maxSpread = Gold_MaxSpread;
        goldConfig->minimumPressure = Gold_MinimumPressure;
        goldConfig->minimumPressureDifference = Gold_MinimumPressureDiff;
        goldConfig->minimumMomentumStrength = Gold_MinimumMomentumStrength;
        goldConfig->minSLPoints = Gold_MinSLPoints;
        goldConfig->maxSLPoints = Gold_MaxSLPoints;
        goldConfig->slVolatilityMultiplier = Gold_SLVolatilityMultiplier;
        goldConfig->tpRiskRewardRatio = Gold_TPRiskRewardRatio;
        goldConfig->sessionStart = Gold_SessionStart;
        goldConfig->sessionEnd = Gold_SessionEnd;
        goldConfig->tradeOnSession = Gold_TradeOnSession;
        goldConfig->allowReinforcement = AllowReinforcement;
        goldConfig->maxReinforcementTrades = MaxReinforcementTrades;
        goldConfig->minTimeBetweenReinforcement = MinTimeBetweenReinforcement;
        
        goldRiskManager = new CRiskManager(goldSymbol, goldConfig, logger);
        goldVolatility = new CVolatilityAnalyzer(goldSymbol, goldConfig, logger);
        goldPressure = new CPressureAnalyzer(goldSymbol, goldConfig, logger);
        goldMomentum = new CMomentumAnalyzer(goldSymbol, goldConfig, logger);
        goldSignal = new CSignalEngine(goldSymbol, goldConfig, goldPressure, goldMomentum, goldVolatility, logger);
        goldExecutor = new CTradeExecutor(goldSymbol, goldConfig, goldRiskManager, logger);
        goldPositionManager = new CPositionManager(goldSymbol, goldConfig, goldExecutor, goldVolatility, logger);
        goldReinforcement = new CReinforcementManager(goldSymbol, goldConfig, goldSignal, goldExecutor, goldPositionManager, goldRiskManager, logger);
        goldSession = new CSessionManager(goldConfig, logger);
        
        if (ShowDashboard) {
            goldDashboard = new CDashboard(goldSymbol, goldConfig, logger);
        }
        
        logger->Info("Init", "Gold (" + goldSymbol + ") initialized successfully");
    }
    
    // ===== INITIALIZE BITCOIN =====
    if (TradeBitcoin) {
        SSymbolConfig *bitcoinConfig = configManager->GetBitcoinConfig();
        bitcoinConfig->symbol = bitcoinSymbol;
        bitcoinConfig->maxRiskPerTrade = Bitcoin_RiskPercentPerTrade;
        bitcoinConfig->maxDailyLoss = Bitcoin_MaxDailyLoss;
        bitcoinConfig->maxDrawdown = Bitcoin_MaxDrawdown;
        bitcoinConfig->maxSpread = Bitcoin_MaxSpread;
        bitcoinConfig->minimumPressure = Bitcoin_MinimumPressure;
        bitcoinConfig->minimumPressureDifference = Bitcoin_MinimumPressureDiff;
        bitcoinConfig->minimumMomentumStrength = Bitcoin_MinimumMomentumStrength;
        bitcoinConfig->minSLPoints = Bitcoin_MinSLPoints;
        bitcoinConfig->maxSLPoints = Bitcoin_MaxSLPoints;
        bitcoinConfig->slVolatilityMultiplier = Bitcoin_SLVolatilityMultiplier;
        bitcoinConfig->tpRiskRewardRatio = Bitcoin_TPRiskRewardRatio;
        bitcoinConfig->sessionStart = Bitcoin_SessionStart;
        bitcoinConfig->sessionEnd = Bitcoin_SessionEnd;
        bitcoinConfig->tradeOnSession = Bitcoin_TradeOnSession;
        bitcoinConfig->allowReinforcement = AllowReinforcement;
        bitcoinConfig->maxReinforcementTrades = MaxReinforcementTrades;
        bitcoinConfig->minTimeBetweenReinforcement = MinTimeBetweenReinforcement;
        
        bitcoinRiskManager = new CRiskManager(bitcoinSymbol, bitcoinConfig, logger);
        bitcoinVolatility = new CVolatilityAnalyzer(bitcoinSymbol, bitcoinConfig, logger);
        bitcoinPressure = new CPressureAnalyzer(bitcoinSymbol, bitcoinConfig, logger);
        bitcoinMomentum = new CMomentumAnalyzer(bitcoinSymbol, bitcoinConfig, logger);
        bitcoinSignal = new CSignalEngine(bitcoinSymbol, bitcoinConfig, bitcoinPressure, bitcoinMomentum, bitcoinVolatility, logger);
        bitcoinExecutor = new CTradeExecutor(bitcoinSymbol, bitcoinConfig, bitcoinRiskManager, logger);
        bitcoinPositionManager = new CPositionManager(bitcoinSymbol, bitcoinConfig, bitcoinExecutor, bitcoinVolatility, logger);
        bitcoinReinforcement = new CReinforcementManager(bitcoinSymbol, bitcoinConfig, bitcoinSignal, bitcoinExecutor, bitcoinPositionManager, bitcoinRiskManager, logger);
        bitcoinSession = new CSessionManager(bitcoinConfig, logger);
        
        if (ShowDashboard) {
            bitcoinDashboard = new CDashboard(bitcoinSymbol, bitcoinConfig, logger);
        }
        
        logger->Info("Init", "Bitcoin (" + bitcoinSymbol + ") initialized successfully");
    }
    
    logger->Info("EA", "VORAX™ initialization complete - Ready to trade");
    eaStatus = EA_READY;
    
    return INIT_SUCCEEDED;
}

//===================================================================
//                    DEINITIALIZATION
//===================================================================

void OnDeinit(const int reason)
{
    logger->Info("Deinit", "VORAX™ shutting down - Reason: " + IntegerToString(reason));
    
    // Clear dashboards
    if (TradeGold && goldDashboard) {
        goldDashboard->ClearDisplay();
        delete goldDashboard;
    }
    
    if (TradeBitcoin && bitcoinDashboard) {
        bitcoinDashboard->ClearDisplay();
        delete bitcoinDashboard;
    }
    
    // Delete Gold objects
    if (TradeGold) {
        if (goldRiskManager) delete goldRiskManager;
        if (goldVolatility) delete goldVolatility;
        if (goldPressure) delete goldPressure;
        if (goldMomentum) delete goldMomentum;
        if (goldSignal) delete goldSignal;
        if (goldExecutor) delete goldExecutor;
        if (goldPositionManager) delete goldPositionManager;
        if (goldReinforcement) delete goldReinforcement;
        if (goldSession) delete goldSession;
    }
    
    // Delete Bitcoin objects
    if (TradeBitcoin) {
        if (bitcoinRiskManager) delete bitcoinRiskManager;
        if (bitcoinVolatility) delete bitcoinVolatility;
        if (bitcoinPressure) delete bitcoinPressure;
        if (bitcoinMomentum) delete bitcoinMomentum;
        if (bitcoinSignal) delete bitcoinSignal;
        if (bitcoinExecutor) delete bitcoinExecutor;
        if (bitcoinPositionManager) delete bitcoinPositionManager;
        if (bitcoinReinforcement) delete bitcoinReinforcement;
        if (bitcoinSession) delete bitcoinSession;
    }
    
    // Delete managers
    if (configManager) delete configManager;
    if (newsFilter) delete newsFilter;
    if (logger) delete logger;
}

//===================================================================
//                    MAIN TRADING LOGIC
//===================================================================

void OnTick()
{
    // ===== GOLD TRADING LOGIC =====
    if (TradeGold) {
        ProcessGold();
    }
    
    // ===== BITCOIN TRADING LOGIC =====
    if (TradeBitcoin) {
        ProcessBitcoin();
    }
    
    // Update dashboards
    if (ShowDashboard) {
        UpdateDashboards();
    }
}

//===================================================================
//                    GOLD PROCESSING
//===================================================================

void ProcessGold()
{
    if (!goldVolatility || !goldPressure || !goldMomentum || !goldSignal) return;
    
    // Update all analyzers
    if (!goldVolatility->Update()) return;
    if (!goldPressure->Update()) return;
    if (!goldMomentum->Update()) return;
    
    // Update position manager
    goldPositionManager->UpdateAllPositions();
    
    // Check if trading is allowed
    if (!goldSession->CanTrade()) {
        eaStatus = EA_TRADING_DISABLED;
        return;
    }
    
    if (!newsFilter->IsTradeAllowed()) {
        eaStatus = EA_NEWS_FILTER;
        return;
    }
    
    if (goldVolatility->IsExtremeVolatility()) {
        eaStatus = EA_EXTREME_VOLATILITY;
        return;
    }
    
    // Analyze signal
    STradeSignal goldSignalData = goldSignal->AnalyzeSignal();
    
    if (goldSignalData.signalType != SIGNAL_NONE && goldSignal->IsSignalNew(goldSignalData)) {
        
        if (goldSignalData.signalType == SIGNAL_BUY) {
            ExecuteGoldBuy(goldSignalData);
        } else if (goldSignalData.signalType == SIGNAL_SELL) {
            ExecuteGoldSell(goldSignalData);
        }
    }
    
    eaStatus = EA_READY;
}

void ExecuteGoldBuy(STradeSignal &signal)
{
    SSymbolConfig *config = configManager->GetGoldConfig();
    
    // Check for existing positions
    if (goldPositionManager->GetOpenPositionsCount() >= (int)config->maxPositions) {
        eaStatus = EA_MAX_POSITIONS;
        return;
    }
    
    // Calculate lot size
    double slPoints = signal.entryPrice - signal.stopLoss;
    double lot = goldRiskManager->CalculateLotSize(slPoints / SymbolInfoDouble(goldSymbol, SYMBOL_POINT));
    
    if (lot <= 0) {
        logger->Warning("Gold", "Invalid lot size calculated");
        return;
    }
    
    // Execute order
    ulong ticket = goldExecutor->ExecuteSignal(signal, lot);
    
    if (ticket > 0) {
        eaStatus = EA_BUY_SIGNAL;
        lastGoldSignalTime = TimeCurrent();
        goldRiskManager->RecordTrade(0); // Record trade for statistics
    }
}

void ExecuteGoldSell(STradeSignal &signal)
{
    SSymbolConfig *config = configManager->GetGoldConfig();
    
    // Check for existing positions
    if (goldPositionManager->GetOpenPositionsCount() >= (int)config->maxPositions) {
        eaStatus = EA_MAX_POSITIONS;
        return;
    }
    
    // Calculate lot size
    double slPoints = signal.stopLoss - signal.entryPrice;
    double lot = goldRiskManager->CalculateLotSize(slPoints / SymbolInfoDouble(goldSymbol, SYMBOL_POINT));
    
    if (lot <= 0) {
        logger->Warning("Gold", "Invalid lot size calculated");
        return;
    }
    
    // Execute order
    ulong ticket = goldExecutor->ExecuteSignal(signal, lot);
    
    if (ticket > 0) {
        eaStatus = EA_SELL_SIGNAL;
        lastGoldSignalTime = TimeCurrent();
        goldRiskManager->RecordTrade(0);
    }
}

//===================================================================
//                    BITCOIN PROCESSING
//===================================================================

void ProcessBitcoin()
{
    if (!bitcoinVolatility || !bitcoinPressure || !bitcoinMomentum || !bitcoinSignal) return;
    
    // Update all analyzers
    if (!bitcoinVolatility->Update()) return;
    if (!bitcoinPressure->Update()) return;
    if (!bitcoinMomentum->Update()) return;
    
    // Update position manager
    bitcoinPositionManager->UpdateAllPositions();
    
    // Check if trading is allowed
    if (!bitcoinSession->CanTrade()) {
        eaStatus = EA_TRADING_DISABLED;
        return;
    }
    
    if (!newsFilter->IsTradeAllowed()) {
        eaStatus = EA_NEWS_FILTER;
        return;
    }
    
    if (bitcoinVolatility->IsExtremeVolatility()) {
        eaStatus = EA_EXTREME_VOLATILITY;
        return;
    }
    
    // Analyze signal
    STradeSignal bitcoinSignalData = bitcoinSignal->AnalyzeSignal();
    
    if (bitcoinSignalData.signalType != SIGNAL_NONE && bitcoinSignal->IsSignalNew(bitcoinSignalData)) {
        
        if (bitcoinSignalData.signalType == SIGNAL_BUY) {
            ExecuteBitcoinBuy(bitcoinSignalData);
        } else if (bitcoinSignalData.signalType == SIGNAL_SELL) {
            ExecuteBitcoinSell(bitcoinSignalData);
        }
    }
    
    eaStatus = EA_READY;
}

void ExecuteBitcoinBuy(STradeSignal &signal)
{
    SSymbolConfig *config = configManager->GetBitcoinConfig();
    
    // Check for existing positions
    if (bitcoinPositionManager->GetOpenPositionsCount() >= (int)config->maxPositions) {
        eaStatus = EA_MAX_POSITIONS;
        return;
    }
    
    // Calculate lot size
    double slPoints = signal.entryPrice - signal.stopLoss;
    double lot = bitcoinRiskManager->CalculateLotSize(slPoints / SymbolInfoDouble(bitcoinSymbol, SYMBOL_POINT));
    
    if (lot <= 0) {
        logger->Warning("Bitcoin", "Invalid lot size calculated");
        return;
    }
    
    // Execute order
    ulong ticket = bitcoinExecutor->ExecuteSignal(signal, lot);
    
    if (ticket > 0) {
        eaStatus = EA_BUY_SIGNAL;
        lastBitcoinSignalTime = TimeCurrent();
        bitcoinRiskManager->RecordTrade(0);
    }
}

void ExecuteBitcoinSell(STradeSignal &signal)
{
    SSymbolConfig *config = configManager->GetBitcoinConfig();
    
    // Check for existing positions
    if (bitcoinPositionManager->GetOpenPositionsCount() >= (int)config->maxPositions) {
        eaStatus = EA_MAX_POSITIONS;
        return;
    }
    
    // Calculate lot size
    double slPoints = signal.stopLoss - signal.entryPrice;
    double lot = bitcoinRiskManager->CalculateLotSize(slPoints / SymbolInfoDouble(bitcoinSymbol, SYMBOL_POINT));
    
    if (lot <= 0) {
        logger->Warning("Bitcoin", "Invalid lot size calculated");
        return;
    }
    
    // Execute order
    ulong ticket = bitcoinExecutor->ExecuteSignal(signal, lot);
    
    if (ticket > 0) {
        eaStatus = EA_SELL_SIGNAL;
        lastBitcoinSignalTime = TimeCurrent();
        bitcoinRiskManager->RecordTrade(0);
    }
}

//===================================================================
//                    DASHBOARD UPDATE
//===================================================================

void UpdateDashboards()
{
    if (TradeGold && goldDashboard) {
        SAccountStats goldStats = goldRiskManager->GetAccountStats();
        goldDashboard->UpdateDisplay(goldPressure->GetData(), goldMomentum->GetData(),
                                    goldVolatility->GetData(), goldStats, eaStatus);
    }
    
    if (TradeBitcoin && bitcoinDashboard) {
        SAccountStats bitcoinStats = bitcoinRiskManager->GetAccountStats();
        bitcoinDashboard->UpdateDisplay(bitcoinPressure->GetData(), bitcoinMomentum->GetData(),
                                       bitcoinVolatility->GetData(), bitcoinStats, eaStatus);
    }
}

//+------------------------------------------------------------------+
//| End of VORAX_EA.mq5
//+------------------------------------------------------------------+
