pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import {AggregatorV2V3Interface} from "../interfaces/AggregatorV2V3Interface.sol";
import {IPyth} from "../interfaces/IPyth.sol";
import {IStdReference} from "./BandOracleInterfaces.sol";


contract BandOracleReader is AggregatorV2V3Interface, IPyth {
    // only available after solidity v0.8.4
    // error NotImplemented();
    string constant NOT_IMPLEMENTED = "NOT_IMPLEMENTED";

    IStdReference public bandOracle;
    string public base;
    string public quote;

    mapping(uint256 => int256) internal roundData;

    struct RateAtRound {
        int256 rate;
        uint256 round;
    }

    constructor(IStdReference _bandOracle, string memory _base, string memory _quote){
        bandOracle = _bandOracle;
        base = _base;
        quote = _quote;
    }

    function pullDataAndCache() public returns (RateAtRound memory) {
        IStdReference.ReferenceData data = bandOracle.getReferenceData(base, quote);
        uint256 round = block.timestamp;
        if (data.lastUpdatedBase != 0) {
            round = data.lastUpdatedBase;
        }
        roundData[round] = int256(data.rate);
        return RateAtRound(data.rate, round);
    }

    // ========= Chainlink interface ======
    function latestRound() external view returns (uint256) {
        // note that Band oracle sometimes return empty value for lastUpdatedBase and lastUpdatedQuote, even though they should contain the timestamp for the last update
        IStdReference.ReferenceData data = bandOracle.getReferenceData(base, quote);
        if (data.lastUpdatedBase != 0) {
            return data.lastUpdatedBase;
        }
        return block.timestamp;
    }

    function decimals() external view returns (uint8) {
        // Band oracle uses 18 decimals, see https://docs.bandchain.org/products/band-standard-dataset/using-band-standard-dataset/contract
        return 18;
    }

    function getAnswer(uint256 roundId) external view returns (int256){
        revert(NOT_IMPLEMENTED);
    }

    function getTimestamp(uint256 roundId) external view returns (uint256){
        revert(NOT_IMPLEMENTED);
    }

    function getRoundData(uint80 _roundId)
    external
    view
    returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        // There is no interface from Band oracle to retrieve previous round data
        // return previous round data if we have it, otherwise return empty data, unless round id equals block.timestamp, in which case we return the latest data
        if (uint256(_roundId) == block.timestamp) {
            return _latestRoundData();
        }
        int256 data = roundData[uint256(roundId)];
        if (data != 0) {
            return (roundId, data, roundId, roundId, roundId);
        }
        return (0, 0, 0, 0, 0);
    }

    function latestRoundData()
    external
    view
    returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ){
        return _latestRoundData();
    }

    function _latestRoundData() internal view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ){
        RateAtRound memory rr = pullDataAndCache();
        return (uint80(rr.round), rr.rate, rr.round, rr.round, uint80(rr.round));

    }
    // =============================================

    // ========= Pyth Interface =========
    function getValidTimePeriod() external view returns (uint validTimePeriod);

    function getPrice(bytes32 id) external view returns (PythStructs.Price memory price);

    function getEmaPrice(bytes32 id) external view returns (PythStructs.Price memory price);

    function getPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price);

    function getPriceNoOlderThan(bytes32 id, uint age) external view returns (PythStructs.Price memory price);

    function getEmaPriceUnsafe(bytes32 id) external view returns (PythStructs.Price memory price);

    function getEmaPriceNoOlderThan(bytes32 id, uint age) external view returns (PythStructs.Price memory price);

    function updatePriceFeeds(bytes[] calldata updateData) external payable;

    function updatePriceFeedsIfNecessary(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64[] calldata publishTimes
    ) external payable;

    function getUpdateFee(bytes[] calldata updateData) external view returns (uint feeAmount);

    function parsePriceFeedUpdates(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64 minPublishTime,
        uint64 maxPublishTime
    ) external payable returns (PythStructs.PriceFeed[] memory priceFeeds);
    // =============================================
}