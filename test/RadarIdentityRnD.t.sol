// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {RadarIdentityRnD} from "src/RadarIdentityRnD.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

contract RadarIdentityRnDTest is Test {
    RadarIdentityRnD radarIdentityRnD;
    address recipientAddress;

    function setUp() external {
        radarIdentityRnD = new RadarIdentityRnD(
            "https://ipfs.io/ipfs/bafybeifx7yeb55armcsxwwitkymga5xf53dxiarykms3ygqic223w5sk3m/",
            "https://ipfs.io/ipfs/bafybeifx7yeb55armcsxwwitkymga5xf53dxiarykms3ygqic223w5sk3m/",
            0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49,
            payable(0x589e021B88F36103D3678301622b2368DBa44691)
        );
        recipientAddress = makeAddr("recipient");
    }

    // Contract initilizes correctly
    function testInitializeOwner() public {
        assertEq(
            radarIdentityRnD.hasRole(
                0x00,
                0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49
            ),
            true
        );
    }

    function testInitializeRadarAddress() public {
        assertEq(
            radarIdentityRnD.radarMintFeeAddress(),
            payable(0x589e021B88F36103D3678301622b2368DBa44691)
        );
    }

    function testInitializeContractURI() public {
        bool result = keccak256(
            abi.encodePacked(radarIdentityRnD.contractURI())
        ) ==
            keccak256(
                abi.encodePacked(
                    "https://ipfs.io/ipfs/bafybeifx7yeb55armcsxwwitkymga5xf53dxiarykms3ygqic223w5sk3m/"
                )
            );
        assertEq(result, true);
    }

    function testInitializeBaseTokenURI() public {
        bool result = keccak256(
            abi.encodePacked(radarIdentityRnD.baseTokenURI())
        ) ==
            keccak256(
                abi.encodePacked(
                    "https://ipfs.io/ipfs/bafybeifx7yeb55armcsxwwitkymga5xf53dxiarykms3ygqic223w5sk3m/"
                )
            );
        assertEq(result, true);
    }

    // NFT transfers and approvals revert
    function testRevertSafeTransferFrom() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                RadarIdentityRnD.SoulboundTokenNoSafeTransferFrom.selector,
                msg.sender,
                recipientAddress,
                0,
                1,
                ""
            )
        );
        uint256 mint_price = radarIdentityRnD.mint_price();

        radarIdentityRnD.mint{value: mint_price}(msg.sender, 1);
        radarIdentityRnD.safeTransferFrom(
            msg.sender,
            recipientAddress,
            0,
            1,
            ""
        );
    }

    function testRevertSetApprovalForAll() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                RadarIdentityRnD.SoulboundTokenNoSetApprovalForAll.selector,
                recipientAddress,
                true
            )
        );
        radarIdentityRnD.setApprovalForAll(recipientAddress, true);
    }

    function testRevertIsApprovedForAll() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                RadarIdentityRnD.SoulboundTokenNoIsApprovedForAll.selector,
                msg.sender,
                recipientAddress
            )
        );
        radarIdentityRnD.isApprovedForAll(msg.sender, recipientAddress);
    }

    // Users can only mint one NFT of a type
    function testRevertDoubleMint() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                RadarIdentityRnD.TokenAlreadyMinted.selector,
                recipientAddress,
                0,
                1
            )
        );
        uint256 mint_price = radarIdentityRnD.mint_price();

        radarIdentityRnD.mint{value: mint_price}(recipientAddress, 0);
        radarIdentityRnD.mint{value: mint_price}(recipientAddress, 0);
    }

    // Users can only batch mint one NFT of a type
    function testRevertBatchMintSameType() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                RadarIdentityRnD.TokenAlreadyMinted.selector,
                recipientAddress,
                0,
                1
            )
        );
        uint256 mint_price = radarIdentityRnD.mint_price();
        uint96[] memory tagTypes = new uint96[](3);
        tagTypes[0] = 0;
        tagTypes[1] = 0;
        tagTypes[2] = 0;
        radarIdentityRnD.mintBatch{value: mint_price * tagTypes.length}(
            recipientAddress,
            tagTypes
        );
    }

    // Uri function returns the correct uri
    function testURI() public {
        bool result = keccak256(abi.encodePacked(radarIdentityRnD.uri(0))) ==
            keccak256(
                abi.encodePacked(
                    string.concat(
                        radarIdentityRnD.baseTokenURI(),
                        Strings.toString(0)
                    )
                )
            );
        assertEq(result, true);
    }

    // Token id encoding works correctly
    function testTokenIdEncoding() public {
        uint256 result = radarIdentityRnD.encodeTokenId(0, msg.sender);
        assertEq(result, 137122462167341575662000267002353578582749290296);
    }

    // Token id decoding works correctly
    function testTokenIdDecoding() public {
        uint256 id = 137122462167341575662000267002353578582749290296;
        (uint256 tagType, address account) = radarIdentityRnD.decodeTokenId(id);

        assertEq(account, msg.sender);
        assertEq(tagType, 0);
    }

    // Minting is not possible without payment
    function testMintingWithoutPayment() public {
        vm.expectRevert(RadarIdentityRnD.InsufficientFunds.selector);

        radarIdentityRnD.mint(recipientAddress, 1);
    }

    // Radar fee is calculated correctly
    // Radar fee is paid out to the correct address when minting
    function testRadarFee() public {
        address radarMintFeeAddress = radarIdentityRnD.radarMintFeeAddress();
        uint256 mint_price = radarIdentityRnD.mint_price();

        radarIdentityRnD.mint{value: mint_price}(recipientAddress, 0);
        assertEq(radarMintFeeAddress.balance, mint_price);
    }

    //Tags can only be minted in sequential order
    function testTagsInSequentialOrder() public {
        uint256 mint_price = radarIdentityRnD.mint_price();
        uint96[] memory tagTypes = new uint96[](3);
        tagTypes[0] = 0;
        tagTypes[1] = 1;
        tagTypes[2] = 2;
        radarIdentityRnD.mintBatch{value: mint_price * tagTypes.length}(
            msg.sender,
            tagTypes
        );
    }

    function testFailInNonsequentialOrder() public {
        uint256 mint_price = radarIdentityRnD.mint_price();
        uint96[] memory tagTypes = new uint96[](3);
        tagTypes[0] = 0;
        tagTypes[1] = 2;
        tagTypes[2] = 1;
        radarIdentityRnD.mintBatch{value: mint_price * tagTypes.length}(
            msg.sender,
            tagTypes
        );
    }

    function testBalanceOfNonMintedToken() public {
        uint256 result = radarIdentityRnD.balanceOf(msg.sender, 0);
        assertEq(result, 0);
    }

    function testBalanceOfMintedToken() public {
        uint256 mint_price = radarIdentityRnD.mint_price();
        radarIdentityRnD.mint{value: mint_price}(msg.sender, 0);
        uint256 result = radarIdentityRnD.balanceOf(
            msg.sender,
            137122462167341575662000267002353578582749290296
        );
        assertEq(result, 1);
    }

    // Admin functions can only be performed by the contract owner
    function testFailNonAdminSetTokenURI() public {
        radarIdentityRnD.setTokenURI("https://testurl.xyz/");
    }

    function testFailNonAdminSetContractURI() public {
        radarIdentityRnD.setContractURI("https://testurl.xyz/");
    }

    function testFailNonAdminSetMintPrice() public {
        radarIdentityRnD.setContractURI("https://testurl.xyz/");
    }

    function testFailNonAdminSetMintFeeAddress() public {
        radarIdentityRnD.setMintFeeAddress(payable(msg.sender));
    }
}
