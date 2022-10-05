// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../src/CyberDogeGirlsClub.sol";
import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Deploy is Test {
    using Strings for uint256;

    function setUp() public view {
        console.log(
            "Running script on chain with ID:",
            block.chainid.toString()
        );
    }

    function run() external {
        vm.broadcast();
        new CyberDogeGirlsClub();
    }
}
