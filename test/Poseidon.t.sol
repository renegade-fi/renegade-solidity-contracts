// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {HuffDeployer} from "foundry-huff/HuffDeployer.sol";

contract PoseidonTest is Test {
    /// @dev The Poseidon main contract
    PoseidonSuite public poseidonSuite;

    /// @dev The BN254 field modulus from roundUtils.huff
    uint256 PRIME = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001;
    /// @dev The round constant used in testing
    uint256 TEST_RC = 0x1337;

    /// @dev Deploy the PoseidonSuite contract
    function setUp() public {
        poseidonSuite = PoseidonSuite(HuffDeployer.deploy("../test/huff/testPoseidonUtils"));
    }

    /// @dev Test the sbox function applied to a single input
    function testSboxSingle() public {
        uint256 testValue = vm.randomUint();
        uint256 result = poseidonSuite.testSboxSingle(testValue);

        // Calculate expected x^5 mod p
        uint256 x2 = mulmod(testValue, testValue, PRIME);
        uint256 x4 = mulmod(x2, x2, PRIME);
        uint256 expected = mulmod(testValue, x4, PRIME);
        assertEq(result, expected, "Expected result to match x^5 mod p");
    }

    /// @dev Test the add round constant function applied to a single input
    function testAddRcSingle() public {
        uint256 testValue = vm.randomUint();
        uint256 result = poseidonSuite.testAddRc(testValue);
        uint256 expected = addmod(testValue, TEST_RC, PRIME);
        assertEq(result, expected, "Expected result to match x + RC mod p");
    }

    /// @dev Test the internal MDS function applied to a single input
    /// The internal MDS adds the sum of the elements to each element
    function testInternalMds() public {
        uint256 a = vm.randomUint();
        uint256 b = vm.randomUint();
        uint256 c = vm.randomUint();
        (uint256 a1, uint256 b1, uint256 c1) = poseidonSuite.testInternalMds(a, b, c);

        // Calculate the sum of the elements
        uint256 sum = addmod(a, b, PRIME);
        sum = addmod(sum, c, PRIME);

        // Calculate the expected results
        uint256 expectedA = addmod(a, sum, PRIME);
        uint256 expectedB = addmod(b, sum, PRIME);
        uint256 expectedC = addmod(c, sum, PRIME);
        assertEq(a1, expectedA, "Expected result to match a + sum mod p");
        assertEq(b1, expectedB, "Expected result to match b + sum mod p");
        assertEq(c1, expectedC, "Expected result to match c + sum mod p");
    }
}

interface PoseidonSuite {
    function testSboxSingle(uint256) external returns (uint256);
    function testAddRc(uint256) external returns (uint256);
    function testInternalMds(uint256, uint256, uint256) external returns (uint256, uint256, uint256);
}
