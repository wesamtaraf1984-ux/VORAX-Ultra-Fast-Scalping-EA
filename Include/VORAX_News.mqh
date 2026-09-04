//+------------------------------------------------------------------+
//|                                                    VORAX_News.mqh |
//|                                   VORAX™ Ultra-Fast Scalping EA   |
//|                           Copyright 2024 - Professional Edition   |
//+------------------------------------------------------------------+

#ifndef VORAX_NEWS_H
#define VORAX_NEWS_H

#include "VORAX_Defines.mqh"
#include "VORAX_Utils.mqh"

//--- News Filter Class
class CNewsFilter
{
private:
    bool enabled;
    int minutesBefore;
    int minutesAfter;
    CLogger *logger;
    
    datetime lastNewsTime;
    datetime nextNewsTime;

public:
    CNewsFilter(bool enable = false, int before = 5, int after = 10, CLogger *log = NULL)
        : enabled(enable), minutesBefore(before), minutesAfter(after), logger(log),
          lastNewsTime(0), nextNewsTime(0)
    {
        if (logger) logger->Debug("NewsFilter", "News filter initialized - Enabled: " + 
                                 string(enabled ? "Yes" : "No"));
    }
    
    void SetEnabled(bool state) { enabled = state; }
    void SetMinutesBeforeNews(int mins) { minutesBefore = mins; }
    void SetMinutesAfterNews(int mins) { minutesAfter = mins; }
    
    // ===== CHECK IF TRADING IS ALLOWED =====
    bool IsTradeAllowed()
    {
        if (!enabled) return true;
        
        datetime currentTime = TimeCurrent();
        
        // Simple implementation: High impact economic events are typically
        // on Tuesdays and Wednesdays, 1330 GMT, 1600 GMT, 2030 GMT
        // For production, integrate with actual economic calendar API
        
        int dayOfWeek = DayOfWeek();
        int hour = Hour();
        int minute = Minute();
        int timeOfDay = hour * 100 + minute;
        
        // High impact news times (example)
        int newsTimeWindows[] = {1330, 1600, 2030};
        
        for (int i = 0; i < ArraySize(newsTimeWindows); i++) {
            int newsHour = newsTimeWindows[i] / 100;
            int newsMin = newsTimeWindows[i] % 100;
            
            datetime newsTime = StructCreate(newsHour, newsMin, 0);
            int timeDiffMinutes = (int)((currentTime - newsTime) / 60);
            
            if (timeDiffMinutes >= -minutesBefore && timeDiffMinutes <= minutesAfter) {
                if (logger) logger->Warning("NewsFilter", "Trading blocked - News window active");
                return false;
            }
        }
        
        return true;
    }
    
    bool IsEnabled() { return enabled; }

private:
    datetime StructCreate(int h, int m, int s)
    {
        MqlDateTime mdt;
        mdt.year = Year();
        mdt.mon = Month();
        mdt.day = Day();
        mdt.hour = h;
        mdt.min = m;
        mdt.sec = s;
        mdt.day_of_week = DayOfWeek();
        mdt.day_of_year = DayOfYear();
        return StructToTime(mdt);
    }
};

#endif
