// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { PoolFactory } from "../../src/PoolFactory.sol";
import { TSwapPool } from "../../src/TSwapPool.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { handler } from "../invariant/handler.sol";

contract invariant is StdInvariant, Test {
    ERC20Mock pooltoken;
    ERC20Mock weth;
    /////////////////////////
    PoolFactory factory;
    TSwapPool pool;
    handler Handler;
    //////////////////
    int256 constant STARTING_X = 1000e18;
    int256 constant STARTING_Y = 500e18;

    function setUp() public {
        pooltoken = new ERC20Mock();
        weth = new ERC20Mock();

        factory = new PoolFactory(address(weth));

        pool = TSwapPool(factory.createPool(address(pooltoken)));
        Handler = new handler(pool);

        pooltoken.mint(address(this), uint256(STARTING_X));
        weth.mint(address(this), uint256(STARTING_Y));

        pooltoken.approve(address(pool), type(uint256).max);
        weth.approve(address(pool), type(uint256).max);

        pool.deposit(uint256(STARTING_Y), uint256(STARTING_Y), uint256(STARTING_X), uint64(block.timestamp));

        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = Handler.deposit.selector;
        selectors[1] = Handler.swapPoolTokenForWethBasedOnOutputWeth.selector;

        targetSelector(FuzzSelector({ addr: address(Handler), selectors: selectors }));

        targetContract(address(Handler));
    }
    /////////////////////////////////////////////////////////////

    function invariant_breakEquation() public {
        assertEq(Handler.actualDeltaX(), Handler.expectedDeltaX());
        assertEq(Handler.actualDeltaY(), Handler.expectedDeltaY());
    }
}
