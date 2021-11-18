// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

// Waifu Token
contract WaifuToken is ERC20("Waifu Token", "WAIFU"), Ownable {

    using SafeMath for uint256;

    uint256 public constant TOTAL_SUPPLY_CAP = 500000000 ether;

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (MasterSimp).
    function mint(address _to, uint256 _amount) public onlyOwner {
        if (totalSupply().add(_amount) <= TOTAL_SUPPLY_CAP) {
            _mint(_to, _amount);
        } else {
            uint256 balance = TOTAL_SUPPLY_CAP.sub(totalSupply());
            _mint(_to, balance);
        }
    }
}