const getMnemonicTeam = async () => {

  // Get tangibleTeam
  const teamAddress = ethers.Wallet.fromMnemonic(process.env.MNEMONIC).address;

  // Return fungifyTeam signer
  return (await ethers.getSigner(teamAddress));
}

const deployContract = async (_factoryName, _signer, _constructorParams = null) => {

  console.log("");
  console.log(`Deploying ${_factoryName}...`);
  console.log("Getting Factory...");

  // Get Factory
  const Factory = await ethers.getContractFactory(_factoryName);

  console.log("Deploying Contract...");

  // Deploy & return contract
  const contract = await Factory.connect(_signer).deploy(_constructorParams);

  console.log(`Contract deployed at ${contract.address}`);

  return contract;
}

module.exports = deploy = async () => {

  // ---------- TEAM ----------
  const team = await getMnemonicTeam();
  // const team = await ethers.getSigner();
  console.log("team.address:", team.address);
  console.log("await ethers.provider.getBalance(team.address):", await ethers.provider.getBalance(team.address))

  // ---------- MULTI-SIGS ----------
  const TANGIBLE = team;
  const GSP = team;
  const PAC = team;

  // ---------- PROXY ----------
  const proxy = await deployContract("ProtocolProxy", team);

  // ---------- IMPLEMENTATIONS ----------
  console.log("")
  console.log("deploying implementations...");

  const auctions = await deployContract("Auctions", team);
  const borrowing = await deployContract("Borrowing", team);
  const info = await deployContract("Info", team);
  const initializer = await deployContract("Initializer", team);
  const lending = await deployContract("Lending", team);
  const residents = await deployContract("Residents", team);
  const setter = await deployContract("Setter", team);

  console.log("implementations deployed.");

  // ---------- TOKENS ----------
  const mockUsdc = await deployContract("MockUsdc", team);
  const tUsdcDefaultOperators = [ proxy.address ];
  const tUsdc = await deployContract("tUsdc", team, tUsdcDefaultOperators);
  const TangibleNft = await ethers.getContractFactory("TangibleNft");
  const tangibleNft = await TangibleNft.connect(team).deploy(proxy.address);

  // ---------- SELECTORS ------------
  console.log("")
  console.log("setting selectors...");
  
  // Auctions
  console.log("");
  console.log("setting auctionSelectors...");
  const Auctions = await ethers.getContractFactory("Auctions");
  const auctionSelectors = [
    Auctions.interface.getSighash("bid"),
    Auctions.interface.getSighash("cancelBid"),
    Auctions.interface.getSighash("acceptBid"),
  ];
  await proxy.connect(team).setSelectorsTarget(auctionSelectors, auctions.address);
  console.log("auctionSelectors set.");
  
  // Borrowing
  console.log("");
  console.log("setting borrowingSelectors...");
  const Borrowing = await ethers.getContractFactory("Borrowing");
  const borrowingSelectors = [
    Borrowing.interface.getSighash("payMortgage"),
    Borrowing.interface.getSighash("redeemMortgage"),
    Borrowing.interface.getSighash("debtTransfer"),
    // Borrowing.interface.getSighash("refinance"),
    Borrowing.interface.getSighash("foreclose"),
    Borrowing.interface.getSighash("increaseOtherDebt"),
    Borrowing.interface.getSighash("decreaseOtherDebt"),
  ];
  await proxy.connect(team).setSelectorsTarget(borrowingSelectors, borrowing.address);
  console.log("borrowingSelectors set.");

  // Info
  console.log("");
  console.log("setting infoSelectors...");
  const Info = await ethers.getContractFactory("Info");
  const infoSelectors = [
    Info.interface.getSighash("totalPrincipal"),
    Info.interface.getSighash("totalDeposits"),
    Info.interface.getSighash("availableLiquidity"),
    Info.interface.getSighash("utilization"),
    Info.interface.getSighash("optimalUtilization"),
    Info.interface.getSighash("usdcToTUsdc"),
    Info.interface.getSighash("tUsdcToUsdc"),
    Info.interface.getSighash("isResident"),
    Info.interface.getSighash("addressToResident"),
    Info.interface.getSighash("residentToAddress"),
    Info.interface.getSighash("bids"),
    Info.interface.getSighash("bidsLength"),
    Info.interface.getSighash("bidActionable"),
    Info.interface.getSighash("userBids"),
    Info.interface.getSighash("minSalePrice"),
    Info.interface.getSighash("unpaidPrincipal"),
    Info.interface.getSighash("accruedInterest"),
    Info.interface.getSighash("status"),
    Info.interface.getSighash("redeemable"),
    Info.interface.getSighash("loanChart"),
    Info.interface.getSighash("maxLtv"),
    Info.interface.getSighash("maxLoanMonths"),
    Info.interface.getSighash("borrowerApr"),
    Info.interface.getSighash("redemptionWindow"),
    Info.interface.getSighash("baseSaleFeeSpread"),
    Info.interface.getSighash("interestFeeSpread"),
    Info.interface.getSighash("redemptionFeeSpread"),
    Info.interface.getSighash("defaultFeeSpread"),
  ];
  await proxy.connect(team).setSelectorsTarget(infoSelectors, info.address);
  console.log("infoSelectors set.");

  // Initializer
  console.log("");
  console.log("setting initializerSelectors...");
  const Intializer = await ethers.getContractFactory("Initializer");
  const initializerSelectors = [
    Intializer.interface.getSighash("initialize"),
  ];
  await proxy.connect(team).setSelectorsTarget(initializerSelectors, initializer.address);
  console.log("initializerSelectors set.");

  // Lending
  console.log("");
  console.log("setting lendingSelectors...");
  const Lending = await ethers.getContractFactory("Lending");
  const lendingSelectors = [
    Lending.interface.getSighash("deposit"),
    Lending.interface.getSighash("withdraw")
  ];
  await proxy.connect(team).setSelectorsTarget(lendingSelectors, lending.address);
  console.log("lendingSelectors set.");

  // Resident
  console.log("");
  console.log("setting residentsSelectors...");
  const Residents = await ethers.getContractFactory("Residents");
  const residentsSelectors = [
    Residents.interface.getSighash("verifyResident")
  ];
  await proxy.connect(team).setSelectorsTarget(residentsSelectors, residents.address);
  console.log("residentsSelectors set.");
  
  // Resident
  console.log("");
  console.log("setting setterSelectors...");
  const Setter = await ethers.getContractFactory("Setter");
  const setterSelectors = [
    Setter.interface.getSighash("updateOptimalUtilization"),
    Setter.interface.getSighash("updateMaxLtv"),
    Setter.interface.getSighash("updateMaxLoanMonths"),
    Setter.interface.getSighash("updateRedemptionWindow"),
    Setter.interface.getSighash("updateM1"),
    Setter.interface.getSighash("updateB1"),
    Setter.interface.getSighash("updateM2"),
    Setter.interface.getSighash("updateBaseSaleFeeSpread"),
    Setter.interface.getSighash("updateInterestFeeSpread"),
    Setter.interface.getSighash("updateRedemptionFeeSpread"),
    Setter.interface.getSighash("updateDefaultFeeSpread")
  ];
  await proxy.connect(team).setSelectorsTarget(setterSelectors, setter.address);
  console.log("setterSelectors set.");

  console.log("");
  console.log("all selectors set.");

  // ---------- INITIALIZE ----------
  console.log("");
  console.log("initializing...");
  const initializerProxy = initializer.attach(proxy.address);
  await initializerProxy.connect(team).initialize(mockUsdc.address, tUsdc.address, tangibleNft.address, TANGIBLE.address, GSP.address, PAC.address);
  console.log("initialized.");

  return {
    team: team,
    multiSigs: {
      tangible: TANGIBLE,
      gsp: GSP,
      pac: PAC
    },
    protocol: {
      proxy: proxy,
      implementations: {
        auctions: auctions,
        borrowing: borrowing,
        info: info,
        initializer: initializer,
        lending: lending,
        residents: residents,
        setter: setter
      }
    },
    tokens: {
      mockUsdc: mockUsdc,
      tUsdc: tUsdc,
      tangibleNft: tangibleNft
    }
  }
}