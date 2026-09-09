// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {HookMiner} from "@uniswap/v4-periphery/test/shared/HookMiner.sol";

import {CounterHook} from "../src/hooks/CounterHook.sol";

/// @notice Deploys CounterHook and registers a pool against a REAL,
/// already-deployed V4 PoolManager on a testnet.
///
/// Before running: set POOL_MANAGER, TOKEN0, TOKEN1 (TOKEN0 < TOKEN1 by
/// address) as env vars for the target network. You can find the official
/// PoolManager address for each testnet in Uniswap's v4-deployments repo;
/// don't assume the mainnet address is right for a testnet, verify it.
///
/// IMPORTANT (per the earlier reentrancy review): CREATE2 in a forge script
/// goes through the canonical deterministic deployer proxy
/// (0x4e59b44847b379578588920cA78FbF26c0B4956C), not the script's own
/// address, so HookMiner must mine against THAT deployer, not
/// `msg.sender`/`address(this)`. Using the wrong deployer address here
/// silently mines a salt that produces the WRONG on-chain address, and the
/// pool initialize() call reverts with HookAddressNotValid. This is the one
/// place scripts and tests differ from each other.
contract DeployV4Hook is Script {
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function run() external {
        address poolManagerAddr = vm.envAddress("POOL_MANAGER");
        address token0 = vm.envAddress("TOKEN0");
        address token1 = vm.envAddress("TOKEN1");
        require(token0 < token1, "TOKEN0 must be < TOKEN1 by address");

        IPoolManager manager = IPoolManager(poolManagerAddr);

        uint160 flags = uint160(Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);
        (address predictedAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(CounterHook).creationCode, abi.encode(manager));

        vm.startBroadcast();

        CounterHook hook = new CounterHook{salt: salt}(manager);
        require(address(hook) == predictedAddress, "mined address mismatch, see CREATE2_DEPLOYER note above");

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000, // 0.30%, matches this repo's custom AMM fee for comparability
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });

        // 1:1 starting price (sqrtPriceX96 for price = 1). Adjust for your
        // token decimals/relative value before using this on anything but a
        // quick testnet smoke test.
        uint160 sqrtPriceX96_1_1 = 79228162514264337593543950336;
        manager.initialize(key, sqrtPriceX96_1_1);

        vm.stopBroadcast();

        console2.log("CounterHook deployed at:", address(hook));
        console2.log("Pool initialized. Add liquidity via a PositionManager/router next.");
    }
}
