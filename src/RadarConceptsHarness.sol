// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./RadarConcepts.sol";

contract RadarConceptsHarness is RadarConcepts {
    constructor(
        string memory _baseTokenURI,
        string memory _contractURI,
        address _owner,
        address payable _radarMintFeeAddress
    )
        RadarConcepts(_baseTokenURI, _contractURI, _owner, _radarMintFeeAddress)
    {}

    function exposed_radarFeeForAmount(uint256 amount)
        external
        payable
        returns (uint256)
    {
        return _radarFeeForAmount(amount);
    }

    function exposed_msgSender() external view returns (address) {
        return _msgSender();
    }
}
