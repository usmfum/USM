// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;
import "./GasMeasuredOracle.sol";
import "./SettableOracle.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@nomiclabs/buidler/console.sol";


contract TestOracle is SettableOracle(this), GasMeasuredOracle("test"), Ownable {
    using SafeMath for uint;

    uint public override(SettableOracle, IOracle) decimalShift;

    constructor(uint price, uint shift) public {
        setPrice(price);
        decimalShift = shift;
        // 25000, 2 = $250.00
    }
}
