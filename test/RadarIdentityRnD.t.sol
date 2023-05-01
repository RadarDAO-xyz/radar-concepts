// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {RadarIdentityRnD} from "src/RadarIdentityRnD.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

contract RadarIdentityRnDTest is Test {
    RadarIdentityRnD radarIdentityRnD;

    function setUp() external {
        radarIdentityRnD = new RadarIdentityRnD(
            "https://ipfs.io/ipfs/bafybeifx7yeb55armcsxwwitkymga5xf53dxiarykms3ygqic223w5sk3m",
            "https://ipfs.io/ipfs/bafybeifx7yeb55armcsxwwitkymga5xf53dxiarykms3ygqic223w5sk3m",
            0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49,
            payable(0x589e021B88F36103D3678301622b2368DBa44691)
        );
    }

    // Contract initilizes correctly
    function testOwner() public view {
        assert(
            radarIdentityRnD.hasRole(
                0x00,
                0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49
            ) == true
        );
    }

    function testRadarAddress() public view {
        assert(
            radarIdentityRnD.radarMintFeeAddress() ==
                payable(0x589e021B88F36103D3678301622b2368DBa44691)
        );
    }

    function testContractURI() public view {
        bool result = keccak256(
            abi.encodePacked(radarIdentityRnD.contractURI())
        ) ==
            keccak256(
                abi.encodePacked(
                    "https://ipfs.io/ipfs/bafybeifx7yeb55armcsxwwitkymga5xf53dxiarykms3ygqic223w5sk3m"
                )
            );
        assert(result == true);
    }

    function testBaseTokenURI() public view {
        bool result = keccak256(
            abi.encodePacked(radarIdentityRnD.baseTokenURI())
        ) ==
            keccak256(
                abi.encodePacked(
                    "https://ipfs.io/ipfs/bafybeifx7yeb55armcsxwwitkymga5xf53dxiarykms3ygqic223w5sk3m"
                )
            );
        assert(result == true);
    }

    // NFT transfers and approvals revert
    function testFailTransfer() public {
        uint256 mint_price = radarIdentityRnD.mint_price();

        vm.deal(0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49, 1 ether);
        vm.startPrank(0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49);
        radarIdentityRnD.mint{value: mint_price}(
            0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49,
            1
        );
        radarIdentityRnD.safeTransferFrom(
            0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49,
            0x267D422b6A40DB310024aad2b77a5b296cB87128,
            1,
            1,
            ""
        );
    }

    function testSetApprovalForAll() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                RadarIdentityRnD.SoulboundTokenNoSetApprovalForAll.selector,
                0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49,
                true
            )
        );
        radarIdentityRnD.setApprovalForAll(
            0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49,
            true
        );
    }

    function testIsApprovedForAll() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                RadarIdentityRnD.SoulboundTokenNoIsApprovedForAll.selector,
                msg.sender,
                0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49
            )
        );
        radarIdentityRnD.isApprovedForAll(
            msg.sender,
            0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49
        );
    }

    // Users can only mint one NFT of a type
    function testFailDoubleMint() public {
        uint256 mint_price = radarIdentityRnD.mint_price();

        vm.deal(msg.sender, 1 ether);
        radarIdentityRnD.mint{value: mint_price}(
            0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49,
            0
        );
        radarIdentityRnD.mint{value: mint_price}(
            0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49,
            0
        );
    }

    // Users can only batch mint one NFT of a type
    function testFailBatchMint() public {
        uint256 mint_price = radarIdentityRnD.mint_price();
        uint64[] memory tagTypes = new uint64[](3);
        tagTypes[0] = 0;
        tagTypes[1] = 0;
        tagTypes[2] = 0;
        vm.deal(msg.sender, 3 ether);
        radarIdentityRnD.mintBatch{value: mint_price}(
            0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49,
            tagTypes
        );
    }

    // Uri function returns the correct uri
    function testURI() public view {
        bool result = keccak256(abi.encodePacked(radarIdentityRnD.uri(0))) ==
            keccak256(
                abi.encodePacked(
                    string.concat(
                        radarIdentityRnD.baseTokenURI(),
                        Strings.toString(0)
                    )
                )
            );
        assert(result == true);
    }

    // Token id encoding works correctly
    function testTokenIdEncoding() public view {
        uint256 result = radarIdentityRnD.encodeTokenId(0, msg.sender);
        assert(
            result == uint256(bytes32(abi.encodePacked(uint64(0), msg.sender)))
        );
    }

    // Token id decoding works correctly

    function testTokenIdDecoding() public view {
        uint256 id = 588936490555729346729400696718376575041474231588530159616;
        (uint64 tagType, address account) = radarIdentityRnD.decodeTokenId(id);
        assert(tagType == 0);
        assert(account == msg.sender);
    }

    // Minting is not possible without payment
    function testMintingWithoutPayment() public {
        vm.expectRevert(RadarIdentityRnD.InsufficientFunds.selector);

        vm.prank(0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49);
        radarIdentityRnD.mint(0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49, 1);
    }

    // Radar fee is calculated correctly
    // Radar fee is paid out to the correct address when minting
    function testRadarFee() public {
        address radarMintFeeAddress = radarIdentityRnD.radarMintFeeAddress();
        uint256 mint_price = radarIdentityRnD.mint_price();

        vm.deal(0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49, 1 ether);
        vm.startPrank(0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49);
        radarIdentityRnD.mint{value: mint_price}(msg.sender, 0);
        console.log(msg.sender.balance);
        assert(radarMintFeeAddress.balance == mint_price);
        assert(msg.sender.balance != 1 ether);
    }
    // Admin functions can only be performed by the contract owner
		function testAdmin() public {
			vm.expectRevert(
				
			)
		}
    // Safetransfer acceptance check works correctly
    // Batch safetransfer acceptance check works correctly
}
