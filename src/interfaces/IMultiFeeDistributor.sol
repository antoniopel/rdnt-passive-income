pragma solidity >=0.8.19;

interface IMultiFeeDistributor {
    function getReward(address[] memory _rewardTokens) external;
}

interface Controller {
    function withdraw(address asset, uint256 amount, address to) external;
}

interface aToken {
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}

struct lzTxObj {
        uint256 dstGasForCall;
        uint256 dstNativeAmount;
        bytes dstNativeAddr;
}

interface StargateRouter {
        function swap(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address payable _refundAddress,
        uint256 _amountLD,
        uint256 _minAmountLD,
        lzTxObj memory _lzTxParams,
        bytes calldata _to,
        bytes calldata _payload
    ) external payable;

    function quoteLayerZeroFee(
        uint16 _dstChainId,
        uint8 _functionType,
        bytes calldata _toAddress,
        bytes calldata _transferAndCallPayload,
        lzTxObj memory _lzTxParams
    ) external view returns (uint256, uint256);
}