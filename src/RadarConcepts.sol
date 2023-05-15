// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155Receiver} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {Context} from "openzeppelin-contracts/contracts/utils/Context.sol";
import {BitMaps} from "openzeppelin-contracts/contracts/utils/structs/BitMaps.sol";
import {Base64} from "openzeppelin-contracts/contracts/utils/Base64.sol";
import {svg} from "./SVG.sol";
import {utils} from "./Utils.sol";

///@title Radar Concepts
///@notice Radar Concepts are non-transferable ERC1155-similar tokens that can be minted through the RADAR Discovery Network.
//@author delightfulabyss
contract RadarConcepts is IERC1155, ERC165, AccessControl {
    using BitMaps for BitMaps.BitMap;

    ////////////////////////////
    ////////// Errors //////////
    ////////////////////////////

    error NewTagTypeNotIncremental(uint96 tagType, uint256 maxTagType);
    error TokenAlreadyMinted(
        address account,
        uint96 tagType,
        uint256 priorBalance
    );
    error TokenNotMinted(address account, uint96 tagType, uint256 priorBalance);
    error NotTokenOwner();
    error InsufficientFunds();
    error SoulboundTokenNoSetApprovalForAll();
    error SoulboundTokenNoIsApprovedForAll();
    error SoulboundTokenNoSafeTransferFrom();
    error SoulboundTokenNoSafeBatchTransferFrom();
    error ERC1155ReceiverNotImplemented();
    error ERC1155ReceiverRejectedTokens();

    ////////////////////////////
    ////////// Events //////////
    ////////////////////////////

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
    ////////// Storage //////////////////
    /////////////////////////////////////

    ///@notice The current price for minting tokens
    uint256 public mintPrice;

    ///@notice The current address to send minting fees
    address payable public radarMintFeeAddress;

    ///@notice The maximum tag type that has been minted
    uint96 public maxTagType;

    //@notice The current URI of the contract
    string public contractURI;

    //@notice  The current user balances
    //@dev Token ownership is represented via bitmaps for gas efficiency since only user can own only one of each token type
    mapping(address => BitMaps.BitMap) private _balances;

    ///@notice The total supply of each tag type
    mapping(uint96 => uint256) public totalSupply;

    ///@notice The zero address
    address private immutable ZERO_ADDRESS = address(0);

    /////////////////////////////////////
    ////////// Constructor //////////////
    /////////////////////////////////////

    ///@notice All arguments are set initially during construction and then can be changed by the conract admin
    ///@param _contractURI The URI of the contract
    ///@param _owner The owner of the contract
    ///@param _radarMintFeeAddress The address to send minting fees
    constructor(
        string memory _contractURI,
        address _owner,
        address payable _radarMintFeeAddress
    ) {
        mintPrice = 0.000777 ether;
        contractURI = _contractURI;
        radarMintFeeAddress = _radarMintFeeAddress;

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
    }

    ////////////////////////////////
    ////////// Functions ///////////
    ////////////////////////////////

    /// @notice Returns a serialized token id based on a tagType and owner account address
    /// @dev Each user can only own one of each tag type. Serializing ids based on a tagType and owner address allows us to have both shared, tagType level metadata as well as individual token data. First 12 bytes = badgeType (uint96), next 20 bytes = owner address.
    /// @param tagType Tag type
    /// @param account Owner account address
    /// @return tokenId Serialized token id
    function encodeTokenId(uint96 tagType, address account)
        public
        pure
        returns (uint256 tokenId)
    {
        return uint256(bytes32(abi.encodePacked(tagType, account)));
    }

    /// @notice Decodes a token id into a tag type and owner account address
    /// @param tokenId Token id
    /// @return tagType Tag type
    /// @return account Owner account address
    function decodeTokenId(uint256 tokenId)
        public
        pure
        returns (uint96 tagType, address account)
    {
        tagType = uint96(tokenId >> 160);
        account = address(uint160(uint256(((bytes32(tokenId) << 96) >> 96))));
        return (tagType, account);
    }

    /// @dev Internal function to calculate the fee for a given amount of tokens
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

    /// @dev Verifies contract supports the standard ERC1155 interface
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC165, IERC165, AccessControl)
        returns (bool)
    {
        return
            interfaceId == type(IERC1155).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @notice This function will revert. Soulbound tokens cannot be transferred.
    function setApprovalForAll(address operator, bool approved)
        external
        pure
        override
    {
        revert SoulboundTokenNoSetApprovalForAll();
    }

    /// @notice This function will revert. Soulbound tokens cannot be transferred.
    function isApprovedForAll(address account, address operator)
        external
        pure
        override
        returns (bool)
    {
        revert SoulboundTokenNoIsApprovedForAll();
    }

    /// @notice This function will revert. Soulbound tokens cannot be transferred.
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public pure override {
        revert SoulboundTokenNoSafeTransferFrom();
    }

    /// @notice This function will revert. Soulbound tokens cannot be transferred.
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public pure override {
        revert SoulboundTokenNoSafeBatchTransferFrom();
    }

    /// @notice Get token balance of account address
    /// @dev Addresses can only own one of each tag type, this function will return either 0 or 1
    /// @param account Account address
    /// @param id Token id
    /// @return balance Token balance
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

    /// @notice Get token balances of an array of account addresses
    /// @dev Addresses can only own one of each tag type, this function will return an array of either 0s or 1s
    /// @param accounts Array of account addresses
    /// @param ids Array of token ids
    /// @return balances Array of token balances
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        external
        view
        override
        returns (uint256[] memory balances)
    {
        uint256 count = accounts.length;
        uint256[] memory batchBalances = new uint256[](count);
        for (uint256 i = 0; i < count; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }
        return batchBalances;
    }

    /// @dev Internal function to mint tokens
    function _mint(address account, uint96 tagType)
        internal
        returns (uint256 tokenId)
    {
        if (msg.value < mintPrice) revert InsufficientFunds();

        tokenId = encodeTokenId(tagType, account);

        uint256 priorBalance = balanceOf(account, tokenId);
        if (priorBalance > 0)
            revert TokenAlreadyMinted(account, tagType, priorBalance); // token already owned

        BitMaps.BitMap storage balances = _balances[account];
        BitMaps.set(balances, tagType);

        // ensure new tagTypes are one greater, pack bitmaps sequentially
        uint96 nextPossibleNewTagType = uint96(maxTagType) + 1;
        if (tagType > nextPossibleNewTagType)
            revert NewTagTypeNotIncremental(tagType, maxTagType);
        if (tagType == nextPossibleNewTagType) maxTagType = tagType;

        // Unlikely to overflow because of incrementing by 1
        unchecked {
            ++totalSupply[tagType];
        }
        return tokenId;
    }

    /// @notice Mint tokens to account address
    /// @param to Account address
    /// @param tagType Tag type
    /// @return tokenId Token id
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

    /// @dev Internal function to burn tokens
    function _burn(address account, uint96 tagType)
        internal
        returns (uint256 tokenId)
    {
        uint256 id = encodeTokenId(tagType, account);
        uint256 priorBalance = balanceOf(account, id);

        if (priorBalance == 0)
            revert TokenNotMinted(account, tagType, priorBalance);
        if (balanceOf(msg.sender, id) != 1) revert NotTokenOwner();

        BitMaps.BitMap storage balances = _balances[account];
        BitMaps.unset(balances, tagType);

        //Should not underflow beause of 0 balance check
        unchecked {
            --totalSupply[tagType];
        }
        return id;
    }

    /// @notice Burn a token from an account address
    /// @dev Checks if the token id has been minted and also that the provided address is the token owner
    /// @param account Account address
    /// @param tagType Tag type
    function burn(address account, uint96 tagType) external {
        uint256 tokenId = _burn(account, tagType);
        emit TransferSingle(_msgSender(), account, ZERO_ADDRESS, tokenId, 1);
    }

    /// @notice Get token metadata URI
    /// @dev Timestamp, tagName, and token number are provided by the caller temporarily until an oracle is implemented
    /// @param tagName Tag name
    /// @param mintTimestamp Mint timestamp
    /// @param tokenId Token id
    /// @param tokenNumber Token's number out of total supply
    /// @return metadata Token metadata
    function uri(
        string memory tagName,
        string memory mintTimestamp,
        uint256 tokenId,
        uint256 tokenNumber
    ) external pure returns (string memory metadata) {
        string memory output = string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="500" height="500" >',
            string.concat("<style>", "body { background:#FFF; }", "</style>"),
            svg.text(
                string.concat(
                    svg.prop("x", "20"),
                    svg.prop("y", "50"),
                    svg.prop("font-size", "20"),
                    svg.prop("fill", "black")
                ),
                string.concat(svg.cdata("DISCOVER NETWORK"))
            ),
            svg.text(
                string.concat(
                    svg.prop("x", "20"),
                    svg.prop("y", "75"),
                    svg.prop("font-size", "20"),
                    svg.prop("fill", "black")
                ),
                string.concat(
                    svg.cdata(
                        string.concat(
                            "'",
                            tagName,
                            "' #",
                            utils.uint2str(tokenNumber)
                        )
                    )
                )
            ),
            svg.text(
                string.concat(
                    svg.prop("x", "20"),
                    svg.prop("y", "100"),
                    svg.prop("font-size", "20"),
                    svg.prop("fill", "black")
                ),
                string.concat(svg.cdata(mintTimestamp))
            ),
            svg.text(
                string.concat(
                    svg.prop("x", "400"),
                    svg.prop("y", "475"),
                    svg.prop("font-size", "20"),
                    svg.prop("fill", "black")
                ),
                string.concat(svg.cdata("RADAR"))
            ),
            "</svg>"
        );

        string memory json = Base64.encode(
            bytes(
                string.concat(
                    '{"name": ',
                    tagName,
                    ', "token id": "',
                    utils.uint2str(tokenId),
                    '", "token number": "',
                    utils.uint2str(tokenNumber),
                    '", "timestamp": "',
                    mintTimestamp,
                    '", "image": "data:image/svg+xml;base64,',
                    Base64.encode(bytes(output)),
                    '"}'
                )
            )
        );
        output = string.concat("data:application/json;base64,", json);
        return output;
    }

    /// @dev ERC1155 receiver check to ensure a "to" address can receive the ERC1155 token standard, used in single mint
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

    //////////////////////////////////////
    ////////// Admin Functions ///////////
    //////////////////////////////////////

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

    /// @notice Withdraw all funds from the contract
    /// @dev Only owner can withdraw
    function withdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        (bool success, ) = radarMintFeeAddress.call{
            value: address(this).balance
        }("");
        emit FundsWithdrawn(address(this).balance);
    }
}
