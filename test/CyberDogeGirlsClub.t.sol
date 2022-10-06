// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../src/CyberDogeGirlsClub.sol";
import "forge-std/Test.sol";

contract CyberDogeGirlsClubTest is Test {
    CyberDogeGirlsClub nft;
    uint256 baseMintPrice;
    uint256 treasuryAmount;
    uint256 inviterFeeAmount;
    address alice;
    address bob;
    uint256 initialSupply;

    function setUp() public {
        alice = address(1);
        bob = address(2);

        vm.label(alice, "alice");
        vm.label(address(this), "deployer");

        nft = new CyberDogeGirlsClub();
        vm.label(nft.TREASURY(), "treasury");
        nft.setMintStartTimestamp(block.timestamp);

        baseMintPrice = nft.priceOracle().getBasePrice();
        inviterFeeAmount = (baseMintPrice * nft.inviterFeeBPS()) / 1e4;
        treasuryAmount = baseMintPrice - inviterFeeAmount;
        initialSupply = nft.totalSupply();

        vm.deal(address(this), 0);
    }

    function testPublicMint() public {
        vm.deal(alice, baseMintPrice);
        vm.startPrank(alice);
        nft.publicMint{value: baseMintPrice}(1, address(this));
        vm.stopPrank();
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.totalSupply(), 1 + initialSupply);
        assertEq(nft.unreservedSupply(), 1);
        assertEq(nft.reservedSupply(), 0 + initialSupply);
        assertEq(nft.TREASURY().balance, treasuryAmount);
        assertEq(address(this).balance, inviterFeeAmount);
    }

    function testPublicMintWithoutPayment() public {
        vm.expectRevert(CyberDogeGirlsClub.MintPriceNotPaid.selector);
        vm.prank(alice);
        nft.publicMint(1, address(this));
    }

    function testPublicMintWithExcessPayment() public {
        vm.deal(alice, baseMintPrice + 1 ether);
        vm.startPrank(alice);
        nft.publicMint{value: baseMintPrice + 1 ether}(1, address(this));
        vm.stopPrank();
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.totalSupply(), 1 + initialSupply);
        assertEq(nft.unreservedSupply(), 1);
        assertEq(nft.reservedSupply(), 0 + initialSupply);
        assertEq(nft.TREASURY().balance, treasuryAmount);
        assertEq(address(this).balance, inviterFeeAmount);
        assertEq(alice.balance, 1 ether);
    }

    function testPublicMintWithInsufficientPayment() public {
        vm.expectRevert(CyberDogeGirlsClub.MintPriceNotPaid.selector);
        vm.deal(alice, baseMintPrice - 1);
        vm.prank(alice);
        nft.publicMint{value: baseMintPrice - 1}(1, address(this));
    }

    function testPublicMintWithZeroAmount() public {
        vm.expectRevert(CyberDogeGirlsClub.InvalidAmount.selector);
        vm.deal(alice, baseMintPrice);
        vm.prank(alice);
        nft.publicMint{value: baseMintPrice}(0, address(this));
    }

    function testPublicMintingNotStarted() public {
        uint256 mintPrice = baseMintPrice;
        nft.setMintStartTimestamp(block.timestamp + 1 days);
        vm.deal(alice, baseMintPrice);

        vm.expectRevert(CyberDogeGirlsClub.MintingNotStarted.selector);
        vm.prank(alice);
        nft.publicMint{value: mintPrice}(1, address(this));
    }

    function testPublicMintInviterNotAMember() public {
        vm.deal(alice, baseMintPrice);
        vm.expectRevert(CyberDogeGirlsClub.InviterIsNotAMember.selector);
        vm.startPrank(alice);
        nft.publicMint{value: baseMintPrice}(1, bob);
        vm.stopPrank();
    }

    function testPublicMintInviterIsTheSender() public {
        vm.deal(alice, baseMintPrice);
        vm.expectRevert(CyberDogeGirlsClub.InviterIsTheSender.selector);
        vm.startPrank(alice);
        nft.publicMint{value: baseMintPrice}(1, alice);
        vm.stopPrank();
    }

    function testInviteCount() public {
        vm.deal(alice, baseMintPrice);
        vm.startPrank(alice);
        nft.publicMint{value: baseMintPrice}(1, address(this));
        vm.stopPrank();
        assertEq(nft.inviteCount(address(this)), 1);
    }

    function testInviteCountWithMultipleInvites() public {
        vm.deal(alice, baseMintPrice);
        vm.startPrank(alice);
        nft.publicMint{value: baseMintPrice}(1, address(this));
        vm.stopPrank();
        assertEq(nft.inviteCount(address(this)), 1);
        assertEq(nft.inviteCount(alice), 0);

        vm.deal(bob, baseMintPrice);
        vm.startPrank(bob);
        nft.publicMint{value: baseMintPrice}(1, address(this));
        vm.stopPrank();
        assertEq(nft.inviteCount(address(this)), 2);
        assertEq(nft.inviteCount(bob), 0);

        vm.deal(alice, baseMintPrice);
        vm.startPrank(alice);
        nft.publicMint{value: baseMintPrice}(1, address(this));
        vm.stopPrank();
        assertEq(nft.inviteCount(address(this)), 3);
        assertEq(nft.inviteCount(alice), 0);
    }

    function testInviteCountWithMultipleInvitesAndReserves() public {
        vm.deal(alice, baseMintPrice);
        vm.startPrank(alice);
        nft.publicMint{value: baseMintPrice}(1, address(this));
        vm.stopPrank();
        assertEq(nft.inviteCount(address(this)), 1);
        assertEq(nft.inviteCount(alice), 0);

        vm.deal(bob, baseMintPrice);
        vm.startPrank(bob);
        nft.publicMint{value: baseMintPrice}(1, address(this));
        vm.stopPrank();
        assertEq(nft.inviteCount(address(this)), 2);
        assertEq(nft.inviteCount(bob), 0);

        vm.deal(alice, baseMintPrice);
        vm.startPrank(alice);
        nft.publicMint{value: baseMintPrice}(1, address(this));
        vm.stopPrank();
        assertEq(nft.inviteCount(address(this)), 3);
        assertEq(nft.inviteCount(alice), 0);

        nft.reservedMint(address(this), 1);
        assertEq(nft.inviteCount(address(this)), 3);
        assertEq(nft.inviteCount(alice), 0);
        assertEq(nft.inviteCount(bob), 0);

        nft.adminMint(address(this), 1);
        assertEq(nft.inviteCount(address(this)), 3);
        assertEq(nft.inviteCount(alice), 0);
        assertEq(nft.inviteCount(bob), 0);
    }

    function testTokensOfOwner() public {
        assertEq(nft.tokensOfOwner(address(this)).length, 1);
        assertEq(nft.tokensOfOwner(address(this))[0], 1);

        vm.deal(alice, baseMintPrice);
        vm.prank(alice);
        nft.publicMint{value: baseMintPrice}(1, address(this));
        assertEq(nft.tokensOfOwner(alice).length, 1);
        assertEq(nft.tokensOfOwner(alice)[0], 2);

        vm.deal(alice, baseMintPrice);
        vm.prank(alice);
        nft.publicMint{value: baseMintPrice}(1, address(this));
        assertEq(nft.tokensOfOwner(alice).length, 2);
        assertEq(nft.tokensOfOwner(alice)[0], 2);
        assertEq(nft.tokensOfOwner(alice)[1], 3);

        vm.prank(alice);
        nft.transferFrom(alice, bob, 2);
        assertEq(nft.tokensOfOwner(alice).length, 1);
        assertEq(nft.tokensOfOwner(alice)[0], 3);
        assertEq(nft.tokensOfOwner(bob).length, 1);
        assertEq(nft.tokensOfOwner(bob)[0], 2);
    }

    function testTotalMembers() public {
        assertEq(nft.totalMembers(), 1);

        vm.deal(alice, baseMintPrice);
        vm.startPrank(alice);
        nft.publicMint{value: baseMintPrice}(1, address(this));
        vm.stopPrank();
        assertEq(nft.totalMembers(), 1);

        vm.prank(alice);
        nft.activateMembership(2);
        assertEq(nft.totalMembers(), 2);
    }

    function testActivateMembership() public {
        assertEq(nft.totalMembers(), 1);
        assertEq(nft.hasActiveMembership(address(this)), true);

        vm.deal(alice, baseMintPrice);
        vm.startPrank(alice);
        nft.publicMint{value: baseMintPrice}(1, address(this));
        vm.stopPrank();
        assertEq(nft.totalMembers(), 1);
        assertEq(nft.hasActiveMembership(alice), false);

        vm.prank(alice);
        nft.activateMembership(2);
        assertEq(nft.totalMembers(), 2);
        assertEq(nft.hasActiveMembership(alice), true);
    }

    function testMembershipAlreadyActive() public {
        vm.deal(alice, baseMintPrice);
        vm.startPrank(alice);
        nft.publicMint{value: baseMintPrice}(1, address(this));
        vm.stopPrank();
        assertEq(nft.totalMembers(), 1);
        assertEq(nft.hasActiveMembership(alice), false);

        vm.prank(alice);
        nft.activateMembership(2);
        assertEq(nft.totalMembers(), 2);
        assertEq(nft.hasActiveMembership(alice), true);

        vm.expectRevert(CyberDogeGirlsClub.MembershipAlreadyActive.selector);
        nft.activateMembership(2);
    }

    function testActivateMembershipNotTheOwnerOfTheToken() public {
        vm.deal(alice, baseMintPrice);
        vm.prank(alice);
        nft.publicMint{value: baseMintPrice}(1, address(this));
        assertEq(nft.totalMembers(), 1);
        assertEq(nft.hasActiveMembership(alice), false);

        vm.expectRevert(CyberDogeGirlsClub.NotTheOwnerOfTheToken.selector);
        vm.prank(bob);
        nft.activateMembership(2);
    }

    function testSwitchActiveMembership() public {
        vm.deal(alice, baseMintPrice * 2);
        vm.startPrank(alice);
        nft.publicMint{value: baseMintPrice * 2}(2, address(this));
        nft.activateMembership(2);
        vm.stopPrank();
        assertEq(nft.hasActiveMembership(alice), true);
        assertEq(nft.totalMembers(), 2);
        assertEq(nft.isMembershipActiveForTokenId(2), true);
        assertEq(nft.isMembershipActiveForTokenId(3), false);

        vm.prank(alice);
        nft.switchActiveMembership(3);
        assertEq(nft.totalMembers(), 2);
        assertEq(nft.hasActiveMembership(alice), true);
        assertEq(nft.isMembershipActiveForTokenId(2), false);
        assertEq(nft.isMembershipActiveForTokenId(3), true);
    }

    function testSwitchActiveMembershipNotTheOwnerOfTheToken() public {
        vm.deal(alice, baseMintPrice * 2);
        vm.startPrank(alice);
        nft.publicMint{value: baseMintPrice * 2}(2, address(this));
        nft.activateMembership(2);
        vm.stopPrank();
        assertEq(nft.hasActiveMembership(alice), true);
        assertEq(nft.totalMembers(), 2);
        assertEq(nft.isMembershipActiveForTokenId(2), true);
        assertEq(nft.isMembershipActiveForTokenId(3), false);

        vm.expectRevert(CyberDogeGirlsClub.NotTheOwnerOfTheToken.selector);
        vm.prank(bob);
        nft.switchActiveMembership(3);
    }

    function testSwitchActiveMembershipNotActive() public {
        vm.deal(alice, baseMintPrice * 2);
        vm.startPrank(alice);
        nft.publicMint{value: baseMintPrice * 2}(2, address(this));
        vm.stopPrank();
        assertEq(nft.hasActiveMembership(alice), false);
        assertEq(nft.totalMembers(), 1);
        assertEq(nft.isMembershipActiveForTokenId(2), false);
        assertEq(nft.isMembershipActiveForTokenId(3), false);

        vm.expectRevert(CyberDogeGirlsClub.MembershipNotActive.selector);
        vm.prank(alice);
        nft.switchActiveMembership(3);
    }

    function testCannotTransferActiveMembershipToken() public {
        vm.deal(alice, baseMintPrice * 2);
        vm.startPrank(alice);
        nft.publicMint{value: baseMintPrice * 2}(2, address(this));
        nft.activateMembership(2);
        vm.stopPrank();
        assertEq(nft.hasActiveMembership(alice), true);
        assertEq(nft.totalMembers(), 2);
        assertEq(nft.isMembershipActiveForTokenId(2), true);
        assertEq(nft.isMembershipActiveForTokenId(3), false);

        vm.startPrank(alice);
        vm.expectRevert(CyberDogeGirlsClub.MembershipActiveForTokenId.selector);
        nft.transferFrom(alice, bob, 2);
        vm.expectRevert(CyberDogeGirlsClub.MembershipActiveForTokenId.selector);
        nft.safeTransferFrom(alice, bob, 2);
        nft.switchActiveMembership(3);
        nft.transferFrom(alice, bob, 2);
        vm.stopPrank();

        vm.prank(bob);
        nft.transferFrom(bob, alice, 2);

        vm.startPrank(alice);
        nft.safeTransferFrom(alice, bob, 2);
        vm.expectRevert(CyberDogeGirlsClub.MembershipActiveForTokenId.selector);
        nft.transferFrom(bob, alice, 3);
        vm.expectRevert(CyberDogeGirlsClub.MembershipActiveForTokenId.selector);
        nft.safeTransferFrom(bob, alice, 3);
        vm.stopPrank();
    }

    function testAdminMint() public {
        nft.adminMint(alice, 1);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.totalSupply(), 1 + initialSupply);
        assertEq(nft.unreservedSupply(), 1);
        assertEq(nft.reservedSupply(), 0 + initialSupply);
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
        assertEq(nft.totalSupply(), 1 + initialSupply);
        assertEq(nft.unreservedSupply(), 0);
        assertEq(nft.reservedSupply(), 1 + initialSupply);
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

    function testSetInviterFeeBPS() public {
        nft.setInviterFeeBPS(1000);
        assertEq(nft.inviterFeeBPS(), 1000);
    }

    function testSetInviterFeeBPSUnauthorized() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        nft.setInviterFeeBPS(1000);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    receive() external payable {}
}
