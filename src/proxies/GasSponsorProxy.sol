// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { TransparentUpgradeableProxy } from "oz-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IGasSponsor } from "renegade-lib/interfaces/IGasSponsor.sol";

/**
 * @title GasSponsorProxy
 * @dev This contract is a TransparentUpgradeableProxy for the GasSponsor contract.
 * It simplifies deployment by accepting GasSponsor-specific initialization parameters
 * and encoding them appropriately.
 */
contract GasSponsorProxy is TransparentUpgradeableProxy {
    /**
     * @dev Initializes a TransparentUpgradeableProxy for a GasSponsor implementation.
     *
     * @param implementation The GasSponsor implementation address
     * @param admin The admin address - serves as both ProxyAdmin owner and can manage proxy upgrades
     * @param darkpoolAddress The address of the darkpool proxy contract
     * @param authAddress The public key used to authenticate gas sponsorship
     */
    constructor(
        address implementation,
        address admin,
        // GasSponsor-specific initialization parameters
        address darkpoolAddress,
        address authAddress
    )
        payable
        TransparentUpgradeableProxy(
            implementation,
            admin,
            abi.encodeWithSelector(IGasSponsor.initialize.selector, admin, darkpoolAddress, authAddress)
        )
    { }
}
