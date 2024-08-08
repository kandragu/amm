// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "./Mocks/ECR20Mintable.sol";
import "../src/univ2/RareswapV2Pair.sol";

contract RareswapV2PairTest is Test {
    ECR20Mintable token0;
    ECR20Mintable token1;
    RareswapV2Pair pair;

    function setUp() public {
        token0 = new ECR20Mintable("TokenA", "TA", 18);
        token1 = new ECR20Mintable("TokenB", "TB", 18);

        pair = new RareswapV2Pair(address(token0), address(token1));

        token0.mint(address(this), 10 ether);
        token1.mint(address(this), 10 ether);
    }

    function assertReserves(
        uint112 expectedReserve0,
        uint112 expectedReserve1
    ) internal {
        (uint112 _reserve0, uint112 _reserve1, ) = pair.getReserves();
        assertEq(_reserve0, expectedReserve0, "unexpected reserve0");
        assertEq(_reserve1, expectedReserve1, "unexpected reserve1");
    }

    function testMinBootStrap() public {
        RareswapV2Pair pair = new RareswapV2Pair(
            address(token0),
            address(token1)
        );
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint();

        (uint112 _reserve0, uint112 _reserve1, ) = pair.getReserves();

        assertEq(_reserve0, 1 ether, "unexpected reserve0");
        assertEq(_reserve1, 1 ether, "unexpected reserve1");

        assertEq(pair.balanceOf(address(this)), 1 ether - 1000);
        assertEq(pair.totalSupply(), 1 ether);
    }

    function testWithLiquidity() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint();

        vm.warp(37);

        token0.transfer(address(pair), 3 ether);
        token1.transfer(address(pair), 3 ether);

        pair.mint();

        (uint112 _reserve0, uint112 _reserve1, ) = pair.getReserves();

        assertEq(_reserve0, 4 ether, "unexpected reserve0");
        assertEq(_reserve1, 4 ether, "unexpected reserve1");

        assertEq(pair.balanceOf(address(this)), 4 ether - 1000);
        assertEq(pair.totalSupply(), 4 ether);
    }

    function testMintUnbalanced() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(); // + 1 LP
        assertEq(pair.balanceOf(address(this)), 1 ether - 1000);
        assertReserves(1 ether, 1 ether);

        token0.transfer(address(pair), 2 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(); // + 1 LP
        assertEq(pair.balanceOf(address(this)), 2 ether - 1000);
        assertReserves(3 ether, 2 ether);
    }

    function testMintLiquidityUnderflow() public {
        // 0x11: If an arithmetic operation results in underflow or overflow outside of an unchecked { ... } block.
        vm.expectRevert(
            hex"4e487b710000000000000000000000000000000000000000000000000000000000000011"
        );
        pair.mint();
    }

    function testMintZeroLiquidity() public {
        token0.transfer(address(pair), 1000);
        token1.transfer(address(pair), 1000);

        vm.expectRevert("RareswapV2Pair: INSUFFICIENT_LIQUIDITY_MINTED"); // InsufficientLiquidityMinted()
        pair.mint();
        // assertEq(pair.balanceOf(address(this)), 0);
    }

    function testBurn() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(); // + 1 LP

        uint balance = pair.balanceOf(address(this));
        pair.transfer(address(pair), balance);
        pair.burn();

        assertEq(pair.balanceOf(address(this)), 0);
    }

    function testBurnUnbalancedLp() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(); // + 1 LP

        token0.transfer(address(pair), 2 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(); // + 1 LP

        uint balance = pair.balanceOf(address(this));
        pair.transfer(address(pair), balance);
        pair.burn();

        assertEq(pair.balanceOf(address(this)), 0);
    }
}
