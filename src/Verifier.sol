// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { PlonkProof, VerificationKey } from "./libraries/verifier/Types.sol";
import {
    ValidWalletCreateStatement,
    ValidWalletUpdateStatement,
    StatementSerializer
} from "./libraries/darkpool/PublicInputs.sol";
import { VerificationKeys } from "./libraries/darkpool/VerificationKeys.sol";
import { IVerifier } from "./libraries/verifier/IVerifier.sol";
import { VerifierCore } from "./libraries/verifier/VerifierCore.sol";
import { BN254 } from "solidity-bn254/BN254.sol";

using StatementSerializer for ValidWalletCreateStatement;
using StatementSerializer for ValidWalletUpdateStatement;

/// @title PlonK Verifier with the Jellyfish-style arithmetization
/// @notice The methods on this contract are darkpool-specific
contract Verifier is IVerifier {
    /// @notice Verify a proof of `VALID WALLET CREATE`
    /// @param statement The public inputs to the proof
    /// @param proof The proof to verify
    /// @return True if the proof is valid, false otherwise
    function verifyValidWalletCreate(
        ValidWalletCreateStatement memory statement,
        PlonkProof memory proof
    )
        external
        view
        returns (bool)
    {
        VerificationKey memory vk = abi.decode(VerificationKeys.VALID_WALLET_CREATE_VKEY, (VerificationKey));
        BN254.ScalarField[] memory publicInputs = statement.scalarSerialize();
        return VerifierCore.verify(proof, publicInputs, vk);
    }

    /// @notice Verify a proof of `VALID WALLET UPDATE`
    /// @param statement The public inputs to the proof
    /// @param proof The proof to verify
    /// @return True if the proof is valid, false otherwise
    function verifyValidWalletUpdate(
        ValidWalletUpdateStatement memory statement,
        PlonkProof memory proof
    )
        external
        view
        returns (bool)
    {
        VerificationKey memory vk = abi.decode(VerificationKeys.VALID_WALLET_UPDATE_VKEY, (VerificationKey));
        BN254.ScalarField[] memory publicInputs = statement.scalarSerialize();
        return VerifierCore.verify(proof, publicInputs, vk);
    }
}
