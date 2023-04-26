// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC1155} from "solmate/tokens/ERC1155.sol";
import {LibString} from "solmate/utils/LibString.sol";
import {RolesAuthority} from "solmate/auth/authorities/RolesAuthority.sol";
import {IERC5192} from "./IERC5192.sol";

contract IdentityRnD is ERC1155, IERC5192, RolesAuthority {
    using LibString for uint256;

    ////////////////////////////
    ////////// Errors //////////
    ////////////////////////////

    error NotTokenOwner();
    error BondedToken();
    error InsufficientFunds();

    ////////////////////////////
    ////////// Events //////////
    ////////////////////////////

    event UpdateTokenURI(string oldTokenURI, string newTokenURI);
    event UpdateContractURI(string oldContractURI, string newContractURI);
    event BalanceWithdrawn(uint256 balance);

    /////////////////////////////////////
    ////////// State Variables //////////
    /////////////////////////////////////

    uint256 public mint_price;

    constructor() {
        mint_price = 0.000777 ether;
    }

    ////////////////////////////////
    ////////// Functions ///////////
    ////////////////////////////////

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal {
        _mint(to, id, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal {
        _mintBatch(to, ids, amounts, data);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        return string.concat(baseTokenURI, tokenId.toString());
    }

    function burn(uint256 tokenId) public {
        onlyTokenOwner(tokenId);
        _burn(tokenId);
    }

    function onlyTokenOwner(uint256 tokenId) internal view {
        if (ownerOf(tokenId) != msg.sender) {
            revert NotTokenOwner();
        }
    }

    function requirePayment() internal view {
        if (msg.value < MINT_PRICE) {
            revert InsufficientFunds();
        }
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override(ERC1155) {
        _beforeTokenTransfer(tokenId);
        super.transferFrom(from, to, tokenId);
    }

    //////////////////////////////////////
    ////////// Admin Functions ///////////
    //////////////////////////////////////

    /// @notice Method for withdrawing contract balance
    /// @dev Only owner can withdraw the contract balance
    function withdraw() external onlyOwner {
        if (address(this).balance == 0) {
            revert InsufficientFunds();
        }
        address payable _to = payable(msg.sender);
        (bool sent, ) = _to.call{value: address(this).balance}("");
        emit BalanceWithdrawn(address(this).balance);
    }

    /// @notice Setter method for updating the tokenURI
    /// @dev Only owner can update the tokenURI
    /// @param _newTokenURI The new tokenURI
    function setTokenURI(string memory _newTokenURI) external onlyOwner {
        string memory _oldTokenURI = baseTokenURI;
        baseTokenURI = _newTokenURI;
        emit UpdateTokenURI(_oldTokenURI, _newTokenURI);
    }
}
