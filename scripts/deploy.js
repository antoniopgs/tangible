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

  // ---------- MAIN ----------

  // Get team
  const team = await getMnemonicTeam();
  // const team = await ethers.getSigner();

  // proxy
  const proxy = await deployContract("ProtocolProxy", team);

  // ---------- TOKENS ----------
  const mockUsdc = await deployContract("MockUsdc", team);
  const tUsdcDefaultOperators = [ proxy.address ];
  const tUsdc = await deployContract("tUsdc", team, tUsdcDefaultOperators);
  const tangibleNft = await deployContract("TangibleNft", team, proxy.address);

  // ---------- INITIALIZE ----------

  // Initialize proxy
  await proxy.connect(team).initialize(mockUsdc.address, tUsdc.address, tangibleNft.address);

  // ---------- IMPLEMENTATIONS ----------
  const auctions = await deployContract("Auctions", team);
  const automation = await deployContract("Automation", team);
  // const borrowing = await deployContract("Borrowing", team);
  const interest = await deployContract("Interest", team);
  const lending = await deployContract("Lending", team);
  const getter = await deployContract("Getter", team);

  // ---------- BID ACCEPTANCE IMPLEMENTATIONS ----------
  const acceptNone = await deployContract("AcceptNone", team);
  const acceptMortgage = await deployContract("AcceptMortgage", team);
  const acceptDefault = await deployContract("AcceptDefault", team);
  const acceptForeclosurable = await deployContract("AcceptForeclosurable", team);

  // ---------- SELECTORS ------------

  // Auctions
  console.log("");
  console.log("setting auctionSelectors...");
  const Auctions = await ethers.getContractFactory("Auctions");
  const auctionSelectors = [
    Auctions.interface.getSighash("bid"),
    Auctions.interface.getSighash("cancelBid"),
    Auctions.interface.getSighash("acceptBid")
  ];
  await proxy.connect(team).setSelectorsTarget(auctionSelectors, auctions.address);
  console.log("auctionSelectors set.");

  // Automation
  console.log("");
  console.log("setting automationSelectors...");
  const Automation = await ethers.getContractFactory("Automation");
  const automationSelectors = [
    Automation.interface.getSighash("startLoan"),
    Automation.interface.getSighash("payLoan"),
    Automation.interface.getSighash("redeemLoan"),
    Automation.interface.getSighash("utilization"),
    Automation.interface.getSighash("status"),
    Automation.interface.getSighash("findHighestActionableBidIdx")
  ];
  await proxy.connect(team).setSelectorsTarget(automationSelectors, automation.address);
  console.log("automationSelectors set.");

  // Borrowing
  // console.log("setting borrowingSelectors...");
  // const borrowingSelectors = [];
  // await proxy.connect(team).setSelectorsTarget(borrowingSelectors, borrowing.address);

  // Interest
  console.log("");
  console.log("setting interestSelectors...");
  const Interest = await ethers.getContractFactory("Interest");
  const interestSelectors = [
    Interest.interface.getSighash("borrowerRatePerSecond"),
  ];
  await proxy.connect(team).setSelectorsTarget(interestSelectors, interest.address);
  console.log("interestSelectors set.");
  
  // Lending
  console.log("");
  console.log("setting lendingSelectors...");
  const Lending = await ethers.getContractFactory("Lending");
  const lendingSelectors = [
    Lending.interface.getSighash("deposit"),
    Lending.interface.getSighash("withdraw"),
    Lending.interface.getSighash("usdcToTUsdc")
  ];
  await proxy.connect(team).setSelectorsTarget(lendingSelectors, lending.address);
  console.log("lendingSelectors set.");

  // Getter
  console.log("");
  console.log("setting getterSelectors...");
  const Getter = await ethers.getContractFactory("Getter");
  const getterSelectors = [
    Getter.interface.getSighash("loans"),
    Getter.interface.getSighash("bids"),
    Getter.interface.getSighash("availableLiquidity"),
    Getter.interface.getSighash("myLoans"),
    Getter.interface.getSighash("myBids"),
    Getter.interface.getSighash("loansTokenIdsLength"),
    Getter.interface.getSighash("loansTokenIdsAt"),
    Getter.interface.getSighash("redemptionFeeSpread"),
    Getter.interface.getSighash("defaultFeeSpread"),
    Getter.interface.getSighash("accruedInterest"),
    Getter.interface.getSighash("lenderApy"),
    Getter.interface.getSighash("tUsdcToUsdc"),
  ];
  await proxy.connect(team).setSelectorsTarget(getterSelectors, getter.address);
  console.log("getterSelectors set.");

  // ---------- BID ACCEPTANCE SELECTORS ----------

  // acceptNoneSelectors
  console.log("");
  console.log("setting acceptNoneSelectors...");
  const AcceptNone = await ethers.getContractFactory("AcceptNone");
  const acceptNoneSelectors = [ AcceptNone.interface.getSighash("acceptNoneBid") ];
  await proxy.connect(team).setSelectorsTarget(acceptNoneSelectors, acceptNone.address);
  console.log("acceptNoneSelectors set.");

  // acceptMortgageSelectors
  console.log("");
  console.log("setting acceptMortgageSelectors...");
  const AcceptMortgage = await ethers.getContractFactory("AcceptMortgage");
  const acceptMortgageSelectors = [ AcceptMortgage.interface.getSighash("acceptMortgageBid") ];
  await proxy.connect(team).setSelectorsTarget(acceptMortgageSelectors, acceptMortgage.address);
  console.log("acceptMortgageSelectors set.");

  // acceptDefaultSelectors
  console.log("");
  console.log("setting acceptDefaultSelectors...");
  const AcceptDefault = await ethers.getContractFactory("AcceptDefault");
  const acceptDefaultSelectors = [ AcceptDefault.interface.getSighash("acceptDefaultBid") ];
  await proxy.connect(team).setSelectorsTarget(acceptDefaultSelectors, acceptDefault.address);
  console.log("acceptDefaultSelectors set.");

  // acceptForeclosurableSelectors
  console.log("");
  console.log("setting acceptForeclosurableSelectors...");
  const AcceptForeclosurable = await ethers.getContractFactory("AcceptForeclosurable");
  const acceptForeclosurableSelectors = [ AcceptForeclosurable.interface.getSighash("acceptForeclosurableBid") ];
  await proxy.connect(team).setSelectorsTarget(acceptForeclosurableSelectors, acceptForeclosurable.address);
  console.log("acceptForeclosurableSelectors set.");

  return {
    team: team,
    proxy: proxy,
    tokens: {
      mockUsdc: mockUsdc,
      tUsdc: tUsdc,
      tangibleNft: tangibleNft
    },
    auctions: auctions,
    automation: automation,
    // borrowing: borrowing,
    interest: interest,
    lending: lending,
    acceptNone: acceptNone,
    acceptMortgage: acceptMortgage,
    acceptDefault: acceptDefault,
    acceptForeclosurable: acceptForeclosurable
  }
}