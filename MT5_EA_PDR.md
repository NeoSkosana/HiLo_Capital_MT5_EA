# Product Requirements Document: MT5 Forex Signal Bot (Telegram)

**Version:** 1.1
**Date:** 2025-04-20 (Based on user clarification date)
**Author/Stakeholder:** [User Name/Organization]

---

**Table of Contents**

1.  [Introduction](#1-introduction)
2.  [Goals & Objectives](#2-goals--objectives)
3.  [Assumptions & Dependencies](#3-assumptions--dependencies)
4.  [User Roles](#4-user-roles)
5.  [Functional Requirements](#5-functional-requirements)
    * [FR1: Indicator Calculation](#fr1-indicator-calculation)
    * [FR2: Buy Signal Logic](#fr2-buy-signal-logic)
    * [FR3: Sell Signal Logic](#fr3-sell-signal-logic)
    * [FR4: Signal Timing & Frequency](#fr4-signal-timing--frequency)
    * [FR5: Telegram Notification](#fr5-telegram-notification)
    * [FR6: Configuration (EA Inputs)](#fr6-configuration-ea-inputs)
    * [FR7: Logging](#fr7-logging)
    * [FR8: Lot Size State Management](#fr8-lot-size-state-management)
6.  [Non-Functional Requirements](#6-non-functional-requirements)
7.  [Data Requirements](#7-data-requirements)
8.  [Release Criteria](#8-release-criteria)
9.  [Glossary](#9-glossary)

---

## 1. Introduction

* **1.1. Purpose:** This document describes the requirements for an automated trading bot (Expert Advisor - EA) for the MetaTrader 5 (MT5) platform. The primary purpose of this bot is **not** to place trades directly but to analyze market conditions based on a predefined strategy and send alert notifications via Telegram when potential entry signals occur, including a suggested lot size based on a specific risk model.
* **1.2. Scope:** The bot will run on the MT5 platform, utilize specific technical indicators (EMAs, TDI from provided source), evaluate entry conditions based on the defined logic, calculate a suggested lot size, manage lot size based on account balance growth, and trigger Telegram messages detailing the signal. It will be developed using MQL5, adhering to industry best practices for algorithmic trading software. Direct trade execution and backtesting capabilities within the bot itself are out of scope (backtesting will be done via MT5's Strategy Tester).
* **1.3. Target Audience:** This document is intended for the MQL5 developer(s) building the bot and the trader/user who will configure and utilize the bot's signals.

## 2. Goals & Objectives

* **2.1. Goal:** Automate the detection of trading signals based on the specified technical strategy.
* **2.2. Goal:** Provide timely and informative notifications of these signals, including a risk-based suggested lot size, to the user via Telegram.
* **2.3. Goal:** Implement a specific lot sizing logic that adjusts based on achieving new account balance highs.
* **2.4. Objective:** Ensure accurate calculation of all required technical indicators (EMA 50, EMA 200, TDI via `iCustom`).
* **2.5. Objective:** Implement the specific signal logic precisely as defined.
* **2.6. Objective:** Achieve reliable and stable operation on the MT5 platform.
* **2.7. Objective:** Develop maintainable and understandable MQL5 code following best practices.

## 3. Assumptions & Dependencies

* **3.1. Platform:** The user has an operational MetaTrader 5 terminal connected to a broker account (Demo or Live).
* **3.2. Connectivity:** A stable internet connection is required for both MT5 market data and sending Telegram messages.
* **3.3. Telegram:** The user has a Telegram account and has created a Telegram Bot to obtain the necessary API Token and Chat ID.
* **3.4. MQL5 Environment:** The bot will be developed and compiled using the MetaEditor environment included with MT5.
* **3.5. Market Data:** The MT5 terminal provides sufficient historical and real-time market data for the chosen symbol(s) and timeframe(s).
* **3.6. TDI Indicator Source:** **The user will provide the source code (`.mql5` file) for the specific Traders Dynamic Index (TDI) indicator to be used.** The EA will utilize this indicator via `iCustom`.
* **3.7. Lot Size Parameters:** The risk parameters for lot size calculation (5% risk, 25 pip stop loss target, $10/pip/lot value) are assumed to be fixed for this version.
* **3.8. Broker Constraints:** The EA should respect the minimum, maximum, and step volume constraints for the specific symbol being analyzed when calculating/suggesting the lot size.

## 4. User Roles

* **4.1. Trader/User:** Configures the bot's input parameters (indicator settings if applicable, Telegram details, etc.), attaches it to MT5 charts, monitors signals received via Telegram, and makes manual trading decisions based on the signals.
* **4.2. Developer:** Uses this PRD to code, test, and debug the MQL5 Expert Advisor, integrating the provided TDI indicator source.

## 5. Functional Requirements

### FR1: Indicator Calculation

* **FR1.1:** The EA must calculate the 50-period Exponential Moving Average (EMA) based on the closing price of each bar using `iMA`.
* **FR1.2:** The EA must calculate the 200-period Exponential Moving Average (EMA) based on the closing price of each bar using `iMA`.
* **FR1.3:** The EA must calculate the Traders Dynamic Index (TDI) indicator values by calling the user-provided TDI indicator file via `iCustom`. The specific buffer indices corresponding to the required lines must be identified from the provided TDI source code. Required lines are:
    * RSI Price Line (Assumed Green)
    * Upper Volatility Band (Assumed Blue)
    * Lower Volatility Band (Assumed Blue)
* **FR1.4 (TDI Parameters):** The EA should allow TDI parameters (e.g., RSI Period, Signal Period, Price type, MA types, Volatility Band Period) to be passed through to the `iCustom` call via EA inputs (See FR6). Default values should match common standards or the defaults in the provided TDI file.

### FR2: Buy Signal Logic

* A Buy signal is generated on the close of a new bar if **ALL** the following conditions are met:
    * **FR2.1:** The value of the 50 EMA is greater than the value of the 200 EMA (`EMA(50)[1] > EMA(200)[1]` - checked on the previously closed bar).
    * **FR2.2:** The Closing Price of the previously closed bar is greater than the 50 EMA **OR** the Closing Price is greater than the 200 EMA (`Close[1] > EMA(50)[1] OR Close[1] > EMA(200)[1]`).
    * **FR2.3:** The TDI's RSI Price Line (Green) crosses **above** the TDI's Lower Volatility Band (Blue). This means:
        * `TDI_RSI_Price_Line[1] > TDI_Lower_Volatility_Band[1]` (Current value is above the band)
        * `TDI_RSI_Price_Line[2] <= TDI_Lower_Volatility_Band[2]` (Previous value was on or below the band)

### FR3: Sell Signal Logic

* A Sell signal is generated on the close of a new bar if **ALL** the following conditions are met:
    * **FR3.1:** The value of the 50 EMA is less than the value of the 200 EMA (`EMA(50)[1] < EMA(200)[1]` - checked on the previously closed bar).
    * **FR3.2:** The Closing Price of the previously closed bar is less than the 50 EMA **OR** the Closing Price is less than the 200 EMA (`Close[1] < EMA(50)[1] OR Close[1] < EMA(200)[1]`).
    * **FR3.3:** The TDI's RSI Price Line (Green) crosses **below** the TDI's Upper Volatility Band (Blue). This means:
        * `TDI_RSI_Price_Line[1] < TDI_Upper_Volatility_Band[1]` (Current value is below the band)
        * `TDI_RSI_Price_Line[2] >= TDI_Upper_Volatility_Band[2]` (Previous value was on or above the band)

### FR4: Signal Timing & Frequency

* **FR4.1:** Signal conditions (FR2, FR3) must be evaluated only once per bar, specifically when a new bar opens/closes on the chart timeframe the EA is attached to. (Check conditions based on index `[1]` for the most recently closed bar. Use `IsNewBar()` logic within `OnTick` or use `OnCalculate`).
* **FR4.2:** Only one Telegram notification should be sent per signal *cross* event (FR2.3 or FR3.3). If the conditions remain true on subsequent bars but no new *cross* occurs, no new message should be sent.

### FR5: Telegram Notification

* **FR5.1:** Upon successful generation of a Buy (FR2) or Sell (FR3) signal, the EA must immediately attempt to send a message to the specified Telegram Chat ID via the specified Telegram Bot Token.
* **FR5.2:** The message content must include:
    * Symbol (e.g., EURUSD)
    * Chart Timeframe (e.g., H1)
    * Signal Type (e.g., "BUY Signal" or "SELL Signal")
    * Time of Signal (Bar closing time `Time[1]`, formatted, using Broker time zone)
    * Suggested Lot Size (Calculated according to FR8, formatted to 2 decimal places)
    * *Example Format:*
        ```
        **[Symbol] [Timeframe] Alert**
        Type: [BUY/SELL] Signal
        Time: [YYYY.MM.DD HH:MM] (Broker)
        Suggested Lot: [LotSize]
        ```
* **FR5.3:** The Telegram message must be sent using MQL5's `WebRequest` function, targeting the Telegram Bot API endpoint (`https://api.telegram.org/bot<TOKEN>/sendMessage`). Ensure the message text is properly URL-encoded.
* **FR5.4:** The EA must handle potential errors during the `WebRequest` (e.g., network issues, invalid token/chat ID). Errors should be logged (FR7) but should not cause the EA to crash.

### FR6: Configuration (EA Inputs)

* The EA must provide the following parameters as user-configurable inputs:
    * **FR6.1:** `EMA_Fast_Period` (int, Default: 50)
    * **FR6.2:** `EMA_Slow_Period` (int, Default: 200)
    * **FR6.3:** `TDI_Custom_Indicator_Name` (string, Default: "NameOfProvidedTDIFile.ex5" - User must set this to the compiled name of the provided TDI indicator)
    * **FR6.4:** TDI Indicator Parameters (inputs matching the parameters of the provided TDI `.mql5` file, allowing overrides of its defaults - e.g., `TDI_RSI_Period`, `TDI_Volatility_Band_Period`, etc.)
    * **FR6.5:** `Telegram_Bot_Token` (string)
    * **FR6.6:** `Telegram_Chat_ID` (string)
    * **FR6.7:** `MagicNumber` (int, Default: [Suggest a unique number]) - Unique identifier for the EA instance.

### FR7: Logging

* The EA must log important events and errors to the MT5 Experts journal/log tab.
    * **FR7.1:** Log EA initialization (name, version, parameters including key TDI params used).
    * **FR7.2:** Log detected Buy/Sell signals (Symbol, Timeframe, Type, Time[1]).
    * **FR7.3:** Log calculated Lot Size and the `lastHighestAccountBalance` used for calculation.
    * **FR7.4:** Log successful Telegram message sending attempts.
    * **FR7.5:** Log failed Telegram message sending attempts, including any error codes or reasons if available.
    * **FR7.6:** Log critical errors encountered during indicator calculation (`iCustom` errors, `iMA` errors) or execution.
    * **FR7.7:** Log when `lastHighestAccountBalance` is updated.

### FR8: Lot Size State Management

* **FR8.1:** The EA must maintain two persistent state variables (e.g., using global variables or EA properties):
    * `lastHighestAccountBalance`: Stores the highest account balance recorded since the EA started or since the last update. Initialized to the current `AccountInfoDouble(ACCOUNT_BALANCE)` on EA start.
    * `lastCalculatedLotSize`: Stores the lot size used in the last sent Telegram message. Initialized on EA start based on the initial balance.
* **FR8.2:** Lot Size Calculation Formula:
    * `riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * 0.05`
    * `stopLossPips = 25`
    * `pipValuePerLot = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE)` (Note: This calculates value per tick; adjust based on point size if needed, or assume $10 for USD-quoted pairs if simpler, but verify). *Alternative Simpler Formula (Based on $10/pip/lot & 25 pip SL):* `rawLotSize = AccountInfoDouble(ACCOUNT_BALANCE) * 0.05 / (25 * 10)` = `AccountInfoDouble(ACCOUNT_BALANCE) * 0.0002`.
    * The developer should verify the correct pip value calculation for various symbols or confirm if the simplified formula is sufficient.
* **FR8.3:** Lot Size Normalization:
    * The calculated `rawLotSize` must be normalized:
        * Rounded to two decimal places (`NormalizeDouble(rawLotSize, 2)`).
        * Adjusted to comply with `SYMBOL_VOLUME_MIN`, `SYMBOL_VOLUME_MAX`, and `SYMBOL_VOLUME_STEP` for the current symbol. If `rawLotSize` is below min, use min. If above max, use max. Adjust to the nearest valid step.
* **FR8.4:** Lot Size Update Logic:
    * Before sending a Telegram message (FR5):
        * Get the current `currentAccountBalance = AccountInfoDouble(ACCOUNT_BALANCE)`.
        * IF `currentAccountBalance > lastHighestAccountBalance`:
            * Calculate `newLotSize` using FR8.2 and FR8.3 based on `currentAccountBalance`.
            * Update `lastCalculatedLotSize = newLotSize`.
            * Update `lastHighestAccountBalance = currentAccountBalance`.
            * Log the update (FR7.7).
        * ELSE (`currentAccountBalance <= lastHighestAccountBalance`):
            * Do not recalculate or update `lastCalculatedLotSize`. Continue using the existing value.
    * The value of `lastCalculatedLotSize` (either newly updated or the previous value) is used in the Telegram message (FR5.2).

## 6. Non-Functional Requirements

* **NFR1: Performance:**
    * **NFR1.1:** Indicator calculations (`iMA`, `iCustom`) and signal checks should be efficient and not significantly slow down the MT5 terminal performance. Minimize redundant indicator calls.
    * **NFR1.2:** Avoid unnecessary calculations or repetitive actions within a single bar.
    * **NFR1.3:** `WebRequest` for Telegram should be executed efficiently.
* **NFR2: Reliability:**
    * **NFR2.1:** The EA must run stably without crashing during normal operation.
    * **NFR2.2:** The EA must handle potential errors gracefully (e.g., invalid indicator handles from `iCustom`, network timeouts for Telegram, missing historical data, zero balance) by logging the error and continuing operation where possible. Handle potential division-by-zero in lot size calculation if balance is zero or negative.
    * **NFR2.3:** The EA should function correctly across different brokers and account types (Hedging/Netting - though less relevant as it's not trading).
* **NFR3: Usability:**
    * **NFR3.1:** EA input parameters (FR6) must be clearly named and understandable, with comments in the Inputs tab if possible.
    * **NFR3.2:** Log messages (FR7) should be informative and easy to understand for troubleshooting.
* **NFR4: Maintainability (MQL5 Best Practices):**
    * **NFR4.1:** Code must be well-structured and commented.
    * **NFR4.2:** Use meaningful variable and function names.
    * **NFR4.3:** Employ modular design (e.g., separate functions for indicator calls, signal logic, lot size calculation, Telegram sending). Consider using MQL5 classes where appropriate (e.g., for Telegram integration, State Management).
    * **NFR4.4:** Adhere to standard MQL5 coding conventions. Avoid "magic numbers" (e.g., buffer indices for `iCustom` should be clearly defined, possibly as constants).
    * **NFR4.5:** Ensure proper resource handling (e.g., indicator handles via `IndicatorRelease`).
* **NFR5: Security:**
    * **NFR5.1:** The Telegram Bot Token and Chat ID, being sensitive, must be input parameters and not hardcoded into the source code.

## 7. Data Requirements

* **DR1:** Access to historical and real-time Bar data (Open, High, Low, Close, Time) for the chart Symbol/Timeframe.
* **DR2:** Access to calculated values from EMA(50), EMA(200) indicators.
* **DR3:** Access to calculated values (specifically RSI Price Line, Upper/Lower Volatility Bands) from the custom TDI indicator via `iCustom`.
* **DR4:** Access to Account Information (`AccountInfoDouble(ACCOUNT_BALANCE)`).
* **DR5:** Access to Symbol Information (`SymbolInfoDouble`, `SymbolInfoInteger` for volume constraints, pip value).

## 8. Release Criteria

* **RC1:** All Functional Requirements (FR1-FR8) implemented.
* **RC2:** All Non-Functional Requirements (NFR1-NFR5) met.
* **RC3:** Successful compilation without errors or critical warnings in MetaEditor using the provided TDI source code.
* **RC4:** Successful signal generation, lot size calculation (including state management), and Telegram message delivery verified in MT5 Strategy Tester (Visual Mode) against historical data matching known signal occurrences.
* **RC5:** Stable execution on a Demo account for a predefined period (e.g., 48 hours) without crashes or unexpected errors, correctly updating lot size only when new balance highs are reached.
* **RC6:** Code review passed, confirming adherence to MQL5 best practices (NFR4) and correct implementation of the logic.

## 9. Glossary

* **EA (Expert Advisor):** An automated trading program written in MQL5 for the MetaTrader 5 platform.
* **EMA (Exponential Moving Average):** A type of moving average that gives more weight to recent prices.
* **MQL5:** MetaQuotes Language 5, the programming language used for developing trading robots and indicators on MT5.
* **MT5 (MetaTrader 5):** A popular electronic trading platform widely used by online retail forex traders.
* **TDI (Traders Dynamic Index):** A technical indicator that uses RSI, moving averages, and volatility bands (based on Bollinger Bands) to determine market state and potential trade signals.
    * **RSI Price Line:** Typically the main green line in TDI, based on RSI calculation.
    * **Trade Signal Line:** Typically a red line, a slower moving average of the RSI Price Line.
    * **Market Base Line:** Typically a yellow line, a medium-term moving average indicating overall direction.
    * **Volatility Bands:** Typically blue lines, based on Bollinger Bands applied to the RSI Price Line, indicating market volatility.
* **iCustom:** An MQL5 function used to call custom indicators within an EA or another indicator.
* **Pip (Price Interest Point):** A unit of change in an exchange rate. Typically the 4th decimal place for most pairs (e.g., 0.0001), or 2nd for JPY pairs.
* **Point:** The smallest possible price change, often 1/10th of a pip for 5-decimal brokers.
* **Lot Size:** The volume or quantity of a trade. Standard lot = 100,000 units. Mini lot = 10,000 units. Micro lot = 1,000 units (0.01).
* **Account Balance:** The amount of money in an account, excluding profit/loss from open positions.
* **Account Equity:** The account balance plus or minus the profit/loss from open positions.