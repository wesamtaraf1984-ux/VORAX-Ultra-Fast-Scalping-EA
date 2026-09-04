//+------------------------------------------------------------------+
//|                                                VORAX_Dashboard.mqh |
//|                                   VORAX™ Ultra-Fast Scalping EA   |
//|                           Copyright 2024 - Professional Edition   |
//+------------------------------------------------------------------+

#ifndef VORAX_DASHBOARD_H
#define VORAX_DASHBOARD_H

#include "VORAX_Defines.mqh"
#include "VORAX_Utils.mqh"
#include "VORAX_SymbolConfig.mqh"

//--- Dashboard Display Class
class CDashboard
{
private:
    string symbol;
    SSymbolConfig *config;
    CLogger *logger;
    bool enabled;
    datetime lastUpdate;
    
    const int LABEL_X = 20;
    const int LABEL_Y = 20;
    const int LINE_HEIGHT = 25;
    const string FONT_NAME = "Arial";
    const int FONT_SIZE = 10;
    const color FONT_COLOR = clrWhite;
    const color HEADER_COLOR = clrGoldenrod;
    const color BG_COLOR = clrDarkBlue;

public:
    CDashboard(string sym, SSymbolConfig *cfg, CLogger *log)
        : symbol(sym), config(cfg), logger(log), enabled(true), lastUpdate(0)
    {
        if (logger) logger->Debug("Dashboard", "Dashboard initialized for " + symbol);
    }
    
    void SetEnabled(bool state) { enabled = state; }
    
    void UpdateDisplay(SPressureData &pressure, SMomentumData &momentum,
                      SVolatilityData &volatility, SAccountStats &stats,
                      ENUM_EA_STATUS eaStatus)
    {
        if (!enabled) return;
        
        // Update only every 500ms to avoid excessive redraws
        if (TimeCurrent() - lastUpdate < 1) return;
        lastUpdate = TimeCurrent();
        
        int yPos = LABEL_Y;
        string prefix = symbol + "_";
        
        // ===== HEADER =====
        DrawLabel(prefix + "header", "═══ VORAX™ ULTRA-FAST SCALPING ═══", LABEL_X, yPos, HEADER_COLOR);
        yPos += LINE_HEIGHT;
        
        // ===== SYMBOL INFO =====
        DrawLabel(prefix + "symbol", "Symbol: " + symbol, LABEL_X, yPos, FONT_COLOR);
        yPos += LINE_HEIGHT;
        
        // ===== SPREAD =====
        string spreadText = "Spread: " + DoubleToString((SymbolInfoDouble(symbol, SYMBOL_ASK) -
                           SymbolInfoDouble(symbol, SYMBOL_BID)) / SymbolInfoDouble(symbol, SYMBOL_POINT), 1);
        DrawLabel(prefix + "spread", spreadText, LABEL_X, yPos, FONT_COLOR);
        yPos += LINE_HEIGHT;
        
        // ===== PRESSURE =====
        string pressureText = "Buy Pressure: " + DoubleToString(pressure.buyPressure, 1) + "%  |  " +
                             "Sell Pressure: " + DoubleToString(pressure.sellPressure, 1) + "%";
        DrawLabel(prefix + "pressure", pressureText, LABEL_X, yPos, FONT_COLOR);
        yPos += LINE_HEIGHT;
        
        // ===== MOMENTUM =====
        string momentumText = "Momentum: " + DoubleToString(momentum.value, 1) + "  |  " +
                             "Strength: " + DoubleToString(momentum.strength, 1);
        DrawLabel(prefix + "momentum", momentumText, LABEL_X, yPos, FONT_COLOR);
        yPos += LINE_HEIGHT;
        
        // ===== VOLATILITY =====
        string volatilityText = "Volatility: " + volatility.GetRegimeString() + "  |  " +
                               "ATR: " + DoubleToString(volatility.atr, 2);
        DrawLabel(prefix + "volatility", volatilityText, LABEL_X, yPos, FONT_COLOR);
        yPos += LINE_HEIGHT * 1.5;
        
        // ===== ACCOUNT STATS =====
        string balanceText = "Balance: " + DoubleToString(stats.balance, 2);
        DrawLabel(prefix + "balance", balanceText, LABEL_X, yPos, FONT_COLOR);
        yPos += LINE_HEIGHT;
        
        string equityText = "Equity: " + DoubleToString(stats.equity, 2);
        DrawLabel(prefix + "equity", equityText, LABEL_X, yPos, FONT_COLOR);
        yPos += LINE_HEIGHT;
        
        string drawdownText = "Drawdown: " + DoubleToString((stats.balance - stats.equity) / stats.balance * 100, 2) + "%";
        DrawLabel(prefix + "drawdown", drawdownText, LABEL_X, yPos, FONT_COLOR);
        yPos += LINE_HEIGHT;
        
        string positionsText = "Open Positions: " + IntegerToString(stats.openPositions);
        DrawLabel(prefix + "positions", positionsText, LABEL_X, yPos, FONT_COLOR);
        yPos += LINE_HEIGHT * 1.5;
        
        // ===== EA STATUS =====
        string statusText = "Status: " + GetStatusString(eaStatus);
        color statusColor = GetStatusColor(eaStatus);
        DrawLabel(prefix + "status", statusText, LABEL_X, yPos, statusColor);
    }
    
