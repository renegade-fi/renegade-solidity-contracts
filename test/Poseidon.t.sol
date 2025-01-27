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
    uint256 TEST_RC1 = 0x1337;
    /// @dev The second round constant used in testing
    uint256 TEST_RC2 = 0x1338;
    /// @dev The third round constant used in testing
    uint256 TEST_RC3 = 0x1339;

    /// @dev Deploy the PoseidonSuite contract
    function setUp() public {
        poseidonSuite = PoseidonSuite(HuffDeployer.deploy("../test/huff/testPoseidonUtils"));
    }

    /// @dev Test the sbox function applied to a single input
    function testSboxSingle() public {
        uint256 testValue = randomFelt();
        uint256 result = poseidonSuite.testSboxSingle(testValue);

        // Calculate expected x^5 mod p
        uint256 expected = fifthPower(testValue);
        assertEq(result, expected, "Expected result to match x^5 mod p");
    }

    /// @dev Test the add round constant function applied to a single input
    function testAddRcSingle() public {
        uint256 testValue = randomFelt();
        uint256 result = poseidonSuite.testAddRc(testValue);
        uint256 expected = addmod(testValue, TEST_RC1, PRIME);
        assertEq(result, expected, "Expected result to match x + RC mod p");
    }

    /// @dev Test the internal MDS function applied to a single input
    /// The internal MDS adds the sum of the elements to each element
    function testInternalMds() public {
        uint256 a = randomFelt();
        uint256 b = randomFelt();
        uint256 c = randomFelt();
        (uint256 a1, uint256 b1, uint256 c1) = poseidonSuite.testInternalMds(a, b, c);

        // Calculate the expected results
        (uint256 expectedA, uint256 expectedB, uint256 expectedC) = internalMds(a, b, c);
        assertEq(a1, expectedA, "Expected result to match a + sum mod p");
        assertEq(b1, expectedB, "Expected result to match b + sum mod p");
        assertEq(c1, expectedC, "Expected result to match c + sum mod p");
    }

    /// @dev Test the external MDS function applied to a trio of inputs
    function testExternalMds() public {
        uint256 a = randomFelt();
        uint256 b = randomFelt();
        uint256 c = randomFelt();
        (uint256 a1, uint256 b1, uint256 c1) = poseidonSuite.testExternalMds(a, b, c);

        // Calculate the expected results
        (uint256 expectedA, uint256 expectedB, uint256 expectedC) = externalMds(a, b, c);
        assertEq(a1, expectedA, "Expected result to match a");
        assertEq(b1, expectedB, "Expected result to match b");
        assertEq(c1, expectedC, "Expected result to match c");
    }

    /// @dev Test the external round function applied to a trio of inputs
    function testExternalRound() public {
        uint256 a = randomFelt();
        uint256 b = randomFelt();
        uint256 c = randomFelt();
        (uint256 a1, uint256 b1, uint256 c1) = poseidonSuite.testExternalRound(a, b, c);
        (uint256 expectedA, uint256 expectedB, uint256 expectedC) = externalRound(a, b, c);
        assertEq(a1, expectedA, "Expected result to match a");
        assertEq(b1, expectedB, "Expected result to match b");
        assertEq(c1, expectedC, "Expected result to match c");
    }

    /// @dev Test the internal round function applied to a trio of inputs
    function testInternalRound() public {
        uint256 a = randomFelt();
        uint256 b = randomFelt();
        uint256 c = randomFelt();
        (uint256 a1, uint256 b1, uint256 c1) = poseidonSuite.testInternalRound(a, b, c);
        (uint256 expectedA, uint256 expectedB, uint256 expectedC) = internalRound(a, b, c);
        assertEq(a1, expectedA, "Expected result to match a");
        assertEq(b1, expectedB, "Expected result to match b");
        assertEq(c1, expectedC, "Expected result to match c");
    }

    /// @dev Test the full hash function applied to two inputs
    function testFullHash() public {
        uint256 a = randomFelt();
        uint256 b = randomFelt();

        uint256 result = poseidonSuite.testFullHash(a, b);
        uint256 expected = runReferenceImpl(a, b);
        assertEq(result, expected, "Hash result does not match reference implementation");
    }

    /// @dev Helper to run the reference implementation
    function runReferenceImpl(uint256 a, uint256 b) internal returns (uint256) {
        // First compile the binary
        string[] memory compileInputs = new string[](5);
        compileInputs[0] = "cargo";
        compileInputs[1] = "build";
        compileInputs[2] = "--quiet";
        compileInputs[3] = "--manifest-path";
        compileInputs[4] = "test/poseidon-reference-implementation/Cargo.toml";
        vm.ffi(compileInputs);

        // Now run the binary directly from target/debug
        string[] memory runInputs = new string[](3);
        runInputs[0] = "./test/poseidon-reference-implementation/target/debug/poseidon-reference-implementation";
        runInputs[1] = vm.toString(a);
        runInputs[2] = vm.toString(b);

        bytes memory res = vm.ffi(runInputs);
        string memory str = string(res);

        // Strip the "RES:" prefix and parse
        // We prefix here to avoid the FFI interface interpreting the output as either raw bytes or a string
        // This forces the output to be a string
        require(
            bytes(str).length > 4 && bytes(str)[0] == "R" && bytes(str)[1] == "E" && bytes(str)[2] == "S"
                && bytes(str)[3] == ":",
            "Invalid output format"
        );

        // Extract everything after "RES:"
        bytes memory hexBytes = new bytes(bytes(str).length - 4);
        for (uint256 i = 4; i < bytes(str).length; i++) {
            hexBytes[i - 4] = bytes(str)[i];
        }
        return vm.parseUint(string(hexBytes));
    }

    /// --- Helpers --- ///

    /// @dev Generates a random input modulo the PRIME
    /// Note that this is not uniformly distributed over the prime field, because of the "wraparound"
    /// but it suffices for fuzzing test inputs
    function randomFelt() internal returns (uint256) {
        return vm.randomUint() % PRIME;
    }

    /// @dev Calculate the fifth power of an input
    function fifthPower(uint256 x) internal view returns (uint256) {
        uint256 x2 = mulmod(x, x, PRIME);
        uint256 x4 = mulmod(x2, x2, PRIME);
        return mulmod(x, x4, PRIME);
    }

    /// @dev Calculate the result of the internal MDS matrix applied to the inputs
    function internalMds(uint256 a, uint256 b, uint256 c) internal view returns (uint256, uint256, uint256) {
        uint256 sum = sumInputs(a, b, c);
        uint256 a1 = addmod(a, sum, PRIME);
        uint256 b1 = addmod(b, sum, PRIME);
        uint256 c1 = addmod(addmod(c, sum, PRIME), c, PRIME); // c is doubled
        return (a1, b1, c1);
    }

    /// @dev Calculate the result of the external MDS matrix applied to the inputs
    function externalMds(uint256 a, uint256 b, uint256 c) internal view returns (uint256, uint256, uint256) {
        uint256 sum = sumInputs(a, b, c);
        uint256 a1 = addmod(a, sum, PRIME);
        uint256 b1 = addmod(b, sum, PRIME);
        uint256 c1 = addmod(c, sum, PRIME);
        return (a1, b1, c1);
    }

    /// @dev Calculate the result of the external round function applied to the inputs
    function externalRound(uint256 a, uint256 b, uint256 c) internal view returns (uint256, uint256, uint256) {
        uint256 a1 = addmod(a, TEST_RC1, PRIME);
        uint256 b1 = addmod(b, TEST_RC2, PRIME);
        uint256 c1 = addmod(c, TEST_RC3, PRIME);
        uint256 a2 = fifthPower(a1);
        uint256 b2 = fifthPower(b1);
        uint256 c2 = fifthPower(c1);
        return externalMds(a2, b2, c2);
    }

    /// @dev Calculate the result of the internal round function applied to the inputs
    function internalRound(uint256 a, uint256 b, uint256 c) internal view returns (uint256, uint256, uint256) {
        uint256 a1 = addmod(a, TEST_RC1, PRIME);
        uint256 a2 = fifthPower(a1);
        return internalMds(a2, b, c);
    }

    /// @dev Sum the inputs and return the result
    function sumInputs(uint256 a, uint256 b, uint256 c) internal view returns (uint256) {
        uint256 sum = addmod(a, b, PRIME);
        sum = addmod(sum, c, PRIME);
        return sum;
    }
}

interface PoseidonSuite {
    function testSboxSingle(uint256) external returns (uint256);
    function testAddRc(uint256) external returns (uint256);
    function testInternalMds(uint256, uint256, uint256) external returns (uint256, uint256, uint256);
    function testExternalMds(uint256, uint256, uint256) external returns (uint256, uint256, uint256);
    function testExternalRound(uint256, uint256, uint256) external returns (uint256, uint256, uint256);
    function testInternalRound(uint256, uint256, uint256) external returns (uint256, uint256, uint256);
    function testFullHash(uint256, uint256) external returns (uint256);
}
