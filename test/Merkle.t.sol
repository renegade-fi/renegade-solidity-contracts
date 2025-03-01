// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { HuffDeployer } from "foundry-huff/HuffDeployer.sol";
import { TestUtils } from "./utils/TestUtils.sol";
import { console2 } from "forge-std/console2.sol";
import { IHasher } from "../src/libraries/poseidon2/IHasher.sol";

contract MerkleTest is TestUtils {
    /// @dev The Merkle depth
    uint256 constant MERKLE_DEPTH = 32;

    /// @dev The MerklePoseidon contract
    IHasher public hasher;

    /// @dev Deploy the MerklePoseidon contract
    function setUp() public {
        hasher = IHasher(HuffDeployer.deploy("libraries/poseidon2/poseidonHasher"));
    }

    /// @dev Test the hashMerkle function with sequential inserts
    function testHashMerkle() public {
        uint256 input = randomFelt();
        uint256 idx = randomIdx();
        uint256[] memory sisterLeaves = new uint256[](MERKLE_DEPTH);
        for (uint256 i = 0; i < MERKLE_DEPTH; i++) {
            sisterLeaves[i] = randomFelt();
        }
        uint256[] memory results = hasher.merkleHash(idx, input, sisterLeaves);
        uint256[] memory expected = runMerkleReferenceImpl(idx, input, sisterLeaves);
        assertEq(results.length, MERKLE_DEPTH, "Expected 32 results");

        for (uint256 i = 0; i < MERKLE_DEPTH; i++) {
            assertEq(results[i], expected[i], string(abi.encodePacked("Result mismatch at index ", vm.toString(i))));
        }
    }

    /// @dev Test the spongeHash function
    function testSpongeHash() public {
        uint256 n = randomUint(1, 10);
        uint256[] memory inputs = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            inputs[i] = randomFelt();
        }

        uint256 expected = runSpongeHashReferenceImpl(inputs);
        uint256 result = hasher.spongeHash(inputs);
        assertEq(result, expected, "Sponge hash result does not match reference implementation");
    }

    // --- Helpers --- //

    /// @dev Generate a random index in the Merkle tree
    function randomIdx() internal returns (uint256) {
        return vm.randomUint() % (2 ** MERKLE_DEPTH);
    }

    /// @dev Helper to run the sponge hash reference implementation
    function runSpongeHashReferenceImpl(uint256[] memory inputs) internal returns (uint256) {
        // First compile the binary
        compileRustBinary("test/rust-reference-impls/merkle/Cargo.toml");

        // Prepare arguments for the binary
        string[] memory args = new string[](inputs.length + 2);
        args[0] = "./test/rust-reference-impls/target/debug/merkle";
        args[1] = "sponge-hash";

        // Pass inputs as space-separated arguments
        for (uint256 i = 0; i < inputs.length; i++) {
            args[i + 2] = vm.toString(inputs[i]);
        }

        // Run binary and parse space-separated array output
        return vm.parseUint(runBinaryGetResponse(args));
    }

    /// @dev Helper to run the reference implementation
    function runMerkleReferenceImpl(
        uint256 idx,
        uint256 input,
        uint256[] memory sisterLeaves
    )
        internal
        returns (uint256[] memory)
    {
        // First compile the binary
        compileRustBinary("test/rust-reference-impls/merkle/Cargo.toml");

        // Prepare arguments for the binary
        string[] memory args = new string[](36); // program name + idx + input + 32 sister leaves
        args[0] = "./test/rust-reference-impls/target/debug/merkle";
        args[1] = "merkle-hash";
        args[2] = vm.toString(idx);
        args[3] = vm.toString(input);

        // Pass sister leaves as individual arguments
        for (uint256 i = 0; i < MERKLE_DEPTH; i++) {
            args[i + 4] = vm.toString(sisterLeaves[i]);
        }

        // Run binary and parse space-separated array output
        uint256[] memory result = runBinaryGetArray(args, " ");
        require(result.length == MERKLE_DEPTH, "Expected 32 values");
        return result;
    }
}
