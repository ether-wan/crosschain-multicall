// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// Multicall imports
import { Multicall } from "../../contracts/Multicall.sol";
import { Target } from "../../contracts/Target.sol";

import { MulticallCodes } from "../../contracts/utils/MulticallCodes.sol";

// OApp imports
import { IOAppOptionsType3, EnforcedOptionParam } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

// OZ imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Forge imports
import "forge-std/console.sol";
import "forge-std/Test.sol";
import { Vm } from "forge-std/Test.sol";

// DevTools imports
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

contract MulticallTest is TestHelperOz5, MulticallCodes {
    using OptionsBuilder for bytes;

    uint32 private aEid = 1;
    uint32 private bEid = 2;
    uint32 private cEid = 3;

    uint16 REQUEST = 1;
    uint16 RESPONSE = 2;

    Multicall private mA;
    Multicall private mB;
    Multicall private mC;

    Target private tB;
    Target private tC;

    address private userA = address(0x1);
    address private userB = address(0x2);
    address private userC = address(0x3);
    uint256 private initialBalance = 100 ether;

    function setUp() public virtual override {
        vm.deal(userA, 1000 ether);
        vm.deal(userB, 1000 ether);
        vm.deal(userC, 1000 ether);

        super.setUp();
        setUpEndpoints(3, LibraryType.UltraLightNode);

        mA = Multicall(_deployOApp(type(Multicall).creationCode, abi.encode(address(endpoints[aEid]), address(this))));

        mB = Multicall(_deployOApp(type(Multicall).creationCode, abi.encode(address(endpoints[bEid]), address(this))));

        mC = Multicall(_deployOApp(type(Multicall).creationCode, abi.encode(address(endpoints[cEid]), address(this))));

        tB = Target(_deployOApp(type(Target).creationCode, abi.encode()));

        tC = Target(_deployOApp(type(Target).creationCode, abi.encode()));

        address[] memory oapps = new address[](3);
        oapps[0] = address(mA);
        oapps[1] = address(mB);
        oapps[2] = address(mC);

        this.wireOApps(oapps);

        vm.recordLogs();
    }

    function test_constructor() public {
        assertEq(mA.owner(), address(this));
        assertEq(mB.owner(), address(this));
        assertEq(mC.owner(), address(this));

        assertEq(tB.owner(), address(this));
        assertEq(tC.owner(), address(this));

        assertEq(address(mA.endpoint()), address(endpoints[aEid]));
        assertEq(address(mB.endpoint()), address(endpoints[bEid]));
        assertEq(address(mC.endpoint()), address(endpoints[cEid]));

    }

    function test_peers() public {
        assertEq(mA.peers(bEid), addressToBytes32(address(mB)));
        assertEq(mB.peers(aEid), addressToBytes32(address(mA)));

        assertEq(mA.peers(cEid), addressToBytes32(address(mC)));
        assertEq(mC.peers(aEid), addressToBytes32(address(mA)));

        assertEq(mB.peers(cEid), addressToBytes32(address(mC)));
        assertEq(mC.peers(bEid), addressToBytes32(address(mB)));
    }

    function test_aggregate_ordered() public {

        Multicall.Call[] memory _calls = new Multicall.Call[](2);
        _calls[0] = Multicall.Call(address(tB), abi.encodeWithSignature("setValue(uint256)", 5), true, 0 ether, bEid);
        _calls[1] = Multicall.Call(address(tC), abi.encodeWithSignature("setValue(uint256)", 10), true, 0 ether, cEid);

        uint256 nativeFee = mA.quoteAggregate(_calls, DeliveryCode.ORDERED_DELIVERY, 500000);

        mA.lzAggregate{value : nativeFee}(_calls, DeliveryCode.ORDERED_DELIVERY, 500000);

        verifyPackets(bEid, addressToBytes32((address(mB))));
        verifyPackets(cEid, addressToBytes32((address(mC))));

        assertEq(tB.value(), 5);
        assertEq(tC.value(), 10);
    }
}