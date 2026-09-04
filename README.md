# VORAX™ ULTRA-FAST MULTI-ASSET SCALPING EA

## EA Information
- **Name:** VORAX™
- **Version:** 2.0.1
- **Type:** Ultra-Fast Scalping Robot
- **Supported Symbols:** XAUUSD (Gold), BTCUSD (Bitcoin)
- **Timeframe:** M1 (Minute)
- **Strategy:** Momentum + Buyer/Seller Pressure Analysis

## Features

### 1. Dual-Asset Support
- **XAUUSD (Gold)** with optimized micro-trading parameters
- **BTCUSD (Bitcoin)** with optimized volatility-adjusted parameters
- Independent configurations for each asset
- Each asset has its own risk management system

### 2. Advanced Signal Engine
- **Momentum Analysis** - EMA slope, price acceleration, rate of change
- **Pressure Calculation** - Buy/Sell pressure based on market microstructure
- **Volatility Classification** - 4 regimes: LOW, NORMAL, HIGH, EXTREME
- **Multi-Condition Confirmation** - NO trade if any condition fails

### 3. Professional Risk Management
- Dynamic lot size calculation
- Daily loss limits (configurable per asset)
- Drawdown protection
- Maximum consecutive loss cooldown
- Spread quality filter
- Extreme volatility protection

### 4. Intelligent Position Management
- 4-Stage Trailing Stop System
  - Stage 1: Protection (Entry to +10 points)
  - Stage 2: Break-Even (10 to 25 points)
  - Stage 3: Lock Profit (25 to 50 points)
  - Stage 4: Trail (50+ points)
- Automatic position monitoring
- Early exit on momentum reversal
- Maximum trade duration control

### 5. Optional Features
- Position Reinforcement (controlled add-ons)
- News Filter (blocks trading around high-impact events)
- Session Management (restrict trading hours)
- Professional Dashboard Display
- Debug Logging Mode

## Default Settings - GOLD (XAUUSD)

| Setting | Value | Description |
|---------|-------|-------------|
| Risk % | 0.50% | Conservative position sizing |
| Max Daily Loss | 2.00% | Hard stop-loss for the day |
| Max Drawdown | 5.00% | Account protection limit |
| Max Spread | 1.5 pts | Rejects trades if spread wide |
| Min Pressure | 65.0 | Strong directional requirement |
| Min Pressure Diff | 18.0 | Clear buy/sell advantage needed |
| Min Momentum | 50.0 | Require strong momentum |
| Min SL | 0.50$ | Tight protective stop |
| Max SL | 2.50$ | Maximum allowable risk per trade |
| TP Ratio | 1:1.50 | Realistic profit targets |
| Session | 09:00-17:00 | London/NY active hours |

## Default Settings - BITCOIN (BTCUSD)

| Setting | Value | Description |
|---------|-------|-------------|
| Risk % | 0.50% | Conservative position sizing |
| Max Daily Loss | 2.00% | Hard stop-loss for the day |
| Max Drawdown | 5.00% | Account protection limit |
| Max Spread | 75.0 pts | Accounts for crypto spreads |
| Min Pressure | 62.0 | Slightly lower for volatility |
| Min Pressure Diff | 16.0 | Adaptive to crypto nature |
| Min Momentum | 48.0 | Adaptive to crypto nature |
| Min SL | 50$ | Larger stops for volatility |
| Max SL | 300$ | Higher volatility tolerance |
| TP Ratio | 1:1.50 | Same risk/reward as gold |
| Session | 00:00-23:59 | 24/7 trading capability |

## Installation Instructions

### Step 1: Prepare Files
1. Create a folder: `MQL5/Experts/VORAX/`
2. Create subfolder: `MQL5/Experts/VORAX/Include/`

### Step 2: Copy Files
- Copy `VORAX_EA.mq5` to `MQL5/Experts/VORAX/`
- Copy all `.mqh` files to `MQL5/Experts/VORAX/Include/`

### Step 3: Compile
1. Open MetaTrader 5
2. File → Open Data Folder
3. Navigate to MQL5/Experts/VORAX/
4. Right-click VORAX_EA.mq5 → Compile (or F5)
5. Check for compilation errors in the Errors tab

