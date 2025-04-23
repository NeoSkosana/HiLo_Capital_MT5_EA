//+------------------------------------------------------------------+
//| HighLowCapitalBot.mq5                                            |
//| Version: 1.0 | Date: 2025-04-20                                  |
//| Author: [Your Name/Org]                                          |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <MovingAverages.mqh>
#property copyright   "[Your Name/Org]"
#property version     "1.0"
#property strict

#define MODE_EMA 1
#define MODE_SMA 0
#define PRICE_CLOSE 0

//--- Input parameters (FR6)
input int    EMA_Fast_Period = 50;                // Fast EMA period (FR6.1)
input int    EMA_Slow_Period = 200;               // Slow EMA period (FR6.2)
input string TDI_Custom_Indicator_Name = "TradersDynamicIndex"; // TDI indicator filename (FR6.3)
input int    TDI_RSI_Period = 13;                 // RSI Period
input int    TDI_RSI_Price = PRICE_CLOSE;         // RSI Price type (e.g., PRICE_CLOSE)
input int    TDI_Volatility_Band_Period = 34;     // Volatility Band Period
input double TDI_StdDev = 1.6185;                 // Standard Deviations for Volatility Bands
input int    TDI_RSI_Price_Line = 2;              // RSI Price Line MA period
input int    TDI_RSI_Price_Type = MODE_SMA;       // RSI Price Line MA type
input int    TDI_Trade_Signal_Line = 7;           // Trade Signal Line MA period
input int    TDI_Trade_Signal_Type = MODE_SMA;    // Trade Signal Line MA type
input int    TDI_UpperTimeframe = 0;              // Upper timeframe (0 = current)
input string Telegram_Bot_Token = "";             // Telegram Bot Token (FR6.5)
input string Telegram_Chat_ID = "";               // Telegram Chat ID (FR6.6)
input int    MagicNumber = 20250420;              // Unique EA identifier (FR6.7)
input double Risk_Percent = 5.0;                  // Risk percent per trade (e.g., 1.0 = 1%)

//--- Indicator handles
int handleEMA50 = INVALID_HANDLE;
int handleEMA200 = INVALID_HANDLE;
int handleTDI = INVALID_HANDLE;

//--- State variables for lot size management (FR8)
double lastHighestAccountBalance = 0.0;
double lastCalculatedLotSize = 0.0;
datetime lastBarTime = 0;

//--- Trade object
CTrade trade;

// --- Lot size calculation function (FR8) ---
double CalculateLotSize()
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double wPercent = Risk_Percent / 100.0; // Convert input percent to fraction
    double lotSize = balance * wPercent / 100.0; // Example: $100 per 0.01 lot (adjust as needed)
    lotSize = MathMax(minLot, MathMin(maxLot, MathFloor(lotSize / lotStep) * lotStep));
    return lotSize;
}

// --- Telegram message sending function ---
void SendTelegramMessage(const string message)
{
    if(StringLen(Telegram_Bot_Token) == 0 || StringLen(Telegram_Chat_ID) == 0)
    {
        Print("[TELEGRAM] Bot token or chat ID not set.");
        return;
    }
    string url = "https://api.telegram.org/bot" + Telegram_Bot_Token + "/sendMessage?chat_id=" + Telegram_Chat_ID + "&text=" + UrlEncode(message);
    uchar post[];
    uchar result[];
    string headers = "";
    string result_headers = "";
    int timeout = 5000;
    int res = WebRequest("GET", url, headers, timeout, post, result, result_headers);
    if(res != 200)
        Print("[TELEGRAM] Failed to send message. HTTP code: ", res);
}

