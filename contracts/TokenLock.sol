// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenLock is Ownable {
	using SafeMath for uint256;
	using SafeERC20 for IERC20;

	uint256 public unlockTimestamp;
	uint256 public constant LOCK_DURATION = 90 days;

	constructor() public {
		unlockTimestamp = (block.timestamp).add(LOCK_DURATION);
	}

	function withdraw(address _token) external onlyOwner {
		require(block.timestamp >= unlockTimestamp, "TokenLock: LOCKED");

		uint256 balance = IERC20(_token).balanceOf(address(this));
		IERC20(_token).safeTransfer(msg.sender, balance);
	}
}