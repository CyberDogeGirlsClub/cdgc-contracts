// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../src/CyberDogeGirlsClub.sol";
import "forge-std/Test.sol";

contract CyberDogeGirlsClubTest is Test {
    CyberDogeGirlsClub nft;
    uint256 baseMintPrice;
    address alice;

    function setUp() public {
        alice = address(1);

        vm.label(alice, "alice");
        vm.label(address(this), "deployer");

        vm.deal(address(this), 150_000 ether);

        nft = new CyberDogeGirlsClub();
        vm.label(nft.TREASURY(), "treasury");
        nft.setMintStartTimestamp(block.timestamp);

        baseMintPrice = nft.priceOracle().getBasePrice();
    }

    function testPublicMint() public {
        vm.deal(alice, baseMintPrice);
        vm.startPrank(alice);
        nft.publicMint{value: baseMintPrice}(1);
        vm.stopPrank();
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.totalSupply(), 1);
        assertEq(nft.unreservedSupply(), 1);
        assertEq(nft.reservedSupply(), 0);
        assertEq(nft.TREASURY().balance, baseMintPrice);
    }

    function testPublicMintWithoutPayment() public {
        vm.expectRevert(CyberDogeGirlsClub.MintPriceNotPaid.selector);
        vm.prank(alice);
        nft.publicMint(1);
    }

    function testPublicMintWithExcessPayment() public {
        vm.deal(alice, baseMintPrice + 1 ether);
        vm.startPrank(alice);
        nft.publicMint{value: baseMintPrice + 1 ether}(1);
        vm.stopPrank();
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.totalSupply(), 1);
        assertEq(nft.unreservedSupply(), 1);
        assertEq(nft.reservedSupply(), 0);
        assertEq(nft.TREASURY().balance, baseMintPrice);
        assertEq(alice.balance, 1 ether);
    }

    function testPublicMintingNotStarted() public {
        uint256 mintPrice = baseMintPrice;
        nft.setMintStartTimestamp(block.timestamp + 1 days);
        vm.deal(alice, baseMintPrice);

        vm.expectRevert(CyberDogeGirlsClub.MintingNotStarted.selector);
        vm.prank(alice);
        nft.publicMint{value: mintPrice}(1);
    }

    function testAdminMint() public {
        nft.adminMint(alice, 1);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.totalSupply(), 1);
        assertEq(nft.unreservedSupply(), 1);
        assertEq(nft.reservedSupply(), 0);
        assertEq(nft.TREASURY().balance, 0);
    }

    function testAdminMintUnauthorized() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        nft.adminMint(alice, 1);
    }

    function testReservedMint() public {
        nft.reservedMint(alice, 1);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.totalSupply(), 1);
        assertEq(nft.unreservedSupply(), 0);
        assertEq(nft.reservedSupply(), 1);
        assertEq(nft.TREASURY().balance, 0);
    }

    function testReservedMintUnauthorized() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        nft.reservedMint(alice, 1);
    }

    function testRoyaltyInfo() public {
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(0, 100);
        assertEq(receiver, nft.TREASURY());
        assertEq(royaltyAmount, 5);
    }

    function testSetMintStartTimestamp() public {
        nft.setMintStartTimestamp(block.timestamp + 1);
        assertEq(nft.mintStartTimestamp(), block.timestamp + 1);
    }

    function testSetMintStartTimestampUnauthorized() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        nft.setMintStartTimestamp(block.timestamp + 1);
    }

    function testSetDefaultRoyalty() public {
        nft.setDefaultRoyalty(address(this), 1000);
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(0, 100);
        assertEq(receiver, address(this));
        assertEq(royaltyAmount, 10);
    }

    function testSetDefaultRoyaltyUnauthorized() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        nft.setDefaultRoyalty(address(this), 1000);
    }

    function testSetBaseURI() public {
        nft.adminMint(alice, 1);
        nft.setBaseURI("https://example.com/");
        assertEq(nft.baseURI(), "https://example.com/");
        assertEq(nft.tokenURI(1), "https://example.com/1");
    }

    function testSetBaseURIUnauthorized() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        nft.setBaseURI("https://example.com/");
    }
}
