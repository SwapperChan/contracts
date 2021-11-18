// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./WaifuToken.sol";

// MasterSimp is the ultimate simp for WAIFUs, but instead of pillows he gives out tokens.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once WAIFU is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterSimp is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of WAIFUs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accWaifuPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accWaifuPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }
    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. WAIFUs to distribute per block.
        uint256 lastRewardBlock; // Last block number that WAIFUs distribution occurs.
        uint256 accWaifuPerShare; // Accumulated WAIFUs per share, times 1e12. See below.
    }
    // The WAIFU TOKEN!
    WaifuToken public waifu;
    // Block number when bonus WAIFU period ends.
    uint256 public bonusEndBlock;
    // WAIFU tokens created per block.
    uint256 public waifuPerBlock;
    // Bonus muliplier for early waifu makers.
    uint256 public constant BONUS_MULTIPLIER = 2;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when WAIFU mining starts.
    uint256 public startBlock;

    // Distribution addresses
    address public treasuryAddress; // 20%
    address public devAddress; // 20% (3 months cliff)
    address public investorAddress; // 10% (3 months cliff)

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event UpdateEmissionRate(address indexed user, uint256 _waifuPerBlock);

    constructor(
        address _treasuryAddress,
        address _devAddress,
        address _investorAddress
    ) public {
        waifu = new WaifuToken();

        // LP Mint
        waifu.mint(msg.sender, 100000 ether);

        treasuryAddress = _treasuryAddress;
        devAddress = _devAddress;
        investorAddress = _investorAddress;

        startBlock = uint256(-1);
    }

    function poolLength() public view returns (uint256) {
        return poolInfo.length;
    }

    function startFarm(uint256 _startBlock, uint256 _bonusEndBlock) external onlyOwner {
        require(startBlock == uint256(-1), "MasterSimp: FARM_STARTED");

        startBlock = _startBlock;
        bonusEndBlock = _bonusEndBlock;

        for (uint256 i = 0; i < poolLength(); i++) {
            poolInfo[i].lastRewardBlock = startBlock;
        }
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock =
            block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accWaifuPerShare: 0
            })
        );
    }

    // Update the given pool's WAIFU allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        } else if (_from >= bonusEndBlock) {
            return _to.sub(_from);
        } else {
            return
                bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
                    _to.sub(bonusEndBlock)
                );
        }
    }

    // View function to see pending WAIFUs on frontend.
    function pendingWaifu(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accWaifuPerShare = pool.accWaifuPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier =
                getMultiplier(pool.lastRewardBlock, block.number);
            uint256 waifuReward =
                multiplier.mul(waifuPerBlock).mul(pool.allocPoint).div(
                    totalAllocPoint
                );
            accWaifuPerShare = accWaifuPerShare.add(
                waifuReward.mul(1e12).div(lpSupply)
            );
        }
        return user.amount.mul(accWaifuPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 waifuEmission =
            multiplier.mul(waifuPerBlock).mul(pool.allocPoint).div(
                totalAllocPoint
            );

        // 50% rewards
        uint256 waifuReward = waifuEmission.div(2);

        uint256 balanceBeforeMint = waifu.balanceOf(address(this));
        waifu.mint(address(this), waifuReward);
        uint256 balanceAfterMint = waifu.balanceOf(address(this));

        waifuReward = balanceAfterMint.sub(balanceBeforeMint);

        pool.accWaifuPerShare = pool.accWaifuPerShare.add(
            waifuReward.mul(1e12).div(lpSupply)
        );

        pool.lastRewardBlock = block.number;

        // 20% Treasury
        waifu.mint(treasuryAddress, waifuEmission.div(5));

        // 20% Dev
        waifu.mint(devAddress, waifuEmission.div(5));

        // 10% Investors
        waifu.mint(investorAddress, waifuEmission.div(10));
    }

    // Deposit LP tokens to MasterChef for WAIFU allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        require(startBlock != uint256(-1), "MasterSimp: FARM_NOT_STARTED");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending =
                user.amount.mul(pool.accWaifuPerShare).div(1e12).sub(
                    user.rewardDebt
                );
            safeWaifuTransfer(msg.sender, pending);
        }
        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accWaifuPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending =
            user.amount.mul(pool.accWaifuPerShare).div(1e12).sub(
                user.rewardDebt
            );
        safeWaifuTransfer(msg.sender, pending);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accWaifuPerShare).div(1e12);
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe waifu transfer function, just in case if rounding error causes pool to not have enough WAIFUs.
    function safeWaifuTransfer(address _to, uint256 _amount) internal {
        uint256 waifuBal = waifu.balanceOf(address(this));
        if (_amount > waifuBal) {
            waifu.transfer(_to, waifuBal);
        } else {
            waifu.transfer(_to, _amount);
        }
    }

    function updateEmissionRate(uint256 _waifuPerBlock) external onlyOwner {
        massUpdatePools();
        waifuPerBlock = _waifuPerBlock;
        emit UpdateEmissionRate(msg.sender, _waifuPerBlock);
    }

    function updateDistributionAddresses(
        address _treasuryAddress,
        address _devAddress,
        address _investorAddress
    ) external onlyOwner {
        treasuryAddress = _treasuryAddress;
        devAddress = _devAddress;
        investorAddress = _investorAddress;
    }
}