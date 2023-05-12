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

    RadarConcepts radarConcepts;
    RadarConceptsHarness radarConceptsHarness;
    address recipientAddress;
    address defaultAdminAddress;
    address radarAddress;
    ERC1155Receiver erc1155Receiver;
    ERC1155ReceiverWrongFunctionSelectors erc1155ReceiverWrongFunctionSelectors;

    function setUp() external {
        recipientAddress = makeAddr("recipient");
        defaultAdminAddress = makeAddr("admin");
        radarAddress = makeAddr("radar");
        radarConcepts = new RadarConcepts(
            "www.testtokenuri1.xyz/",
            "www.testcontracturi1.xyz/",
            defaultAdminAddress,
            payable(radarAddress)
        );
        radarConceptsHarness = new RadarConceptsHarness(
            "www.testtokenuri1.xyz/",
            "www.testcontracturi1.xyz/",
            defaultAdminAddress,
            payable(radarAddress)
        );

        erc1155Receiver = new ERC1155Receiver();
        erc1155ReceiverWrongFunctionSelectors = new ERC1155ReceiverWrongFunctionSelectors();
        recipientAddress = makeAddr("recipient");
    }

    // Contract initilizes correctly
    function test_constructor_setsOwner() public {
        assertEq(radarConcepts.hasRole(0x00, defaultAdminAddress), true);
    }

    function test_constructor_setsRadarAddress() public {
        assertEq(radarConcepts.radarMintFeeAddress(), payable(radarAddress));
    }

    function test_constructor_setsContractURI() public {
        bool result = keccak256(
            abi.encodePacked(radarConcepts.contractURI())
        ) == keccak256(abi.encodePacked("www.testcontracturi1.xyz/"));
        assertEq(result, true);
    }

    function test_constructor_setsBaseTokenURI() public {
        bool result = keccak256(
            abi.encodePacked(radarConcepts.baseTokenURI())
        ) == keccak256(abi.encodePacked("www.testtokenuri1.xyz/"));
        assertEq(result, true);
    }

    function test_revertWhen_safeTransferFromCalled() public {
        uint256 tagType = 0;
        uint256 amount = 1;

        uint256 mintPrice = radarConcepts.mintPrice();
        radarConcepts.mint{value: mintPrice}(msg.sender, 0);

        vm.expectRevert(
            RadarConcepts.SoulboundTokenNoSafeTransferFrom.selector
        );
        radarConcepts.safeTransferFrom(
            msg.sender,
            recipientAddress,
            tagType,
            amount,
            ""
        );
    }

    function test_revertWhen_setApprovalForAllCalled() public {
        vm.expectRevert(
            RadarConcepts.SoulboundTokenNoSetApprovalForAll.selector
        );
        radarConcepts.setApprovalForAll(recipientAddress, true);
    }

    function test_revertWhen_isApprovedForAllCalled() public {
        vm.expectRevert(
            RadarConcepts.SoulboundTokenNoIsApprovedForAll.selector
        );
        radarConcepts.isApprovedForAll(msg.sender, recipientAddress);
    }

    function test_revertWhen_tokenMintedTwiceBySameAddress() public {
        uint256 mintPrice = radarConcepts.mintPrice();

        radarConcepts.mint{value: mintPrice}(recipientAddress, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                RadarConcepts.TokenAlreadyMinted.selector,
                recipientAddress,
                0,
                1
            )
        );
        radarConcepts.mint{value: mintPrice}(recipientAddress, 0);
    }

    function test_maxTagType_incrementsWhenTokenMinted() public {
        uint256 mintPrice = radarConcepts.mintPrice();
        radarConcepts.mint{value: mintPrice}(recipientAddress, 0);
        radarConcepts.mint{value: mintPrice}(recipientAddress, 1);
        assertEq(radarConcepts.maxTagType(), 1);
    }

    function test_mint_isSuccessfulToERC1155Receiver() public {
        uint256 mintPrice = radarConcepts.mintPrice();
        radarConcepts.mint{value: mintPrice}(address(erc1155Receiver), 0);
    }

    function test_revertWhen_tokenMintedToERC1155ReceiverWithWrongFunctionSelectors()
        public
    {
        uint256 mintPrice = radarConcepts.mintPrice();
        vm.expectRevert(RadarConcepts.ERC1155ReceiverRejectedTokens.selector);
        radarConcepts.mint{value: mintPrice}(
            address(erc1155ReceiverWrongFunctionSelectors),
            0
        );
    }

    function test_RevertWhen_tokenMintedToERC1155NonReceiver() public {
        uint256 mintPrice = radarConcepts.mintPrice();

        vm.expectRevert(RadarConcepts.ERC1155ReceiverNotImplemented.selector);
        radarConcepts.mint{value: mintPrice}(address(radarConceptsHarness), 0);
    }

    function test_uri_returnsCorrectTokenURI() public {
        bool result = keccak256(abi.encodePacked(radarConcepts.uri(0))) ==
            keccak256(
                abi.encodePacked(
                    string.concat(
                        radarConcepts.baseTokenURI(),
                        Strings.toString(0)
                    )
                )
            );
        assertEq(result, true);
    }

    function test_encodeTokenId_returnsCorrectTokenId() public {
        uint256 result = radarConcepts.encodeTokenId(0, msg.sender);
        assertEq(result, 137122462167341575662000267002353578582749290296);
    }

    function test_decodeTokenId_returnsCorrectAddressAndTagType() public {
        uint256 id = 137122462167341575662000267002353578582749290296;
        (uint256 tagType, address account) = radarConcepts.decodeTokenId(id);

        assertEq(account, msg.sender);
        assertEq(tagType, 0);
    }

    function test_RevertWhen_mintWithoutPayment() public {
        vm.expectRevert(RadarConcepts.InsufficientFunds.selector);

        radarConcepts.mint(recipientAddress, 1);
    }

    function test_burn_tokenOwnerCanBurnSuccessfully() public {
        uint256 mintPrice = radarConcepts.mintPrice();
        radarConcepts.mint{value: mintPrice}(recipientAddress, 0);
        uint256 tokenId = radarConcepts.encodeTokenId(0, recipientAddress);
        vm.prank(recipientAddress);
        radarConcepts.burn(tokenId);
    }

    function test_RevertWhen_burningNonTokenOwner() public {
        uint256 mintPrice = radarConcepts.mintPrice();
        radarConcepts.mint{value: mintPrice}(recipientAddress, 0);
        uint256 tokenId = radarConcepts.encodeTokenId(0, recipientAddress);
        vm.expectRevert(RadarConcepts.NotTokenOwner.selector);
        radarConcepts.burn(tokenId);
    }

    function test_radarFeeForAmount_calculatesRadarFeeAccurately() public {
        uint256 mintPrice = radarConcepts.mintPrice();

        uint256 expectedRadarFee = radarConceptsHarness
            .exposed_radarFeeForAmount{value: 1 ether}(100);
        assertEq(expectedRadarFee, mintPrice * 100);
    }

    function test_RevertWhen_RadarFeeForAmountCalledWithInsufficientFunds()
        public
    {
        vm.expectRevert(RadarConcepts.InsufficientFunds.selector);

        radarConceptsHarness.exposed_radarFeeForAmount(100);
    }

    function test_balanceOf_correctBalanceOfNonMintedToken() public {
        uint256 result = radarConcepts.balanceOf(msg.sender, 0);
        assertEq(result, 0);
    }

    function test_totalSupply_correctTotalSupplyOfNonMintedToken() public {
        uint256 result = radarConcepts.totalSupply(0);
        assertEq(result, 0);
    }

    function test_balanceOf_correctBalanceOfMintedToken() public {
        uint256 mintPrice = radarConcepts.mintPrice();
        radarConcepts.mint{value: mintPrice}(msg.sender, 0);
        uint256 result = radarConcepts.balanceOf(
            msg.sender,
            137122462167341575662000267002353578582749290296
        );
        assertEq(result, 1);
    }

    function test_mint_correctTotalSupplyOfMintedToken() public {
        uint256 mintPrice = radarConcepts.mintPrice();
        radarConcepts.mint{value: mintPrice}(msg.sender, 0);
        uint256 result = radarConcepts.totalSupply(0);
        assertEq(result, 1);
    }

    function test_RevertsWhen_nonAdminSetsTokenURI() public {
        bytes memory message = bytes(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(radarConceptsHarness.exposed_msgSender()),
                " is missing role ",
                Strings.toHexString(uint256(0x00), 32)
            )
        );

        vm.expectRevert(message);
        radarConcepts.setTokenURI("www.testtokenuri2.xyz/");
    }

    function test_setTokenURI_defaultAdminCanCall() public {
        vm.prank(defaultAdminAddress);
        radarConcepts.setTokenURI("www.testtokenuri2.xyz/");
    }

    function test_RevertWhen_nonAdminSetsContractURI() public {
        bytes memory message = bytes(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(radarConceptsHarness.exposed_msgSender()),
                " is missing role ",
                Strings.toHexString(uint256(0x00), 32)
            )
        );
        vm.expectRevert(message);
        radarConcepts.setContractURI("www.testcontracturi2.xyz/");
    }

    function test_setContractURI_defaultAdminCanCall() public {
        vm.prank(defaultAdminAddress);
        radarConcepts.setContractURI("https://testcontracturi2.xyz/");
    }

    function test_RevertWhen_nonAdminSetsMintPrice() public {
        bytes memory message = bytes(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(radarConceptsHarness.exposed_msgSender()),
                " is missing role ",
                Strings.toHexString(uint256(0x00), 32)
            )
        );
        vm.expectRevert(message);
        radarConcepts.setMintPrice(1 ether);
    }

    function test_setMintPrice_defaultAdminCanCall() public {
        vm.prank(defaultAdminAddress);
        radarConcepts.setMintPrice(1 ether);
    }

    function test_RevertWhen_nonAdminSetsMintFeeAddress() public {
        bytes memory message = bytes(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(radarConceptsHarness.exposed_msgSender()),
                " is missing role ",
                Strings.toHexString(uint256(0x00), 32)
            )
        );
        vm.expectRevert(message);
        radarConcepts.setMintFeeAddress(payable(msg.sender));
    }

    function test_setMintFeeAddress_defaultAdminCanCall() public {
        vm.prank(defaultAdminAddress);
        radarConcepts.setMintFeeAddress(payable(recipientAddress));
    }

    function test_RevertWhen_NonAdminWithdrawsFunds() public {
        uint256 mintPrice = radarConcepts.mintPrice();
        radarConcepts.mint{value: mintPrice}(msg.sender, 0);
        bytes memory message = bytes(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(radarConceptsHarness.exposed_msgSender()),
                " is missing role ",
                Strings.toHexString(uint256(0x00), 32)
            )
        );
        vm.expectRevert(message);
        radarConcepts.withdraw();
    }

    function test_withdrawFunds_DefaultAdminCanCall() public {
        uint256 mintPrice = radarConcepts.mintPrice();
        vm.deal(defaultAdminAddress, 1 ether);
        vm.startPrank(defaultAdminAddress);
        radarConcepts.mint{value: mintPrice}(msg.sender, 0);
        radarConcepts.withdraw();
        vm.stopPrank();
        assertEq(address(radarConcepts).balance, 0);
        assertEq(radarConcepts.radarMintFeeAddress().balance, 0.000777 ether);
    }

    //Supports the proper interfaces
    function test_supportsInterface_supportERC1155Interfaces() public {
        bytes4 erc1155InterfaceId = radarConcepts.balanceOf.selector ^
            radarConcepts.balanceOfBatch.selector ^
            radarConcepts.setApprovalForAll.selector ^
            radarConcepts.isApprovedForAll.selector ^
            radarConcepts.safeTransferFrom.selector ^
            radarConcepts.safeBatchTransferFrom.selector;
        assertEq(radarConcepts.supportsInterface(erc1155InterfaceId), true);
        assertEq(
            radarConcepts.supportsInterface(radarConcepts.uri.selector),
            true
        );
    }

    //Contract events are emitted correctly
    function test_setTokenURI_tokenUriEventEmitted() public {
        vm.expectEmit(true, true, false, false);
        emit TokenURIUpdated(
            "www.testtokenuri1.xyz/",
            "www.testtokenuri2.xyz/"
        );

        vm.prank(defaultAdminAddress);
        radarConcepts.setTokenURI("www.testtokenuri2.xyz/");
    }

    function test_setContractURI_contractUriEventEmitted() public {
        vm.expectEmit(true, true, false, false);
        emit ContractURIUpdated(
            "www.testcontracturi1.xyz/",
            "www.testcontracturi2.xyz/"
        );

        vm.prank(defaultAdminAddress);
        radarConcepts.setContractURI("www.testcontracturi2.xyz/");
    }

    function test_setMintPrice_mintPriceEventEmitted() public {
        vm.expectEmit(true, true, false, false);
        emit MintPriceUpdated(0.000777 ether, 1 ether);

        vm.prank(defaultAdminAddress);
        radarConcepts.setMintPrice(1 ether);
    }

    function test_setMintFeeAddress_mintFeeAddressEventEmitted() public {
        vm.expectEmit(true, true, false, false);
        emit MintFeeAddressUpdated(radarAddress, defaultAdminAddress);
        vm.prank(defaultAdminAddress);
        radarConcepts.setMintFeeAddress(payable(defaultAdminAddress));
    }

    function test_mint_transferSingleEventEmitted() public {
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

    function test_burn_transferSingleEventEmmited() public {
        uint256 mintPrice = radarConcepts.mintPrice();
        radarConcepts.mint{value: mintPrice}(recipientAddress, 0);
        uint256 tokenId = radarConcepts.encodeTokenId(0, recipientAddress);
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(
            recipientAddress,
            recipientAddress,
            address(0),
            tokenId,
            1
        );
        vm.prank(recipientAddress);
        radarConcepts.burn(tokenId);
    }
}
