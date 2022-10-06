// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity =0.8.17;

import "./interfaces/PriceOracle.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CDGCPriceOracle is PriceOracle, Ownable {
    IERC721[] public nftCollectionsEligibleForDiscount;
    uint16[] public discountPercentageBPS;

    uint256 private _basePrice;

    error CollectionAlreadyEligible();
    error CollectionNotEligible();

    event BasePriceChanged(uint256 previousBasePrice, uint256 newBasePrice);
    event DiscountPercentageBPSChanged(
        uint16[] previousDiscountPercentageBPS,
        uint16[] newDiscountPercentageBPS
    );
    event EligibleNFTCollectionAdded(IERC721 nftCollection);
    event EligibleNFTCollectionRemoved(IERC721 nftCollection);

    constructor() {
        _basePrice = 99 ether;

        discountPercentageBPS = new uint16[](11);
        discountPercentageBPS[0] = 0;
        discountPercentageBPS[1] = 500;
        discountPercentageBPS[2] = 500;
        discountPercentageBPS[3] = 500;
        discountPercentageBPS[4] = 500;
        discountPercentageBPS[5] = 1000;
        discountPercentageBPS[6] = 1000;
        discountPercentageBPS[7] = 1000;
        discountPercentageBPS[8] = 1000;
        discountPercentageBPS[9] = 1000;
        discountPercentageBPS[10] = 1500;
    }

    function countNFTs(address buyer) public view returns (uint256) {
        if (buyer == address(0)) {
            return 0;
        }

        uint256 totalBalance = 0;
        for (uint256 i = 0; i < nftCollectionsEligibleForDiscount.length; i++) {
            totalBalance += nftCollectionsEligibleForDiscount[i].balanceOf(
                buyer
            );
        }

        return totalBalance;
    }

    function isEligibleForDiscount(address buyer) public view returns (bool) {
        for (uint256 i = 0; i < nftCollectionsEligibleForDiscount.length; i++) {
            if (nftCollectionsEligibleForDiscount[i].balanceOf(buyer) > 0) {
                return true;
            }
        }

        return false;
    }

    function getPriceBreakdown(address _buyer)
        public
        view
        returns (PriceBreakdown memory priceBreakdown)
    {
        uint256 nftCount = countNFTs(_buyer);
        priceBreakdown.isEligibleForDiscount = isEligibleForDiscount(_buyer);
        priceBreakdown.basePrice = _basePrice;
        priceBreakdown.discountPercentageBPS = getDiscountPercentageBPS(
            nftCount
        );
        priceBreakdown.discount =
            (_basePrice * priceBreakdown.discountPercentageBPS) /
            10000;
        priceBreakdown.finalPrice = getFinalPrice(nftCount);
    }

    function getDiscountPercentageBPS(uint256 nftCount)
        private
        view
        returns (uint256)
    {
        if (nftCount > discountPercentageBPS.length - 1) {
            nftCount = discountPercentageBPS.length - 1;
        }

        return discountPercentageBPS[nftCount];
    }

    function getFinalPrice(uint256 nftCount) private view returns (uint256) {
        uint256 discountPercentage = getDiscountPercentageBPS(nftCount);
        uint256 discount = (_basePrice * discountPercentage) / 10000;
        return _basePrice - discount;
    }

    function addEligibleCollection(IERC721 collection) public onlyOwner {
        for (uint256 i = 0; i < nftCollectionsEligibleForDiscount.length; i++) {
            if (nftCollectionsEligibleForDiscount[i] == collection) {
                revert CollectionAlreadyEligible();
            }
        }

        nftCollectionsEligibleForDiscount.push(collection);
        emit EligibleNFTCollectionAdded(collection);
    }

    function removeEligibleCollection(IERC721 collection) public onlyOwner {
        for (uint256 i = 0; i < nftCollectionsEligibleForDiscount.length; i++) {
            if (nftCollectionsEligibleForDiscount[i] == collection) {
                nftCollectionsEligibleForDiscount[
                    i
                ] = nftCollectionsEligibleForDiscount[
                    nftCollectionsEligibleForDiscount.length - 1
                ];
                nftCollectionsEligibleForDiscount.pop();
                emit EligibleNFTCollectionRemoved(collection);
                return;
            }
        }

        revert CollectionNotEligible();
    }

    function getEligibleCollections() public view returns (IERC721[] memory) {
        return nftCollectionsEligibleForDiscount;
    }

    function setBasePrice(uint256 basePrice_) public onlyOwner {
        uint256 previousBasePrice = _basePrice;
        _basePrice = basePrice_;
        emit BasePriceChanged(previousBasePrice, _basePrice);
    }

    function getBasePrice() public view override returns (uint256) {
        return _basePrice;
    }

    function setDiscountPercentageBPS(uint16[] memory _discountBasePoints)
        public
        onlyOwner
    {
        uint16[] memory previousDiscountPercentageBPS = discountPercentageBPS;
        discountPercentageBPS = _discountBasePoints;
        emit DiscountPercentageBPSChanged(
            previousDiscountPercentageBPS,
            discountPercentageBPS
        );
    }

    function getDiscountPercentageBPS() public view returns (uint16[] memory) {
        return discountPercentageBPS;
    }
}
