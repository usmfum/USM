// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.6;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./IUSM.sol";
import "./WadMath.sol";

/**
 * @title FUMLimitOrderBook
 * @author Jacob Eliosoff
 *
 * @notice Stores FUM buy limit orders sent by users in a heap, plus stores the ETH they sent, and uses it to buy FUM on request,
 * if the limit price is met.
 */
contract FUMLimitOrderBook {
    using Address for address payable;
    using SafeMath for uint;
    using WadMath for uint;

    struct Bid {
        address sender;
        uint ethQty;
        uint maxFumPriceInEth;
        uint heapIndex;
    }

    IUSM public immutable usm;
    mapping(uint => Bid) public bids;       // Maps orderNumber (starts at 1) -> Bid struct
    uint public numBids;
    mapping(uint => uint) public bidHeap;     // Maps heap index (starts at 1 - not 0, careful!) -> orderNumber
    uint public bidHeapSize;

    /* ____________________ Constructor ____________________ */

    constructor(IUSM usm_) public {
        usm = usm_;
    }

    /* ____________________ External stateful functions ____________________ */

    function submitBid(uint maxFumPriceInEth) external payable returns (uint orderNumber) {
        uint heapIndex = ++bidHeapSize;
        orderNumber = ++numBids;
        bidHeap[heapIndex] = orderNumber;
        bids[orderNumber] = Bid(msg.sender, msg.value, maxFumPriceInEth, heapIndex);
        upheapIfNeeded(heapIndex);
    }

    function cancelBid(uint orderNumber) external {
        Bid memory bid = bids[orderNumber];
        require(bid.sender == msg.sender, "Only creator can cancel");
        extractBid(bid.heapIndex);
        msg.sender.sendValue(bid.ethQty);
    }

    /**
     * @notice Executes the given bid, if possible given its limit price and the current latestPrice(), *plus all other bids
     * ahead of it in the queue* (ie, bids with higher maxFumPriceInEth, or the same maxFumPriceInEth and lower orderNumbers).
     * Fails without effect if any bid fails: so either executes some number of bids including the requested one, or none.
     */
    function executeBid(uint orderNumberToExecute) external {
        require(bids[orderNumberToExecute].sender != address(0), "Bid doesn't exist");
        uint topOrderNumber;
        Bid memory topBid;
        do {
            (topOrderNumber, topBid) = extractBid(1);    // Again careful - our heap starts at 1, not 0
            uint minFumOut = topBid.ethQty.wadDivUp(topBid.maxFumPriceInEth);
            usm.fund{ value: topBid.ethQty }(topBid.sender, minFumOut);
        } while (topOrderNumber != orderNumberToExecute);
    }

    /* ____________________ Internal stateful functions ____________________ */

    /**
     * @dev These algos are mostly just adapted from good old Wikipedia.  https://en.wikipedia.org/wiki/Binary_heap
     */
    function extractBid(uint heapIndex) internal returns (uint orderNumber, Bid memory bid) {
        swapHeapElements(heapIndex, bidHeapSize);

        orderNumber = bidHeap[bidHeapSize];
        delete bidHeap[bidHeapSize];
        --bidHeapSize;
        bid = bids[orderNumber];
        delete bids[orderNumber];

        downheapIfNeeded(heapIndex);

        return (orderNumber, bid);
    }

    /**
     * @notice Repeatedly swap with its parent - the bid at index heapIndex/2 (rounded down) - if both a) the parent exists
     * (we're not already at index 1), and b) we belong ahead of the parent in the queue.
     */
    function upheapIfNeeded(uint heapIndex) internal {
        uint parentHeapIndex = heapIndex / 2;
        if ((parentHeapIndex > 0) && belongsBefore(heapIndex, parentHeapIndex)) {
            swapHeapElements(heapIndex, parentHeapIndex);
            upheapIfNeeded(parentHeapIndex);
        }
    }

    /**
     * @notice Repeatedly swap with the child (at indices 2*heapIndex and 2*heapIndex+1) that belongs earliest in the queue, if at
     * least one child a) exists and b) belongs earlier in the queue than this element.  Eg, if heapIndex = 13, we need to compare
     * and possibly swap with the elements at indices 26 and 27.  Then if, say, element 27 belonged ahead so we swapped 13 with
     * it, we need to consider swapping element 27 with elements 54 or 55, and so on.
     */
    function downheapIfNeeded(uint heapIndex) internal {
        uint child1HeapIndex = 2 * heapIndex;
        uint child2HeapIndex = 2 * heapIndex + 1;
        if (child1HeapIndex <= bidHeapSize) {
            if (belongsBefore(child1HeapIndex, heapIndex) &&
                (child2HeapIndex > bidHeapSize || belongsBefore(child1HeapIndex, child2HeapIndex)))
            {
                swapHeapElements(heapIndex, child1HeapIndex);
                downheapIfNeeded(child1HeapIndex);
            } else if (child2HeapIndex <= bidHeapSize && belongsBefore(child2HeapIndex, heapIndex)) {
                swapHeapElements(heapIndex, child2HeapIndex);
                downheapIfNeeded(child2HeapIndex);
            }
        }   // Neither child exists - no downheaping to do.
    }

    function swapHeapElements(uint heapIndex1, uint heapIndex2) internal {
        // First, swap the orderNumbers pointed to by the two bidHeap indices:
        (bidHeap[heapIndex1], bidHeap[heapIndex2]) = (bidHeap[heapIndex2], bidHeap[heapIndex1]);
        // Then, update each bid's internal heapIndex member:
        bids[bidHeap[heapIndex1]].heapIndex = heapIndex1;
        bids[bidHeap[heapIndex2]].heapIndex = heapIndex2;
    }

    /* ____________________ Internal view functions ____________________ */

    /**
     * @return before whether bid1 belongs before bid2 in the queue.
     */
    function belongsBefore(uint heapIndex1, uint heapIndex2) internal view returns (bool before) {
        uint orderNumber1 = bidHeap[heapIndex1];
        uint orderNumber2 = bidHeap[heapIndex2];
        uint bid1Price = bids[orderNumber1].maxFumPriceInEth;
        uint bid2Price = bids[orderNumber2].maxFumPriceInEth;
        before = (bid1Price > bid2Price) || (bid1Price == bid2Price && orderNumber1 < orderNumber2);
    }

    /* ____________________ External view functions, for testing ____________________ */

    function getOrderNumber(uint heapIndex) external view returns (uint num) {
        num = bidHeap[heapIndex];
    }

    function getBidDetails(uint orderNumber) external view returns (address sender, uint qty, uint price, uint heapIndex) {
        sender = bids[orderNumber].sender;
        qty = bids[orderNumber].ethQty;
        price = bids[orderNumber].maxFumPriceInEth;
        heapIndex = bids[orderNumber].heapIndex;
    }
}
