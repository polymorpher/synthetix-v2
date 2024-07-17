See contracts/oracles/BandOracleReader.sol

Make one deployment for each asset pair (e.g. ONE/USD, BTC/USD, ETH/USD, ...)

Deployment constructor parameters:

- _bandOracle must be 0xA55d9ef16Af921b70Fed1421C1D298Ca5A3a18F1
- _base can be ONE, BTC, ETH, ...
- _quote should be USD, but maybe it can also be one of those symbols
- _updateFee can be anything (such as 0)

Owner (transferable) can change _updateFee and call `withdraw` to withdraw fees paid to the contract. Users reading via Pyth interface would need to pay `updateFee` in their normal Pyth pay-and-pull-data workflow.

Data returned via Pyth interface has only 9 decimal precision instead of 18 (provided by Band Protocol), since Pyth interface uses only 64-bit integer for price presentation.

Some Synthetix contracts appear to expect the oracle from Chainlink interfaces to support historical pricing (given round id). Relevant functions (from ExchangeRate and PerpsV2ExchangeRate contracts) are:

```
getLastRoundIdBeforeElapsedSecs
effectiveValueAndRatesAtRound
rateAndTimestampAtRound
ratesAndUpdatedTimeForCurrencyLastNRounds
anyRateIsInvalidAtRound
```

To support this, a mapping storage is added that caches prices based on block timestamps. Please run an external server to periodically call `pullDataAndCache` on the deployed reader. It will cost a very small amount of gas but will assist the contract to periodically store historical prices.


