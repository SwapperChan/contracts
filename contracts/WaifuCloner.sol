// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

// WaifuCloner are for simps who can't get enough of WAIFU. You come in with some WAIFU, and leave with more! The longer you stay, the more WAIFU you get.
//
// This contract handles swapping to and from xWAIFU
contract WaifuCloner is ERC20("Waifu Cloner", "xWAIFU") {
    using SafeMath for uint256;
    IERC20 public waifu;

    // Define the WAIFU token contract
    constructor(IERC20 _waifu) public {
        waifu = _waifu;
    }

    // Give the cloner some WAIFUs, earn some shares.
    // Locks WAIFU and mints xWAIFU
    function enter(uint256 _amount) public {
        // Gets the amount of WAIFU locked in the contract
        uint256 totalWaifu = waifu.balanceOf(address(this));
        // Gets the amount of xWAIFU in existence
        uint256 totalShares = totalSupply();
        // If no xWAIFU exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalWaifu == 0) {
            _mint(msg.sender, _amount);
        } 
        // Calculate and mint the amount of xWAIFU the WAIFU is worth. The ratio will change overtime, as xWAIFU is burned/minted and WAIFU deposited + gained from fees / withdrawn.
        else {
            uint256 what = _amount.mul(totalShares).div(totalWaifu);
            _mint(msg.sender, what);
        }
        // Lock the WAIFU in the contract
        waifu.transferFrom(msg.sender, address(this), _amount);
    }

    // Claim back your WAIFUs.
    // Unlocks the staked + gained WAIFU and burns xWAIFU
    function leave(uint256 _share) public {
        // Gets the amount of xWAIFU in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of WAIFU the xWAIFU is worth
        uint256 what = _share.mul(waifu.balanceOf(address(this))).div(totalShares);
        _burn(msg.sender, _share);
        waifu.transfer(msg.sender, what);
    }
}