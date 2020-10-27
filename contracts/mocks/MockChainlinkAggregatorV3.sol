// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;


contract MockChainlinkAggregatorV3 {
    int internal _answer;

    function set(int value) external {
        _answer = value;
    }

    function latestRoundData() public view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, _answer, 0, 0, 0);
    }
}
