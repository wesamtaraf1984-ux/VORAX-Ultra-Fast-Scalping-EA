# VORAX™ Quick Start Guide

## 5-Minute Setup

### 1. Download Files
- Clone or download from GitHub
- Extract to a folder

### 2. Install to MetaTrader 5
```
MQL5/Experts/VORAX/
├── VORAX_EA.mq5
└── Include/
    └── (all .mqh files)
```

### 3. Compile
- Open Meta Editor (F11)
- File → Open → VORAX_EA.mq5
- Press F5 to compile
- Check for errors

### 4. Attach to Chart
- Open XAUUSD or BTCUSD on M1
- Navigator (Ctrl+N)
- Experts → VORAX_EA → Drag to chart
- Click OK

### 5. Configure (Optional)
- Click on Expert Advisor in chart → Modify
- Adjust settings if desired
- Default settings are conservative and tested

## Recommended Settings for Each Symbol

### GOLD (XAUUSD)
```
Risk per Trade: 0.50%
Daily Loss Limit: 2.00%
Maximum Spread: 1.5 points
Minimum Pressure: 65.0
Min SL: 0.50 USD
Max SL: 2.50 USD
Session: 09:00 - 17:00 (London/NY)
```

### BITCOIN (BTCUSD)
```
Risk per Trade: 0.50%
Daily Loss Limit: 2.00%
Maximum Spread: 75.0 points
Minimum Pressure: 62.0
Min SL: 50 USD
Max SL: 300 USD
Session: 00:00 - 23:59 (24/7)
```

## Monitor Performance

### Dashboard Shows:
- Current spread
- Buy/Sell pressure levels
- Momentum strength
- Volatility regime
- Account balance and equity
- Open positions count
- EA status (READY, BUY SIGNAL, etc.)

### Expected Performance
- Win Rate: 45-55% (quality > quantity)
- Profit Factor: 1.5-2.5
- Monthly Return: 2-5% (realistic)
- Max Drawdown: 3-8%

## DO NOT
❌ Trade live without Demo testing first
❌ Change settings during active trading
❌ Use leverage above 1:10
❌ Disable stop-losses
❌ Trade during major news events
❌ Leave running unattended for days

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Symbol not found | Broker-specific naming | Check Market Watch for exact symbol |
| Invalid stops error | Broker minimum distance | Increase Min SL Points |
| No trades opening | Spread too high | Check Spread filter in settings |
| Insufficient margin | Lot size too big | Reduce Risk % per trade |
| EA won't compile | Include path wrong | Check folder structure |

## Next Steps

1. **Test on Demo** (Minimum 2 weeks)
2. **Monitor Logs** (Enable Debug Mode)
3. **Backtest** (Strategy Tester)
4. **Go Live** (Only after successful testing)
5. **Start Small** (Minimum lot sizes)

---

**Questions?** Check README.md for detailed documentation

**VORAX™ - HUNT VOLATILITY. EXPLOIT MOMENTUM.**
