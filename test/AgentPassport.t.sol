// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AgentPassport} from "../src/AgentPassport.sol";

contract MockAgentID {
    mapping(address => uint256) public balances;

    function setBalance(address a, uint256 b) external {
        balances[a] = b;
    }

    function balanceOf(address a) external view returns (uint256) {
        return balances[a];
    }
}

contract AgentPassportTest is Test {
    AgentPassport public passport;
    MockAgentID public registry;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        registry = new MockAgentID();
        passport = new AgentPassport(address(registry));
        registry.setBalance(alice, 1);
        registry.setBalance(bob, 1);
    }

    function testClaimSuccess() public {
        vm.prank(alice);
        passport.claim();
        assertEq(passport.ownerOf(1), alice);
        assertEq(passport.totalSupply(), 1);
        assertTrue(passport.claimed(alice));
        assertEq(passport.claimerOf(1), alice);
        assertEq(passport.claimedAt(1), block.timestamp);
        assertEq(passport.tierOf(1), "Genesis");
    }

    function testClaimRevertsWithoutAgentID() public {
        address stranger = makeAddr("stranger");
        vm.prank(stranger);
        vm.expectRevert(AgentPassport.NotAgentIDHolder.selector);
        passport.claim();
    }

    function testClaimRevertsTwice() public {
        vm.prank(alice);
        passport.claim();
        vm.prank(alice);
        vm.expectRevert(AgentPassport.AlreadyClaimed.selector);
        passport.claim();
    }

    function testSecondClaimerGetsTokenTwo() public {
        vm.prank(alice);
        passport.claim();
        vm.prank(bob);
        passport.claim();
        assertEq(passport.ownerOf(2), bob);
        assertEq(passport.totalSupply(), 2);
    }

    function testSoldOut() public {
        // Per `forge inspect storage-layout`: OZ ERC721 occupies slots 0-5,
        // so this contract's totalSupply sits at slot 6.
        vm.store(address(passport), bytes32(uint256(6)), bytes32(uint256(999)));
        assertEq(passport.totalSupply(), 999);
        vm.prank(alice);
        passport.claim(); // #1000 ok
        assertEq(passport.totalSupply(), 1000);
        vm.prank(bob);
        vm.expectRevert(AgentPassport.SoldOut.selector);
        passport.claim();
    }

    function testTierBoundaries() public {
        assertEq(passport.tierOf(1), "Genesis");
        assertEq(passport.tierOf(10), "Genesis");
        assertEq(passport.tierOf(11), "Pioneer");
        assertEq(passport.tierOf(100), "Pioneer");
        assertEq(passport.tierOf(101), "Agent");
        assertEq(passport.tierOf(1000), "Agent");
        assertEq(passport.tierColorOf(1), "FFD166");
        assertEq(passport.tierColorOf(50), "22D3EE");
        assertEq(passport.tierColorOf(500), "A78BFA");
    }

    function testTokenURIFormat() public {
        vm.prank(alice);
        passport.claim();
        string memory uri = passport.tokenURI(1);
        assertTrue(_startsWith(uri, "data:application/json;base64,"));
        string memory svg = passport.svgOf(1);
        assertTrue(_contains(svg, "AGENT PASSPORT"));
        assertTrue(_contains(svg, "Genesis"));
        assertTrue(_contains(svg, "#001"));
        assertTrue(_contains(svg, "VERIFIED AGENT ID HOLDER"));
        // short address of alice is embedded
        assertTrue(_contains(svg, "0x"));
    }

    function testTokenURIRevertsForMissing() public {
        vm.expectRevert(AgentPassport.NonexistentToken.selector);
        passport.tokenURI(1);
    }

    function testClaimEmitsEvent() public {
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit AgentPassport.Claimed(alice, 1, block.timestamp);
        passport.claim();
    }

    /// @notice Writes SVG + tokenURI previews for visual review (not an assertion test).
    function testWritePreviews() public {
        for (uint256 i = 1; i <= 101; i++) {
            address claimer = vm.addr(i);
            registry.setBalance(claimer, 1);
            vm.prank(claimer);
            passport.claim();
        }
        vm.writeFile("preview/token-1.svg", passport.svgOf(1));
        vm.writeFile("preview/token-11.svg", passport.svgOf(11));
        vm.writeFile("preview/token-101.svg", passport.svgOf(101));
        vm.writeFile("preview/token-1-uri.txt", passport.tokenURI(1));
    }

    function _startsWith(string memory hay, string memory needle) internal pure returns (bool) {
        bytes memory h = bytes(hay);
        bytes memory n = bytes(needle);
        if (n.length > h.length) return false;
        for (uint256 i = 0; i < n.length; i++) {
            if (h[i] != n[i]) return false;
        }
        return true;
    }

    function _contains(string memory hay, string memory needle) internal pure returns (bool) {
        bytes memory h = bytes(hay);
        bytes memory n = bytes(needle);
        if (n.length > h.length) return false;
        for (uint256 i = 0; i <= h.length - n.length; i++) {
            bool ok = true;
            for (uint256 j = 0; j < n.length; j++) {
                if (h[i + j] != n[j]) {
                    ok = false;
                    break;
                }
            }
            if (ok) return true;
        }
        return false;
    }
}
