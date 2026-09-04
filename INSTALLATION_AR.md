# VORAX™ Installation Guide (Arabic)

## دليل التثبيت - VORAX™ Ultra-Fast Scalping EA

### المتطلبات
- MetaTrader 5 (v5.30 أو أحدث)
- حساب تجريبي أو حقيقي
- رمز (Symbol) XAUUSD و/أو BTCUSD متاح لديك

### خطوات التثبيت

#### الخطوة 1: تحضير المجلدات
1. افتح MetaTrader 5
2. اذهب إلى: File → Open Data Folder
3. تأكد من وجود المجلدات التالية:
   ```
   MQL5/
   ├── Experts/
   │   └── VORAX/
   │       ├── Include/
   │       └── VORAX_EA.mq5
   ```
4. إذا لم تكن موجودة، أنشئها يدويًا

#### الخطوة 2: نسخ الملفات

**انسخ هذه الملفات إلى `MQL5/Experts/VORAX/`:**
- VORAX_EA.mq5

**انسخ هذه الملفات إلى `MQL5/Experts/VORAX/Include/`:**
- VORAX_Defines.mqh
- VORAX_Utils.mqh
- VORAX_SymbolConfig.mqh
- VORAX_Volatility.mqh
- VORAX_Pressure.mqh
- VORAX_Momentum.mqh
- VORAX_Risk.mqh
- VORAX_Signal.mqh
- VORAX_Execution.mqh
- VORAX_PositionManager.mqh
- VORAX_Reinforcement.mqh
- VORAX_Dashboard.mqh
- VORAX_News.mqh
- VORAX_SessionManager.mqh

#### الخطوة 3: الترجمة (Compilation)
1. أعد تشغيل MetaTrader 5 (مهم جداً!)
2. افتح Meta Editor (F11 أو Tools → MetaQuotes Language Editor)
3. File → Open → MQL5/Experts/VORAX/VORAX_EA.mq5
4. اضغط F5 أو Compile
5. تحقق من الأخطاء في تبويب "Errors"
   - إذا لم تكن هناك أخطاء: ✅ نجح!
   - إذا كان هناك أخطاء: تحقق من مسارات الملفات

#### الخطوة 4: الاستخدام
1. افتح رسم بياني (Chart) لـ XAUUSD أو BTCUSD على فترة M1
2. اذهب إلى Navigator (Ctrl+N)
3. Expert Advisors → VORAX_EA
4. اسحب وأفلت على الرسم البياني
5. في الشاشة المنبثقة:
   - Enable Expert Advisor: ✅ تحقق
   - Allow live trading: ✅ تحقق
   - Allow DLL imports: ✅ تحقق
   - اضغط OK

### الإعدادات الافتراضية

#### للذهب (XAUUSD) - محافظ
```
TradeGold = true
Gold_RiskPercentPerTrade = 0.50%
Gold_MaxDailyLoss = 2.00%
Gold_MaxSpread = 1.5
Gold_MinimumPressure = 65.0
Gold_MinimumPressureDiff = 18.0
Gold_MinimumMomentumStrength = 50.0
Gold_MinSLPoints = 0.50
Gold_MaxSLPoints = 2.50
```

#### للبيتكوين (BTCUSD) - محافظ
```
TradeBitcoin = true
Bitcoin_RiskPercentPerTrade = 0.50%
Bitcoin_MaxDailyLoss = 2.00%
Bitcoin_MaxSpread = 75.0
Bitcoin_MinimumPressure = 62.0
Bitcoin_MinimumPressureDiff = 16.0
Bitcoin_MinimumMomentumStrength = 48.0
Bitcoin_MinSLPoints = 50.0
Bitcoin_MaxSLPoints = 300.0
```

### اختبار على المحاكي (Demo)

#### قبل التداول الحقيقي:
1. استخدم حساب Demo أولاً
2. شغل EA لمدة أسبوعين على الأقل
3. راقب الأداء في السجل
4. تأكد من أن النسبة المئوية اليومية مقبولة
5. لا تبدأ التداول الحقيقي بدون هذا الاختبار!

