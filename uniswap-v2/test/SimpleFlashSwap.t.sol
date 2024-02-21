// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/interfaces/IUniswapV2Pair.sol";
import "../src/examples/SimpleFlashSwap.sol";
import "../src/test/ERC20.sol";
import "../src/UniswapV2Router01.sol";
import "../src/UniswapV2Factory.sol";
import "../src/UniswapV2Pair.sol";
import "../src/libraries/UniswapV2Library.sol";

contract SimpleFlashSwapTest is Test {
    UniswapV2Router01 public router;
    UniswapV2Factory public factory;
    UniswapV2Pair public pair;
    UniswapV2ERC20WithMint public token0;
    UniswapV2ERC20WithMint public token1;
    SimpleFlashSwap public flashSwap;

    uint public constant INIT_SUPPLY = 1000000e18;

    function setUp() public {
        token0 = new UniswapV2ERC20WithMint();
        token1 = new UniswapV2ERC20WithMint();

        (token0, token1) = token0 < token1
            ? (token0, token1)
            : (token1, token0);

        token0.mint(address(this), INIT_SUPPLY);
        token1.mint(address(this), INIT_SUPPLY);

        factory = new UniswapV2Factory(address(this));
        router = new UniswapV2Router01(address(factory), address(0));
        pair = UniswapV2Pair(
            factory.createPair(address(token0), address(token1))
        );

        vm.label(address(token0), "token0");
        vm.label(address(token1), "token1");
        vm.label(address(factory), "factory");
        vm.label(address(router), "router");
        vm.label(address(pair), "pair");

        token0.approve(address(router), type(uint256).max);
        token1.approve(address(router), type(uint256).max);

        (uint amountA, uint amountB, uint liquidity) = router.addLiquidity(
            address(token0),
            address(token1),
            INIT_SUPPLY / 2,
            INIT_SUPPLY / 2,
            INIT_SUPPLY / 2,
            INIT_SUPPLY / 2,
            address(this),
            block.timestamp
        );

        assertEq(amountA, INIT_SUPPLY / 2);
        assertEq(amountB, INIT_SUPPLY / 2);
        assertEq(liquidity, INIT_SUPPLY / 2 - 1000);

        flashSwap = new SimpleFlashSwap(IUniswapV2Pair(address(pair)));

        vm.label(address(flashSwap), "flashSwap");

        token0.mint(address(flashSwap), 10000e18);
    }

    function test_FlashSwap() public {
        uint256 amount = 100000e18;
        uint256 fee = flashSwap.calculateFee(amount);
        uint256 swapBalanceBefore = token0.balanceOf(address(flashSwap));
        uint256 pairBalanceBefore = token0.balanceOf(address(pair));

        flashSwap.flashSwap(address(token0), amount, true);

        uint256 swapBalanceAfter = token0.balanceOf(address(flashSwap));
        uint256 pairBalanceAfter = token0.balanceOf(address(pair));

        assertEq(swapBalanceAfter, swapBalanceBefore - fee);
        assertEq(pairBalanceAfter, pairBalanceBefore + fee);
    }

    function test_RevertFlashSwapWithNoFee() public {
        uint256 amount = 100000e18;

        vm.expectRevert("UniswapV2: K");
        flashSwap.flashSwap(address(token0), amount, false);
    }
}
