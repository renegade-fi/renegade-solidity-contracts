// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { BN254 } from "solidity-bn254/BN254.sol";
import { ERC20Mock } from "oz-contracts/mocks/token/ERC20Mock.sol";
import { Test } from "forge-std/Test.sol";
import { DarkpoolTestBase } from "./DarkpoolTestBase.sol";

import {
    PartyMatchPayload,
    MalleableMatchAtomicProofs,
    MatchAtomicLinkingProofs
} from "renegade-lib/darkpool/types/Settlement.sol";
import { TypesLib } from "renegade-lib/darkpool/types/TypesLib.sol";
import { FeeTake, FeeTakeRate } from "renegade-lib/darkpool/types/Fees.sol";
import {
    ExternalMatchDirection, BoundedMatchResult, ExternalMatchResult
} from "renegade-lib/darkpool/types/Settlement.sol";
import { ValidMalleableMatchSettleAtomicStatement } from "renegade-lib/darkpool/PublicInputs.sol";
import { DarkpoolConstants } from "renegade-lib/darkpool/Constants.sol";

contract SettleMalleableAtomicMatch is DarkpoolTestBase {
    using TypesLib for FeeTake;
    using TypesLib for FeeTakeRate;
    using TypesLib for BoundedMatchResult;

    address public txSender;
    address public relayerFeeAddr;

    function setUp() public override {
        super.setUp();
        txSender = vm.randomAddress();
        relayerFeeAddr = vm.randomAddress();
    }

    // --- Valid Match Tests --- //

    /// @notice Test settling a malleable atomic match with the external party buy side
    function test_settleMalleableAtomicMatch_externalPartyBuySide() public {
        // Setup calldata
        BN254.ScalarField merkleRoot = darkpool.getMerkleRoot();
        (
            PartyMatchPayload memory internalPartyPayload,
            ValidMalleableMatchSettleAtomicStatement memory statement,
            MalleableMatchAtomicProofs memory proofs,
            MatchAtomicLinkingProofs memory linkingProofs
        ) = genMalleableMatchCalldata(ExternalMatchDirection.InternalPartySell, merkleRoot);

        // Fund the external party and darkpool
        ExternalMatchResult memory externalMatchResult = sampleExternalMatch(statement.matchResult);
        fundExternalPartyAndDarkpool(externalMatchResult);
        verifyMalleableAtomicMatch(
            txSender, externalMatchResult.baseAmount, internalPartyPayload, statement, proofs, linkingProofs
        );
    }

    /// @notice Test settling a malleable atomic match with the external party sell side
    function test_settleMalleableAtomicMatch_externalPartySellSide() public {
        // Setup calldata
        BN254.ScalarField merkleRoot = darkpool.getMerkleRoot();
        (
            PartyMatchPayload memory internalPartyPayload,
            ValidMalleableMatchSettleAtomicStatement memory statement,
            MalleableMatchAtomicProofs memory proofs,
            MatchAtomicLinkingProofs memory linkingProofs
        ) = genMalleableMatchCalldata(ExternalMatchDirection.InternalPartyBuy, merkleRoot);

        // Fund the external party and darkpool
        ExternalMatchResult memory externalMatchResult = sampleExternalMatch(statement.matchResult);
        fundExternalPartyAndDarkpool(externalMatchResult);

        verifyMalleableAtomicMatch(
            txSender, externalMatchResult.baseAmount, internalPartyPayload, statement, proofs, linkingProofs
        );
    }

    /// @notice Test settling a malleable atomic match on the native asset, buy side
    function test_settleMalleableAtomicMatch_nativeAssetBuySide() public {
        // Setup calldata
        BN254.ScalarField merkleRoot = darkpool.getMerkleRoot();
        (
            PartyMatchPayload memory internalPartyPayload,
            ValidMalleableMatchSettleAtomicStatement memory statement,
            MalleableMatchAtomicProofs memory proofs,
            MatchAtomicLinkingProofs memory linkingProofs
        ) = genMalleableMatchCalldata(ExternalMatchDirection.InternalPartySell, merkleRoot);
        statement.matchResult.baseMint = DarkpoolConstants.NATIVE_TOKEN_ADDRESS;

        // Fund the external party and darkpool
        ExternalMatchResult memory externalMatchResult = sampleExternalMatch(statement.matchResult);
        fundExternalPartyAndDarkpool(externalMatchResult);
        verifyMalleableAtomicMatch(
            txSender, externalMatchResult.baseAmount, internalPartyPayload, statement, proofs, linkingProofs
        );
    }

    /// @notice Test settling a malleable atomic match on the native asset, sell side
    function test_settleMalleableAtomicMatch_nativeAssetSellSide() public {
        // Setup calldata
        BN254.ScalarField merkleRoot = darkpool.getMerkleRoot();
        (
            PartyMatchPayload memory internalPartyPayload,
            ValidMalleableMatchSettleAtomicStatement memory statement,
            MalleableMatchAtomicProofs memory proofs,
            MatchAtomicLinkingProofs memory linkingProofs
        ) = genMalleableMatchCalldata(ExternalMatchDirection.InternalPartyBuy, merkleRoot);
        statement.matchResult.baseMint = DarkpoolConstants.NATIVE_TOKEN_ADDRESS;

        // Fund the external party and darkpool
        ExternalMatchResult memory externalMatchResult = sampleExternalMatch(statement.matchResult);
        fundExternalPartyAndDarkpool(externalMatchResult);
        verifyMalleableAtomicMatch(
            txSender, externalMatchResult.baseAmount, internalPartyPayload, statement, proofs, linkingProofs
        );
    }

    /// @notice Test settling a malleable atomic match with a receiver that is not the tx sender
    function test_settleMalleableAtomicMatch_nonSenderReceiver() public {
        address receiver = vm.randomAddress();

        // Setup calldata
        BN254.ScalarField merkleRoot = darkpool.getMerkleRoot();
        (
            PartyMatchPayload memory internalPartyPayload,
            ValidMalleableMatchSettleAtomicStatement memory statement,
            MalleableMatchAtomicProofs memory proofs,
            MatchAtomicLinkingProofs memory linkingProofs
        ) = genMalleableMatchCalldata(ExternalMatchDirection.InternalPartySell, merkleRoot);

        // Fund the external party and darkpool
        ExternalMatchResult memory externalMatchResult = sampleExternalMatch(statement.matchResult);
        fundExternalPartyAndDarkpool(externalMatchResult);

        // Get the receiver and sender's balances before the match
        (uint256 receiverBaseBalance1, uint256 receiverQuoteBalance1) = baseQuoteBalances(receiver);
        (uint256 senderBaseBalance1, uint256 senderQuoteBalance1) = baseQuoteBalances(txSender);

        // Submit the match
        vm.startBroadcast(txSender);
        darkpool.processMalleableAtomicMatchSettle(
            externalMatchResult.baseAmount, receiver, internalPartyPayload, statement, proofs, linkingProofs
        );
        vm.stopBroadcast();

        // Get the balances after the match
        (uint256 receiverBaseBalance2, uint256 receiverQuoteBalance2) = baseQuoteBalances(receiver);
        (uint256 senderBaseBalance2, uint256 senderQuoteBalance2) = baseQuoteBalances(txSender);

        // Check the token flows
        uint256 baseAmt = externalMatchResult.baseAmount;
        uint256 quoteAmt = externalMatchResult.quoteAmount;
        FeeTakeRate memory externalPartyFees = statement.externalFeeRates;
        FeeTake memory externalPartyFeeTake = TypesLib.computeFeeTake(externalPartyFees, baseAmt);

        // Check that the receiver got the tokens and sender didn't
        assertEq(receiverBaseBalance2, receiverBaseBalance1 + baseAmt - externalPartyFeeTake.total());
        assertEq(receiverQuoteBalance2, receiverQuoteBalance1);
        assertEq(senderBaseBalance2, senderBaseBalance1);
        assertEq(senderQuoteBalance2, senderQuoteBalance1 - quoteAmt);
    }

    // --- Helper Functions --- //

    /// @notice Sample a random base amount between the bounds on a `BoundedMatchResult`
    function sampleBaseAmount(BoundedMatchResult memory matchResult) internal returns (uint256) {
        uint256 min = matchResult.minBaseAmount;
        uint256 max = matchResult.maxBaseAmount;
        return randomUint(min, max);
    }

    /// @notice Sample an external match from a bounded match
    function sampleExternalMatch(BoundedMatchResult memory matchResult) internal returns (ExternalMatchResult memory) {
        uint256 baseAmt = sampleBaseAmount(matchResult);
        return TypesLib.buildExternalMatchResult(baseAmt, matchResult);
    }

    /// @notice Fund the external party and darkpool given a match result
    function fundExternalPartyAndDarkpool(ExternalMatchResult memory externalMatchResult) internal {
        (address sellMint, uint256 sellAmt) = TypesLib.externalPartySellMintAmount(externalMatchResult);
        (address buyMint, uint256 buyAmt) = TypesLib.externalPartyBuyMintAmount(externalMatchResult);

        // Fund the external party and darkpool
        fundExternalParty(sellMint, sellAmt);
        fundDarkpool(buyMint, buyAmt);

        // Approve the darkpool to spend the tokens
        if (!DarkpoolConstants.isNativeToken(sellMint)) {
            ERC20Mock sellToken = ERC20Mock(sellMint);
            vm.startBroadcast(txSender);
            sellToken.approve(address(darkpool), sellAmt);
            vm.stopBroadcast();
        }
    }

    /// @notice Fund the external party with the given amount of the given token
    function fundExternalParty(address token, uint256 amt) internal {
        if (DarkpoolConstants.isNativeToken(token)) {
            vm.deal(txSender, amt);
        } else {
            ERC20Mock erc20 = ERC20Mock(token);
            erc20.mint(txSender, amt);
        }
    }

    /// @notice Fund the darkpool with the given amount of the given token
    function fundDarkpool(address token, uint256 amt) internal {
        if (DarkpoolConstants.isNativeToken(token)) {
            weth.mint(address(darkpool), amt);
        } else {
            ERC20Mock erc20 = ERC20Mock(token);
            erc20.mint(address(darkpool), amt);
        }
    }

    /// @notice Generate the calldata for settling a malleable atomic match, using the testing contracts
    /// @param direction The direction of the match
    /// @param merkleRoot The merkle root of the darkpool
    /// @return internalPartyPayload The internal party payload
    /// @return statement The statement
    /// @return proofs The proofs
    /// @return linkingProofs The linking proofs
    function genMalleableMatchCalldata(
        ExternalMatchDirection direction,
        BN254.ScalarField merkleRoot
    )
        internal
        returns (
            PartyMatchPayload memory,
            ValidMalleableMatchSettleAtomicStatement memory,
            MalleableMatchAtomicProofs memory,
            MatchAtomicLinkingProofs memory
        )
    {
        (
            PartyMatchPayload memory internalPartyPayload,
            ValidMalleableMatchSettleAtomicStatement memory statement,
            MalleableMatchAtomicProofs memory proofs,
            MatchAtomicLinkingProofs memory linkingProofs
        ) = settleMalleableAtomicMatchCalldata(direction, merkleRoot);

        // Modify the pair to be the quote and base token setup by the test harness
        statement.matchResult.quoteMint = address(quoteToken);
        statement.matchResult.baseMint = address(baseToken);
        statement.relayerFeeAddress = relayerFeeAddr;

        return (internalPartyPayload, statement, proofs, linkingProofs);
    }

    /// @notice Submit a malleable atomic match and check the token flows
    function verifyMalleableAtomicMatch(
        address receiver,
        uint256 baseAmount,
        PartyMatchPayload memory internalPartyPayload,
        ValidMalleableMatchSettleAtomicStatement memory statement,
        MalleableMatchAtomicProofs memory proofs,
        MatchAtomicLinkingProofs memory linkingProofs
    )
        internal
    {
        // Get the balances before the match
        (
            uint256 userBaseBalance1,
            uint256 userQuoteBalance1,
            uint256 darkpoolBaseBalance1,
            uint256 darkpoolQuoteBalance1,
            uint256 relayerBaseBalance1,
            uint256 relayerQuoteBalance1,
            uint256 protocolBaseBalance1,
            uint256 protocolQuoteBalance1
        ) = getPartyBalances(statement.matchResult.baseMint);

        // Submit the match
        uint256 ethValue = 0;
        bool isNative = DarkpoolConstants.isNativeToken(statement.matchResult.baseMint);
        bool externalPartySells = statement.matchResult.direction == ExternalMatchDirection.InternalPartyBuy;
        if (isNative && externalPartySells) {
            ethValue = baseAmount;
        }

        vm.startBroadcast(txSender);
        darkpool.processMalleableAtomicMatchSettle{ value: ethValue }(
            baseAmount, receiver, internalPartyPayload, statement, proofs, linkingProofs
        );
        vm.stopBroadcast();

        // Get the balances after the match
        (
            uint256 userBaseBalance2,
            uint256 userQuoteBalance2,
            uint256 darkpoolBaseBalance2,
            uint256 darkpoolQuoteBalance2,
            uint256 relayerBaseBalance2,
            uint256 relayerQuoteBalance2,
            uint256 protocolBaseBalance2,
            uint256 protocolQuoteBalance2
        ) = getPartyBalances(statement.matchResult.baseMint);

        ExternalMatchResult memory externalMatchResult =
            TypesLib.buildExternalMatchResult(baseAmount, statement.matchResult);

        // Check the token flows
        uint256 baseAmt = externalMatchResult.baseAmount;
        uint256 quoteAmt = externalMatchResult.quoteAmount;

        if (externalMatchResult.direction == ExternalMatchDirection.InternalPartySell) {
            FeeTake memory externalPartyFees = statement.externalFeeRates.computeFeeTake(baseAmt);

            // External party buys the base, sells the quote
            assertEq(userBaseBalance2, userBaseBalance1 + baseAmt - externalPartyFees.total());
            assertEq(userQuoteBalance2, userQuoteBalance1 - quoteAmt);
            assertEq(darkpoolBaseBalance2, darkpoolBaseBalance1 - baseAmt);
            assertEq(darkpoolQuoteBalance2, darkpoolQuoteBalance1 + quoteAmt);
            assertEq(relayerBaseBalance2, relayerBaseBalance1 + externalPartyFees.relayerFee);
            assertEq(relayerQuoteBalance2, relayerQuoteBalance1);
            assertEq(protocolBaseBalance2, protocolBaseBalance1 + externalPartyFees.protocolFee);
            assertEq(protocolQuoteBalance2, protocolQuoteBalance1);
        } else {
            FeeTake memory externalPartyFees = statement.externalFeeRates.computeFeeTake(quoteAmt);

            // External party buys the quote, sells the base
            assertEq(userBaseBalance2, userBaseBalance1 - baseAmt);
            assertEq(userQuoteBalance2, userQuoteBalance1 + quoteAmt - externalPartyFees.total());
            assertEq(darkpoolBaseBalance2, darkpoolBaseBalance1 + baseAmt);
            assertEq(darkpoolQuoteBalance2, darkpoolQuoteBalance1 - quoteAmt);
            assertEq(relayerBaseBalance2, relayerBaseBalance1);
            assertEq(relayerQuoteBalance2, relayerQuoteBalance1 + externalPartyFees.relayerFee);
            assertEq(protocolBaseBalance2, protocolBaseBalance1);
            assertEq(protocolQuoteBalance2, protocolQuoteBalance1 + externalPartyFees.protocolFee);
        }
    }

    /// @notice Get the balances of the user, darkpool, relayer, and protocol
    function getPartyBalances(address baseMint)
        internal
        view
        returns (
            uint256 userBaseBalance,
            uint256 userQuoteBalance,
            uint256 darkpoolBaseBalance,
            uint256 darkpoolQuoteBalance,
            uint256 relayerBaseBalance,
            uint256 relayerQuoteBalance,
            uint256 protocolBaseBalance,
            uint256 protocolQuoteBalance
        )
    {
        if (DarkpoolConstants.isNativeToken(baseMint)) {
            (userBaseBalance, userQuoteBalance) = etherQuoteBalances(txSender);
            (darkpoolBaseBalance, darkpoolQuoteBalance) = wethQuoteBalances(address(darkpool));
            (relayerBaseBalance, relayerQuoteBalance) = etherQuoteBalances(relayerFeeAddr);
            (protocolBaseBalance, protocolQuoteBalance) = etherQuoteBalances(protocolFeeAddr);
        } else {
            (userBaseBalance, userQuoteBalance) = baseQuoteBalances(txSender);
            (darkpoolBaseBalance, darkpoolQuoteBalance) = baseQuoteBalances(address(darkpool));
            (relayerBaseBalance, relayerQuoteBalance) = baseQuoteBalances(relayerFeeAddr);
            (protocolBaseBalance, protocolQuoteBalance) = baseQuoteBalances(protocolFeeAddr);
        }
    }
}
