pragma solidity ^0.6.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USM is ERC20 {

    constructor() public ERC20("Minimal USD", "USM") {
    }
}