string UrlEncode(const string str)
{
    string encoded = "";
    for(int i = 0; i < StringLen(str); i++)
    {
        ushort c = StringGetCharacter(str, i);
        if((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9'))
            encoded += StringFormat("%c", c);
        else if(c == ' ')
            encoded += "+";
        else
            encoded += "%" + StringFormat("%02X", c);
    }
    return encoded;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    Print("[INIT] HighLowCapitalBot initializing. Version: 1.0");
    // Initialize EMA handles
    handleEMA50 = iMA(_Symbol, _Period, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
    handleEMA200 = iMA(_Symbol, _Period, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
    // Initialize TDI handle (pass TDI params as needed)
    handleTDI = iCustom(_Symbol, _Period, TDI_Custom_Indicator_Name);
    if(handleEMA50 == INVALID_HANDLE || handleEMA200 == INVALID_HANDLE || handleTDI == INVALID_HANDLE)
    {
        Print("[ERROR] Indicator handle initialization failed.");
        return(INIT_FAILED);
    }
    lastHighestAccountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    lastCalculatedLotSize = 0.0;
    lastBarTime = 0;
    Print("[INIT] Initialization complete. TDI params: RSI_Period=", TDI_RSI_Period, ", RSI_Price=", TDI_RSI_Price, ", Vol_Band_Period=", TDI_Volatility_Band_Period, ", StdDev=", TDI_StdDev, ", RSI_Price_Line=", TDI_RSI_Price_Line, ", RSI_Price_Type=", TDI_RSI_Price_Type, ", Trade_Signal_Line=", TDI_Trade_Signal_Line, ", Trade_Signal_Type=", TDI_Trade_Signal_Type, ", UpperTimeframe=", TDI_UpperTimeframe);
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
    Print("[DEINIT] HighLowCapitalBot deinitialized.");
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    // --- IsNewBar logic ---
    datetime currentBarTime = iTime(_Symbol, _Period, 0);
    if(currentBarTime == lastBarTime)
        return; // Not a new bar
    lastBarTime = currentBarTime;

    // --- Update lot size if new highest balance ---
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    if(currentBalance > lastHighestAccountBalance)
    {
        lastHighestAccountBalance = currentBalance;
        lastCalculatedLotSize = CalculateLotSize();
    }
    // If first run, initialize lot size
    if(lastCalculatedLotSize == 0.0)
        lastCalculatedLotSize = CalculateLotSize();

    // --- Read indicator values for previous closed bar (index 1) ---
    double ema50[2], ema200[2];
    if(CopyBuffer(handleEMA50, 0, 1, 2, ema50) <= 0 || CopyBuffer(handleEMA200, 0, 1, 2, ema200) <= 0)
    {
        Print("[ERROR] Failed to copy EMA buffers");
        return;
    }
    double closePrev = iClose(_Symbol, _Period, 1);

    // --- Read TDI buffers (assume buffer indices: 0=RSI Price Line, 1=Upper Band, 2=Lower Band) ---
    double tdiRSI[3], tdiUpper[3], tdiLower[3];
    if(CopyBuffer(handleTDI, 0, 1, 3, tdiRSI) <= 0 ||
       CopyBuffer(handleTDI, 1, 1, 3, tdiUpper) <= 0 ||
       CopyBuffer(handleTDI, 2, 1, 3, tdiLower) <= 0)
    {
        Print("[ERROR] Failed to copy TDI buffers");
        return;
    }

    // --- Signal logic implementation (FR2, FR3) ---
    bool buySignal = false, sellSignal = false;

    // Buy Signal Logic (FR2)
    if(ema50[1] > ema200[1] &&
      (closePrev > ema50[1] || closePrev > ema200[1]) &&
      tdiRSI[1] > tdiLower[1] && tdiRSI[2] <= tdiLower[2])
    {
        buySignal = true;
        Print("[SIGNAL] BUY detected: ", _Symbol, " ", EnumToString(_Period), " Time=", TimeToString(iTime(_Symbol, _Period, 1)),
              " LotSize=", DoubleToString(lastCalculatedLotSize, 2));
        SendTelegramMessage("BUY signal detected for " + _Symbol + " Lot: " + DoubleToString(lastCalculatedLotSize, 2));
        // --- Execute Buy Order ---
        if(trade.Buy(lastCalculatedLotSize, _Symbol))
            Print("[ORDER] Buy order placed successfully.");
        else
            Print("[ORDER] Buy order failed: ", trade.ResultRetcodeDescription());
    }

    // Sell Signal Logic (FR3)
    if(ema50[1] < ema200[1] &&
      (closePrev < ema50[1] || closePrev < ema200[1]) &&
      tdiRSI[1] < tdiUpper[1] && tdiRSI[2] >= tdiUpper[2])
    {
        sellSignal = true;
        Print("[SIGNAL] SELL detected: ", _Symbol, " ", EnumToString(_Period), " Time=", TimeToString(iTime(_Symbol, _Period, 1)),
              " LotSize=", DoubleToString(lastCalculatedLotSize, 2));
        SendTelegramMessage("SELL signal detected for " + _Symbol + " Lot: " + DoubleToString(lastCalculatedLotSize, 2));
        // --- Execute Sell Order ---
        if(trade.Sell(lastCalculatedLotSize, _Symbol))
            Print("[ORDER] Sell order placed successfully.");
        else
            Print("[ORDER] Sell order failed: ", trade.ResultRetcodeDescription());
    }
  }
//+------------------------------------------------------------------+
