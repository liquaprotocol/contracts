// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MainnetHelper {
    // Supported Networks
    enum SupportedNetworks {
        ETHEREUM,
        OPTIMISM,
        AVALANCHE,
        ARBITRUM,
        POLYGON,
        BNB_CHAIN,
        BASE
    }

    mapping(SupportedNetworks enumValue => string humanReadableName)
        public networks;

    enum PayFeesIn {
        Native,
        LINK
    }

    // Chain IDs
    uint64 constant chainIdEthereum = 5009297550715157269;
    uint64 constant chainIdOptimism = 3734403246176062136;
    uint64 constant chainIdAvalanche = 6433500567565415381;
    uint64 constant chainIdArbitrum = 4949039107694359620;
    uint64 constant chainIdPolygon = 4051577828743386545;
    uint64 constant chainIdBnbChain = 11344663589394136015;
    uint64 constant chainIdBase = 15971525489660198786;

    // Router addresses
    address constant routerEthereum =
        0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D;
    address constant routerOptimism =
        0x3206695CaE29952f4b0c22a169725a865bc8Ce0f;
    address constant routerAvalanche =
        0xF4c7E640EdA248ef95972845a62bdC74237805dB;
    address constant routerArbitrum =
        0x141fa059441E0ca23ce184B6A78bafD2A517DdE8;
    address constant routerPolygon =
        0x849c5ED5a80F5B408Dd4969b78c2C8fdf0565Bfe;
    address constant routerBnbChain =
        0x34B03Cb9086d7D758AC55af71584F81A598759FE;
    address constant routerBase =
        0x881e3A65B4d4a04dD529061dd0071cf975F58bCD;


    // Link addresses (can be used as fee)
    address constant linkEthereum =
        0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address constant linkOptimism =
        0x350a791Bfc2C21F9Ed5d10980Dad2e2638ffa7f6;
    address constant linkAvalanche =
        0x5947BB275c521040051D82396192181b413227A3;
    address constant linkArbitrum =
        0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    address constant linkPolygon =
        0xb0897686c545045aFc77CF20eC7A532E3120E0F1;
    address constant linkBnbChain =
        0x404460C6A5EdE2D891e8297795264fDe62ADBB75;
    address constant linkBase =
        0x88Fb150BDc53A65fe94Dea0c9BA0a6dAf8C6e196;

    // USDC
    address constant usdcEthereum =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant usdcOptimism =
        0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
    address constant usdcAvalanche =
        0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E; //
    address constant usdcArbitrum =
        0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address constant usdcPolygon =
        0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    address constant usdcBnbChain =
        0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359; // FIXME: No usdc on BNB chain
    address constant usdcBase =
        0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;


    function getLiquaGatewayDeployConfig(SupportedNetworks network)
        public
        pure
        returns (
            uint64 chainId,
            address router,
            address link,
            address usdc
        )
    {
        if (network == SupportedNetworks.ETHEREUM) {
            return (chainIdEthereum, routerEthereum, linkEthereum, usdcEthereum);
        } else if (network == SupportedNetworks.OPTIMISM) {
            return (chainIdOptimism, routerOptimism, linkOptimism, usdcOptimism);
        } else if (network == SupportedNetworks.AVALANCHE) {
            return (chainIdAvalanche, routerAvalanche, linkAvalanche, usdcAvalanche);
        } else if (network == SupportedNetworks.ARBITRUM) {
            return (chainIdArbitrum, routerArbitrum, linkArbitrum, usdcArbitrum);
        } else if (network == SupportedNetworks.POLYGON) {
            return (chainIdPolygon, routerPolygon, linkPolygon, usdcPolygon);
        } else if (network == SupportedNetworks.BNB_CHAIN) {
            return (chainIdBnbChain, routerBnbChain, linkBnbChain, usdcBnbChain);
        } else {
            return (chainIdBase, routerBase, linkBase, usdcBase);
        }
    }

}
