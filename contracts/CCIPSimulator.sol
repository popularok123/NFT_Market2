// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CCIPLocalSimulator} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";

contract CCIPSimulator is CCIPLocalSimulator {
    constructor() CCIPLocalSimulator() {}
}