    void DrawLabel(string name, string text, int x, int y, color textColor)
    {
        if (!ObjectFind(ChartID(), name) >= 0) {
            ObjectCreate(ChartID(), name, OBJ_LABEL, 0, 0, 0);
        }
        
        ObjectSetString(ChartID(), name, OBJPROP_TEXT, text);
        ObjectSetInteger(ChartID(), name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(ChartID(), name, OBJPROP_YDISTANCE, y);
        ObjectSetString(ChartID(), name, OBJPROP_FONT, FONT_NAME);
        ObjectSetInteger(ChartID(), name, OBJPROP_FONTSIZE, FONT_SIZE);
        ObjectSetInteger(ChartID(), name, OBJPROP_COLOR, textColor);
    }
    
    void ClearDisplay()
    {
        if (!enabled) return;
        
        string prefix = symbol + "_";
        
        ObjectDelete(ChartID(), prefix + "header");
        ObjectDelete(ChartID(), prefix + "symbol");
        ObjectDelete(ChartID(), prefix + "spread");
        ObjectDelete(ChartID(), prefix + "pressure");
        ObjectDelete(ChartID(), prefix + "momentum");
        ObjectDelete(ChartID(), prefix + "volatility");
        ObjectDelete(ChartID(), prefix + "balance");
        ObjectDelete(ChartID(), prefix + "equity");
        ObjectDelete(ChartID(), prefix + "drawdown");
        ObjectDelete(ChartID(), prefix + "positions");
        ObjectDelete(ChartID(), prefix + "status");
    }
    
private:
    string GetStatusString(ENUM_EA_STATUS status)
    {
        switch(status) {
            case EA_READY:               return "READY";
            case EA_BUY_SIGNAL:          return "BUY SIGNAL";
            case EA_SELL_SIGNAL:         return "SELL SIGNAL";
            case EA_COOLDOWN:            return "COOLDOWN";
            case EA_NEWS_FILTER:         return "NEWS FILTER ACTIVE";
            case EA_DAILY_LOSS_LIMIT:    return "DAILY LOSS LIMIT";
            case EA_EXTREME_VOLATILITY:  return "EXTREME VOLATILITY";
            case EA_TRADING_DISABLED:    return "TRADING DISABLED";
            case EA_SPREAD_TOO_HIGH:     return "SPREAD TOO HIGH";
            case EA_MAX_POSITIONS:       return "MAX POSITIONS";
            case EA_ERROR:               return "ERROR";
            default:                     return "UNKNOWN";
        }
    }
    
    color GetStatusColor(ENUM_EA_STATUS status)
    {
        switch(status) {
            case EA_READY:               return clrGreen;
            case EA_BUY_SIGNAL:          return clrLimeGreen;
            case EA_SELL_SIGNAL:         return clrOrange;
            case EA_DAILY_LOSS_LIMIT:    return clrRed;
            case EA_EXTREME_VOLATILITY:  return clrRed;
            case EA_TRADING_DISABLED:    return clrRed;
            case EA_ERROR:               return clrRed;
            default:                     return clrYellow;
        }
    }
};

#endif
