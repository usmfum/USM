pragma solidity ^0.6.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title FUM Token
 * @author Alex Roan (@alexroan)
 *
 * @notice This should be owned by the stablecoin.
 */
contract FUM is ERC20, Ownable {

    constructor() public ERC20("Minimal Funding", "FUM") {
    }

    /**
     * @notice Mint new FUM to the _recipient
     *
     * @param _recipient address to mint to
     * @param _amount amount to mint
     */
    function mint(address _recipient, uint _amount) external onlyOwner {
        _mint(_recipient, _amount);
    }

    /**
     * @notice Burn FUM from _holder
     *
     * @param _holder address to burn from
     * @param _amount amount to burn
     */
    function burn(address _holder, uint _amount) external onlyOwner {
        _burn(_holder, _amount);
    }
}