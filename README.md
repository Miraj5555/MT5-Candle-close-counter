# Candle Close Countdown

A simple candle close timer for MetaTrader 5.

It syncs once with MT5 server time when it loads and again at every new bar, then counts down using your computer's clock. Because of this, the timer keeps running smoothly even when your internet is slow or ticks stop coming in.

- Accurate to the second, as long as your PC clock is synced
- Runs locally in MT5, so no VPS is needed
- Clean black box with a white outline, placed on the chart
- Customizable corner, position, size, font, and colors

**Install:** Download `CandleCloseCountdown.ex5` from Releases, copy it to `MQL5/Indicators/`, refresh the Navigator, and drag it onto a chart.
