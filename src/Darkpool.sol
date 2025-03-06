// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IPermit2 } from "permit2/interfaces/IPermit2.sol";
import { PlonkProof, VerificationKey, NUM_SELECTORS, NUM_WIRE_TYPES } from "./libraries/verifier/Types.sol";
import { BN254 } from "solidity-bn254/BN254.sol";
import { VerifierCore } from "./libraries/verifier/VerifierCore.sol";
import { VerificationKeys } from "./libraries/darkpool/VerificationKeys.sol";
import { IHasher } from "./libraries/poseidon2/IHasher.sol";
import { IVerifier } from "./libraries/verifier/IVerifier.sol";
import {
    ValidWalletCreateStatement,
    ValidWalletUpdateStatement,
    ValidCommitmentsStatement,
    ValidReblindStatement,
    ValidMatchSettleStatement,
    StatementSerializer
} from "./libraries/darkpool/PublicInputs.sol";
import { WalletOperations } from "./libraries/darkpool/WalletOperations.sol";
import { TransferExecutor } from "./libraries/darkpool/ExternalTransfers.sol";
import {
    TransferAuthorization, isZero, PartyMatchPayload, MatchProofs, indicesEqual
} from "./libraries/darkpool/Types.sol";
import { MerkleTreeLib } from "./libraries/merkle/MerkleTree.sol";
import { NullifierLib } from "./libraries/darkpool/NullifierSet.sol";

using MerkleTreeLib for MerkleTreeLib.MerkleTree;
using NullifierLib for NullifierLib.NullifierSet;

