// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {SimpleV4Router} from "../src/hooks/SimpleV4Router.sol";

/// Usage:
///   POOL_MANAGER=0x... forge script script/DeployRouter.s.sol \
///     --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY \
///     --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
contract DeployRouter is Script {
    function run() external returns (SimpleV4Router router) {
        address poolManagerAddr = vm.envAddress("POOL_MANAGER");

        vm.startBroadcast();
        router = new SimpleV4Router(IPoolManager(poolManagerAddr));
        vm.stopBroadcast();

        console2.log("SimpleV4Router deployed at:", address(router));
    }
}
