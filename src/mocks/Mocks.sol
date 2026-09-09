// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {DEX} from "../DEX.sol";

/// @notice Plain compliant ERC20 for baseline tests.
contract TestToken is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @notice ERC20 that burns a fee on every transfer, so the recipient always
/// receives less than the nominal amount. Used to prove the DEX prices off
/// actually-received balances, not requested amounts.
contract FeeOnTransferToken is ERC20 {
    uint256 public feeBps; // e.g. 200 = 2%

    constructor(string memory name, string memory symbol, uint256 initialSupply, uint256 _feeBps) ERC20(name, symbol) {
        feeBps = _feeBps;
        _mint(msg.sender, initialSupply);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from == address(0) || to == address(0) || feeBps == 0) {
            super._update(from, to, value);
            return;
        }
        uint256 fee = (value * feeBps) / 10_000;
        super._update(from, to, value - fee);
        if (fee > 0) {
            super._update(from, address(0), fee); // burn the fee
        }
    }
}

/// @notice Non-compliant ERC20: returns false on failed transfer instead of
/// reverting (pre-EIP20-clarification style token, e.g. old BNB/USDT clones).
/// Used to prove SafeERC20 catches this rather than silently corrupting
/// reserve accounting.
contract ReturnsFalseToken is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }

    function transfer(address, uint256) public pure override returns (bool) {
        return false;
    }

    function transferFrom(address, address, uint256) public pure override returns (bool) {
        return false;
    }
}

/// @notice Malicious ERC20 whose transferFrom callback tries to re-enter the
/// DEX mid-call. Simulates an attacker who deploys their own token (possible
/// because pool creation is permissionless) to exploit reentrancy.
contract ReentrantAttackerToken is ERC20 {
    DEX public dex;
    address public otherToken;
    bool public attackOnSwap;
    bool public attackOnAddLiquidity;
    bool public attacked;

    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }

    function setTarget(DEX _dex, address _otherToken) external {
        dex = _dex;
        otherToken = _otherToken;
    }

    function setAttackOnSwap(bool v) external {
        attackOnSwap = v;
    }

    function setAttackOnAddLiquidity(bool v) external {
        attackOnAddLiquidity = v;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (!attacked && attackOnSwap) {
            attacked = true;
            // Try to re-enter swap while reserves haven't been finalized yet.
            dex.swap(address(this), otherToken, 1, 0, block.timestamp + 1);
        }
        if (!attacked && attackOnAddLiquidity) {
            attacked = true;
            dex.addLiquidity(address(this), otherToken, 1, 1, 0, 0, block.timestamp + 1);
        }
        return super.transferFrom(from, to, amount);
    }
}
