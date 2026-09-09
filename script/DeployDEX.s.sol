// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {DEX} from "../src/DEX.sol";

/// @notice Deploys the custom DEX contract. No constructor args needed.
/// Usage:
///   forge script script/DeployDEX.s.sol \
///     --rpc-url $SEPOLIA_RPC_URL \
///     --private-key $PRIVATE_KEY \
///     --broadcast \
///     --verify --etherscan-api-key $ETHERSCAN_API_KEY
contract DeployDEX is Script {
    function run() external returns (DEX dex) {
        vm.startBroadcast();
        dex = new DEX();
        vm.stopBroadcast();

        console2.log("DEX deployed at:", address(dex));
    }
}
