// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {kUSD} from "../src/kUSD.sol";

/**
 * @title DeploykUSD
 * @notice Deployment script for the kUSD stablecoin.
 *
 * Usage:
 *   forge script script/Deploy.s.sol:DeploykUSD \
 *       --rpc-url $RPC_URL \
 *       --broadcast \
 *       --verify \
 *       -vvvv
 *
 * Environment variables:
 *   DEPLOYER_PRIVATE_KEY  – Private key used to deploy.
 *   OWNER                 – Address that will own the contract.
 *   PAUSER                – Address that can pause/unpause.
 *   BLACKLISTER           – Address that can blacklist/unblacklist.
 *   MASTER_MINTER         – Address that can configure minters.
 */
contract DeploykUSD is Script {
    function run() external {
        address owner = vm.envAddress("OWNER");
        address pauser = vm.envAddress("PAUSER");
        address blacklister = vm.envAddress("BLACKLISTER");
        address masterMinter = vm.envAddress("MASTER_MINTER");

        vm.startBroadcast();

        kUSD token = new kUSD(owner, pauser, blacklister, masterMinter);

        console.log("kUSD deployed at:", address(token));
        console.log("  owner:        ", owner);
        console.log("  pauser:       ", pauser);
        console.log("  blacklister:  ", blacklister);
        console.log("  masterMinter: ", masterMinter);

        vm.stopBroadcast();
    }
}
