// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "../libraries/Math.sol";
import "solmate/tokens/ERC20.sol";
import "../interfaces/IUniswapV2Pair.sol";

import {console} from "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external returns (uint256);

    function transfer(address to, uint256 amount) external;
}

/// @author Rahunandan K
/// @title UniswaV2Pair clone
contract RareswapV2Pair is ERC20 {
    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;

    address public token0;
    address public token1;

    uint112 public reserve0;
    uint112 public reserve1;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);

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

    // @dev update the reserve
    // @param balance0 balance of token0
    function _update(uint256 balance0, uint256 balance1) private {
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
    }

    // @dev get the reserves
    function getReserves() public view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, 0);
    }
}
