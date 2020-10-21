// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "./IOracle.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CompositeOracle is IOracle, Ownable {
    using SafeMath for uint;

    IOracle[] public oracles;
    uint public override decimalShift;

    // The source oracles may have different decimalShifts from us, so we'll need to shift them:
    bool[] private shiftSigns;
    uint[] private shiftFactors;

    constructor(IOracle[] memory oracles_, uint decimalShift_)
        public
    {
        oracles = oracles_; 
        decimalShift = decimalShift_;

        // We assume here that source oracles never change their decimalShifts!
        shiftSigns = new bool[](oracles_.length);
        shiftFactors = new uint[](oracles_.length);
        for (uint i = 0; i < oracles_.length; ++i) {
            uint shift = decimalShift_ - oracles_[i].decimalShift();
            shiftSigns[i] = shift > 0;
            // If the source is shifted 15 places, and we want 20 places, then we need to *multiply* its prices by 10**(20-15).
            // Or, if the source is shifted 30 places, and we want 20 places, then we need to *divide* its prices by 10**(30-20).
            shiftFactors[i] = 10 ** (shiftSigns[i] ? shift : -shift);
        }
    }

    function latestPrice()
        external override view returns (uint)
    {
        uint[] memory sourcePrices = new uint[](oracles.length);
        for (uint i = 0; i < oracles.length; ++i) {
            uint rawSourcePrice = oracles[i].latestPrice();
            sourcePrices[i] = (shiftSigns[i] ? rawSourcePrice.mul(shiftFactors[i]) : rawSourcePrice.div(shiftFactors[i]));
        }
        return median(sourcePrices);
    }

    function median(uint[] memory arr)
        public pure returns (uint)
    {
        sort(arr);
        if (arr.length % 2 == 1) {
            return arr[arr.length / 2];
        } else {
            return arr[arr.length / 2 - 1].add(arr[arr.length / 2]).div(2);     // Average of the two middle elements
        }
    }

    function sort(uint[] memory arr)
        public pure
    {
        quickSort(arr, int(0), int(arr.length) - 1);
    }

    /**
     * @notice From @subhodi at https://gist.github.com/subhodi/b3b86cc13ad2636420963e692a4d896f, fixing @chriseth's (slightly
     * broken!) version at https://ethereum.stackexchange.com/a/1518/64318
     */
    function quickSort(uint[] memory arr, int left, int right)
         public pure
    {
        if (left >= right) {
            return;
        }
        uint pivot = arr[uint((left + right) / 2)];
        int i = left;
        int j = right;
        while (i <= j) {
            while (arr[uint(i)] < pivot) ++i;
            while (pivot < arr[uint(j)]) --j;
            if (i <= j) {
                (arr[uint(i)], arr[uint(j)]) = (arr[uint(j)], arr[uint(i)]);
                ++i;
                --j;
            }
        }
        quickSort(arr, left, j);
        quickSort(arr, i, right);
    }
}
