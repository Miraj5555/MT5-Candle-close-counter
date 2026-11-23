//+------------------------------------------------------------------+
//|                                     CandleCloseCountdown.mq5      |
//|  Shows a countdown to the current candle's close.                |
//|  Syncs ONCE with MT5 on init/refresh and once again each time     |
//|  a new bar actually closes. Between syncs it counts down using   |
//|  the local PC clock only, so it never freezes on slow internet   |
//|  or a stalled tick feed.                                         |
//+------------------------------------------------------------------+
#property copyright "Custom"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots   0
#property indicator_buffers 0

input ENUM_BASE_CORNER InpCorner    = CORNER_RIGHT_UPPER; // Corner
input int              InpXOffset  = 64;                  // Box right edge, distance from chart's right edge (px)
input int              InpSlide    = 35;                  // Fixed px slide-right applied (as requested earlier)
input int              InpPadX     = 10;                   // Horizontal padding inside box (px, each side)
input int              InpPanelH   = 30;                   // Box height (px)
input color            InpBgColor  = clrBlack;             // Box background
input color            InpOutline  = clrWhite;             // Box outline
input int              InpFontSize = 13;                  // Font size
input color            InpColor    = clrWhite;             // Text color
input string           InpFontName = "Consolas";           // Font
input string           InpPrefix   = "CCD_";                // Object name prefix

string   BoxName, ValueName;
datetime g_barCloseTime;    // exact server-time close of current bar
datetime g_syncServerTime;  // server time at the moment of last sync
datetime g_syncLocalTime;   // local PC time at the moment of last sync
datetime g_lastBarOpen;     // open time of the bar we last synced against

//+------------------------------------------------------------------+
int OnInit()
{
   string id = IntegerToString(ChartID());
   BoxName   = InpPrefix + "box_" + id;
   ValueName = InpPrefix + "val_" + id;

   CreateLabel();
   SyncNow();
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectDelete(0, BoxName);
   ObjectDelete(0, ValueName);
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
// Black box with a white outline, plus the countdown text inside it.
//
// IMPORTANT: for CORNER_RIGHT_UPPER, OBJ_RECTANGLE_LABEL ALWAYS draws
// rightward/downward from its XDISTANCE/YDISTANCE — it silently ignores
// ANCHOR entirely. OBJ_LABEL text DOES respect ANCHOR, so ANCHOR_RIGHT_UPPER
// is set on the text so it grows leftward from its anchor and stays inset.
//
// The box's right edge is placed at (InpXOffset - InpSlide) px from the
// chart's right edge (the fixed slide requested earlier), and its width
// is recalculated every second in ResizeBox() to snugly fit whatever the
// current countdown string is — so "05:59" and "400:00:00" both get a
// tight-fitting box instead of one sized for a single fixed case.
//+------------------------------------------------------------------+
void CreateLabel()
{
   int effectiveR = InpXOffset - InpSlide;

   // Box (initial size — ResizeBox() keeps it accurate every tick)
   if(ObjectFind(0, BoxName) < 0)
      ObjectCreate(0, BoxName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, BoxName, OBJPROP_CORNER, InpCorner);
   ObjectSetInteger(0, BoxName, OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, BoxName, OBJPROP_YSIZE, InpPanelH);
   ObjectSetInteger(0, BoxName, OBJPROP_BGCOLOR, InpBgColor);
   ObjectSetInteger(0, BoxName, OBJPROP_COLOR, InpOutline);
   ObjectSetInteger(0, BoxName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, BoxName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, BoxName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, BoxName, OBJPROP_BACK, false);
   ObjectSetInteger(0, BoxName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, BoxName, OBJPROP_HIDDEN, true);

   // Text — right-anchored, inset InpPadX from the box's right edge.
   // This offset is fixed regardless of box width, so it's set once here.
   if(ObjectFind(0, ValueName) < 0)
      ObjectCreate(0, ValueName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, ValueName, OBJPROP_CORNER, InpCorner);
   ObjectSetInteger(0, ValueName, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, ValueName, OBJPROP_XDISTANCE, effectiveR + InpPadX);
   ObjectSetInteger(0, ValueName, OBJPROP_YDISTANCE, 27);
   ObjectSetString(0, ValueName, OBJPROP_FONT, InpFontName);
   ObjectSetInteger(0, ValueName, OBJPROP_FONTSIZE, InpFontSize);
   ObjectSetInteger(0, ValueName, OBJPROP_COLOR, InpColor);
   ObjectSetInteger(0, ValueName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, ValueName, OBJPROP_HIDDEN, true);

   ResizeBox("00:00"); // sane initial size before the first real tick
}

//+------------------------------------------------------------------+
// Recomputes the box's width to snugly fit the given text, keeping its
// right edge fixed at (InpXOffset - InpSlide) px from the chart edge.
//+------------------------------------------------------------------+
void ResizeBox(const string txt)
{
   int effectiveR = InpXOffset - InpSlide;
   int textW      = (int)MathRound(StringLen(txt) * InpFontSize * 0.62);
   int boxW       = textW + InpPadX * 2;

   ObjectSetInteger(0, BoxName, OBJPROP_XSIZE, boxW);
   ObjectSetInteger(0, BoxName, OBJPROP_XDISTANCE, effectiveR + boxW);
}

//+------------------------------------------------------------------+
// Pulls fresh, real data from MT5. Called on init/refresh, and once
// each time a new bar is detected. This is the ONLY place server
// data is trusted.
//+------------------------------------------------------------------+
void SyncNow()
{
   g_syncServerTime = TimeCurrent();
   g_syncLocalTime  = TimeLocal();
   g_lastBarOpen    = iTime(_Symbol, _Period, 0);
   g_barCloseTime   = g_lastBarOpen + PeriodSeconds(_Period);
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   return(rates_total);
}

//+------------------------------------------------------------------+
// Runs every second off the terminal's own timer (not chart ticks).
//+------------------------------------------------------------------+
void OnTimer()
{
   // Detect whether MT5 has actually rolled to a new bar. If so,
   // resync ONCE against real data for the new candle.
   datetime curBarOpen = iTime(_Symbol, _Period, 0);
   if(curBarOpen != 0 && curBarOpen != g_lastBarOpen)
      SyncNow();

   // Count down using ONLY the local PC clock's elapsed time.
   long elapsedLocal      = (long)(TimeLocal() - g_syncLocalTime);
   datetime estServerNow  = g_syncServerTime + elapsedLocal;
   long remaining = (long)(g_barCloseTime - estServerNow);
   if(remaining < 0) remaining = 0;

   string txt = FormatTime(remaining);
   ResizeBox(txt);
   ObjectSetString(0, ValueName, OBJPROP_TEXT, txt);
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
string FormatTime(const long secs)
{
   int h = (int)(secs / 3600);
   int m = (int)((secs % 3600) / 60);
   int s = (int)(secs % 60);
   if(h > 0)
      return StringFormat("%02d:%02d:%02d", h, m, s);
   return StringFormat("%02d:%02d", m, s);
}
//+------------------------------------------------------------------+
