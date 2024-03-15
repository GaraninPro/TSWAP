// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { TSwapPool } from "../../src/TSwapPool.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract handler is Test {
    TSwapPool pool;
    ERC20Mock weth;
    ERC20Mock pooltoken;
    //////////////////
    uint256 startingX; // pooltokens
    uint256 startingY;
    /////////////////////
    int256 public expectedDeltaX; // pooltokens
    int256 public expectedDeltaY;
    //////////////////////////
    int256 public actualDeltaX;
    int256 public actualDeltaY;
    ///////////////////
    address liquidityProvider = makeAddr("lp");
    address swapper = makeAddr("swapper");

    constructor(TSwapPool _pool) {
        pool = _pool;
        weth = ERC20Mock(_pool.getWeth());
        pooltoken = ERC20Mock(_pool.getPoolToken());
    }

    ///////////////////FUNCTIONS//////////////

    function deposit(uint256 wethAmount) public {
        wethAmount = bound(wethAmount, pool.getMinimumWethDepositAmount(), type(uint64).max);
        /////////////////////////////////////////////////////////////
        expectedDeltaX = int256(pool.getPoolTokensToDepositBasedOnWeth(wethAmount)); //how much pooltoken will be
            // deposited
        expectedDeltaY = int256(wethAmount);
        ////////////////////////////////////////////////////////
        startingX = pooltoken.balanceOf(address(pool));
        startingY = weth.balanceOf(address(pool));
        ////////////////////////////////////////////////////////
        vm.startPrank(liquidityProvider);

        weth.mint(liquidityProvider, wethAmount);
        pooltoken.mint(liquidityProvider, uint256(expectedDeltaX));
        weth.approve(address(pool), type(uint256).max);
        pooltoken.approve(address(pool), type(uint256).max);

        pool.deposit(uint256(expectedDeltaY), 0, uint256(expectedDeltaX), uint64(block.timestamp));
        vm.stopPrank();

        uint256 endingX = pooltoken.balanceOf(address(pool));
        uint256 endingY = weth.balanceOf(address(pool));

        actualDeltaX = int256(endingX) - int256(startingX);
        actualDeltaY = int256(endingY) - int256(startingY);
    }

    ////////////////////////////////////////////////////////////

    function swapPoolTokenForWethBasedOnOutputWeth(uint256 outputWeth) public {
        outputWeth = bound(outputWeth, pool.getMinimumWethDepositAmount(), type(uint64).max);

        if (outputWeth >= weth.balanceOf(address(pool))) {
            return;
        }

        uint256 pooltokenAmount = pool.getInputAmountBasedOnOutput(
            outputWeth, pooltoken.balanceOf(address(pool)), weth.balanceOf(address(pool))
        );
        //   if (pooltokenAmount > type(uint64).max) {
        //      return;
        //  }
        /////////////////////////////////////////////////////////////////
        startingX = pooltoken.balanceOf(address(pool));
        startingY = weth.balanceOf(address(pool));

        expectedDeltaX = int256(pooltokenAmount);
        expectedDeltaY = int256(-1) * int256(outputWeth);

        vm.startPrank(swapper);
        pooltoken.mint(swapper, pooltokenAmount + 1);

        pooltoken.approve(address(pool), pooltokenAmount);
        pool.swapExactOutput(pooltoken, weth, outputWeth, uint64(block.timestamp));
        vm.stopPrank(); // do we need IERC20 wrapper ?

        uint256 endingX = pooltoken.balanceOf(address(pool));
        uint256 endingY = weth.balanceOf(address(pool));

        actualDeltaX = int256(endingX) - int256(startingX);
        actualDeltaY = int256(endingY) - int256(startingY);
    }
}
