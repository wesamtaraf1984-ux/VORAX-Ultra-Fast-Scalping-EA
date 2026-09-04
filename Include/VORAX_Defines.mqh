//+------------------------------------------------------------------+
//|                                                  VORAX_Defines.mqh |
//|                                   VORAX™ Ultra-Fast Scalping EA   |
//|                           Copyright 2024 - Professional Edition   |
//+------------------------------------------------------------------+

#ifndef VORAX_DEFINES_H
#define VORAX_DEFINES_H

//--- Enums
enum ENUM_VOLATILITY_REGIME
{
    VOLATILITY_LOW = 0,       // ATR < P25
    VOLATILITY_NORMAL = 1,    // P25-P75
    VOLATILITY_HIGH = 2,      // P75-P90
    VOLATILITY_EXTREME = 3    // ATR > P90
};

enum ENUM_MARKET_REGIME
{
    REGIME_TRENDING_UP = 0,
    REGIME_TRENDING_DOWN = 1,
    REGIME_RANGING = 2,
    REGIME_UNSTABLE = 3
};

enum ENUM_SIGNAL_TYPE
{
    SIGNAL_NONE = 0,
    SIGNAL_BUY = 1,
    SIGNAL_SELL = 2
};

enum ENUM_EA_STATUS
{
    EA_READY = 0,
    EA_BUY_SIGNAL = 1,
    EA_SELL_SIGNAL = 2,
    EA_COOLDOWN = 3,
    EA_NEWS_FILTER = 4,
    EA_DAILY_LOSS_LIMIT = 5,
    EA_EXTREME_VOLATILITY = 6,
    EA_TRADING_DISABLED = 7,
    EA_SPREAD_TOO_HIGH = 8,
    EA_MAX_POSITIONS = 9,
    EA_ERROR = 10
};

enum ENUM_EXECUTION_ERROR
{
    EXEC_OK = 0,
    EXEC_SPREAD_TOO_HIGH = 1,
    EXEC_INVALID_STOPS = 2,
    EXEC_INVALID_VOLUME = 3,
    EXEC_INSUFFICIENT_MARGIN = 4,
    EXEC_ORDER_FAILED = 5,
    EXEC_SLIPPAGE_TOO_HIGH = 6,
    EXEC_MARKET_CLOSED = 7,
    EXEC_TRADE_DISABLED = 8
};

//--- Structures
struct SSymbolInfo
{
    string   symbol;
    double   point;
    int      digits;
    double   tickSize;
    double   tickValue;
    double   contractSize;
    double   minLot;
    double   maxLot;
    double   lotStep;
    int      stopsLevel;
    int      freezeLevel;
    int      spread;
    double   bid;
    double   ask;
    bool     valid;
};

struct SPressureData
{
    double   buyPressure;
    double   sellPressure;
    double   pressureDifference;
    double   bullishRatio;
    double   bearishRatio;
    double   volumeAcceleration;
    double   momentumStrength;
    bool     confirmed;
    datetime timestamp;
};

struct SMomentumData
{
    double   value;           // Current momentum (-100 to +100)
    double   acceleration;    // Rate of change of momentum
    double   strength;        // Absolute momentum strength (0-100)
    bool     isUptrend;
    bool     isDowntrend;
    int      consecutiveUpTicks;
    int      consecutiveDownTicks;
    datetime timestamp;
};

struct SVolatilityData
{
    double   atr;
    double   atrPercent;
    double   p25;
    double   p50;
    double   p75;
    double   p90;
    ENUM_VOLATILITY_REGIME regime;
    double   spreadPercent;
    datetime timestamp;
};

struct SRiskData
{
    double   riskPercentPerTrade;
    double   lotSize;
    double   slPoints;
    double   slPrice;
    double   tpPrice;
    double   slDistance;
    double   tpDistance;
    double   riskRewardRatio;
    double   dailyRiskUsed;
    double   totalRiskExposure;
    bool     valid;
};

struct STradeSignal
{
    ENUM_SIGNAL_TYPE signalType;
    double   entryPrice;
    double   stopLoss;
    double   takeProfit;
    double   lot;
    double   pressure;
    double   momentum;
    double   confidence;
    string   reason;
    datetime timestamp;
};

struct SPositionData
{
    ulong    ticket;
    string   symbol;
    ENUM_POSITION_TYPE type;
    double   volume;
    double   openPrice;
    double   stopLoss;
    double   takeProfit;
    double   currentProfit;
    double   profitPercent;
    double   currentPrice;
    int      magicNumber;
    datetime openTime;
    double   slDistance;
    double   tpDistance;
    bool     isValid;
};

struct SAccountStats
{
    double   balance;
    double   equity;
    double   freeMargin;
    double   usedMargin;
    double   dailyProfit;
    double   dailyLoss;
    double   dailyDrawdown;
    double   maxDrawdown;
    int      totalTrades;
    int      dailyTrades;
    int      consecutiveLosses;
    int      openPositions;
    datetime lastTradeTime;
};

//--- Constants
#define EA_VERSION "2.0.1"
#define EA_NAME "VORAX™"
#define EA_SUBTITLE "ULTRA-FAST MULTI-ASSET SCALPING"
#define MAGIC_GOLD 19840001
#define MAGIC_BITCOIN 19840002

#define MAX_RETRY_ATTEMPTS 3
#define RETRY_DELAY_MS 500

#define PRESSURE_MIN_VALUE 0.0
#define PRESSURE_MAX_VALUE 100.0

#define MOMENTUM_MIN_VALUE -100.0
#define MOMENTUM_MAX_VALUE 100.0

#define ATR_PERIOD 14
#define EMA_PERIOD 20
#define LOOKBACK_BARS 20

#define TICKS_PER_SECOND_THRESHOLD 100

//--- Default Input Values
#define DEFAULT_RISK_PERCENT 0.50
#define DEFAULT_MAX_SPREAD_GOLD 1.5
#define DEFAULT_MAX_SPREAD_BTC 50.0
#define DEFAULT_MIN_PRESSURE 60.0
#define DEFAULT_MIN_PRESSURE_DIFF 15.0
#define DEFAULT_RISK_REWARD_RATIO 1.5
#define DEFAULT_MAX_DAILY_LOSS 2.0
#define DEFAULT_MAX_DRAWDOWN 5.0
#define DEFAULT_MAX_POSITIONS 2
#define DEFAULT_MAX_TRADES_PER_DAY 20
#define DEFAULT_MAX_TRADES_PER_HOUR 5

#endif
