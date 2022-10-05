// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity =0.8.17;

import "./interfaces/PriceOracle.sol";
import "./CDGCPriceOracle.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/// @custom:security-contact gilgames@heroesvale.com
contract CyberDogeGirlsClub is
    ERC721,
    ERC721Enumerable,
    ERC2981,
    Pausable,
    Ownable
{
    using Counters for Counters.Counter;

    uint256 public constant MAX_RESERVED_SUPPLY = 222;
    uint256 public constant MAX_UNRESERVED_SUPPLY = 2000;
    uint256 public constant MAX_SUPPLY =
        MAX_RESERVED_SUPPLY + MAX_UNRESERVED_SUPPLY;
    address public constant TREASURY =
        0xE4484f6438d5C35659B55F6CA3EE727159b8b225;

    PriceOracle public priceOracle;
    uint256 public reservedSupply;
    uint256 public unreservedSupply;
    uint256 public mintStartTimestamp;
    uint256 public totalMembers;
    uint96 public inviterFeeBPS;
    string public baseURI;

    Counters.Counter private _tokenIdCounter;
    mapping(address => uint256) private _invites;
    mapping(address => uint256) private _membershipTokenIds;
    mapping(uint256 => bool) private _activeTokenIds;

    error MaxSupplyReached();
    error MintPriceNotPaid();
    error PriceOracleNotSet();
    error MintingNotStarted();
    error MembershipAlreadyActive();
    error MembershipNotActive();
    error MembershipActiveForTokenId();
    error NotTheOwnerOfTheToken();
    error InviterIsNotAMember();
    error InviterIsTheSender();
    error NonExistentTokenId();
    error RoyaltyTooHigh();
    error TransferFailed(address recipient);
    error InvalidAmount();

    constructor() ERC721("CyberDoge Girls Club", "CDGC") {
        priceOracle = new CDGCPriceOracle();
        inviterFeeBPS = 2500;
        baseURI = "https://cyberdogegirls.club/api/v1/collections/cdgc/metadata/";
        _tokenIdCounter.increment(); // start at 1
        super._setDefaultRoyalty(TREASURY, 500);

        reservedMint(msg.sender, 1);
        activateMembership(1);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _mint(address to) private {
        if (totalSupply() >= MAX_SUPPLY) {
            revert MaxSupplyReached();
        }

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    function adminMint(address to, uint256 amount) public onlyOwner {
        if (unreservedSupply + amount > MAX_UNRESERVED_SUPPLY) {
            revert MaxSupplyReached();
        }

        unreservedSupply += amount;
        for (uint256 i = 0; i < amount; i++) {
            _mint(to);
        }
    }

    function reservedMint(address to, uint256 amount) public onlyOwner {
        if (reservedSupply + amount > MAX_RESERVED_SUPPLY) {
            revert MaxSupplyReached();
        }

        reservedSupply += amount;
        for (uint256 i = 0; i < amount; i++) {
            _mint(to);
        }
    }

    function isMembershipActiveForTokenId(uint256 tokenId)
        public
        view
        returns (bool)
    {
        if (!_exists(tokenId)) {
            revert NonExistentTokenId();
        }

        return _activeTokenIds[tokenId];
    }

    function hasActiveMembership(address account) public view returns (bool) {
        return _membershipTokenIds[account] != 0;
    }

    function activateMembership(uint256 tokenId) public {
        if (hasActiveMembership(msg.sender)) {
            revert MembershipAlreadyActive();
        }

        if (ownerOf(tokenId) != msg.sender) {
            revert NotTheOwnerOfTheToken();
        }

        totalMembers += 1;
        _activeTokenIds[tokenId] = true;
        _membershipTokenIds[msg.sender] = tokenId;
    }

    function switchActiveMembership(uint256 tokenId) public {
        if (ownerOf(tokenId) != msg.sender) {
            revert NotTheOwnerOfTheToken();
        }

        if (!hasActiveMembership(msg.sender)) {
            revert MembershipNotActive();
        }

        uint256 oldTokenId = _membershipTokenIds[msg.sender];
        _activeTokenIds[oldTokenId] = false;
        _activeTokenIds[tokenId] = true;
        _membershipTokenIds[msg.sender] = tokenId;
    }

    function publicMint(uint256 amount, address inviter)
        public
        payable
        whenNotPaused
    {
        if (block.timestamp < mintStartTimestamp) {
            revert MintingNotStarted();
        }

        if (amount == 0) {
            revert InvalidAmount();
        }

        if (address(priceOracle) == address(0)) {
            revert PriceOracleNotSet();
        }

        PriceBreakdown memory priceBreakdown = priceOracle.getPriceBreakdown(
            msg.sender
        );
        uint256 mintPrice = priceBreakdown.finalPrice;
        uint256 mintPriceTotal = mintPrice * amount;
        if (msg.value < mintPrice * amount) {
            revert MintPriceNotPaid();
        }

        if (unreservedSupply + amount > MAX_UNRESERVED_SUPPLY) {
            revert MaxSupplyReached();
        }

        if (inviter == msg.sender) {
            revert InviterIsTheSender();
        }

        if (!hasActiveMembership(inviter)) {
            revert InviterIsNotAMember();
        }

        _invites[inviter] += amount;
        unreservedSupply += amount;
        for (uint256 i = 0; i < amount; i++) {
            _mint(msg.sender);
        }

        uint256 inviterFee = (mintPriceTotal * inviterFeeBPS) / 1e4;
        uint256 treasuryFee = mintPriceTotal - inviterFee;
        uint256 excessPayment = msg.value - mintPriceTotal;

        (bool success, ) = TREASURY.call{value: treasuryFee}("");
        if (!success) {
            revert TransferFailed(TREASURY);
        }

        (success, ) = inviter.call{value: inviterFee}("");
        if (!success) {
            revert TransferFailed(inviter);
        }

        if (excessPayment == 0) {
            return;
        }

        (success, ) = msg.sender.call{value: excessPayment}("");
        if (!success) {
            revert TransferFailed(msg.sender);
        }
    }

    function inviteCount(address account) public view returns (uint256) {
        return _invites[account];
    }

    function setPriceOracle(PriceOracle _priceOracle) public onlyOwner {
        priceOracle = _priceOracle;
    }

    function setMintStartTimestamp(uint256 _mintStartTimestamp)
        public
        onlyOwner
    {
        mintStartTimestamp = _mintStartTimestamp;
    }

    function setInviterFeeBPS(uint96 _inviterFeeBPS) public onlyOwner {
        inviterFeeBPS = _inviterFeeBPS;
    }

    function setBaseURI(string memory baseURI_) public onlyOwner {
        baseURI = baseURI_;
    }

    function setDefaultRoyalty(address recipient, uint96 royaltyBps)
        public
        onlyOwner
    {
        if (royaltyBps > 1000) {
            revert RoyaltyTooHigh();
        }

        super._setDefaultRoyalty(recipient, royaltyBps);
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = TREASURY.call{value: balance}("");
        if (!success) {
            revert TransferFailed(TREASURY);
        }
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        if (isMembershipActiveForTokenId(tokenId)) {
            revert MembershipActiveForTokenId();
        }

        super._transfer(from, to, tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
