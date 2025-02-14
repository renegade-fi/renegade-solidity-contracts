// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import { BN254 } from "solidity-bn254/BN254.sol";

import { TestUtils } from "./utils/TestUtils.sol";
import { Verifier } from "../src/verifier/Verifier.sol";
import { PlonkProof, NUM_WIRE_TYPES, NUM_SELECTORS, VerificationKey } from "../src/verifier/Types.sol";

contract VerifierTest is TestUtils {
    Verifier public verifier;
    TestUtils public testUtils;

    bytes constant INVALID_G1_POINT = "Bn254: invalid G1 point";
    bytes constant INVALID_SCALAR = "Bn254: invalid scalar field";

    function setUp() public {
        verifier = new Verifier();
    }

    /// @dev Creates a mock verification key for testing
    function createMockVerificationKey() internal pure returns (VerificationKey memory) {
        BN254.G1Point memory validPoint = BN254.P1();
        BN254.ScalarField validScalar = BN254.ScalarField.wrap(1);

        // Create arrays for the verification key
        BN254.G1Point[NUM_SELECTORS] memory q_comms;
        BN254.G1Point[NUM_WIRE_TYPES] memory sigma_comms;
        BN254.ScalarField[NUM_WIRE_TYPES] memory k;

        // Fill arrays with valid values
        for (uint256 i = 0; i < NUM_SELECTORS; i++) {
            q_comms[i] = validPoint;
        }
        for (uint256 i = 0; i < NUM_WIRE_TYPES; i++) {
            sigma_comms[i] = validPoint;
            k[i] = validScalar;
        }

        return VerificationKey({
            n: 8, // Small power of 2 for testing
            l: 1, // Single public input
            k: k,
            q_comms: q_comms,
            sigma_comms: sigma_comms,
            g: validPoint,
            h: BN254.P2(),
            x_h: BN254.P2()
        });
    }

    /// @notice Test that the verifier properly validates all proof components in step 1 of Plonk verification
    function testMalformedProof() public {
        // Create a valid scalar and EC point to use as a base
        BN254.G1Point memory validPoint = BN254.P1();
        BN254.G1Point memory invalidPoint = BN254.G1Point({ x: BN254.BaseField.wrap(42), y: BN254.BaseField.wrap(0) });
        BN254.ScalarField validScalar = BN254.ScalarField.wrap(1);
        BN254.ScalarField invalidScalar = BN254.ScalarField.wrap(BN254.R_MOD);

        // Create fixed-size arrays
        BN254.G1Point[NUM_WIRE_TYPES] memory wire_comms;
        BN254.G1Point[NUM_WIRE_TYPES] memory quotient_comms;
        BN254.ScalarField[NUM_WIRE_TYPES] memory wire_evals;
        BN254.ScalarField[NUM_WIRE_TYPES - 1] memory sigma_evals;

        // Fill arrays with valid values
        for (uint256 i = 0; i < NUM_WIRE_TYPES; i++) {
            wire_comms[i] = validPoint;
            quotient_comms[i] = validPoint;
            wire_evals[i] = validScalar;
            if (i < NUM_WIRE_TYPES - 1) {
                sigma_evals[i] = validScalar;
            }
        }

        // Create a valid proof
        BN254.ScalarField[] memory publicInputs = new BN254.ScalarField[](1);
        publicInputs[0] = validScalar;
        PlonkProof memory proof = PlonkProof({
            wire_comms: wire_comms,
            z_comm: validPoint,
            quotient_comms: quotient_comms,
            w_zeta: validPoint,
            w_zeta_omega: validPoint,
            wire_evals: wire_evals,
            sigma_evals: sigma_evals,
            z_bar: validScalar
        });

        // Create a mock verification key
        VerificationKey memory vk = createMockVerificationKey();

        // Test Case 1: Invalid wire commitment
        uint256 invalidIdx = randomUint(NUM_WIRE_TYPES);
        proof.wire_comms[invalidIdx] = invalidPoint;
        vm.expectRevert(INVALID_G1_POINT);
        verifier.verify(proof, publicInputs, vk);
        proof.wire_comms[invalidIdx] = validPoint; // Reset

        // Test Case 2: Invalid z commitment
        invalidIdx = randomUint(NUM_WIRE_TYPES);
        proof.z_comm = invalidPoint;
        vm.expectRevert(INVALID_G1_POINT);
        verifier.verify(proof, publicInputs, vk);
        proof.z_comm = validPoint; // Reset

        // Test Case 3: Invalid quotient commitment
        invalidIdx = randomUint(NUM_WIRE_TYPES);
        proof.quotient_comms[invalidIdx] = invalidPoint;
        vm.expectRevert(INVALID_G1_POINT);
        verifier.verify(proof, publicInputs, vk);
        proof.quotient_comms[invalidIdx] = validPoint; // Reset

        // Test Case 4: Invalid w_zeta
        invalidIdx = randomUint(NUM_WIRE_TYPES);
        proof.w_zeta = invalidPoint;
        vm.expectRevert(INVALID_G1_POINT);
        verifier.verify(proof, publicInputs, vk);
        proof.w_zeta = validPoint; // Reset

        // Test Case 5: Invalid w_zeta_omega
        invalidIdx = randomUint(NUM_WIRE_TYPES);
        proof.w_zeta_omega = invalidPoint;
        vm.expectRevert(INVALID_G1_POINT);
        verifier.verify(proof, publicInputs, vk);
        proof.w_zeta_omega = validPoint; // Reset

        // Test Case 6: Invalid wire evaluation
        invalidIdx = randomUint(NUM_WIRE_TYPES);
        proof.wire_evals[invalidIdx] = invalidScalar;
        vm.expectRevert(INVALID_SCALAR);
        verifier.verify(proof, publicInputs, vk);
        proof.wire_evals[invalidIdx] = validScalar; // Reset

        // Test Case 7: Invalid sigma evaluation
        invalidIdx = randomUint(NUM_WIRE_TYPES - 1);
        proof.sigma_evals[invalidIdx] = invalidScalar;
        vm.expectRevert(INVALID_SCALAR);
        verifier.verify(proof, publicInputs, vk);
        proof.sigma_evals[invalidIdx] = validScalar; // Reset

        // Test Case 8: Invalid z_bar
        invalidIdx = randomUint(NUM_WIRE_TYPES);
        proof.z_bar = invalidScalar;
        vm.expectRevert(INVALID_SCALAR);
        verifier.verify(proof, publicInputs, vk);
        proof.z_bar = validScalar; // Reset
    }

    /// @notice Test that the verifier properly validates public inputs in step 3 of Plonk verification
    function testInvalidPublicInputs() public {
        uint256 NUM_PUBLIC_INPUTS = 3;

        // Create a valid scalar and EC point to use as a base
        BN254.G1Point memory validPoint = BN254.P1();
        BN254.ScalarField validScalar = BN254.ScalarField.wrap(1);
        BN254.ScalarField invalidScalar = BN254.ScalarField.wrap(BN254.R_MOD);

        // Create fixed-size arrays for a valid proof
        BN254.G1Point[NUM_WIRE_TYPES] memory wire_comms;
        BN254.G1Point[NUM_WIRE_TYPES] memory quotient_comms;
        BN254.ScalarField[NUM_WIRE_TYPES] memory wire_evals;
        BN254.ScalarField[NUM_WIRE_TYPES - 1] memory sigma_evals;

        // Fill arrays with valid values
        for (uint256 i = 0; i < NUM_WIRE_TYPES; i++) {
            wire_comms[i] = validPoint;
            quotient_comms[i] = validPoint;
            wire_evals[i] = validScalar;
            if (i < NUM_WIRE_TYPES - 1) {
                sigma_evals[i] = validScalar;
            }
        }

        // Create a valid proof
        PlonkProof memory proof = PlonkProof({
            wire_comms: wire_comms,
            z_comm: validPoint,
            quotient_comms: quotient_comms,
            w_zeta: validPoint,
            w_zeta_omega: validPoint,
            wire_evals: wire_evals,
            sigma_evals: sigma_evals,
            z_bar: validScalar
        });

        // Create a mock verification key
        VerificationKey memory vk = createMockVerificationKey();

        // Test Case: Invalid public input
        BN254.ScalarField[] memory publicInputs = new BN254.ScalarField[](NUM_PUBLIC_INPUTS);
        for (uint256 i = 0; i < NUM_PUBLIC_INPUTS; i++) {
            publicInputs[i] = validScalar;
        }

        // Try a random position with an invalid scalar
        uint256 invalidIdx = randomUint(NUM_PUBLIC_INPUTS);
        publicInputs[invalidIdx] = invalidScalar;
        vm.expectRevert(INVALID_SCALAR);
        verifier.verify(proof, publicInputs, vk);
    }

    /// @notice Test that a valid proof passes steps 1-3 of Plonk verification
    function testValidProof() public view {
        // Create a valid scalar and EC point to use as a base
        BN254.G1Point memory validPoint = BN254.P1();
        BN254.ScalarField validScalar = BN254.ScalarField.wrap(1);

        // Create fixed-size arrays for a valid proof
        BN254.G1Point[NUM_WIRE_TYPES] memory wire_comms;
        BN254.G1Point[NUM_WIRE_TYPES] memory quotient_comms;
        BN254.ScalarField[NUM_WIRE_TYPES] memory wire_evals;
        BN254.ScalarField[NUM_WIRE_TYPES - 1] memory sigma_evals;

        // Fill arrays with valid values
        for (uint256 i = 0; i < NUM_WIRE_TYPES; i++) {
            wire_comms[i] = validPoint;
            quotient_comms[i] = validPoint;
            wire_evals[i] = validScalar;
            if (i < NUM_WIRE_TYPES - 1) {
                sigma_evals[i] = validScalar;
            }
        }

        // Create a valid proof
        PlonkProof memory proof = PlonkProof({
            wire_comms: wire_comms,
            z_comm: validPoint,
            quotient_comms: quotient_comms,
            w_zeta: validPoint,
            w_zeta_omega: validPoint,
            wire_evals: wire_evals,
            sigma_evals: sigma_evals,
            z_bar: validScalar
        });

        // Create a mock verification key
        VerificationKey memory vk = createMockVerificationKey();

        // Create a valid public input
        BN254.ScalarField[] memory publicInputs = new BN254.ScalarField[](1);
        publicInputs[0] = validScalar;

        // This should not revert since we're using valid inputs
        verifier.verify(proof, publicInputs, vk);
    }

    /// @notice Test the verifier against a reference implementation
    function testVerifierAgainstReferenceImpl() public {
        // First compile the binary
        compileRustBinary("test/rust-reference-impls/verifier/Cargo.toml");

        // Run the reference implementation to generate a proof
        string[] memory args = new string[](6);
        args[0] = "./test/rust-reference-impls/target/debug/verifier";
        args[1] = "mul-two";
        args[2] = "prove";
        args[3] = "2"; // a
        args[4] = "3"; // b
        args[5] = "6"; // c = a * b

        // The Rust binary will output a single hex string prefixed with "RES:"
        string memory response = runBinaryGetResponse(args);

        // Split the response to get the proof
        string[] memory parts = vm.split(response, "RES:");
        require(parts.length == 2, "Invalid output format");

        // Decode the proof
        PlonkProof memory proof = abi.decode(vm.parseBytes(parts[1]), (PlonkProof));

        // Create a mock verification key
        VerificationKey memory vk = createMockVerificationKey();

        // Create the public inputs
        BN254.ScalarField[] memory publicInputs = new BN254.ScalarField[](1);
        publicInputs[0] = BN254.ScalarField.wrap(6); // c = a * b = 2 * 3 = 6

        // Print proof structure details
        console2.log("\nProof structure:");
        console2.log("wire_comms length: %d", proof.wire_comms.length);
        console2.log("quotient_comms length: %d", proof.quotient_comms.length);
        console2.log("wire_evals length: %d", proof.wire_evals.length);
        console2.log("sigma_evals length: %d", proof.sigma_evals.length);

        // Print wire commitments
        console2.log("\nWire commitments:");
        for (uint256 i = 0; i < proof.wire_comms.length; i++) {
            console2.log("wire_comms[%d].x: %d", i, BN254.BaseField.unwrap(proof.wire_comms[i].x));
            console2.log("wire_comms[%d].y: %d", i, BN254.BaseField.unwrap(proof.wire_comms[i].y));
        }

        // Print wire evaluations
        console2.log("\nWire evaluations:");
        for (uint256 i = 0; i < proof.wire_evals.length; i++) {
            console2.log("wire_evals[%d]: %d", i, BN254.ScalarField.unwrap(proof.wire_evals[i]));
        }

        // Print sigma evaluations
        console2.log("\nSigma evaluations:");
        for (uint256 i = 0; i < proof.sigma_evals.length; i++) {
            console2.log("sigma_evals[%d]: %d", i, BN254.ScalarField.unwrap(proof.sigma_evals[i]));
        }

        // Print verification key details
        console2.log("\nVerification key details:");
        console2.log("n: %d", vk.n);
        console2.log("l: %d", vk.l);
        for (uint256 i = 0; i < vk.k.length; i++) {
            console2.log("k[%d]: %d", i, BN254.ScalarField.unwrap(vk.k[i]));
        }

        // Print public inputs
        console2.log("\nPublic inputs:");
        for (uint256 i = 0; i < publicInputs.length; i++) {
            console2.log("publicInputs[%d]: %d", i, BN254.ScalarField.unwrap(publicInputs[i]));
        }

        // Try to verify the proof
        try verifier.verify(proof, publicInputs, vk) returns (bool result) {
            console2.log("\nVerification result: %s", result ? "success" : "failure");
            require(result, "Proof verification failed");
        } catch Error(string memory reason) {
            console2.log("\nVerification failed with reason: %s", reason);
            revert(reason);
        } catch (bytes memory) {
            console2.log("\nVerification failed with no reason");
            revert("Verification failed with no reason");
        }
    }
}
