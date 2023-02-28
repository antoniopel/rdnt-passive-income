// script/shared/Base.s.sol
pragma solidity >=0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IMultiFeeDistributor, Controller, aToken, lzTxObj, StargateRouter} from "../src/interfaces/IMultiFeeDistributor.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

abstract contract BaseScript is Script {
    address internal deployer;

    function setUp() public virtual {
        uint256 privKey = vm.envUint("PRIV");
        deployer = vm.rememberKey(privKey);
    }

    modifier broadcaster() {
        vm.startBroadcast(deployer);
        console.log("deployer: %s", deployer);
        _;
        vm.stopBroadcast();
    }
}

contract RDC is BaseScript {
    address internal feeDistributor =
        0xc2054A8C33bfce28De8aF4aF548C48915c455c13;
    address internal controller = 0x2032b9A8e9F7e76768CA9271003d3e43E1616B1F;
    address internal sushiRouter = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
    address internal constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address internal constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant stargateRouter =
        0x53Bf833A5d6c4ddA888F69c22C88C9f356a41614;
    address internal destinationWallet;

    function _withdraw(address _asset) internal {
        Controller(controller).withdraw(_asset, type(uint256).max, deployer);
    }

    function run() external broadcaster returns (uint256 _usdcOutput) {
        destinationWallet = vm.envAddress("DESTINATION_WALLET");
        address[] memory _rewardTokens = new address[](6);
        _rewardTokens[0] = 0x0C4681e6C0235179ec3D4F4fc4DF3d14FDD96017;
        _rewardTokens[1] = 0x5293c6CA56b8941040b8D18f557dFA82cF520216;
        _rewardTokens[2] = 0x805ba50001779CeD4f59CfF63aea527D12B94829;
        _rewardTokens[3] = 0xEf47CCC71EC8941B67DC679D1a5f78fACfD0ec3C;
        _rewardTokens[4] = 0x15b53d277Af860f51c3E6843F8075007026BBb3a;
        _rewardTokens[5] = 0x4cD44E6fCfA68bf797c65889c74B26b8C2e5d4d3;

        uint256[] memory _balancesBefore = new uint256[](_rewardTokens.length);
        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            _balancesBefore[i] = IERC20(_rewardTokens[i]).balanceOf(deployer);
        }

        uint256 _output = IERC20(USDC).balanceOf(deployer);

        IMultiFeeDistributor(feeDistributor).getReward(_rewardTokens);

        uint256[] memory _balancesAfter = new uint256[](_rewardTokens.length);
        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            _balancesAfter[i] = IERC20(_rewardTokens[i]).balanceOf(deployer);
            console.log(
                "Reward %s:\t%s",
                IERC20(_rewardTokens[i]).symbol(),
                _balancesAfter[i] - _balancesBefore[i]
            );
            console.log("====================");
        }

        address[] memory _tokens = new address[](_rewardTokens.length);
        uint256[] memory _amounts = new uint256[](_rewardTokens.length);
        _tokens[0] = _rewardTokens[0];
        _amounts[0] = _balancesAfter[0] - _balancesBefore[0];

        for (uint256 i = 1; i < _rewardTokens.length; i++) {
            _tokens[i] = aToken(_rewardTokens[i]).UNDERLYING_ASSET_ADDRESS();
            uint256 _balanceBefore = IERC20(_tokens[i]).balanceOf(deployer);
            _withdraw(_tokens[i]);
            _amounts[i] =
                IERC20(_tokens[i]).balanceOf(deployer) -
                _balanceBefore;
        }

        for (uint256 i = 0; i < _tokens.length; i++) {
            console.log(
                "Token %s:\t%s",
                IERC20(_tokens[i]).symbol(),
                _amounts[i]
            );
            console.log("====================");
        }


        for (uint256 i = 0; i < _tokens.length; i++) {
            if (_tokens[i] == USDC || _amounts[i] == 0) continue;
            uint256 _usdcBalanceBefore = IERC20(USDC).balanceOf(deployer);
            IERC20(_tokens[i]).approve(sushiRouter, _amounts[i]);
            address[] memory _path;
            if (_tokens[i] == WETH) {
                _path = new address[](2);
                _path[0] = WETH;
                _path[1] = USDC;
            } else {
                _path = new address[](3);  
                _path[0] = _tokens[i];
                _path[1] = WETH;
                _path[2] = USDC;
            }
            IUniswapV2Router02(sushiRouter).swapExactTokensForTokens(
                _amounts[i],
                1,
                _path,
                deployer,
                block.timestamp + 1000
            );
            uint256 _usdcBalanceAfter = IERC20(USDC).balanceOf(deployer);
            console.log(
                "Swap %s for USDC:\t%s",
                IERC20(_tokens[i]).symbol(),
                (_usdcBalanceAfter - _usdcBalanceBefore) / 1e6
            );
        }

        _output = IERC20(USDC).balanceOf(deployer) - _output;

        console.log("Output: %s USDC", _output);

        // approve stargate router
        IERC20(USDC).approve(stargateRouter, _output);

        lzTxObj memory _obj;
        _obj.dstGasForCall = 0;
        _obj.dstNativeAmount = 0;
        _obj.dstNativeAddr = abi.encodePacked(
            0x0000000000000000000000000000000000000001
        );

        (uint256 _fee, ) = StargateRouter(stargateRouter).quoteLayerZeroFee(
            101,
            3,
            abi.encodePacked(destinationWallet),
            abi.encodePacked(""),
            lzTxObj({
                dstGasForCall: 0,
                dstNativeAmount: 0,
                dstNativeAddr: abi.encodePacked(0x0000000000000000000000000000000000000001)
            })
        );

        StargateRouter(stargateRouter).swap{value: _fee}(
            101,
            1,
            1,
            payable(deployer),
            _output,
            (_output * 95) / 100,
            _obj,
            abi.encodePacked(destinationWallet),
            abi.encodePacked("")
        );

        _usdcOutput = _output;
    }
}
