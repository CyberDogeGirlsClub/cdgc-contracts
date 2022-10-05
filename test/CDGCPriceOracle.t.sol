// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../src/CDGCPriceOracle.sol";
import "forge-std/Test.sol";
import "@openzeppelin/contracts/mocks/ERC721Mock.sol";

contract CDGCPriceOracleTest is Test {
    CDGCPriceOracle priceOracle;
    ERC721Mock nft;
    address alice;

    function setUp() public {
        alice = address(1);

        vm.label(alice, "alice");
        vm.label(address(this), "deployer");

        priceOracle = new CDGCPriceOracle();
        nft = new ERC721Mock("CyberDogeGirlsClub", "CDGC");
    }

    function testSetBasePrice() public {
        priceOracle.setBasePrice(1 ether);
        assertEq(priceOracle.getBasePrice(), 1 ether);
    }

    function testSetMintPriceUnauthorized() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        priceOracle.setBasePrice(1 ether);
    }

    function testGetPriceBreakdown() public {
        PriceBreakdown memory priceBreakdown = priceOracle.getPriceBreakdown(
            alice
        );
        assertEq(priceBreakdown.basePrice, 99 ether);
        assertEq(priceBreakdown.discountPercentageBPS, 0);
        assertEq(priceBreakdown.discount, 0);
        assertEq(priceBreakdown.finalPrice, 99 ether);

        nft.mint(alice, 1);
        priceBreakdown = priceOracle.getPriceBreakdown(alice);
        assertEq(priceBreakdown.basePrice, 99 ether);
        assertEq(priceBreakdown.discountPercentageBPS, 0);
        assertEq(priceBreakdown.discount, 0);
        assertEq(priceBreakdown.finalPrice, 99 ether);

        priceOracle.addEligibleCollection(nft);
        priceBreakdown = priceOracle.getPriceBreakdown(alice);
        assertEq(priceBreakdown.basePrice, 99 ether);
        assertEq(priceBreakdown.discountPercentageBPS, 500);
        assertEq(priceBreakdown.discount, 4.95 ether);
        assertEq(priceBreakdown.finalPrice, 94.05 ether);

        for (uint256 i = 2; i <= 11; i++) {
            nft.mint(alice, i);
        }
        priceBreakdown = priceOracle.getPriceBreakdown(alice);
        assertEq(priceBreakdown.basePrice, 99 ether);
        assertEq(priceBreakdown.discountPercentageBPS, 1500);
        assertEq(priceBreakdown.discount, 14.85 ether);
        assertEq(priceBreakdown.finalPrice, 84.15 ether);
    }
}