### Step 4: Deploy
1. Restart MetaTrader 5
2. Open the chart of XAUUSD or BTCUSD on M1 timeframe
3. Navigator → Experts → VORAX_EA
4. Double-click to attach to chart
5. Allow DLL imports and live trading

## Configuration Guide

### Conservative Settings (Recommended for Beginners)
```
Gold_RiskPercentPerTrade = 0.25%
Gold_MaxDailyLoss = 1.00%
Bitcoin_RiskPercentPerTrade = 0.25%
Bitcoin_MaxDailyLoss = 1.00%
AllowReinforcement = false
```

### Aggressive Settings (For Experienced Traders)
```
Gold_RiskPercentPerTrade = 1.00%
Gold_MaxDailyLoss = 3.00%
Bitcoin_RiskPercentPerTrade = 1.00%
Bitcoin_MaxDailyLoss = 3.00%
AllowReinforcement = true
MaxReinforcementTrades = 2
```

### News-Aware Settings
```
NewsFilterEnabled = true
NewsMinutesBefore = 10
NewsMinutesAfter = 15
```

## Backtesting Instructions

1. Open Strategy Tester (Ctrl+R)
2. Select Expert Advisor: VORAX_EA
3. Select Symbol: XAUUSD or BTCUSD
4. Select Period: M1
5. Set Date Range: At least 3-6 months
6. Enable "Every tick based on real ticks"
7. Run with Default Settings first
8. Review results:
   - Profit Factor > 1.5 is good
   - Max Drawdown < 10% is acceptable
   - Win Rate > 45% is normal for scalping
   - Profit Factor = Gross Profit / Gross Loss

## Performance Expectations

### Realistic Returns
- Monthly: 2-5% account growth
- Win Rate: 45-55% (quality over quantity)
- Average Win: 1.5x Average Loss
- Drawdown: 3-8% typical

### NOT Expected
- 100% win rate (impossible in real markets)
- 20%+ monthly returns (unsustainable)
- Zero drawdown (unrealistic)
- Guaranteed profits (no such thing exists)

## Troubleshooting

### Issue: "Symbol not found" error
**Solution:** 
- Check broker's exact symbol name (e.g., XAUUSD, XAUUSD.a, XAUUSDm)
- The EA auto-detects, but if it fails, manually check in Market Watch

### Issue: Orders rejected with "invalid stops"
**Solution:**
- Check SYMBOL_TRADE_STOPS_LEVEL on your broker
- Increase Min SL Points in settings
- Some brokers require minimum 10 points distance

### Issue: No trades opening
**Causes:**
- Spread too high (check current spread vs max spread setting)
- Outside trading session
- Extreme volatility detected
- Daily loss limit reached
- Enable Debug Mode to see exact reason

### Issue: "insufficient margin" error
**Solution:**
- Reduce Risk % setting
- Start with smaller account size
- Increase account balance

### Issue: Dashboard not showing
**Solution:**
- Check ShowDashboard = true in inputs
- Disable/enable EA on chart
- Click View → Zoom to reset chart display

## Safety Rules

✅ **ALWAYS DO:**
- Test on Demo account first (minimum 2 weeks)
- Start with smallest lot sizes
- Monitor daily performance
- Use stop-losses on all trades
- Keep risk % under 1% per trade
- Review logs regularly in debug mode

❌ **NEVER DO:**
- Trade live without demo testing
- Change settings mid-session
- Use leverage beyond 1:10
- Disable stop-loss protection
- Trade during major news events
- Leave EA running unattended for days

## Support & Updates

- GitHub: https://github.com/wesamtaraf1984-ux/VORAX-Ultra-Fast-Scalping-EA
- Documentation: See README.md
- Issue Reports: Use GitHub Issues

## Disclaimer

This EA is provided "as-is" without warranty. Algorithmic trading involves significant risk. Past performance does not guarantee future results. Test thoroughly on a demo account before live trading. Start with small positions. The author is not responsible for losses incurred through use of this EA.

---

**VORAX™ - HUNT VOLATILITY. EXPLOIT MOMENTUM.**

Version 2.0.1 | © 2024 Professional Edition