contract Darkpool {
    /// @notice The hasher for the darkpool
    IHasher public hasher;
    /// @notice The verifier for the darkpool
    IVerifier public verifier;
    /// @notice The Permit2 contract instance for handling deposits
    IPermit2 public permit2;

    /// @notice The Merkle tree for wallet commitments
    MerkleTreeLib.MerkleTree private merkleTree;
    /// @notice The nullifier set for the darkpool
    /// @dev Each time a wallet is updated (placing an order, settling a match, depositing, etc) a nullifier is spent.
    /// @dev This ensures that a pre-update wallet cannot create two separate post-update wallets in the Merkle state
    /// @dev The nullifier is computed deterministically from the shares of the pre-update wallet
    NullifierLib.NullifierSet private nullifierSet;

    /// @notice The constructor for the darkpool
    /// @param hasher_ The hasher for the darkpool
    /// @param verifier_ The verifier for the darkpool
    /// @param permit2_ The Permit2 contract instance for handling deposits
    constructor(IHasher hasher_, IVerifier verifier_, IPermit2 permit2_) {
        hasher = hasher_;
        verifier = verifier_;
        permit2 = permit2_;
        merkleTree.initialize();
    }

    // --- State Getters --- //

    /// @notice Get the current Merkle root
    /// @return The current Merkle root
    function getMerkleRoot() public view returns (BN254.ScalarField) {
        return merkleTree.root;
    }

    /// @notice Check whether a root is in the Merkle root history
    /// @param root The root to check
    /// @return Whether the root is in the history
    function rootInHistory(BN254.ScalarField root) public view returns (bool) {
        return merkleTree.rootHistory[root];
    }

    /// @notice Check whether a nullifier has been spent
    /// @param nullifier The nullifier to check
    /// @return Whether the nullifier has been spent
    function nullifierSpent(BN254.ScalarField nullifier) public view returns (bool) {
        return nullifierSet.isSpent(nullifier);
    }

    // --- Core Wallet Methods --- //

    /// @notice Create a wallet in the darkpool
    /// @param statement The statement to verify
    /// @param proof The proof of `VALID WALLET CREATE`
    function createWallet(ValidWalletCreateStatement calldata statement, PlonkProof calldata proof) public {
        // 1. Verify the proof
        verifier.verifyValidWalletCreate(statement, proof);

        // 2. Insert the wallet shares into the Merkle tree
        WalletOperations.insertWalletCommitment(
            statement.privateShareCommitment, statement.publicShares, merkleTree, hasher
        );
    }

    /// @notice Update a wallet in the darkpool
    /// @param newSharesCommitmentSig The signature of the new wallet shares commitment by the
    /// old wallet's root key
    /// @param statement The statement to verify
    /// @param proof The proof of `VALID WALLET UPDATE`
    function updateWallet(
        bytes calldata newSharesCommitmentSig,
        TransferAuthorization calldata transferAuthorization,
        ValidWalletUpdateStatement calldata statement,
        PlonkProof calldata proof
    )
        public
    {
        // 1. Verify the proof
        verifier.verifyValidWalletUpdate(statement, proof);

        // 2. Rotate the wallet's shares into the Merkle tree
        BN254.ScalarField newCommitment = WalletOperations.rotateWallet(
            statement.previousNullifier,
            statement.merkleRoot,
            statement.newPrivateShareCommitment,
            statement.newPublicShares,
            nullifierSet,
            merkleTree,
            hasher
        );

        // 3. Verify the signature of the new shares commitment by the root key
        bool validSig =
            WalletOperations.verifyWalletUpdateSignature(newCommitment, newSharesCommitmentSig, statement.oldPkRoot);
        require(validSig, "Invalid signature");

        // 4. Execute the external transfer if it is non-zero
        if (!isZero(statement.externalTransfer)) {
            TransferExecutor.executeTransfer(
                statement.externalTransfer, statement.oldPkRoot, transferAuthorization, permit2
            );
        }
    }

    /// @notice Settle a match in the darkpool
    /// @param party0MatchPayload The validity proofs payload for the first party
    /// @param party1MatchPayload The validity proofs payload for the second party
    /// @param matchSettleStatement The statement of `VALID MATCH SETTLE`
    /// @param proofs The proofs for the match, including two sets of validity proofs and a settlement proof
    function processMatchSettle(
        PartyMatchPayload calldata party0MatchPayload,
        PartyMatchPayload calldata party1MatchPayload,
        ValidMatchSettleStatement calldata matchSettleStatement,
        MatchProofs calldata proofs
    )
        public
    {
        ValidCommitmentsStatement calldata commitmentsStatement0 = party0MatchPayload.validCommitmentsStatement;
        ValidCommitmentsStatement calldata commitmentsStatement1 = party1MatchPayload.validCommitmentsStatement;
        ValidReblindStatement calldata reblindStatement0 = party0MatchPayload.validReblindStatement;
        ValidReblindStatement calldata reblindStatement1 = party1MatchPayload.validReblindStatement;

        // 1. Verify the proofs
        verifier.verifyMatchBundle(party0MatchPayload, party1MatchPayload, matchSettleStatement, proofs);

        // 2. Check statement consistency between the proofs for the two parties
        // I.e. public inputs used in multiple proofs should take the same values
        bool party0ValidIndices =
            indicesEqual(commitmentsStatement0.indices, matchSettleStatement.firstPartySettlementIndices);
        bool party1ValidIndices =
            indicesEqual(commitmentsStatement1.indices, matchSettleStatement.secondPartySettlementIndices);
        require(party0ValidIndices, "Invalid party 0 order settlement indices");
        require(party1ValidIndices, "Invalid party 1 order settlement indices");

        // 3. TODO: Validate the protocol fee rate used in the settlement

        // 4. Insert the new shares into the Merkle tree
        WalletOperations.rotateWallet(
            reblindStatement0.originalSharesNullifier,
            reblindStatement0.merkleRoot,
            reblindStatement0.newPrivateShareCommitment,
            matchSettleStatement.firstPartyPublicShares,
            nullifierSet,
            merkleTree,
            hasher
        );
        WalletOperations.rotateWallet(
            reblindStatement1.originalSharesNullifier,
            reblindStatement1.merkleRoot,
            reblindStatement1.newPrivateShareCommitment,
            matchSettleStatement.secondPartyPublicShares,
            nullifierSet,
            merkleTree,
            hasher
        );
    }
}
