// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.6.12;

import './libraries/SwapperChanLibrary.sol';
import './libraries/TransferHelper.sol';
import './interfaces/ISwapperChanFactory.sol';
import './interfaces/IERC20.sol';
import './interfaces/IWETH.sol';

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract SwapperChanRouter is Ownable {
    using SafeMath for uint;

    address public immutable factory;
    address public immutable WETH;

    address public feeAddress;
    uint public swapFee = 1;
    uint public constant MAX_SWAP_FEE = 5;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'SwapperChan: EXPIRED');
        _;
    }

    constructor(address _factory, address _WETH) public {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        if (ISwapperChanFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            ISwapperChanFactory(factory).createPair(tokenA, tokenB);
        }
        (uint reserveA, uint reserveB) = SwapperChanLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = SwapperChanLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'SwapperChan: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = SwapperChanLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'SwapperChan: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = SwapperChanLibrary.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = ISwapperChanPair(pair).mint(to);
    }
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external virtual payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = SwapperChanLibrary.pairFor(factory, token, WETH);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = ISwapperChanPair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = SwapperChanLibrary.pairFor(factory, tokenA, tokenB);
        ISwapperChanPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint amount0, uint amount1) = ISwapperChanPair(pair).burn(to);
        (address token0,) = SwapperChanLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'SwapperChan: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'SwapperChan: INSUFFICIENT_B_AMOUNT');
    }
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual ensure(deadline) returns (uint amountToken, uint amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual returns (uint amountA, uint amountB) {
        address pair = SwapperChanLibrary.pairFor(factory, tokenA, tokenB);
        uint value = approveMax ? uint(-1) : liquidity;
        ISwapperChanPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual returns (uint amountToken, uint amountETH) {
        address pair = SwapperChanLibrary.pairFor(factory, token, WETH);
        uint value = approveMax ? uint(-1) : liquidity;
        ISwapperChanPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual ensure(deadline) returns (uint amountETH) {
        (, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, IERC20SwapperChan(token).balanceOf(address(this)));
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual returns (uint amountETH) {
        address pair = SwapperChanLibrary.pairFor(factory, token, WETH);
        uint value = approveMax ? uint(-1) : liquidity;
        ISwapperChanPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountETHMin, to, deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = SwapperChanLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? SwapperChanLibrary.pairFor(factory, output, path[i + 2]) : _to;
            ISwapperChanPair(SwapperChanLibrary.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual ensure(deadline) returns (uint[] memory amounts) {
        if (feeAddress != address(0)) {
            uint fees = amountIn.mul(swapFee).div(1000);

            TransferHelper.safeTransferFrom(
                path[0], msg.sender, feeAddress, fees
            );

            amountIn = amountIn.sub(fees);
        }

        amounts = SwapperChanLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'SwapperChan: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SwapperChanLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual ensure(deadline) returns (uint[] memory amounts) {
        amounts = SwapperChanLibrary.getAmountsIn(factory, amountOut, path);

        if (feeAddress != address(0)) {
            uint amountIn = amounts[0].mul(1000).div(1000 - swapFee);
            uint fees = amountIn.mul(swapFee).div(1000);

            require(amounts[0].add(fees) <= amountInMax, 'SwapperChan: EXCESSIVE_INPUT_AMOUNT');

            TransferHelper.safeTransferFrom(
                path[0], msg.sender, feeAddress, fees
            );

        } else {
            require(amounts[0] <= amountInMax, 'SwapperChan: EXCESSIVE_INPUT_AMOUNT');
        }
        
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SwapperChanLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'SwapperChan: INVALID_PATH');

        IWETH(WETH).deposit{value: msg.value}();

        uint amountIn = msg.value;

        if (feeAddress != address(0)) {
            uint fees = amountIn.mul(swapFee).div(1000);

            assert(IWETH(WETH).transfer(feeAddress, fees));

            amountIn = amountIn.sub(fees);
        }

        amounts = SwapperChanLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'SwapperChan: INSUFFICIENT_OUTPUT_AMOUNT');
        
        assert(IWETH(WETH).transfer(SwapperChanLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        virtual
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'SwapperChan: INVALID_PATH');
        amounts = SwapperChanLibrary.getAmountsIn(factory, amountOut, path);

        if (feeAddress != address(0)) {
            uint amountIn = amounts[0].mul(1000).div(1000 - swapFee);
            uint fees = amountIn.mul(swapFee).div(1000);

            require(amounts[0].add(fees) <= amountInMax, 'SwapperChan: EXCESSIVE_INPUT_AMOUNT');

            TransferHelper.safeTransferFrom(
                path[0], msg.sender, feeAddress, fees
            );

        } else {
            require(amounts[0] <= amountInMax, 'SwapperChan: EXCESSIVE_INPUT_AMOUNT');
        }


        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SwapperChanLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'SwapperChan: INVALID_PATH');

        if (feeAddress != address(0)) {
            uint fees = amountIn.mul(swapFee).div(1000);

            TransferHelper.safeTransferFrom(
                path[0], msg.sender, feeAddress, fees
            );

            amountIn = amountIn.sub(fees);
        }

        amounts = SwapperChanLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'SwapperChan: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SwapperChanLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        virtual
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'SwapperChan: INVALID_PATH');
        amounts = SwapperChanLibrary.getAmountsIn(factory, amountOut, path);

        if (feeAddress != address(0)) {
            uint amountIn = amounts[0].mul(1000).div(1000 - swapFee);
            uint fees = amountIn.mul(swapFee).div(1000);

            require(amounts[0].add(fees) <= msg.value, 'SwapperChan: EXCESSIVE_INPUT_AMOUNT');

            IWETH(WETH).deposit{value: amounts[0].add(fees)}();

            assert(IWETH(WETH).transfer(feeAddress, fees));

            assert(IWETH(WETH).transfer(SwapperChanLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
            _swap(amounts, path, to);
            // refund dust eth, if any
            if (msg.value > amounts[0].add(fees)) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0].add(fees));

        } else {
            require(amounts[0] <= msg.value, 'SwapperChan: EXCESSIVE_INPUT_AMOUNT');
            IWETH(WETH).deposit{value: amounts[0]}();

            assert(IWETH(WETH).transfer(SwapperChanLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
            _swap(amounts, path, to);
            // refund dust eth, if any
            if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
        }


        
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = SwapperChanLibrary.sortTokens(input, output);
            ISwapperChanPair pair = ISwapperChanPair(SwapperChanLibrary.pairFor(factory, input, output));
            uint amountInput;
            uint amountOutput;
            { // scope to avoid stack too deep errors
            (uint reserve0, uint reserve1,) = pair.getReserves();
            (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            amountInput = IERC20SwapperChan(input).balanceOf(address(pair)).sub(reserveInput);
            amountOutput = SwapperChanLibrary.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? SwapperChanLibrary.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual ensure(deadline) {
        if (feeAddress != address(0)) {
            uint fees = amountIn.mul(swapFee).div(1000);

            TransferHelper.safeTransferFrom(
                path[0], msg.sender, feeAddress, fees
            );

            amountIn = amountIn.sub(fees);
        }

        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SwapperChanLibrary.pairFor(factory, path[0], path[1]), amountIn
        );
        uint balanceBefore = IERC20SwapperChan(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20SwapperChan(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'SwapperChan: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        payable
        ensure(deadline)
    {
        require(path[0] == WETH, 'SwapperChan: INVALID_PATH');

        IWETH(WETH).deposit{value: msg.value}();

        uint amountIn = msg.value;

        if (feeAddress != address(0)) {
            uint fees = amountIn.mul(swapFee).div(1000);

            assert(IWETH(WETH).transfer(feeAddress, fees));

            amountIn = amountIn.sub(fees);
        }

        assert(IWETH(WETH).transfer(SwapperChanLibrary.pairFor(factory, path[0], path[1]), amountIn));
        uint balanceBefore = IERC20SwapperChan(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20SwapperChan(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'SwapperChan: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        ensure(deadline)
    {
        require(path[path.length - 1] == WETH, 'SwapperChan: INVALID_PATH');
        if (feeAddress != address(0)) {
            uint fees = amountIn.mul(swapFee).div(1000);

            TransferHelper.safeTransferFrom(
                path[0], msg.sender, feeAddress, fees
            );

            amountIn = amountIn.sub(fees);
        }

        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SwapperChanLibrary.pairFor(factory, path[0], path[1]), amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20SwapperChan(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'SwapperChan: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual returns (uint amountB) {
        return SwapperChanLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        returns (uint amountOut)
    {
        return SwapperChanLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        returns (uint amountIn)
    {
        return SwapperChanLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] memory path)
        public
        view
        virtual
        returns (uint[] memory amounts)
    {
        return SwapperChanLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] memory path)
        public
        view
        virtual
        returns (uint[] memory amounts)
    {
        return SwapperChanLibrary.getAmountsIn(factory, amountOut, path);
    }

    // **** OWNER FUNCTIONS ****
    function setFeeAddress(address _feeAddress) onlyOwner external virtual {
        feeAddress = _feeAddress;
    }

    function setSwapFees(uint _swapFee) onlyOwner external virtual {
        require(_swapFee <= MAX_SWAP_FEE, "SwapperChan: SWAP_FEE_EXCEEDED_MAX");
        swapFee = _swapFee;
    }
}
