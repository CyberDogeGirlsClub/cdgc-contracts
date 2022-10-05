// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

struct PriceBreakdown {
    bool isEligibleForDiscount;
    uint256 basePrice;
    uint256 discountPercentageBPS;
    uint256 discount;
    uint256 finalPrice;
}

interface PriceOracle {
    function getPriceBreakdown(address buyer)
        external
        view
        returns (PriceBreakdown memory);

    function getBasePrice() external view returns (uint256);
}
