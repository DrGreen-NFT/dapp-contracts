// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/governance/TimelockController.sol";

contract DrGreenTimelock is TimelockController {
    /**
     * @dev Constructor for the TimelockController
     * @param minDelay Minimum delay for executing proposals
     * @param proposers List of addresses with proposer role
     * @param executors List of addresses with executor role
     */
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(minDelay, proposers, executors, admin) {
        // Timelock initialized with given parameters
    }
}
