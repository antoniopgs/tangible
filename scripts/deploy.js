require("@nomiclabs/hardhat-ethers");
const { ethers } = require("hardhat");

const getMnemonicTeam = async () => {

  // Get tangibleTeam
  const tangibleTeamAddress = ethers.Wallet.fromMnemonic(process.env.MNEMONIC).address;

  // Return fungifyTeam signer
  return (await ethers.getSigner(tangibleTeamAddress));
}

const deployContract = async (_factoryName, _signer, _constructorParams = null) => {

  console.log(`Deploying ${Factory}...`);
  console.log("Getting Factory...");

  // Get Factory
  const Factory = await ethers.getContractFactory(_factoryName);

  console.log("Deploying Contract...");

  // Deploy & return contract
  const contract = await Factory.connect(_signer).deploy(_constructorParams);

  console.log(`Contract deployed at ${contract.address}`);
  console.log("");

  return contract;
}

module.exports = deploy = async () => {

  // ---------- MAIN ----------

  // Get team
  // const team = await getMnemonicFungifyTeam();
  const team = await ethers.getSigner();

  // proxy
  const proxy = await deployContract("ProtocolProxy", team);

  // ---------- TOKENS ----------
  const mockUsdc = await deployContract("MockUsd", team);
  const tUsdcDefaultOperators = [ proxy.address ];
  const tUsdc = deployContract("tUsdc", team, tUsdcDefaultOperators);
  const tangibleNft = await deployContract("TangibleNft", team);

  // ---------- INITIALIZE ----------

  // Initialize proxy
  proxy.connect(team).initialize(mockUsdc.address, tUsdc.address, tangibleNft.address);

  // ---------- IMPLEMENTATIONS ----------
  const auctions = await deployContract("Auctions", team);
  const automation = await deployContract("Automation", team);
  // const borrowing = await deployContract("Borrowing", team);
  const interest = await deployContract("Interest", team);
  const lending = await deployContract("Lending", team);

  // ---------- BID ACCEPTANCE IMPLEMENTATIONS ----------
  const acceptNone = await deployContract("AcceptNone", team);
  const acceptMortgage = await deployContract("AcceptMortgage", team);
  const acceptDefault = await deployContract("AcceptDefault", team);
  const acceptForeclosurable = await deployContract("AcceptForeclosurable", team);

  // ---------- SELECTORS ------------

  // Auctions
  const auctionSelectors = [
    Auctions.interface.getSighash("bid"),
    Auctions.interface.getSighash("cancelBid"),
    Auctions.interface.getSighash("acceptBid")
  ];
  proxy.connect(team).setSelectorsTarget(auctionSelectors, auctions.address);

  // Automation
  const automationSelectors = [
    Borrowing.interface.getSighash("startLoan"),
    Borrowing.interface.getSighash("payLoan"),
    Borrowing.interface.getSighash("redeemLoan"),
    Borrowing.interface.getSighash("utilization"),
    Borrowing.interface.getSighash("status"),
    Borrowing.interface.getSighash("lenderApy"),
    Automation.interface.getSighash("findHighestActionableBidIdx")
  ];
  proxy.connect(team).setSelectorsTarget(automationSelectors, automation.address);

  // Borrowing
  // const borrowingSelectors = [];
  // proxy.connect(team).setSelectorsTarget(borrowingSelectors, borrowing.address);

  // Interest
  const interestSelectors = [
    Interest.interface.getSighash("borrowerRatePerSecond"),
  ];
  proxy.connect(team).setSelectorsTarget(interestSelectors, interest.address);
  
  // Lending
  const lendingSelectors = [
    Lending.interface.getSighash("deposit"),
    Lending.interface.getSighash("withdraw"),
    Lending.interface.getSighash("usdcToTUsdc")
  ];
  proxy.connect(team).setSelectorsTarget(lendingSelectors, lending.address);

  // ---------- BID ACCEPTANCE SELECTORS ----------

  // acceptNoneSelectors
  const acceptNoneSelectors = [ AcceptDefault.interface.getSighash("acceptNoneBid") ];
  proxy.connect(team).setSelectorsTarget(acceptNoneSelectors, acceptNone.address);

  // acceptMortgageSelectors
  const acceptMortgageSelectors = [ AcceptDefault.interface.getSighash("acceptMortgageBid") ];
  proxy.connect(team).setSelectorsTarget(acceptMortgageSelectors, acceptMortgage.address);

  // acceptDefaultSelectors
  const acceptDefaultSelectors = [ AcceptDefault.interface.getSighash("acceptDefaultBid") ];
  proxy.connect(team).setSelectorsTarget(acceptDefaultSelectors, acceptDefault.address);

  // acceptForeclosurableSelectors
  const acceptForeclosurableSelectors = [ AcceptForeclosurable.interface.getSighash("acceptForeclosurableBid") ];
  proxy.connect(team).setSelectorsTarget(acceptForeclosurableSelectors, acceptForeclosurable.address);

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