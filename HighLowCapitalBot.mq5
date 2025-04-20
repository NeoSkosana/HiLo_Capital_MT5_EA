//+------------------------------------------------------------------+
//|                        HighLowCapitalBot.mq5                     |
//|                        Version: 1.0 | Date: 2025-04-20           |
//|                        Author: [Your Name/Org]                   |
//+------------------------------------------------------------------+
#property copyright   "[Your Name/Org]"
#property version     "1.0"
#property strict

//--- Input parameters
input int    EMA_Fast_Period = 50;                // Fast EMA period
input int    EMA_Slow_Period = 200;               // Slow EMA period
input string TDI_Custom_Indicator_Name = "TradersDynamicIndex.ex5"; // TDI indicator filename (place in MQL5\Indicators)
// TDI indicator parameters (add more as needed, matching your TDI source)
input int    TDI_RSI_Period = 13;
input int    TDI_Volatility_Band_Period = 34;
input string Telegram_Bot_Token = "7615545187:AAFL__WLJVNd9E5EcXLXOHv2OYCURo7I8Fw";             // Telegram Bot Token
input string Telegram_Chat_ID = "6636214769";               // Telegram Chat ID
input int    MagicNumber = 20250420;              // Unique EA identifier

//--- Indicator handles
int handleEMA50 = INVALID_HANDLE;
int handleEMA200 = INVALID_HANDLE;
int handleTDI = INVALID_HANDLE;

//--- TDI buffer indices (update based on your TDI source code)
#define TDI_RSI_PRICE_LINE 0
#define TDI_UPPER_BAND    1
#define TDI_LOWER_BAND    2

//--- State variables for lot size management
static double lastHighestAccountBalance = 0.0;
static double lastCalculatedLotSize = 0.0;

//--- Bar tracking for signal-once-per-bar
datetime lastBarTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    //--- Initialize indicator handles
    handleEMA50 = iMA(_Symbol, _Period, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
    handleEMA200 = iMA(_Symbol, _Period, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
    handleTDI = iCustom(_Symbol, _Period, TDI_Custom_Indicator_Name, TDI_RSI_Period, TDI_Volatility_Band_Period);
    if(handleEMA50 == INVALID_HANDLE || handleEMA200 == INVALID_HANDLE || handleTDI == INVALID_HANDLE)
    {
        Print("[ERROR] Indicator handle initialization failed.");
        return(INIT_FAILED);
    }
    //--- Initialize state variables
    lastHighestAccountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    lastCalculatedLotSize = CalculateLotSize(lastHighestAccountBalance);
    lastBarTime = 0;
    Print("[INIT] HighLowCapitalBot initialized. Version: 1.0");
    return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
    if(handleEMA50 != INVALID_HANDLE) IndicatorRelease(handleEMA50);
    if(handleEMA200 != INVALID_HANDLE) IndicatorRelease(handleEMA200);
    if(handleTDI != INVALID_HANDLE) IndicatorRelease(handleTDI);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    //--- Check for new bar
    datetime currentBarTime = iTime(_Symbol, _Period, 0);
    if(currentBarTime == lastBarTime) return;
    lastBarTime = currentBarTime;
    //--- Fetch indicator values
    double ema50[], ema200[];
    double tdi_rsi[], tdi_upper[], tdi_lower[];
    if(CopyBuffer(handleEMA50, 0, 0, 3, ema50) <= 0 ||
       CopyBuffer(handleEMA200, 0, 0, 3, ema200) <= 0 ||
       CopyBuffer(handleTDI, TDI_RSI_PRICE_LINE, 0, 3, tdi_rsi) <= 0 ||
       CopyBuffer(handleTDI, TDI_UPPER_BAND, 0, 3, tdi_upper) <= 0 ||
       CopyBuffer(handleTDI, TDI_LOWER_BAND, 0, 3, tdi_lower) <= 0)
    {
        Print("[ERROR] Failed to copy indicator buffers.");
        return;
    }
    //--- Signal logic (to be implemented)
    //--- Lot size management (to be implemented)
    //--- Telegram notification (to be implemented)
  }
//+------------------------------------------------------------------+
//| Calculate lot size based on account balance and broker constraints|
//+------------------------------------------------------------------+
double CalculateLotSize(double balance)
  {
    //--- Example calculation (update as needed)
    double riskAmount = balance * 0.05;
    double stopLossPips = 25.0;
    double pipValuePerLot = 10.0; // Simplified for USD pairs
    double rawLotSize = riskAmount / (stopLossPips * pipValuePerLot);
    //--- Normalize lot size
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double lot = MathMax(minLot, MathMin(maxLot, rawLotSize));
    lot = MathFloor(lot / lotStep) * lotStep;
    lot = NormalizeDouble(lot, 2);
    return lot;
  }
//+------------------------------------------------------------------+