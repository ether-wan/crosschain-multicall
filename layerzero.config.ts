import { EndpointId } from '@layerzerolabs/lz-definitions'

import type { OAppOmniGraphHardhat, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'

const sepoliaContract: OmniPointHardhat = {
    eid: EndpointId.SEPOLIA_V2_TESTNET,
    contractName: 'MultiCall',
}

const baseContract: OmniPointHardhat = {
    eid: EndpointId.BASESEP_V2_TESTNET,
    contractName: 'MultiCall',
}

const arbContract: OmniPointHardhat = {
    eid: EndpointId.ARBITRUM_V2_TESTNET,
    contractName: 'MultiCall',
}

const config: OAppOmniGraphHardhat = {
    contracts: [
        {
            contract: baseContract,
        },
        {
            contract: sepoliaContract,
        },
        {
            contract: arbContract,
        },
    ],
    connections: [
        {
            from: baseContract,
            to: sepoliaContract,
        },
        {
            from: sepoliaContract,
            to: baseContract,
        },
        {
            from: sepoliaContract,
            to: arbContract,
        },
        {
            from: arbContract,
            to: sepoliaContract,
        },
        {
            from: baseContract,
            to: arbContract,
        },
        {
            from: arbContract,
            to: baseContract,
        },
    ],
}

export default config
