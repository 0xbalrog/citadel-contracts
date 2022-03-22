// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";
import {stdCheats} from "forge-std/stdlib.sol";
import {Utils} from "./utils/Utils.sol";
import {ERC20Utils} from "./utils/ERC20Utils.sol";

import {SafeMathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

import {GlobalAccessControl} from "../GlobalAccessControl.sol";

import {CitadelToken} from "../CitadelToken.sol";
import {StakedCitadel} from "../StakedCitadel.sol";
import {StakedCitadelVester} from "../StakedCitadelVester.sol";

import {SupplySchedule} from "../SupplySchedule.sol";
import {CitadelMinter} from "../CitadelMinter.sol";

import {KnightingRound} from "../KnightingRound.sol";
import {Funding} from "../Funding.sol";

import "../interfaces/erc20/IERC20.sol";

contract BaseFixture is DSTest, Utils {
    using SafeMathUpgradeable for uint256;
    Vm constant vm = Vm(HEVM_ADDRESS);

    bytes32 public constant CONTRACT_GOVERNANCE_ROLE =
        keccak256("CONTRACT_GOVERNANCE_ROLE");
    bytes32 public constant TREASURY_GOVERNANCE_ROLE =
        keccak256("TREASURY_GOVERNANCE_ROLE");

    bytes32 public constant TECH_OPERATIONS_ROLE =
        keccak256("TECH_OPERATIONS_ROLE");
    bytes32 public constant POLICY_OPERATIONS_ROLE =
        keccak256("POLICY_OPERATIONS_ROLE");
    bytes32 public constant TREASURY_OPERATIONS_ROLE =
        keccak256("TREASURY_OPERATIONS_ROLE");

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");

    bytes32 public constant BLOCKLIST_MANAGER_ROLE =
        keccak256("BLOCKLIST_MANAGER_ROLE");
    bytes32 public constant BLOCKLISTED_ROLE = keccak256("BLOCKLISTED_ROLE");

    bytes32 public constant CITADEL_MINTER_ROLE =
        keccak256("CITADEL_MINTER_ROLE");

    uint256 public constant ONE = 1 ether;

    // ==================
    // ===== Actors =====
    // ==================

    address immutable governance = getAddress("governance");
    address immutable techOps = getAddress("techOps");
    address immutable policyOps = getAddress("policyOps");
    address immutable guardian = getAddress("guardian");
    address immutable keeper = getAddress("keeper");
    address immutable treasuryVault = getAddress("treasuryVault");
    address immutable treasuryOps = getAddress("treasuryOps");

    address immutable citadelTree = getAddress("citadelTree");

    address immutable rando = getAddress("rando");

    address immutable whale = getAddress("whale");
    address immutable shrimp = getAddress("shrimp");
    address immutable shark = getAddress("shark");

    IERC20 wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20 cvx = IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);

    GlobalAccessControl gac = new GlobalAccessControl();

    CitadelToken citadel = new CitadelToken();
    StakedCitadel xCitadel = new StakedCitadel();
    StakedCitadelVester xCitadelVester = new StakedCitadelVester();

    SupplySchedule schedule = new SupplySchedule();
    CitadelMinter citadelMinter = new CitadelMinter();

    KnightingRound knightingRound = new KnightingRound();

    Funding fundingWbtc = new Funding();
    Funding fundingCvx = new Funding();

    struct KnightingRoundParams {
        uint256 start;
        uint256 duration;
        uint256 citadelWbtcPrice;
        uint256 wbtcLimit;
    }

    KnightingRoundParams knightingRoundParams;

    function setUp() public virtual {
        // Labels
        vm.label(address(this), "this");

        vm.label(governance, "governance");
        vm.label(policyOps, "policyOps");
        vm.label(keeper, "keeper");
        vm.label(guardian, "guardian");
        vm.label(treasuryVault, "treasuryVault");

        vm.label(rando, "rando");

        vm.label(address(schedule), "schedule");
        vm.label(address(gac), "gac");

        vm.label(whale, "whale");
        vm.label(shrimp, "shrimp");
        vm.label(shark, "shark");

        // Initialization
        gac.initialize(governance);

        uint256[4] memory xCitadelFees = [
            uint256(0),
            uint256(0),
            uint256(0),
            uint256(0)
        ];

        citadel.initialize("Citadel", "CTDL", address(gac));
        xCitadel.initialize(
            address(citadel),
            address(governance),
            address(keeper),
            address(guardian),
            address(treasuryVault),
            address(techOps),
            address(citadelTree),
            address(xCitadelVester),
            "Staked Citadel",
            "xCTDL",
            xCitadelFees
        );

        xCitadelVester.initialize(
            address(gac),
            address(citadel),
            address(xCitadel)
        );

        schedule.initialize(address(gac));
        citadelMinter.initialize(
            address(gac),
            address(citadel),
            address(xCitadel),
            address(xCitadel),
            address(schedule)
        );

        // // Knighting Round
        knightingRoundParams = KnightingRoundParams({
            start: block.timestamp + 100,
            duration: 7 days,
            citadelWbtcPrice: ONE / 21, // 21 CTDL per wBTC
            wbtcLimit: 100 * 10**8 // 100 wBTC
        });

        knightingRound.initialize(
            address(gac),
            address(citadel),
            address(wbtc),
            knightingRoundParams.start,
            knightingRoundParams.duration,
            knightingRoundParams.citadelWbtcPrice,
            address(treasuryVault),
            address(0), // TODO: Add guest list and test with it
            knightingRoundParams.wbtcLimit
        );

        // Grant roles
        vm.startPrank(governance);
        gac.grantRole(CONTRACT_GOVERNANCE_ROLE, governance);
        gac.grantRole(TREASURY_GOVERNANCE_ROLE, treasuryVault);

        gac.grantRole(TECH_OPERATIONS_ROLE, techOps);
        gac.grantRole(TREASURY_OPERATIONS_ROLE, treasuryOps);
        gac.grantRole(POLICY_OPERATIONS_ROLE, policyOps);

        gac.grantRole(CITADEL_MINTER_ROLE, address(citadelMinter));

        gac.grantRole(PAUSER_ROLE, guardian);
        gac.grantRole(UNPAUSER_ROLE, techOps);
        vm.stopPrank();
    }
}