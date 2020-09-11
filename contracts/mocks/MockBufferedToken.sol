pragma solidity ^0.6.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../BufferedToken.sol";


/**
 * @title Mock Buffered Token
 * @author Alberto Cuesta Cañada (@acuestacanada)
 * @notice This contract gives access to the internal functions of BufferedToken for testing
 */
contract MockBufferedToken is BufferedToken {

    // solhint-disable-next-line no-empty-blocks
    constructor(address _oracle, string memory _name, string memory _symbol) public BufferedToken(_oracle, _name, _symbol) { }

    function mint(uint ethAmount) public returns (uint) {
        return _mint(ethAmount);
    }

    function burn(uint usmAmount) public returns (uint) {
        return _burn(usmAmount);
    }

    function ethToUsm(uint _ethAmount) public view returns (uint) {
        return _ethToUsm(_ethAmount);
    }

    function usmToEth(uint usmAmount) public view returns (uint) {
        return _usmToEth(usmAmount);
    }

    function oraclePrice() public view returns (uint) {
        return _oraclePrice();
    }

}