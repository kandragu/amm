// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "../libraries/Math.sol";
import "solmate/tokens/ERC20.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IRareswapV2Callee.sol";

import {console} from "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external returns (uint256);

    function transfer(address to, uint256 amount) external;
}

error TransferFailed();

/// @author Rahunandan K
/// @title UniswaV2Pair clone
contract RareswapV2Pair is ERC20 {
    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;

    address public token0;
    address public token1;

    uint112 public reserve0;
    uint112 public reserve1;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(
        address indexed sender,
        uint amount0,
        uint amount1,
        address indexed to
    );

    //  @dev stores the token0 and token1 address
    constructor(address _token0, address _token1) ERC20("RareV2", "RV2", 18) {
        token0 = _token0;
        token1 = _token1;
    }

    /// @dev mint function
    function mint() external returns (uint256 liquidity) {
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();

        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        if (totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min(
                (amount0 * totalSupply) / reserve0,
                (amount1 * totalSupply) / reserve1
            );
        }

        require(liquidity > 0, "RareswapV2Pair: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(msg.sender, liquidity);

        _update(balance0, balance1);

        emit Mint(msg.sender, amount0, amount1);
    }

    // @dev burn LP function
    function burn() external {
        uint256 liquidity = balanceOf[address(this)];
        require(liquidity > 0, "RareswapV2Pair: INSUFFICIENT_LIQUIDITY_BURNED");

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amount0 = (liquidity * balance0) / totalSupply;
        uint256 amount1 = (liquidity * balance1) / totalSupply;

        _burn(address(this), liquidity);

        _safeTransfer(token0, msg.sender, amount0);
        _safeTransfer(token1, msg.sender, amount1);

        _update(balance0, balance1);

        emit Burn(msg.sender, amount0, amount1, msg.sender);
    }

    // @dev get the reserves
    function getReserves() public view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, 0);
    }

    // @dev update the reserve
    // @param balance0 balance of token0
    function _update(uint256 balance0, uint256 balance1) private {
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
    }

    function _safeTransfer(address token, address to, uint256 amount) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    // @dev swap function
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) public {
        require(
            amount0Out > 0 || amount1Out > 0,
            "RareswapV2Pair: INSUFFICIENT_OUTPUT_AMOUNT"
        );

        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();

        require(
            amount0Out < _reserve0 && amount1Out < _reserve1,
            "RareswapV2Pair: INSUFFICIENT_LIQUIDITY"
        );

        if (amount0Out > 0) _safeTransfer(token0, to, amount0Out);
        if (amount1Out > 0) _safeTransfer(token1, to, amount1Out);

        if (data.length > 0)
            IRareswapV2Callee(to).rareswapV2Call(
                msg.sender,
                amount0Out,
                amount1Out,
                data
            );

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        // NOTE:
        // balance0Adjusted = balance0 * 1000 - (amount0In * 3);
        // balance1Adjusted / 1000 = balance1  - (amount1In * 3) / 1000;
        uint256 amount0In = balance0 > _reserve0 - amount0Out
            ? balance0 - (_reserve0 - amount0Out)
            : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out
            ? balance1 - (_reserve1 - amount1Out)
            : 0;

        require(
            amount0In > 0 || amount1In > 0,
            "RareswapV2Pair: INSUFFICIENT_INPUT_AMOUNT"
        );
        // NOTE:
        // (x0 + dx * (1- f)) (y0 -dy) >= x0 * y0
        //
        uint balance0Adjusted = balance0 * 1000 - (amount0In * 3);
        uint balance1Adjusted = balance1 * 1000 - (amount1In * 3);

        require(
            balance0Adjusted * balance1Adjusted >=
                uint(_reserve0) * uint(_reserve1) * 1000 ** 2,
            "RareswapV2Pair: K"
        );

        _update(balance0, balance1);
    }
}
