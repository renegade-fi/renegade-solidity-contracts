// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { PlonkProof, VerificationKey } from "../../src/libraries/verifier/Types.sol";
import {
    ValidWalletCreateStatement,
    ValidWalletUpdateStatement,
    ValidMatchSettleStatement,
    ValidMatchSettleAtomicStatement,
    StatementSerializer
} from "../../src/libraries/darkpool/PublicInputs.sol";
import {
    PartyMatchPayload,
    MatchProofs,
    MatchLinkingProofs,
    MatchAtomicProofs,
    MatchAtomicLinkingProofs
} from "../../src/libraries/darkpool/Types.sol";
import { VerificationKeys } from "../../src/libraries/darkpool/VerificationKeys.sol";
import { IVerifier } from "../../src/libraries/verifier/IVerifier.sol";
import { Verifier } from "../../src/Verifier.sol";
import { VerifierCore } from "../../src/libraries/verifier/VerifierCore.sol";
import { BN254 } from "solidity-bn254/BN254.sol";

/// @title Test Verifier Implementation
/// @notice This is a test implementation of the `IVerifier` interface that always returns true
/// @notice even if verification fails
contract TestVerifier is IVerifier {
    Verifier private verifier;

    constructor() {
        verifier = new Verifier();
    }

    /// @notice Verify a proof of `VALID WALLET CREATE`
    /// @param statement The public inputs to the proof
    /// @param proof The proof to verify
    /// @return True always, regardless of the proof
    function verifyValidWalletCreate(
        ValidWalletCreateStatement calldata statement,
        PlonkProof calldata proof
    )
        external
        view
        returns (bool)
    {
        verifier.verifyValidWalletCreate(statement, proof);
        return true;
    }

    /// @notice Verify a proof of `VALID WALLET UPDATE`
    /// @param statement The public inputs to the proof
    /// @param proof The proof to verify
    /// @return True always, regardless of the proof
    function verifyValidWalletUpdate(
        ValidWalletUpdateStatement calldata statement,
        PlonkProof calldata proof
    )
        external
        view
        returns (bool)
    {
        verifier.verifyValidWalletUpdate(statement, proof);
        return true;
    }

    /// @notice Verify a match bundle
    /// @param party0MatchPayload The payload for the first party
    /// @param party1MatchPayload The payload for the second party
    /// @param matchSettleStatement The statement of `VALID MATCH SETTLE`
    /// @param proofs The proofs for the match, including two sets of validity proofs and a settlement proof
    /// @return True always, regardless of the proof
    function verifyMatchBundle(
        PartyMatchPayload calldata party0MatchPayload,
        PartyMatchPayload calldata party1MatchPayload,
        ValidMatchSettleStatement calldata matchSettleStatement,
        MatchProofs calldata proofs,
        MatchLinkingProofs calldata linkingProofs
    )
        external
        view
        returns (bool)
    {
        verifier.verifyMatchBundle(party0MatchPayload, party1MatchPayload, matchSettleStatement, proofs, linkingProofs);
        return true;
    }

    /// @notice Verify an atomic match bundle
    /// @param internalPartyPayload The payload for the internal party
    /// @param matchSettleStatement The statement of `VALID MATCH SETTLE ATOMIC`
    /// @param proofs The proofs for the match, including a validity proof and a settlement proof
    /// @param linkingProofs The proof linking arguments for the match
    /// @return True always, regardless of the proof
    function verifyAtomicMatchBundle(
        PartyMatchPayload calldata internalPartyPayload,
        ValidMatchSettleAtomicStatement calldata matchSettleStatement,
        MatchAtomicProofs calldata proofs,
        MatchAtomicLinkingProofs calldata linkingProofs
    )
        external
        view
        returns (bool)
    {
        verifier.verifyAtomicMatchBundle(internalPartyPayload, matchSettleStatement, proofs, linkingProofs);
        return true;
    }
}
