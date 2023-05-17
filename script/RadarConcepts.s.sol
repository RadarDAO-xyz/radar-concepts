// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/RadarConcepts.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        RadarConcepts radarConcepts = new RadarConcepts(
            "https://nftstorage.link/ipfs/bafkreic4bb2a35dytczqhgbiudoyxbc2cqxjdwaqd47omtfboenlgwvl5y",
            0xa2eBEa8D93d403A438858d56a3146814610e407d,
            payable(0x149D46eC060e75AE188876AdB6b24024637003C7)
        );

        vm.stopBroadcast();
    }
}
