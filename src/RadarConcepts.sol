// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155Receiver} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC1155MetadataURI} from "openzeppelin-contracts/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";
import {BitMaps} from "openzeppelin-contracts/contracts/utils/structs/BitMaps.sol";
import {Base64} from "openzeppelin-contracts/contracts/utils/Base64.sol";

contract RadarConcepts is IERC1155, IERC1155MetadataURI, ERC165, AccessControl {
    using BitMaps for BitMaps.BitMap;

    ////////////////////////////
    ////////// Errors //////////
    ////////////////////////////

    error NewTagTypeNotIncremental(uint96 tagType, uint256 maxTagType);
    error TokenAlreadyMinted(
        address user,
        uint96 tagType,
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
        string indexed previousTokenURI,
        string indexed newTokenURI
    );
    event ContractURIUpdated(
        string indexed previousContractURI,
        string indexed newContractURI
    );
    event MintPriceUpdated(
        uint256 indexed previousMintPrice,
        uint256 indexed newMintPrice
    );
    event MintFeeAddressUpdated(
        address indexed previousMintFeeAddress,
        address indexed newMintFeeAddress
    );

    event FundsWithdrawn(uint256 indexed amount);

    /////////////////////////////////////
    ////////// State Variables //////////
    /////////////////////////////////////

    uint256 public mintPrice;
    address payable public radarMintFeeAddress;
    uint96 public maxTagType;
    string public contractURI;
    string public baseTokenURI;
    mapping(address => BitMaps.BitMap) private _balances;
    mapping(uint96 => uint256) public totalSupply;
    address private immutable ZERO_ADDRESS = address(0);

    constructor(
        string memory _baseTokenURI,
        string memory _contractURI,
        address _owner,
        address payable _radarMintFeeAddress
    ) {
        mintPrice = 0.000777 ether;
        baseTokenURI = _baseTokenURI;
        contractURI = _contractURI;
        radarMintFeeAddress = _radarMintFeeAddress;

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
    }

    ////////////////////////////////
    ////////// Functions ///////////
    ////////////////////////////////

    function encodeTokenId(uint96 tagType, address account)
        public
        pure
        returns (uint256 tokenId)
    {
        return uint256(bytes32(abi.encodePacked(tagType, account)));
    }

    function decodeTokenId(uint256 tokenId)
        public
        pure
        returns (uint96 tagType, address account)
    {
        tagType = uint96(tokenId >> 160);
        account = address(uint160(uint256(((bytes32(tokenId) << 96) >> 96))));
        return (tagType, account);
    }

    function _radarFeeForAmount(uint256 amount)
        internal
        view
        returns (uint256)
    {
        uint256 totalFee = mintPrice * amount;
        if (msg.value < totalFee) {
            revert InsufficientFunds();
        } else {
            return totalFee;
        }
    }

    /**
     * @dev Verifies contract supports the standard ERC1155 interface
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC165, IERC165, AccessControl)
        returns (bool)
    {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function setApprovalForAll(address operator, bool approved)
        external
        pure
        override
    {
        revert SoulboundTokenNoSetApprovalForAll(operator, approved);
    }

    function isApprovedForAll(address account, address operator)
        external
        pure
        override
        returns (bool)
    {
        revert SoulboundTokenNoIsApprovedForAll(account, operator);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public pure override {
        revert SoulboundTokenNoSafeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public pure override {
        revert SoulboundTokenNoSafeBatchTransferFrom(
            from,
            to,
            ids,
            amounts,
            data
        );
    }

    function balanceOf(address account, uint256 id)
        public
        view
        override
        returns (uint256 balance)
    {
        (uint96 tagType, ) = decodeTokenId(id);
        BitMaps.BitMap storage bitmap = _balances[account];
        bool owned = BitMaps.get(bitmap, tagType);
        return owned ? 1 : 0;
    }

    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        external
        view
        override
        returns (uint256[] memory)
    {
        uint256 count = accounts.length;
        uint256[] memory batchBalances = new uint256[](count);
        for (uint256 i = 0; i < count; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }
        return batchBalances;
    }

    function _mint(address user, uint96 tagType)
        internal
        returns (uint256 tokenId)
    {
        if (msg.value < mintPrice) revert InsufficientFunds();

        tokenId = encodeTokenId(tagType, user);

        uint256 priorBalance = balanceOf(user, tokenId);
        if (priorBalance > 0)
            revert TokenAlreadyMinted(user, tagType, priorBalance); // token already owned

        BitMaps.BitMap storage balances = _balances[user];
        BitMaps.set(balances, tagType);

        // ensure new tagTypes are one greater, pack bitmaps sequentially
        uint96 nextPossibleNewTagType = uint96(maxTagType) + 1;
        if (tagType > nextPossibleNewTagType)
            revert NewTagTypeNotIncremental(tagType, maxTagType);
        if (tagType == nextPossibleNewTagType) maxTagType = tagType;

        totalSupply[tagType]++;
        return tokenId;
    }

    function mint(address to, uint96 tagType)
        external
        payable
        returns (uint256 tokenId)
    {
        tokenId = _mint(to, tagType);
        emit TransferSingle(_msgSender(), ZERO_ADDRESS, to, tokenId, 1);
        _doSafeTransferAcceptanceCheck(
            _msgSender(),
            ZERO_ADDRESS,
            to,
            tokenId,
            1,
            ""
        );
    }

    function mintBatch(address to, uint96[] memory tagTypes)
        external
        payable
        returns (uint256[] memory tokenIds)
    {
        uint256 mintCount = tagTypes.length;
        _radarFeeForAmount(mintCount);
        tokenIds = new uint256[](mintCount);
        uint256[] memory amounts = new uint256[](mintCount); // used in event

        for (uint256 i = 0; i < mintCount; i++) {
            uint256 tokenId = _mint(to, tagTypes[i]);
            tokenIds[i] = tokenId;
            amounts[i] = 1;
        }

        emit TransferBatch(_msgSender(), ZERO_ADDRESS, to, tokenIds, amounts);
        _doSafeBatchTransferAcceptanceCheck(
            _msgSender(),
            ZERO_ADDRESS,
            to,
            tokenIds,
            amounts,
            ""
        );
    }

    function uri(uint256 id) external pure override returns (string memory) {
        (uint96 tagType, ) = decodeTokenId(id);
        string[2] memory parts;
        parts[
            0
        ] = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" /><text x="10" y="20" class="base">';
        parts[1] = "<text></text></svg>";
        string memory output = string(abi.encodePacked(parts[0], parts[1]));
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "Concept #',
                        tagType,
                        '", "description": "A RADAR concept is a...", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(output)),
                        '"}'
                    )
                )
            )
        );
        output = string(abi.encodePacked("data:application/json;base64", json));
        return output;
    }

    function getContractURI() external view returns (string memory) {
        return contractURI;
    }

    /**
     * @dev ERC1155 receiver check to ensure a "to" address can receive the ERC1155 token standard, used in single mint
     */
    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            // check if contract
            try
                IERC1155Receiver(to).onERC1155Received(
                    operator,
                    from,
                    id,
                    amount,
                    data
                )
            returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert ERC1155ReceiverRejectedTokens();
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert ERC1155ReceiverNotImplemented();
            }
        }
    }

    /**
     * @dev ERC1155 receiver check to ensure a "to" address can receive the ERC1155 token standard, used in batch mint
     */
    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            // check if contract
            try
                IERC1155Receiver(to).onERC1155BatchReceived(
                    operator,
                    from,
                    ids,
                    amounts,
                    data
                )
            returns (bytes4 response) {
                if (
                    response != IERC1155Receiver.onERC1155BatchReceived.selector
                ) {
                    revert ERC1155ReceiverRejectedTokens();
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert ERC1155ReceiverNotImplemented();
            }
        }
    }

    //////////////////////////////////////
    ////////// Admin Functions ///////////
    //////////////////////////////////////

    /// @notice Setter method for updating the tokenURI
    /// @dev Only owner can update the tokenURI
    /// @param _newTokenURI The new tokenURI
    function setTokenURI(string memory _newTokenURI)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        string memory previousTokenURI = baseTokenURI;
        baseTokenURI = _newTokenURI;
        emit TokenURIUpdated(previousTokenURI, _newTokenURI);
    }

    /// @notice Setter method for updating the contractURI
    /// @dev Only owner can update the contractURI
    /// @param _newContractURI The new contractURI
    function setContractURI(string memory _newContractURI)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        string memory previousContractURI = contractURI;
        contractURI = _newContractURI;
        emit ContractURIUpdated(previousContractURI, _newContractURI);
    }

    /// @notice Setter method for updating the mintPrice
    /// @dev Only owner can update the mintPrice
    /// @param _newMintPrice The new mintPrice
    function setMintPrice(uint256 _newMintPrice)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        uint256 previousMintPrice = mintPrice;
        mintPrice = _newMintPrice;
        emit MintPriceUpdated(previousMintPrice, _newMintPrice);
    }

    /// @notice Setter method for updating the mintFeeAddress
    /// @dev Only owner can update the mintFeeAddress
    /// @param _newMintFeeAddress The new mintFeeAddress
    function setMintFeeAddress(address payable _newMintFeeAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        address previousMintFeeAddress = radarMintFeeAddress;
        radarMintFeeAddress = _newMintFeeAddress;
        emit MintFeeAddressUpdated(previousMintFeeAddress, _newMintFeeAddress);
    }

    function withdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        (bool success, ) = radarMintFeeAddress.call{
            value: address(this).balance
        }("");
        emit FundsWithdrawn(address(this).balance);
    }
}
