// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/RadarConcepts.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        RadarConcepts radarConcepts = new RadarConcepts(
            "www.testcontracturi1.xyz/",
            0xa2eBEa8D93d403A438858d56a3146814610e407d,
            payable(0x589e021B88F36103D3678301622b2368DBa44691)
        );

        vm.stopBroadcast();
    }
}
