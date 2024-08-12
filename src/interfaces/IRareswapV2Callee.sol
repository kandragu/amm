// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface IRareswapV2Callee {
    function rareswapV2Call(
        address sender,
        uint amount0,
        uint amount1,
        bytes calldata data
    ) external;
}
