pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import {AggregatorV2V3Interface} from "../interfaces/AggregatorV2V3Interface.sol";
import {IPyth} from "../interfaces/IPyth.sol";
import {IStdReference} from "./BandOracleInterfaces.sol";
import {PythStructs} from "../interfaces/PythStructs.sol";
import {Owned} from "../Owned.sol";

contract BandOracleReader is AggregatorV2V3Interface, IPyth, Owned {
    // only available after solidity v0.8.4
    // error NotImplemented();
    string constant NOT_IMPLEMENTED = "NOT_IMPLEMENTED";

    IStdReference public bandOracle;
    string public base;
    string public quote;

    mapping(uint256 => int256) internal roundData;

    uint256 public updateFee;

    struct RateAtRound {
        int256 rate;
        uint256 round;
    }

    constructor(
        IStdReference _bandOracle,
        string memory _base,
        string memory _quote,
        uint256 _updateFee
    ) public {
        bandOracle = _bandOracle;
        base = _base;
        quote = _quote;
        updateFee = _updateFee;
    }

    function pullDataAndCache() public returns (RateAtRound memory) {
        IStdReference.ReferenceData memory data = bandOracle.getReferenceData(base, quote);
        uint256 round = block.timestamp;
        if (data.lastUpdatedBase != 0) {
            round = data.lastUpdatedBase;
        }
        roundData[round] = int256(data.rate);
        return RateAtRound(int256(data.rate), round);
    }

    // Owner functions

    function withdraw() external onlyOwner {
        (bool success, ) = owner.call.value(address(this).balance)("");
        require(success, "withdrawal failed");
    }

    function setUpdateFee(uint256 _fee) external onlyOwner {
        updateFee = _fee;
    }

    // ========= Chainlink interface ======
    function latestRound() external view returns (uint256) {
        // note that Band oracle sometimes return empty value for lastUpdatedBase and lastUpdatedQuote, even though they should contain the timestamp for the last update
        IStdReference.ReferenceData memory data = bandOracle.getReferenceData(base, quote);
        if (data.lastUpdatedBase != 0) {
            return data.lastUpdatedBase;
        }
        return block.timestamp;
    }

    function decimals() external view returns (uint8) {
        // Band oracle uses 18 decimals, see https://docs.bandchain.org/products/band-standard-dataset/using-band-standard-dataset/contract
        return 18;
    }

    function getAnswer(
        uint256 /*roundId*/
    ) external view returns (int256) {
        revert(NOT_IMPLEMENTED);
    }

    function getTimestamp(
        uint256 /*roundId*/
    ) external view returns (uint256) {
        revert(NOT_IMPLEMENTED);
    }

    function getRoundData(uint80 _roundId)
        external
        view
        returns (
            uint80, /*roundId*/
            int256, /*answer*/
            uint256, /*startedAt*/
            uint256, /*updatedAt*/
            uint80 /*answeredInRound*/
        )
    {
        // There is no interface from Band oracle to retrieve previous round data
        // return previous round data if we have it, otherwise return empty data, unless round id equals block.timestamp, in which case we return the latest data
        if (uint256(_roundId) == block.timestamp) {
            return _latestRoundData();
        }
        int256 data = roundData[uint256(_roundId)];
        if (data != 0) {
            return (_roundId, data, _roundId, _roundId, _roundId);
        }
        return (0, 0, 0, 0, 0);
    }

    function latestRoundData()
        external
        view
        returns (
            uint80, /*roundId*/
            int256, /*answer*/
            uint256, /*startedAt*/
            uint256, /*updatedAt*/
            uint80 /*answeredInRound*/
        )
    {
        return _latestRoundData();
    }

    function _latestRoundData()
        internal
        view
        returns (
            uint80, /*roundId*/
            int256, /*answer*/
            uint256, /*startedAt*/
            uint256, /*updatedAt*/
            uint80 /*answeredInRound*/
        )
    {
        IStdReference.ReferenceData memory data = bandOracle.getReferenceData(base, quote);
        uint256 round = block.timestamp;
        if (data.lastUpdatedBase != 0) {
            round = data.lastUpdatedBase;
        }
        return (uint80(round), int256(data.rate), round, round, uint80(round));
    }

    // =============================================

    // ========= Pyth Interface =========
    function _getPrice() internal view returns (PythStructs.Price memory price) {
        (, int256 rate, uint256 time, , ) = _latestRoundData();
        price.publishTime = time;
        price.conf = 0;
        price.expo = 9;
        price.price = int64(rate / 1e9);
        return price;
    }

    function getValidTimePeriod()
        external
        view
        returns (
            uint /*validTimePeriod*/
        )
    {
        revert(NOT_IMPLEMENTED);
    }

    function getPrice(
        bytes32 /*id*/
    )
        external
        view
        returns (
            PythStructs.Price memory /*price*/
        )
    {
        return _getPrice();
    }

    function getEmaPrice(
        bytes32 /*id*/
    )
        external
        view
        returns (
            PythStructs.Price memory /*price*/
        )
    {
        revert(NOT_IMPLEMENTED);
    }

    function getPriceUnsafe(
        bytes32 /*id*/
    )
        external
        view
        returns (
            PythStructs.Price memory /*price*/
        )
    {
        return _getPrice();
    }

    function getPriceNoOlderThan(
        bytes32, /*id*/
        uint /*age*/
    )
        external
        view
        returns (
            PythStructs.Price memory /*price*/
        )
    {
        revert(NOT_IMPLEMENTED);
    }

    function getEmaPriceUnsafe(
        bytes32 /*id*/
    )
        external
        view
        returns (
            PythStructs.Price memory /*price*/
        )
    {
        revert(NOT_IMPLEMENTED);
    }

    function getEmaPriceNoOlderThan(
        bytes32, /*id*/
        uint /*age*/
    )
        external
        view
        returns (
            PythStructs.Price memory /*price*/
        )
    {
        revert(NOT_IMPLEMENTED);
    }

    function updatePriceFeeds(
        bytes[] calldata /*updateData*/
    ) external payable {
        // noop
    }

    function updatePriceFeedsIfNecessary(
        bytes[] calldata, /*updateData*/
        bytes32[] calldata, /*priceIds*/
        uint64[] calldata /*publishTimes*/
    ) external payable {
        // noop
    }

    function getUpdateFee(bytes[] calldata updateData) external view returns (uint feeAmount) {
        feeAmount = updateFee;
    }

    function parsePriceFeedUpdates(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64 minPublishTime,
        uint64 maxPublishTime
    )
        external
        payable
        returns (
            PythStructs.PriceFeed[] memory /*priceFeeds*/
        )
    {
        revert(NOT_IMPLEMENTED);
    }
    // =============================================
}