#### كيفية الاختبار:
1. Strategy Tester (Ctrl+R)
2. اختر VORAX_EA من القائمة
3. اختر Symbol: XAUUSD أو BTCUSD
4. اختر Period: M1
5. اختر نطاق التاريخ: 3-6 أشهر
6. Enable: "Every tick based on real ticks"
7. اضغط Start
8. انتظر حتى ينتهي الاختبار
9. راجع النتائج في تبويب "Results"

### معلومات عن لوحة المعلومات

إذا كان `ShowDashboard = true`، ستظهر معلومات مباشرة على الرسم البياني:

```
══════ VORAX™ ULTRA-FAST SCALPING ══════
Symbol: XAUUSD
Spread: 0.8 pts
Buy Pressure: 72.5%  |  Sell Pressure: 27.5%
Momentum: +45.3  |  Strength: 45.3
Volatility: NORMAL  |  ATR: 0.85

Balance: 10,000.00
Equity: 10,150.00
Drawdown: 1.50%
Open Positions: 1

Status: BUY SIGNAL
```

### استكشاف الأخطاء

**المشكلة: "Symbol not found"**
- الحل: تحقق من الرمز الدقيق على وسيطك (Broker)
- الأنماط الشائعة: XAUUSD, XAUUSD.a, XAUUSDm, GOLD
- اضغط Ctrl+M لفتح Market Watch وتحقق من الرمز الفعلي

**المشكلة: "invalid stops" أخطاء**
- الحل: زيادة الحد الأدنى من نقاط SL
- بعض الوسطاء يتطلبون 10 نقاط على الأقل
- عدّل: Gold_MinSLPoints أو Bitcoin_MinSLPoints

**المشكلة: لا توجد تجارة**
- السبب المحتمل:
  1. الفارق (Spread) مرتفع جداً
  2. خارج ساعات الجلسة
  3. تقلبات شديدة (Extreme Volatility)
  4. وصل الحد الأقصى للخسائر اليومية
- الحل: فعّل Debug Mode = true واقرأ السجلات

**المشكلة: "insufficient margin"**
- الحل: قلل النسبة المئوية للمخاطر
- ابدأ برصيد حساب أكبر
- عدّل: Gold_RiskPercentPerTrade = 0.25%

### الإعدادات الموصى بها

#### للمبتدئين (جداً محافظ)
```
Gold_RiskPercentPerTrade = 0.25%
Gold_MaxDailyLoss = 1.00%
Bitcoin_RiskPercentPerTrade = 0.25%
Bitcoin_MaxDailyLoss = 1.00%
AllowReinforcement = false
DebugMode = true
```

#### للمتقدمين (متوازن)
```
Gold_RiskPercentPerTrade = 0.75%
Gold_MaxDailyLoss = 2.50%
Bitcoin_RiskPercentPerTrade = 0.75%
Bitcoin_MaxDailyLoss = 2.50%
AllowReinforcement = true
MaxReinforcementTrades = 1
```

#### للمتقدمين جداً (عدواني)
```
Gold_RiskPercentPerTrade = 1.00%
Gold_MaxDailyLoss = 3.00%
Bitcoin_RiskPercentPerTrade = 1.00%
Bitcoin_MaxDailyLoss = 3.00%
AllowReinforcement = true
MaxReinforcementTrades = 2
```

### نصائح مهمة ⚠️

✅ **افعل:**
- اختبر على Demo أولاً
- ابدأ برصيد صغير
- راقب الأداء يومياً
- احفظ السجلات
- اقرأ الرسائل في Terminal

❌ **لا تفعل:**
- لا تتداول بدون اختبار Demo
- لا تغيّر الإعدادات أثناء الجلسة
- لا تستخدم Leverage عالي جداً
- لا تعطّل stop-loss
- لا تترك EA بدون مراقبة لأيام طويلة

### الدعم والتحديثات

- GitHub: https://github.com/wesamtaraf1984-ux/VORAX-Ultra-Fast-Scalping-EA
- المشاكل والأسئلة: استخدم GitHub Issues
- التحديثات: راجع releases على GitHub

---

**تم التثبيت بنجاح! 🎉**

استمتع بـ VORAX™ - HUNT VOLATILITY. EXPLOIT MOMENTUM.
