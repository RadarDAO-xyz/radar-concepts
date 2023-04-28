// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @notice Inteface for Radar Identity RnD contract
interface IRadarIdentityRnD {
    ////////////////////////////
    ////////// Errors //////////
    ////////////////////////////

    error NotTokenOwner();
    error NewTagTypeNotIncremental(uint64 tagType, uint256 maxTagType);
    error TokenAlreadyMinted(
        address user,
        uint64 tagType,
        uint256 priorBalance
    );
    error InsufficientFunds();
    error SoulboundTokenNoSetApprovalForAll(address operator, bool approved);
    error SoulboundTokenNoIsApprovedForAll(address account, address operator);
    error SoulboundTokenNoSafeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes data
    );
    error SoulboundTokenNoSafeBatchTransferFrom(
        address from,
        address to,
        uint256[] ids,
        uint256[] amounts,
        bytes data
    );
    error ERC1155ReceiverNotImplemented();
    error ERC1155ReceiverRejectedTokens();

    ////////////////////////////
    ////////// Events //////////
    ////////////////////////////

    event TokenURIUpdated(
        string indexed oldTokenURI,
        string indexed newTokenURI
    );
    event ContractURIUpdated(
        string indexed oldContractURI,
        string indexed newContractURI
    );
    event MintPriceUpdated(
        uint256 indexed oldMintPrice,
        uint256 indexed newMintPrice
    );
    event MintFeePayout(
        uint256 indexed amount,
        address indexed to,
        bool indexed success
    );

    ////////////////////////////////
    ////////// Functions ///////////
    ////////////////////////////////

    function encodeTokenId(uint64 tagType, address account)
        external
        pure
        returns (uint256);

    function decodeTokenId(uint256 tokenId)
        external
        pure
        returns (uint64, address);

    function setTokenURI(string memory _newTokenURI) external;

    function setContractURI(string memory _newContractURI) external;

    function getContractURI() external view returns (string memory);

    function setMintPrice(uint256 _newMintPrice) external;

    function setMintFeeAddress(address payable _newMintFeeAddress) external;
}
