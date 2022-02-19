// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import './IDEXFactory.sol';
import './Auth.sol';
import './DividendDistributor.sol';
import './DEXAVAXRouter.sol';
import './CheckBal.sol';


contract EVB is IBEP20, Auth {
  using SafeMath for uint256;

  uint256 public constant MASK = type(uint128).max;

  bool isAVAX = false;

  // AVAX mainnet: 0x60aE616a2155Ee3d9A68541Ba4544862310933d4
  // Rinkeby: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
  address constant ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

  // AVAX mainnet WAVAX: 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7
  // Rinkeby WETH: 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6
  address public WAVAX = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
  // ********************************************************************************
  //USDT - AVAX 0xc7198437980c041c805A1EDcbA50c1Ce5db95118
  address public PrintToken1 = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6; // Token 1
  
  address DEAD = 0x000000000000000000000000000000000000dEaD;
  address ZERO = 0x0000000000000000000000000000000000000000;


  address DexPoolAddress1 = ZERO;   //set DEX Pair Address for taxes
  address DexPoolAddress2 = ZERO;   //set DEX Pair Address for taxes
  address PairAddress = ZERO;  //Debug DEX
  
  bool useCoupon = true;
  
  address[] CouponAddress;
  mapping (address => uint256) CouponDiscount;
  mapping (address => uint256) CouponMinHolding;
  uint256 CouponMax = 50;

  string constant _name = 'ET4';
  string constant _symbol = 'ET4';
  uint8 constant _decimals = 18;

  uint256 _totalSupply = 1_000_000_000 * (10**_decimals);
  uint256 public _maxTxAmount = _totalSupply.div(1); // 2,5%  - launch 100 %
  uint256 public _maxWallet = _totalSupply.div(1); // 2,5% - launch 100%

  mapping(address => uint256) _balances;
  mapping(address => mapping(address => uint256)) _allowances;

  mapping(address => bool) isFeeExempt;
  mapping(address => bool) isTxLimitExempt;
  mapping(address => bool) isDividendExempt;
  mapping(address => bool) public _isFree;

  bool public transferEnabled = true;

  uint256 liquidityFee = 20; //2%
  
  uint256 marketingFee = 30; //2%
  
  uint256 SellReflectionFee = 100;    
  uint256 BuyReflectionFee = 0; 
  uint256 TransferReflectionFee = 0; 

  uint256 totalFee = 150; //total minus Burn
  uint256 feeDenominator = 1000; 
  
  uint256 burnFee = 50; //not included in totalfee
  uint256 burnFeeBuy = 30; 

  address public autoLiquidityReceiver = 0x58E9242ce35FF3f17D69caB17bF50E3d6e3Bb7b4;
  address public marketingFeeReceiver = 0x58E9242ce35FF3f17D69caB17bF50E3d6e3Bb7b4;

  uint256 targetLiquidity = 10;
  uint256 targetLiquidityDenominator = 100;

  IDEXRouter public router;
  address public pair;

  uint256 public launchedAt;
  uint256 public launchedAtTimestamp;


  DividendDistributor distributor;
  address public distributorAddress;
  uint256 distributorGas = 500000;

  bool public swapEnabled = true;
  uint256 public swapPercentMax = 99; // % of amount swap
  uint256 public swapThresholdMax = _totalSupply / 50; // 2%
  bool inSwap;
  modifier swapping() {
    inSwap = true;
    _;
    inSwap = false;
  }

  constructor() Auth(msg.sender) {
    uint256 MAX = ~uint256(0);
    router = isAVAX ? new DEXAVAXRouter(ROUTER) : IDEXRouter(ROUTER);
    pair = IDEXFactory(router.factory()).createPair(WAVAX, address(this));
    _allowances[address(this)][ROUTER] = MAX;
    _allowances[address(this)][address(router)] = MAX;
    WAVAX = router.WETH();
    distributor = new DividendDistributor(address(router), WAVAX, PrintToken1);
    distributorAddress = address(distributor);


    isFeeExempt[msg.sender] = true;
    isTxLimitExempt[msg.sender] = true;
    isDividendExempt[pair] = true;
    isDividendExempt[address(this)] = true;
    isDividendExempt[DEAD] = true;
    

    autoLiquidityReceiver = msg.sender;

    approve(ROUTER, MAX);
    approve(address(router), MAX);
    approve(address(pair), MAX);
    _balances[msg.sender] = _totalSupply;
    emit Transfer(address(0), msg.sender, _totalSupply);
  }

  receive() external payable {}

  function totalSupply() external view override returns (uint256) {
    return _totalSupply;
  }

  function decimals() external pure override returns (uint8) {
    return _decimals;
  }

  function symbol() external pure override returns (string memory) {
    return _symbol;
  }

  function name() external pure override returns (string memory) {
    return _name;
  }

  function getOwner() external view override returns (address) {
    return owner;
  }

  function getPrintToken1() external view  returns (address) {
    return PrintToken1;
  }
 
  function getDexPoolAddress1() external view  returns (address) {
    return DexPoolAddress1;
  }

    function getDexPoolAddress2() external view  returns (address) {
    return DexPoolAddress2;
  }

    function getCouponAddress(uint256 _index) external view  returns (address) {
      address result = CouponAddress[_index];
    return result;
  }



    function getCouponDiscount(address _address) external view  returns (uint256) {
    return CouponDiscount[_address];
  }

    function getCouponMinHolding(address _address) external view  returns (uint256) {
    return CouponMinHolding[_address];
  }

  function getPairAddress() external view  returns (address) {
    return PairAddress;
  }

  function getCouponMax() external view returns (uint256) {
    return CouponMax ;

  }

  function balanceOf(address account) public view override returns (uint256) {
    return _balances[account];
  }
  function allowance(address holder, address spender)
    external
    view
    override
    returns (uint256)
  {
    return _allowances[holder][spender];
  }

  function approve(address spender, uint256 amount)
    public
    override
    returns (bool)
  {
    _allowances[msg.sender][spender] = amount;
    emit Approval(msg.sender, spender, amount);
    return true;
  }

  function approveMax(address spender) external returns (bool) {
    return approve(spender, _totalSupply);
  }

  function transfer(address recipient, uint256 amount)
    external
    override
    returns (bool)
  {
    return _transferFrom(msg.sender, recipient, amount);
  }

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) external override returns (bool) {
    if (_allowances[sender][msg.sender] != _totalSupply) {
      _allowances[sender][msg.sender] = _allowances[sender][msg.sender].sub(
        amount,
        'Insufficient Allowance'
      );
    }
   return _transferFrom(sender, recipient, amount);
  }

  function _transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) internal returns (bool) {
    require(
      transferEnabled || isAuthorized(msg.sender) || isAuthorized(sender),
      'Transfer is enabled or user is authorized'
    );

    if (inSwap) {
      return _basicTransfer(sender, recipient, amount);
    }

    bool isSell = recipient == pair || recipient == ROUTER || recipient == DexPoolAddress1 || recipient == DexPoolAddress2;

    checkTxLimit(sender, amount);

      if (!isSell && !_isFree[recipient]) {
      require(
        (_balances[recipient] + amount) < _maxWallet,
        'Max wallet has been triggered'
      );
    }
   
    if (isSell) {
      if (shouldSwapBack(amount)) {
        swapBack(balanceOf(address(this)).mul(swapPercentMax).div(100));
      }
    
    }
    
    _balances[sender] = _balances[sender].sub(amount, 'Insufficient Balance');

    uint256 amountReceived = shouldTakeFee(sender)
      ? takeFee(sender, recipient, amount)
      : amount;

    _balances[recipient] = _balances[recipient].add(amountReceived);

    if (!isDividendExempt[sender]) {
      try distributor.setShare(sender, _balances[sender]) {} catch {}
   
    }
    if (!isDividendExempt[recipient]) {
      try distributor.setShare(recipient, _balances[recipient]) {} catch {}
     
    }

    try distributor.process(distributorGas) {} catch {}

    emit Transfer(sender, recipient, amountReceived);
    return true;
  }

  function _basicTransfer(
    address sender,
    address recipient,
    uint256 amount
  ) internal returns (bool) {
    _balances[sender] = _balances[sender].sub(amount, 'Insufficient Balance');
    _balances[recipient] = _balances[recipient].add(amount);
    return true;
  }

  function checkTxLimit(address sender, uint256 amount) internal view {
    require(
      amount <= _maxTxAmount || isTxLimitExempt[sender],
      'TX Limit Exceeded'
    );
  }

  function shouldTakeFee(address sender) internal view returns (bool) {
    return !isFeeExempt[sender];
  }

  function takeFee(
    address sender,
    address receiver,
    uint256 amount
    
  ) internal returns (uint256) {
    uint256 feeAmount;
    uint256 modRefTax;
    uint256 burnAmount = amount.mul(burnFee).div(feeDenominator);
    uint256 burnAmountBuy = amount.mul(burnFeeBuy).div(feeDenominator);
    Checker ApplyCoupon;
    bool CouponExists = false;
    uint256 CouponTotal = 0;
    address SenderAddress = sender;
    
    bool isSell = receiver == DexPoolAddress1 || receiver == DexPoolAddress2;
    bool isBuy = sender == DexPoolAddress1 || sender == DexPoolAddress2; 

    if (isSell && useCoupon) {
      for (uint i=0; i < CouponAddress.length; i++)
       {
           if(ApplyCoupon.checkBal(CouponAddress[i],SenderAddress,CouponMinHolding[CouponAddress[i]]))
           {
              CouponExists = true;
              CouponTotal.add(CouponDiscount[CouponAddress[i]]);
            }
       }
     
      if (CouponExists) {
        if (CouponTotal > CouponMax ){CouponTotal = CouponMax ;} //max Discount is CouponMax 
        modRefTax = liquidityFee + marketingFee + SellReflectionFee.sub(CouponTotal);
        feeAmount = amount.mul(modRefTax).div(feeDenominator);}
    }

    setFindDexPair(sender);  //debug

    if (isBuy){  //BUY TAX

        feeAmount = amount.mul(BuyReflectionFee).div(feeDenominator);
          
        _balances[DEAD] = _balances[DEAD].add(burnAmountBuy);
        emit Transfer(sender, DEAD, burnAmountBuy);

        _balances[address(this)] = _balances[address(this)].add(feeAmount);
        emit Transfer(sender, address(this), feeAmount);

        emit Transfer(sender, DEAD, 1000000000000000000); //debug burn 1

        return amount.sub(feeAmount).sub(burnAmountBuy);
    
    } 
    else if (isSell){  //SELL TAX
          if (CouponExists) {
            feeAmount = amount.mul(modRefTax).div(feeDenominator);
          }
          else {
            feeAmount = amount.mul(totalFee).div(feeDenominator);
          }
        _balances[DEAD] = _balances[DEAD].add(burnAmount);
        emit Transfer(sender, DEAD, burnAmount);

        _balances[address(this)] = _balances[address(this)].add(feeAmount);
        emit Transfer(sender, address(this), feeAmount);
        
        emit Transfer(sender, DEAD, 2000000000000000000);  //debug burn 2
        return amount.sub(feeAmount).sub(burnAmount); 
    
    }
   
    else {  //Transfer TAX - No Burn
        feeAmount = amount.mul(TransferReflectionFee).div(feeDenominator);

        _balances[address(this)] = _balances[address(this)].add(feeAmount);
        emit Transfer(sender, address(this), feeAmount);
    
    return amount.sub(feeAmount);
    }
 
  }

  function getSwapAmount(uint256 _transferAmount)
    public
    view
    returns (uint256)
  {
    uint256 amountFromTxnPercMax = _transferAmount.mul(swapPercentMax).div(100);
    return
      amountFromTxnPercMax > swapThresholdMax
        ? swapThresholdMax
        : amountFromTxnPercMax;
  }

  function shouldSwapBack(uint256 _transferAmount)
    internal
    view
    returns (bool)
  {
    return
      msg.sender != pair &&
      !inSwap &&
      swapEnabled &&
      _balances[address(this)] >= getSwapAmount(_transferAmount);
  }

  function swapBack(uint256 _transferAmount) internal swapping {
    uint256 dynamicLiquidityFee = isOverLiquified(
      targetLiquidity,
      targetLiquidityDenominator
    )
      ? 0
      : liquidityFee;
    uint256 swapAmount = getSwapAmount(_transferAmount);
    uint256 amountToLiquify = swapAmount
      .mul(dynamicLiquidityFee)
      .div(totalFee)
      .div(2);
    uint256 amountToSwap = swapAmount.sub(amountToLiquify);

    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = WAVAX;
    uint256 balanceBefore = address(this).balance;

    _checkAndApproveTokensForRouter(amountToSwap);
    router.swapExactTokensForETHSupportingFeeOnTransferTokens(
      amountToSwap,
      0,
      path,
      address(this),
      block.timestamp
    );

    uint256 amountAVAX = address(this).balance.sub(balanceBefore);

    uint256 totalAVAXFee = totalFee.sub(dynamicLiquidityFee.div(2));

    uint256 amountAVAXLiquidity = amountAVAX
      .mul(dynamicLiquidityFee)
      .div(totalAVAXFee)
      .div(2);
    uint256 amountAVAXReflection = amountAVAX.mul(BuyReflectionFee).div(
      totalAVAXFee
    );
    uint256 amountAVAXMarketing = amountAVAX.mul(marketingFee).div(
      totalAVAXFee
    );


  try distributor.deposit{value: amountAVAXReflection}() {} catch {}
    payable(marketingFeeReceiver).transfer(amountAVAXMarketing);
  

    if (amountToLiquify > 0) {
      _checkAndApproveTokensForRouter(amountToLiquify);
      router.addLiquidityETH{ value: amountAVAXLiquidity }(
        address(this),
        amountToLiquify,
        0,
        0,
        autoLiquidityReceiver,
        block.timestamp
      );
      emit AutoLiquify(amountAVAXLiquidity, amountToLiquify);
    }
  }

  function enableTransfer() external authorized {
    transferEnabled = true;
  }


  function buyTokens(uint256 amount, address to) internal swapping {
    address[] memory path = new address[](2);
    path[0] = WAVAX;
    path[1] = address(this);

    router.swapExactETHForTokensSupportingFeeOnTransferTokens{ value: amount }(
      0,
      path,
      to,
      block.timestamp
    );
  }

  function Sweep() external onlyOwner { 
      uint256 balance = address(this).balance;
      payable(msg.sender).transfer(balance);
  }

  function EnableCoupon(
    bool _bool, 
    uint256 _CouponMax)
    external authorized {
      useCoupon = _bool;
      CouponMax = _CouponMax;
  }



  function AddCouponSettings(
    address  _CouponSmartContract,
    uint256 _CouponValue,
    uint256 _CouponMinHolding
    ) external authorized {
      CouponAddress.push(_CouponSmartContract);
      CouponDiscount[_CouponSmartContract] = _CouponValue;
      CouponMinHolding[_CouponSmartContract] = _CouponMinHolding;
    
    }

    function RemoveCouponSettings(
      uint256 _index
      
    ) external authorized {

        address CouponToRemove = CouponAddress[_index];
        CouponDiscount[CouponAddress[_index]] = 0;
        CouponMinHolding[CouponAddress[_index]] = 1;
        
      }

 
  function launched() internal view returns (bool) {
    return launchedAt != 0;
  }

  function launch() public authorized {
    require(launchedAt == 0, 'Already launched boi');
    launchedAt = block.number;
    launchedAtTimestamp = block.timestamp;
  }

  function setMaxWallet(uint256 amount) external authorized {
    require(amount >= _totalSupply / 1000);
    _maxWallet = amount;
  }

  function setTxLimit(uint256 amount) external authorized {
    require(amount >= _totalSupply / 1000);
    _maxTxAmount = amount;
  }

  function setIsDividendExempt(address holder, bool exempt)
    external
    authorized
  {
    require(holder != address(this) && holder != pair);
    isDividendExempt[holder] = exempt;
    if (exempt) {
      distributor.setShare(holder, 0);
    } else {
      distributor.setShare(holder, _balances[holder]);
    }
  }




  function setIsFeeExempt(address holder, bool exempt) external authorized {
    isFeeExempt[holder] = exempt;
  }

  function setIsTxLimitExempt(address holder, bool exempt) external authorized {
    isTxLimitExempt[holder] = exempt;
  }

  function setFree(address holder) public authorized {
    _isFree[holder] = true;
  }

  function unSetFree(address holder) public authorized {
    _isFree[holder] = false;
  }

  function checkFree(address holder) public view authorized returns (bool) {
    return _isFree[holder];
  }

  function setFees(
    uint256 _liquidityFee,
    
    uint256 _SellReflectionFee,
    uint256 _marketingFee,
    uint256 _feeDenominator,
    uint256 _burnFee,
    uint256 _burnFeeBuy,
    uint256 _BuyReflectionFee,
    uint256 _TransferReflectionFee
  ) external authorized {
    liquidityFee = _liquidityFee;
    
    SellReflectionFee = _SellReflectionFee;
    marketingFee = _marketingFee;
    burnFee = _burnFee;
    burnFeeBuy = _burnFeeBuy;
    BuyReflectionFee = _BuyReflectionFee;
    TransferReflectionFee = _TransferReflectionFee;
 
    totalFee = _liquidityFee.add(_SellReflectionFee);
    feeDenominator = _feeDenominator;
    require(totalFee < feeDenominator / 4);
  }

  function setFeeReceivers(
    address _autoLiquidityReceiver,
    address _marketingFeeReceiver
  ) external authorized {
    autoLiquidityReceiver = _autoLiquidityReceiver;
    marketingFeeReceiver = _marketingFeeReceiver;
  }

  function setSwapBackSettings(
    bool _enabled,
    uint256 _maxPercTransfer,
    uint256 _max
  ) external authorized {
    swapEnabled = _enabled;
    swapPercentMax = _maxPercTransfer;
    swapThresholdMax = _max;
  }

  function setTargetLiquidity(uint256 _target, uint256 _denominator)
    external
    authorized
  {
    targetLiquidity = _target;
    targetLiquidityDenominator = _denominator;
  }

  function setPrintTokens(address _PrintToken1) external authorized {
    PrintToken1 = address(_PrintToken1);

  }

  function setDexPoolAddress1(address _DexPoolAddress) external authorized {
    DexPoolAddress1 = address(_DexPoolAddress);
  }

  function setDexPoolAddress2(address _DexPoolAddress) external authorized {
    DexPoolAddress2 = address(_DexPoolAddress);
  }

  function setFindDexPair(address _PairPoolAddress) internal  {
    PairAddress  = _PairPoolAddress;
  } 

  function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution)
    external
    authorized
  {
    distributor.setDistributionCriteria(_minPeriod, _minDistribution);
  }

  function getMinPeriod() external view  returns (uint256) {
    return distributor.getMinPeriod() ;
  }

  function GetDistribution() external view  returns (uint256) {
    return distributor.GetDistribution() ;
  }

  function setDistributorSettings(uint256 gas) external authorized {
    require(gas < 750000);
    distributorGas = gas;
  }

  function getCirculatingSupply() public view returns (uint256) {
    return _totalSupply.sub(balanceOf(DEAD)).sub(balanceOf(ZERO));
  }

  function getLiquidityBacking(uint256 accuracy) public view returns (uint256) {
    return accuracy.mul(balanceOf(pair).mul(2)).div(getCirculatingSupply());
  }

  function isOverLiquified(uint256 target, uint256 accuracy)
    public
    view
    returns (bool)
  {
    return getLiquidityBacking(accuracy) > target;
  }

  function _checkAndApproveTokensForRouter(uint256 amount) private {
    if (isAVAX) {
      approve(address(router), amount);
    }
  }

  event AutoLiquify(uint256 amountAVAX, uint256 amountBOG);

}