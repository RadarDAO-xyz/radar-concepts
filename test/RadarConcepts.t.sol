// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {RadarConcepts} from "src/RadarConcepts.sol";
import {RadarConceptsHarness} from "src/RadarConceptsHarness.sol";
import {ERC1155Receiver, ERC1155ReceiverWrongFunctionSelectors} from "src/ERC1155Receiver.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

contract RadarConceptsTest is Test {
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

    RadarConcepts radarConcepts;
    RadarConceptsHarness radarConceptsHarness;
    address recipientAddress;
    ERC1155Receiver erc1155Receiver;
    ERC1155ReceiverWrongFunctionSelectors erc1155ReceiverWrongFunctionSelectors;

    function setUp() external {
        radarConcepts = new RadarConcepts(
            "www.testcontracturi1.xyz/",
            0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49,
            payable(0x589e021B88F36103D3678301622b2368DBa44691)
        );
        radarConceptsHarness = new RadarConceptsHarness(
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
            radarConcepts.hasRole(
                0x00,
                0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49
            ),
            true
        );
    }

    function testInitializeRadarAddress() public {
        assertEq(
            radarConcepts.radarMintFeeAddress(),
            payable(0x589e021B88F36103D3678301622b2368DBa44691)
        );
    }

    function testInitializeContractURI() public {
        bool result = keccak256(
            abi.encodePacked(radarConcepts.contractURI())
        ) == keccak256(abi.encodePacked("www.testcontracturi1.xyz/"));
        assertEq(result, true);
    }

    // NFT transfers and approvals revert
    function testRevertSafeTransferFrom() public {
        uint256 tagId = 0;
        uint256 amount = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                RadarConcepts.SoulboundTokenNoSafeTransferFrom.selector,
                msg.sender,
                recipientAddress,
                tagId,
                amount,
                ""
            )
        );
        uint256 mintPrice = radarConcepts.mintPrice();

        radarConcepts.mint{value: mintPrice}(msg.sender, 0);
        radarConcepts.safeTransferFrom(
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
                RadarConcepts.SoulboundTokenNoSafeBatchTransferFrom.selector,
                msg.sender,
                recipientAddress,
                tagTypes,
                amounts,
                ""
            )
        );
        radarConcepts.safeBatchTransferFrom(
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
                RadarConcepts.SoulboundTokenNoSetApprovalForAll.selector,
                recipientAddress,
                true
            )
        );
        radarConcepts.setApprovalForAll(recipientAddress, true);
    }

    function testRevertIsApprovedForAll() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                RadarConcepts.SoulboundTokenNoIsApprovedForAll.selector,
                msg.sender,
                recipientAddress
            )
        );
        radarConcepts.isApprovedForAll(msg.sender, recipientAddress);
    }

    // Users can only mint one NFT of a type
    function testFailDoubleMint() public {
        // vm.expectRevert(
        //     abi.encodeWithSelector(
        //         RadarConcepts.TokenAlreadyMinted.selector,
        //         recipientAddress,
        //         0,
        //         1
        //     )
        // );
        uint256 mintPrice = radarConcepts.mintPrice();

        radarConcepts.mint{value: mintPrice}(recipientAddress, 0);
        radarConcepts.mint{value: mintPrice}(recipientAddress, 0);
    }

    // Users can only batch mint one NFT of a type
    function testFailBatchMintSameType() public {
        // vm.expectRevert(
        //     abi.encodeWithSelector(
        //         RadarConcepts.TokenAlreadyMinted.selector,
        //         recipientAddress,
        //         0,
        //         1
        //     )
        // );
        uint256 mintPrice = radarConcepts.mintPrice();
        uint96[] memory tagTypes = new uint96[](3);
        tagTypes[0] = 0;
        tagTypes[1] = 0;
        tagTypes[2] = 0;
        radarConcepts.mintBatch{value: mintPrice * tagTypes.length}(
            recipientAddress,
            tagTypes
        );
    }

    function testMaxTagTypeValue() public {
        uint256 mintPrice = radarConcepts.mintPrice();
        uint96[] memory tagTypes = new uint96[](3);
        tagTypes[0] = 0;
        tagTypes[1] = 1;
        tagTypes[2] = 2;
        radarConcepts.mintBatch{value: mintPrice * tagTypes.length}(
            recipientAddress,
            tagTypes
        );
        assertEq(radarConcepts.maxTagType(), 2);
    }

    function testMintToERC1155Receiver() public {
        uint256 mintPrice = radarConcepts.mintPrice();
        radarConcepts.mint{value: mintPrice}(address(erc1155Receiver), 0);
    }

    function testBatchMintToERC1155Receiver() public {
        uint256 mintPrice = radarConcepts.mintPrice();
        uint96[] memory tagTypes = new uint96[](3);
        tagTypes[0] = 0;
        tagTypes[1] = 1;
        tagTypes[2] = 2;
        radarConcepts.mintBatch{value: mintPrice * tagTypes.length}(
            address(erc1155Receiver),
            tagTypes
        );
    }

    function testFailMintToERC1155ReceiverWrongFunctionSelectors() public {
        // vm.expectRevert(
        //     RadarConcepts.ERC1155ReceiverRejectedTokens.selector
        // );
        uint256 mintPrice = radarConcepts.mintPrice();
        radarConcepts.mint{value: mintPrice}(
            address(erc1155ReceiverWrongFunctionSelectors),
            0
        );
    }

    function testFailBatchMintToERC1155WrongFunctionSelectors() public {
        // vm.expectRevert(
        //     RadarConcepts.ERC1155ReceiverRejectedTokens.selector
        // );
        uint256 mintPrice = radarConcepts.mintPrice();
        uint96[] memory tagTypes = new uint96[](3);
        tagTypes[0] = 0;
        tagTypes[1] = 1;
        tagTypes[2] = 2;
        radarConcepts.mintBatch{value: mintPrice * tagTypes.length}(
            address(erc1155ReceiverWrongFunctionSelectors),
            tagTypes
        );
    }

    function testFailMintToERC1155NonReceiver() public {
        // vm.expectRevert(
        //     RadarConcepts.ERC1155ReceiverNotImplemented.selector
        // );
        uint256 mintPrice = radarConcepts.mintPrice();
        radarConcepts.mint{value: mintPrice}(address(radarConceptsHarness), 0);
    }

    function testFailBatchMintToNonERC1155Receiver() public {
        // vm.expectRevert(
        //     RadarConcepts.ERC1155ReceiverNotImplemented.selector
        // );
        uint256 mintPrice = radarConcepts.mintPrice();
        uint96[] memory tagTypes = new uint96[](3);
        tagTypes[0] = 0;
        tagTypes[1] = 1;
        tagTypes[2] = 2;
        radarConcepts.mintBatch{value: mintPrice * tagTypes.length}(
            address(radarConceptsHarness),
            tagTypes
        );
    }

    // Uri function returns the correct uri
    function test_uri_returnsCorrectData() public {
        string memory uri = radarConcepts.uri(
            "IDENTITY RND",
            "04.25.23 21:10:18",
            0,
            891
        );
        assertEq(
            uri,
            "data:application/json;base64,eyJuYW1lIjogSURFTlRJVFkgUk5ELCAidG9rZW4gaWQiOiAiMCIsICJ0b2tlbiBudW1iZXIiOiAiODkxIiwgInRpbWVzdGFtcCI6ICIwNC4yNS4yMyAyMToxMDoxOCIsICJpbWFnZSI6ICJkYXRhOmltYWdlL3N2Zyt4bWw7YmFzZTY0LFBITjJaeUI0Yld4dWN6MGlhSFIwY0RvdkwzZDNkeTUzTXk1dmNtY3ZNakF3TUM5emRtY2lJSGRwWkhSb1BTSTFNREFpSUdobGFXZG9kRDBpTlRBd0lpQStQSE4wZVd4bFBtSnZaSGtnZXlCaVlXTnJaM0p2ZFc1a09pTkdSa1k3SUgwOEwzTjBlV3hsUGp4MFpYaDBJSGc5SWpJd0lpQjVQU0kxTUNJZ1ptOXVkQzF6YVhwbFBTSXlNQ0lnWm1sc2JEMGlZbXhoWTJzaUlENDhJVnREUkVGVVFWdEVTVk5EVDFaRlVpQk9SVlJYVDFKTFhWMCtQQzkwWlhoMFBqeDBaWGgwSUhnOUlqSXdJaUI1UFNJM05TSWdabTl1ZEMxemFYcGxQU0l5TUNJZ1ptbHNiRDBpWW14aFkyc2lJRDQ4SVZ0RFJFRlVRVnNuU1VSRlRsUkpWRmtnVWs1RUp5QWpPRGt4WFYwK1BDOTBaWGgwUGp4MFpYaDBJSGc5SWpJd0lpQjVQU0l4TURBaUlHWnZiblF0YzJsNlpUMGlNakFpSUdacGJHdzlJbUpzWVdOcklpQStQQ0ZiUTBSQlZFRmJNRFF1TWpVdU1qTWdNakU2TVRBNk1UaGRYVDQ4TDNSbGVIUStQSFJsZUhRZ2VEMGlOREF3SWlCNVBTSTBOelVpSUdadmJuUXRjMmw2WlQwaU1qQWlJR1pwYkd3OUltSnNZV05ySWlBK1BDRmJRMFJCVkVGYlVrRkVRVkpkWFQ0OEwzUmxlSFErUEM5emRtYysifQ=="
        );
    }

    // Token id encoding works correctly
    function testTokenIdEncoding() public {
        uint256 result = radarConcepts.encodeTokenId(0, msg.sender);
        assertEq(result, 137122462167341575662000267002353578582749290296);
    }

    // Token id decoding works correctly
    function testTokenIdDecoding() public {
        uint256 id = 137122462167341575662000267002353578582749290296;
        (uint256 tagType, address account) = radarConcepts.decodeTokenId(id);

        assertEq(account, msg.sender);
        assertEq(tagType, 0);
    }

    // Minting is not possible without payment
    function testMintingWithoutPayment() public {
        vm.expectRevert(RadarConcepts.InsufficientFunds.selector);

        radarConcepts.mint(recipientAddress, 1);
    }

    // Radar fee is calculated correctly
    // Radar fee is paid out to the correct address when minting
    function testRadarFee() public {
        uint256 mintPrice = radarConcepts.mintPrice();

        uint256 expectedRadarFee = radarConceptsHarness
            .exposed_radarFeeForAmount{value: 1 ether}(100);
        assertEq(expectedRadarFee, mintPrice * 100);
    }

    function testRadarFeeWithInsufficientFunds() public {
        vm.expectRevert(RadarConcepts.InsufficientFunds.selector);

        radarConceptsHarness.exposed_radarFeeForAmount(100);
    }

    //Tags can only be minted in sequential order
    function testMintTagsInSequentialOrder() public {
        uint256 mintPrice = radarConcepts.mintPrice();
        uint96[] memory tagTypes = new uint96[](3);
        tagTypes[0] = 0;
        tagTypes[1] = 1;
        tagTypes[2] = 2;
        radarConcepts.mintBatch{value: mintPrice * tagTypes.length}(
            msg.sender,
            tagTypes
        );
    }

    function testFailMintTagsInNonsequentialOrder() public {
        uint256 mintPrice = radarConcepts.mintPrice();
        uint96[] memory tagTypes = new uint96[](3);
        tagTypes[0] = 0;
        tagTypes[1] = 2;
        tagTypes[2] = 1;
        radarConcepts.mintBatch{value: mintPrice * tagTypes.length}(
            msg.sender,
            tagTypes
        );
    }

    function testCorrectBalanceOfNonMintedToken() public {
        uint256 result = radarConcepts.balanceOf(msg.sender, 0);
        assertEq(result, 0);
    }

    function testCorrectTotalSupplyOfNonMintedToken() public {
        uint256 result = radarConcepts.totalSupply(0);
        assertEq(result, 0);
    }

    function testCorrectBalanceOfMintedToken() public {
        uint256 mintPrice = radarConcepts.mintPrice();
        radarConcepts.mint{value: mintPrice}(msg.sender, 0);
        uint256 result = radarConcepts.balanceOf(
            msg.sender,
            137122462167341575662000267002353578582749290296
        );
        assertEq(result, 1);
    }

    function testCorrectTotalSupplyOfMintedToken() public {
        uint256 mintPrice = radarConcepts.mintPrice();
        radarConcepts.mint{value: mintPrice}(msg.sender, 0);
        uint256 result = radarConcepts.totalSupply(0);
        assertEq(result, 1);
    }

    function testCorrectBalancesofBatchMintedTokens() public {
        uint256 mintPrice = radarConcepts.mintPrice();
        uint96[] memory tagTypes = new uint96[](3);
        tagTypes[0] = 0;
        tagTypes[1] = 1;
        tagTypes[2] = 2;
        radarConcepts.mintBatch{value: mintPrice * tagTypes.length}(
            msg.sender,
            tagTypes
        );

        assertEq(radarConcepts.balanceOf(msg.sender, 0), 1);
        assertEq(radarConcepts.balanceOf(msg.sender, 1), 1);
        assertEq(radarConcepts.balanceOf(msg.sender, 2), 1);
    }

    function testCorrectTotalSupplyofBatchMintedTokens() public {
        uint256 mintPrice = radarConcepts.mintPrice();
        uint96[] memory tagTypes = new uint96[](3);
        tagTypes[0] = 0;
        tagTypes[1] = 1;
        tagTypes[2] = 2;
        radarConcepts.mintBatch{value: mintPrice * tagTypes.length}(
            msg.sender,
            tagTypes
        );

        assertEq(radarConcepts.totalSupply(0), 1);
        assertEq(radarConcepts.totalSupply(1), 1);
        assertEq(radarConcepts.totalSupply(2), 1);
    }

    // Admin functions can only be performed by the contract owner

    function testFailNonAdminSetContractURI() public {
        radarConcepts.setContractURI("www.testcontracturi2.xyz/");
    }

    function testAdminSetContractURI() public {
        vm.prank(0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49);
        radarConcepts.setContractURI("https://testcontracturi2.xyz/");
    }

    function testFailNonAdminSetMintPrice() public {
        radarConcepts.setMintPrice(1 ether);
    }

    function testAdminSetMintPrice() public {
        vm.prank(0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49);
        radarConcepts.setMintPrice(1 ether);
    }

    function testFailNonAdminSetMintFeeAddress() public {
        radarConcepts.setMintFeeAddress(payable(msg.sender));
    }

    function testAdminSetMintFeeAddress() public {
        vm.prank(0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49);
        radarConcepts.setMintFeeAddress(payable(recipientAddress));
    }

    function testAdminWithdrawFunds() public {
        uint256 mintPrice = radarConcepts.mintPrice();
        vm.deal(0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49, 1 ether);
        vm.startPrank(0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49);
        radarConcepts.mint{value: mintPrice}(msg.sender, 0);
        radarConcepts.withdraw();
        vm.stopPrank();
        assertEq(address(radarConcepts).balance, 0);
        assertEq(radarConcepts.radarMintFeeAddress().balance, 0.000777 ether);
    }

    function testFailNonAdminWithdrawFunds() public {
        uint256 mintPrice = radarConcepts.mintPrice();
        radarConcepts.mint{value: mintPrice}(msg.sender, 0);
        radarConcepts.withdraw();
    }

    //Supports the proper interfaces
    function testSupportERC1155Interface() public {
        bytes4 erc1155InterfaceId = radarConcepts.balanceOf.selector ^
            radarConcepts.balanceOfBatch.selector ^
            radarConcepts.setApprovalForAll.selector ^
            radarConcepts.isApprovedForAll.selector ^
            radarConcepts.safeTransferFrom.selector ^
            radarConcepts.safeBatchTransferFrom.selector;
        assertEq(radarConcepts.supportsInterface(erc1155InterfaceId), true);
    }

    //Contract events are emitted correctly

    function testContractURIEventEmitted() public {
        vm.expectEmit(true, true, false, false);
        emit ContractURIUpdated(
            "www.testcontracturi1.xyz/",
            "www.testcontracturi2.xyz/"
        );

        vm.prank(0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49);
        radarConcepts.setContractURI("www.testcontracturi2.xyz/");
    }

    function testMintPriceEventEmitted() public {
        vm.expectEmit(true, true, false, false);
        emit MintPriceUpdated(0.000777 ether, 1 ether);

        vm.prank(0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49);
        radarConcepts.setMintPrice(1 ether);
    }

    function testMintFeeAddressEventEmitted() public {
        vm.expectEmit(true, true, false, false);
        emit MintFeeAddressUpdated(
            0x589e021B88F36103D3678301622b2368DBa44691,
            0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49
        );
        vm.prank(0x82E286DF583C9b0d6504c56EAbA8fF47ffd59f49);
        radarConcepts.setMintFeeAddress(
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

        radarConcepts.mint{value: 1 ether}(msg.sender, 0);
    }

    function testTransferBatchEventEmitted() public {
        vm.expectEmit(true, true, true, true);
        uint96[] memory tagTypes = new uint96[](3);
        uint256[] memory tokenIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        tagTypes[0] = 0;
        tagTypes[1] = 1;
        tagTypes[2] = 2;
        tokenIds[0] = radarConcepts.encodeTokenId(0, msg.sender);
        tokenIds[1] = radarConcepts.encodeTokenId(1, msg.sender);
        tokenIds[2] = radarConcepts.encodeTokenId(2, msg.sender);
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

        uint256 mintPrice = radarConcepts.mintPrice();
        radarConcepts.mintBatch{value: mintPrice * tagTypes.length}(
            msg.sender,
            tagTypes
        );
    }
}
