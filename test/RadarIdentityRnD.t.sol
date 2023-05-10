// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {RadarIdentityRnD} from "src/RadarIdentityRnD.sol";
import {RadarIdentityRnDHarness} from "src/RadarIdentityRnDHarness.sol";
import {ERC1155Receiver, ERC1155ReceiverWrongFunctionSelectors} from "src/ERC1155Receiver.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

contract RadarIdentityRnDTest is Test {
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 value
    );
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );
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
    event MintFeePayout(
        uint256 indexed amount,
        address indexed to,
        bool indexed success
    );
    event MintFeeAddressUpdated(
        address indexed previousMintFeeAddress,
        address indexed newMintFeeAddress
    );

    RadarIdentityRnD radarIdentityRnD;
    RadarIdentityRnDHarness radarIdentityRnDHarness;
    address recipientAddress;
    ERC1155Receiver erc1155Receiver;
    ERC1155ReceiverWrongFunctionSelectors erc1155ReceiverWrongFunctionSelectors;

    function setUp() external {
        radarIdentityRnD = new RadarIdentityRnD(
            "www.testtokenuri1.xyz/",
            "www.testcontracturi1.xyz/",
            0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49,
            payable(0x589e021B88F36103D3678301622b2368DBa44691)
        );
        radarIdentityRnDHarness = new RadarIdentityRnDHarness(
            "www.testtokenuri1.xyz/",
            "www.testcontracturi1.xyz/",
            0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49,
            payable(0x589e021B88F36103D3678301622b2368DBa44691)
        );

        erc1155Receiver = new ERC1155Receiver();
        erc1155ReceiverWrongFunctionSelectors = new ERC1155ReceiverWrongFunctionSelectors();
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
        ) == keccak256(abi.encodePacked("www.testcontracturi1.xyz/"));
        assertEq(result, true);
    }

    function testInitializeBaseTokenURI() public {
        bool result = keccak256(
            abi.encodePacked(radarIdentityRnD.baseTokenURI())
        ) == keccak256(abi.encodePacked("www.testtokenuri1.xyz/"));
        assertEq(result, true);
    }

    // NFT transfers and approvals revert
    function testRevertSafeTransferFrom() public {
        uint256 tagId = 0;
        uint256 amount = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                RadarIdentityRnD.SoulboundTokenNoSafeTransferFrom.selector,
                msg.sender,
                recipientAddress,
                tagId,
                amount,
                ""
            )
        );
        uint256 mintPrice = radarIdentityRnD.mintPrice();

        radarIdentityRnD.mint{value: mintPrice}(msg.sender, 0);
        radarIdentityRnD.safeTransferFrom(
            msg.sender,
            recipientAddress,
            tagId,
            amount,
            ""
        );
    }

    function testRevertSafeBatchTransferFrom() public {
        uint256[] memory tagTypes = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        tagTypes[0] = 0;
        tagTypes[1] = 1;
        tagTypes[2] = 2;

        amounts[0] = 0;
        amounts[1] = 1;
        amounts[2] = 2;

        vm.expectRevert(
            abi.encodeWithSelector(
                RadarIdentityRnD.SoulboundTokenNoSafeBatchTransferFrom.selector,
                msg.sender,
                recipientAddress,
                tagTypes,
                amounts,
                ""
            )
        );
        radarIdentityRnD.safeBatchTransferFrom(
            msg.sender,
            recipientAddress,
            tagTypes,
            amounts,
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
    function testFailDoubleMint() public {
        // vm.expectRevert(
        //     abi.encodeWithSelector(
        //         RadarIdentityRnD.TokenAlreadyMinted.selector,
        //         recipientAddress,
        //         0,
        //         1
        //     )
        // );
        uint256 mintPrice = radarIdentityRnD.mintPrice();

        radarIdentityRnD.mint{value: mintPrice}(recipientAddress, 0);
        radarIdentityRnD.mint{value: mintPrice}(recipientAddress, 0);
    }

    // Users can only batch mint one NFT of a type
    function testFailBatchMintSameType() public {
        // vm.expectRevert(
        //     abi.encodeWithSelector(
        //         RadarIdentityRnD.TokenAlreadyMinted.selector,
        //         recipientAddress,
        //         0,
        //         1
        //     )
        // );
        uint256 mintPrice = radarIdentityRnD.mintPrice();
        uint96[] memory tagTypes = new uint96[](3);
        tagTypes[0] = 0;
        tagTypes[1] = 0;
        tagTypes[2] = 0;
        radarIdentityRnD.mintBatch{value: mintPrice * tagTypes.length}(
            recipientAddress,
            tagTypes
        );
    }

    function testMintToERC1155Receiver() public {
        uint256 mintPrice = radarIdentityRnD.mintPrice();
        radarIdentityRnD.mint{value: mintPrice}(address(erc1155Receiver), 0);
    }

    function testBatchMintToERC1155Receiver() public {
        uint256 mintPrice = radarIdentityRnD.mintPrice();
        uint96[] memory tagTypes = new uint96[](3);
        tagTypes[0] = 0;
        tagTypes[1] = 1;
        tagTypes[2] = 2;
        radarIdentityRnD.mintBatch{value: mintPrice * tagTypes.length}(
            address(erc1155Receiver),
            tagTypes
        );
    }

    function testFailMintToERC1155ReceiverWrongFunctionSelectors() public {
        // vm.expectRevert(
        //     RadarIdentityRnD.ERC1155ReceiverRejectedTokens.selector
        // );
        uint256 mintPrice = radarIdentityRnD.mintPrice();
        radarIdentityRnD.mint{value: mintPrice}(
            address(erc1155ReceiverWrongFunctionSelectors),
            0
        );
    }

    function testFailBatchMintToERC1155WrongFunctionSelectors() public {
        // vm.expectRevert(
        //     RadarIdentityRnD.ERC1155ReceiverRejectedTokens.selector
        // );
        uint256 mintPrice = radarIdentityRnD.mintPrice();
        uint96[] memory tagTypes = new uint96[](3);
        tagTypes[0] = 0;
        tagTypes[1] = 1;
        tagTypes[2] = 2;
        radarIdentityRnD.mintBatch{value: mintPrice * tagTypes.length}(
            address(erc1155ReceiverWrongFunctionSelectors),
            tagTypes
        );
    }

    function testFailMintToERC1155NonReceiver() public {
        // vm.expectRevert(
        //     RadarIdentityRnD.ERC1155ReceiverNotImplemented.selector
        // );
        uint256 mintPrice = radarIdentityRnD.mintPrice();
        radarIdentityRnD.mint{value: mintPrice}(
            address(radarIdentityRnDHarness),
            0
        );
    }

    function testFailBatchMintToNonERC1155Receiver() public {
        // vm.expectRevert(
        //     RadarIdentityRnD.ERC1155ReceiverNotImplemented.selector
        // );
        uint256 mintPrice = radarIdentityRnD.mintPrice();
        uint96[] memory tagTypes = new uint96[](3);
        tagTypes[0] = 0;
        tagTypes[1] = 1;
        tagTypes[2] = 2;
        radarIdentityRnD.mintBatch{value: mintPrice * tagTypes.length}(
            address(radarIdentityRnDHarness),
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
        uint256 mintPrice = radarIdentityRnD.mintPrice();

        uint256 expectedRadarFee = radarIdentityRnDHarness
            .exposed_radarFeeForAmount{value: 1 ether}(100);
        assertEq(expectedRadarFee, mintPrice * 100);
    }

    function testRadarFeeWithInsufficientFunds() public {
        vm.expectRevert(RadarIdentityRnD.InsufficientFunds.selector);

        radarIdentityRnDHarness.exposed_radarFeeForAmount(100);
    }

    //Tags can only be minted in sequential order
    function testMintTagsInSequentialOrder() public {
        uint256 mintPrice = radarIdentityRnD.mintPrice();
        uint96[] memory tagTypes = new uint96[](3);
        tagTypes[0] = 0;
        tagTypes[1] = 1;
        tagTypes[2] = 2;
        radarIdentityRnD.mintBatch{value: mintPrice * tagTypes.length}(
            msg.sender,
            tagTypes
        );
    }

    function testFailMintTagsInNonsequentialOrder() public {
        uint256 mintPrice = radarIdentityRnD.mintPrice();
        uint96[] memory tagTypes = new uint96[](3);
        tagTypes[0] = 0;
        tagTypes[1] = 2;
        tagTypes[2] = 1;
        radarIdentityRnD.mintBatch{value: mintPrice * tagTypes.length}(
            msg.sender,
            tagTypes
        );
    }

    function testCorrectBalanceOfNonMintedToken() public {
        uint256 result = radarIdentityRnD.balanceOf(msg.sender, 0);
        assertEq(result, 0);
    }

    function testCorrectBalanceOfMintedToken() public {
        uint256 mintPrice = radarIdentityRnD.mintPrice();
        radarIdentityRnD.mint{value: mintPrice}(msg.sender, 0);
        uint256 result = radarIdentityRnD.balanceOf(
            msg.sender,
            137122462167341575662000267002353578582749290296
        );
        assertEq(result, 1);
    }

    function testCorrectBalancesofBatchMintedTokens() public {
        uint256 mintPrice = radarIdentityRnD.mintPrice();
        uint96[] memory tagTypes = new uint96[](3);
        tagTypes[0] = 0;
        tagTypes[1] = 1;
        tagTypes[2] = 2;
        radarIdentityRnD.mintBatch{value: mintPrice * tagTypes.length}(
            msg.sender,
            tagTypes
        );

        assertEq(radarIdentityRnD.balanceOf(msg.sender, 0), 1);
        assertEq(radarIdentityRnD.balanceOf(msg.sender, 1), 1);
        assertEq(radarIdentityRnD.balanceOf(msg.sender, 2), 1);
    }

    // Admin functions can only be performed by the contract owner
    function testFailNonAdminSetTokenURI() public {
        radarIdentityRnD.setTokenURI("www.testtokenuri2.xyz/");
    }

    function testAdminSetTokenURI() public {
        vm.prank(0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49);
        radarIdentityRnD.setTokenURI("www.testtokenuri2.xyz/");
    }

    function testFailNonAdminSetContractURI() public {
        radarIdentityRnD.setContractURI("www.testcontracturi2.xyz/");
    }

    function testAdminSetContractURI() public {
        vm.prank(0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49);
        radarIdentityRnD.setContractURI("https://testcontracturi2.xyz/");
    }

    function testFailNonAdminSetMintPrice() public {
        radarIdentityRnD.setMintPrice(1 ether);
    }

    function testAdminSetMintPrice() public {
        vm.prank(0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49);
        radarIdentityRnD.setMintPrice(1 ether);
    }

    function testFailNonAdminSetMintFeeAddress() public {
        radarIdentityRnD.setMintFeeAddress(payable(msg.sender));
    }

    function testAdminSetMintFeeAddress() public {
        vm.prank(0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49);
        radarIdentityRnD.setMintFeeAddress(payable(recipientAddress));
    }

    function testAdminWithdrawFunds() public {
        vm.prank(0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49);
        uint256 mintPrice = radarIdentityRnD.mintPrice();
        radarIdentityRnD.mint{value: mintPrice}(msg.sender, 0);
        radarIdentityRnD.withdraw();
        assertEq(
            radarIdentityRnD.radarMintFeeAddress().balance,
            0.000777 ether
        );
    }

    function testFailNonAdminWithdrawFunds() public {
        uint256 mintPrice = radarIdentityRnD.mintPrice();
        radarIdentityRnD.mint{value: mintPrice}(msg.sender, 0);
        radarIdentityRnD.withdraw();
    }

    //Supports the proper interfaces
    function testSupportERC1155Interface() public {
        bytes4 erc1155InterfaceId = radarIdentityRnD.balanceOf.selector ^
            radarIdentityRnD.balanceOfBatch.selector ^
            radarIdentityRnD.setApprovalForAll.selector ^
            radarIdentityRnD.isApprovedForAll.selector ^
            radarIdentityRnD.safeTransferFrom.selector ^
            radarIdentityRnD.safeBatchTransferFrom.selector;
        assertEq(radarIdentityRnD.supportsInterface(erc1155InterfaceId), true);
    }

    function testSupportERC1155MetadataURIInterface() public {
        assertEq(
            radarIdentityRnD.supportsInterface(radarIdentityRnD.uri.selector),
            true
        );
    }

    //Contract events are emitted correctly
    function testTokenURIEventEmitted() public {
        vm.expectEmit(true, true, false, false);
        emit TokenURIUpdated(
            "www.testtokenuri1.xyz/",
            "www.testtokenuri2.xyz/"
        );

        vm.prank(0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49);
        radarIdentityRnD.setTokenURI("www.testtokenuri2.xyz/");
    }

    function testContractURIEventEmitted() public {
        vm.expectEmit(true, true, false, false);
        emit ContractURIUpdated(
            "www.testcontracturi1.xyz/",
            "www.testcontracturi2.xyz/"
        );

        vm.prank(0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49);
        radarIdentityRnD.setContractURI("www.testcontracturi2.xyz/");
    }

    function testMintPriceEventEmitted() public {
        vm.expectEmit(true, true, false, false);
        emit MintPriceUpdated(0.000777 ether, 1 ether);

        vm.prank(0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49);
        radarIdentityRnD.setMintPrice(1 ether);
    }

    function testMintFeeAddressEventEmitted() public {
        vm.expectEmit(true, true, false, false);
        emit MintFeeAddressUpdated(
            0x589e021B88F36103D3678301622b2368DBa44691,
            0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49
        );
        vm.prank(0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49);
        radarIdentityRnD.setMintFeeAddress(
            payable(0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49)
        );
    }

    function testTransferSingleEventEmitted() public {
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(
            0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496,
            address(0),
            msg.sender,
            137122462167341575662000267002353578582749290296,
            1
        );

        radarIdentityRnD.mint{value: 1 ether}(msg.sender, 0);
    }

    function testTransferBatchEventEmitted() public {
        vm.expectEmit(true, true, true, true);
        uint96[] memory tagTypes = new uint96[](3);
        uint256[] memory tokenIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        tagTypes[0] = 0;
        tagTypes[1] = 1;
        tagTypes[2] = 2;
        tokenIds[0] = radarIdentityRnD.encodeTokenId(0, msg.sender);
        tokenIds[1] = radarIdentityRnD.encodeTokenId(1, msg.sender);
        tokenIds[2] = radarIdentityRnD.encodeTokenId(2, msg.sender);
        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 1;

        emit TransferBatch(
            0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496,
            address(0),
            msg.sender,
            tokenIds,
            amounts
        );

        uint256 mintPrice = radarIdentityRnD.mintPrice();
        radarIdentityRnD.mintBatch{value: mintPrice * tagTypes.length}(
            msg.sender,
            tagTypes
        );
    }
}
