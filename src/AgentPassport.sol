// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @notice Minimal interface of the SPACE ID Agent ID registry (ERC-721, non-transferable).
/// @dev Only balanceOf is needed: the registry exposes no owner -> tokenId lookup,
///      and Agent ID cannot transfer, so one claim per holder address == one per Agent ID.
interface IAgentIDRegistry {
    function balanceOf(address owner) external view returns (uint256);
}

/// @title Agent Passport
/// @notice Free commemorative mint for Binance Agent ID holders, built for the
///         Agent ID Hackathon (Nov 18 - Dec 9, 2026). One passport per Agent ID.
/// @notice Claim is free: the caller only pays their own gas. The contract holds
///         no funds, has no owner and no admin functions. Art + metadata are
///         generated fully on-chain (SVG), so the token renders even if the
///         website disappears.
contract AgentPassport is ERC721 {
    using Strings for uint256;
    using Strings for address;

    IAgentIDRegistry public immutable agentID;
    uint256 public constant MAX_SUPPLY = 1000;
    uint256 public totalSupply;

    mapping(address => bool) public claimed;
    mapping(uint256 => address) public claimerOf;
    mapping(uint256 => uint256) public claimedAt;

    event Claimed(address indexed claimer, uint256 indexed tokenId, uint256 timestamp);

    error SoldOut();
    error NotAgentIDHolder();
    error AlreadyClaimed();
    error NonexistentToken();

    constructor(address _agentID) ERC721("Agent Passport", "AGPASS") {
        agentID = IAgentIDRegistry(_agentID);
    }

    /// @notice Mint one passport. Caller must hold an Agent ID at claim time.
    function claim() external {
        if (totalSupply >= MAX_SUPPLY) revert SoldOut();
        if (agentID.balanceOf(msg.sender) == 0) revert NotAgentIDHolder();
        if (claimed[msg.sender]) revert AlreadyClaimed();

        uint256 tokenId = ++totalSupply;
        claimed[msg.sender] = true;
        claimerOf[tokenId] = msg.sender;
        claimedAt[tokenId] = block.timestamp;

        _safeMint(msg.sender, tokenId);
        emit Claimed(msg.sender, tokenId, block.timestamp);
    }

    /// @notice Tier by mint order: #1-10 Genesis, #11-100 Pioneer, rest Agent.
    function tierOf(uint256 tokenId) public pure returns (string memory) {
        if (tokenId <= 10) return "Genesis";
        if (tokenId <= 100) return "Pioneer";
        return "Agent";
    }

    /// @notice Tier accent color (hex, no leading #).
    function tierColorOf(uint256 tokenId) public pure returns (string memory) {
        if (tokenId <= 10) return "FFD166"; // gold
        if (tokenId <= 100) return "22D3EE"; // cyan
        return "A78BFA"; // violet
    }

    /// @notice Tier secondary color (aurora + pill gradient).
    function tierColor2Of(uint256 tokenId) public pure returns (string memory) {
        if (tokenId <= 10) return "FF6B9D"; // pink
        if (tokenId <= 100) return "818CF8"; // indigo
        return "F472B6"; // pink
    }

    /// @notice Fully on-chain metadata: base64 JSON with an inline base64 SVG image.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (_ownerOf(tokenId) == address(0)) revert NonexistentToken();
        string memory image = Base64.encode(bytes(_svg(tokenId)));
        return string(
            abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(_metadata(tokenId, image))))
        );
    }

    function _metadata(uint256 tokenId, string memory image) internal view returns (string memory) {
        return string(
            abi.encodePacked(
                '{"name":"Agent Passport #',
                _pad3(tokenId),
                '","description":"A free commemorative passport minted by an Agent ID holder during the Agent ID Hackathon (Nov 18 - Dec 9, 2026). One passport per Agent ID. No admin, no fees, art and metadata fully on-chain.","image":"data:image/svg+xml;base64,',
                image,
                '","attributes":',
                _attributes(tokenId),
                "}"
            )
        );
    }

    function _attributes(uint256 tokenId) internal view returns (string memory) {
        return string(
            abi.encodePacked(
                '[{"trait_type":"Tier","value":"',
                tierOf(tokenId),
                '"},{"trait_type":"Mint Number","value":',
                tokenId.toString(),
                ',"display_type":"number"},{"trait_type":"Holder","value":"',
                claimerOf[tokenId].toHexString(),
                '"},{"trait_type":"Claimed At","value":',
                claimedAt[tokenId].toString(),
                ',"display_type":"date"}]'
            )
        );
    }

    /// @notice Raw SVG art for a token (also used by tokenURI). 1000x1000.
    function svgOf(uint256 tokenId) external view returns (string memory) {
        if (_ownerOf(tokenId) == address(0)) revert NonexistentToken();
        return _svg(tokenId);
    }

    function _svg(uint256 tokenId) internal view returns (string memory) {
        string memory color = tierColorOf(tokenId);
        string memory color2 = tierColor2Of(tokenId);
        return
            string(abi.encodePacked(_svgTop(color, color2), _svgMid(color, color2), _svgBottom(tokenId, color)));
    }

    function _svgTop(string memory color, string memory color2) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                "<svg xmlns='http://www.w3.org/2000/svg' width='1000' height='1000' viewBox='0 0 1000 1000'>",
                "<defs>",
                "<linearGradient id='bg' x1='0' y1='0' x2='1' y2='1'>",
                "<stop offset='0' stop-color='#070B1A'/><stop offset='1' stop-color='#0E1734'/>",
                "</linearGradient>",
                "<radialGradient id='aur1' cx='0.5' cy='0.5' r='0.5'>",
                "<stop offset='0' stop-color='#",
                color,
                "' stop-opacity='0.55'/><stop offset='1' stop-color='#",
                color,
                "' stop-opacity='0'/>",
                "</radialGradient>",
                "<radialGradient id='aur2' cx='0.5' cy='0.5' r='0.5'>",
                "<stop offset='0' stop-color='#",
                color2,
                "' stop-opacity='0.5'/><stop offset='1' stop-color='#",
                color2,
                "' stop-opacity='0'/>",
                "</radialGradient>",
                "<radialGradient id='aur3' cx='0.5' cy='0.5' r='0.5'>",
                "<stop offset='0' stop-color='#FFFFFF' stop-opacity='0.12'/><stop offset='1' stop-color='#FFFFFF' stop-opacity='0'/>",
                "</radialGradient>",
                "<radialGradient id='core' cx='0.35' cy='0.3' r='0.9'>",
                "<stop offset='0' stop-color='#FFFFFF' stop-opacity='0.95'/><stop offset='0.28' stop-color='#",
                color,
                "'/><stop offset='1' stop-color='#",
                color2,
                "'/>",
                "</radialGradient>",
                "<radialGradient id='coin' cx='0.38' cy='0.32' r='0.85'>",
                "<stop offset='0' stop-color='#2A355E'/><stop offset='0.55' stop-color='#0B1026'/><stop offset='1' stop-color='#04060F'/>",
                "</radialGradient>",
                "<linearGradient id='chrome' x1='0' y1='0' x2='1' y2='1'>",
                "<stop offset='0' stop-color='#FFFFFF'/><stop offset='0.4' stop-color='#",
                color,
                "'/><stop offset='0.7' stop-color='#E8ECF8'/><stop offset='1' stop-color='#",
                color,
                "'/>",
                "</linearGradient>",
                "<linearGradient id='pill' x1='0' y1='0' x2='1' y2='0'>",
                "<stop offset='0' stop-color='#",
                color,
                "'/><stop offset='1' stop-color='#",
                color2,
                "'/>",
                "</linearGradient>",
                "<linearGradient id='holo' x1='0' y1='0' x2='1' y2='0'>",
                "<stop offset='0' stop-color='#",
                color2,
                "'/><stop offset='0.5' stop-color='#FFFFFF'/><stop offset='1' stop-color='#",
                color,
                "'/>",
                "</linearGradient>",
                "<filter id='glowF' x='-40%' y='-40%' width='180%' height='180%'>",
                "<feGaussianBlur stdDeviation='14' result='b'/><feMerge><feMergeNode in='b'/><feMergeNode in='SourceGraphic'/></feMerge>",
                "</filter>",
                "<filter id='cardShadow' x='-20%' y='-20%' width='140%' height='140%'>",
                "<feDropShadow dx='0' dy='30' stdDeviation='30' flood-color='#000000' flood-opacity='0.65'/>",
                "</filter>",
                "<pattern id='dots' width='40' height='40' patternUnits='userSpaceOnUse'>",
                "<circle cx='20' cy='20' r='1.3' fill='#FFFFFF' fill-opacity='0.08'/>",
                "</pattern>",
                "</defs>",
                "<rect width='1000' height='1000' fill='url(#bg)'/>",
                "<ellipse cx='180' cy='140' rx='420' ry='300' fill='url(#aur1)'/>",
                "<ellipse cx='860' cy='900' rx='460' ry='320' fill='url(#aur2)'/>",
                "<ellipse cx='880' cy='120' rx='300' ry='200' fill='url(#aur3)'/>",
                "<g transform='rotate(-24 500 500)'><rect x='-200' y='380' width='1400' height='130' fill='url(#holo)' fill-opacity='0.10'/></g>",
                "<rect width='1000' height='1000' fill='url(#dots)'/>",
                "<rect x='70' y='64' width='860' height='872' rx='36' fill='#FFFFFF' fill-opacity='0.045' stroke='#FFFFFF' stroke-opacity='0.16' stroke-width='1.5' filter='url(#cardShadow)'/>",
                "<path d='M112 100 H888' stroke='#FFFFFF' stroke-opacity='0.22' stroke-width='2' stroke-linecap='round'/>",
                "<rect x='82' y='76' width='836' height='848' rx='28' fill='none' stroke='#",
                color,
                "' stroke-opacity='0.18' stroke-width='1'/>",
                "<path d='M118 146 V110 Q118 102 126 102 H162' fill='none' stroke='#",
                color,
                "' stroke-width='4' stroke-linecap='round'/>",
                "<path d='M882 146 V110 Q882 102 874 102 H838' fill='none' stroke='#",
                color,
                "' stroke-width='4' stroke-linecap='round'/>",
                "<path d='M118 854 V890 Q118 898 126 898 H162' fill='none' stroke='#",
                color,
                "' stroke-width='4' stroke-linecap='round'/>",
                "<path d='M882 854 V890 Q882 898 874 898 H838' fill='none' stroke='#",
                color,
                "' stroke-width='4' stroke-linecap='round'/>",
                "<text x='500' y='146' font-family='monospace' font-size='44' letter-spacing='13' fill='#F2F5FF' text-anchor='middle'>AGENT PASSPORT</text>",
                "<text x='500' y='186' font-family='monospace' font-size='20' letter-spacing='5' fill='#",
                color,
                "' text-anchor='middle'>",
                unicode"AGENT ID HACKATHON • 2026</text>"
            )
        );
    }

    function _svgMid(string memory color, string memory color2) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                "<circle cx='500' cy='364' r='150' fill='none' stroke='#",
                color,
                "' stroke-opacity='0.45' stroke-width='2' stroke-dasharray='2 10' stroke-linecap='round'/>",
                "<circle cx='641' cy='415' r='7' fill='#",
                color2,
                "'/>",
                "<circle cx='385' cy='460' r='5' fill='#FFFFFF'/>",
                "<circle cx='474' cy='216' r='6' fill='#",
                color,
                "'/>",
                "<circle cx='500' cy='364' r='118' fill='none' stroke='url(#pill)' stroke-opacity='0.85' stroke-width='3'/>",
                "<circle cx='500' cy='364' r='92' fill='url(#core)' fill-opacity='0.55' filter='url(#glowF)'/>",
                "<circle cx='500' cy='372' r='86' fill='#02040A' fill-opacity='0.7'/>",
                "<circle cx='500' cy='378' r='86' fill='#000000' fill-opacity='0.55'/>",
                "<circle cx='500' cy='364' r='86' fill='url(#coin)'/>",
                "<ellipse cx='458' cy='320' rx='58' ry='32' fill='#FFFFFF' fill-opacity='0.35' transform='rotate(-28 458 320)'/>",
                "<circle cx='500' cy='364' r='79' fill='none' stroke='#FFFFFF' stroke-opacity='0.25' stroke-width='1.5'/>",
                _binanceCoinMark()
            )
        );
    }

    function _svgBottom(uint256 tokenId, string memory color) internal view returns (string memory) {
        return string(
            abi.encodePacked(
                "<text x='500' y='645' font-family='monospace' font-size='160' font-weight='bold' fill='#",
                color,
                "' fill-opacity='0.5' filter='url(#glowF)' text-anchor='middle'>#",
                _pad3(tokenId),
                "</text>",
                "<text x='508' y='652' font-family='monospace' font-size='160' font-weight='bold' fill='#05070F' fill-opacity='0.45' text-anchor='middle'>#",
                _pad3(tokenId),
                "</text>",
                "<text x='514' y='660' font-family='monospace' font-size='160' font-weight='bold' fill='#05070F' fill-opacity='0.65' text-anchor='middle'>#",
                _pad3(tokenId),
                "</text>",
                "<text x='500' y='645' font-family='monospace' font-size='160' font-weight='bold' fill='url(#chrome)' text-anchor='middle'>#",
                _pad3(tokenId),
                "</text>",
                "<rect x='350' y='678' width='300' height='60' rx='30' fill='#000000' fill-opacity='0.45'/>",
                "<rect x='350' y='672' width='300' height='60' rx='30' fill='url(#pill)'/>",
                "<rect x='366' y='677' width='268' height='7' rx='3.5' fill='#FFFFFF' fill-opacity='0.35'/>",
                "<text x='500' y='711' font-family='monospace' font-size='28' font-weight='bold' letter-spacing='4' fill='#0A0F22' text-anchor='middle'>",
                tierOf(tokenId),
                "</text>",
                _identicon(claimerOf[tokenId], color),
                "<text x='500' y='834' font-family='monospace' font-size='19' letter-spacing='5' fill='#9AA3C0' text-anchor='middle'>HOLDER</text>",
                "<text x='500' y='876' font-family='monospace' font-size='32' fill='#E8ECF8' text-anchor='middle'>",
                _shortAddress(claimerOf[tokenId]),
                "</text>",
                "<text x='500' y='922' font-family='monospace' font-size='19' letter-spacing='3' fill='#",
                color,
                "' text-anchor='middle'>", unicode"◆ VERIFIED AGENT ID HOLDER ◆</text>",
                "</svg>"
            )
        );
    }

    /// @notice Binance diamond mark on the medallion coin (~116px, yellow on dark coin).
    /// @dev 5 polygons in Binance yellow #F0B90B over a dark-gold offset copy for depth,
    ///      plus a white top-facet highlight. It is a badge for the hackathon organizer,
    ///      not the project brand: the project name stays "Agent Passport" and no
    ///      Binance/BNB name is used in any name or domain.
    function _binanceCoinMark() internal pure returns (string memory) {
        return
            "<g fill='#7A5C00' fill-opacity='0.85'><polygon points='503,310 529,336 503,362 477,336'/><polygon points='535,342 561,368 535,394 509,368'/><polygon points='503,374 529,400 503,426 477,400'/><polygon points='471,342 497,368 471,394 445,368'/><polygon points='503,356 515,368 503,380 491,368'/></g><g fill='#F0B90B'><polygon points='500,306 526,332 500,358 474,332'/><polygon points='532,338 558,364 532,390 506,364'/><polygon points='500,370 526,396 500,422 474,396'/><polygon points='468,338 494,364 468,390 442,364'/><polygon points='500,352 512,364 500,376 488,364'/></g><polygon points='500,306 526,332 500,358 474,332' fill='#FFFFFF' fill-opacity='0.25'/>";
    }

    /// @notice Deterministic 8-block identicon from the holder address (unique per holder).
    function _identicon(address a, string memory color) internal pure returns (string memory) {
        uint160 v = uint160(a);
        string memory s = "";
        for (uint256 i = 0; i < 8; i++) {
            uint256 b = uint256(uint8(v >> (i * 8)));
            uint256 op = 35 + (b % 4) * 15; // 35..80
            string memory fill = (b % 2 == 0) ? color : "FFFFFF";
            s = string(
                abi.encodePacked(
                    s,
                    "<rect x='",
                    (338 + i * 42).toString(),
                    "' y='768' width='30' height='30' rx='7' fill='#",
                    fill,
                    "' fill-opacity='0.",
                    op.toString(),
                    "'/>"
                )
            );
        }
        return s;
    }

    /// @notice 1 -> "001", 42 -> "042", 1000 -> "1000".
    function _pad3(uint256 n) internal pure returns (string memory) {
        if (n < 10) return string(abi.encodePacked("00", n.toString()));
        if (n < 100) return string(abi.encodePacked("0", n.toString()));
        return n.toString();
    }

    /// @notice 0x3fF786... -> "0x3fF7...C85" (first 6 + last 4 chars).
    function _shortAddress(address a) internal pure returns (string memory) {
        bytes memory full = bytes(a.toHexString()); // "0x" + 40 hex chars
        bytes memory out = new bytes(13);
        for (uint256 i = 0; i < 6; i++) out[i] = full[i];
        out[6] = 0xe2;
        out[7] = 0x80;
        out[8] = 0xa6; // UTF-8 ellipsis
        for (uint256 i = 0; i < 4; i++) out[9 + i] = full[38 + i];
        return string(out);
    }
}
