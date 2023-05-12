const getMnemonicTeam = async () => {

  // Get tangibleTeam
  const tangibleTeamAddress = ethers.Wallet.fromMnemonic(process.env.MNEMONIC).address;

  // Return fungifyTeam signer
  return (await ethers.getSigner(tangibleTeamAddress));
}

module.exports = deploy = async () => {

  // ---------- MAIN ----------

  // Get team
  // const team = await getMnemonicFungifyTeam();
  const team = await ethers.getSigner();

  // ProtocolProxy
  const ProtocolProxy = await ethers.getContractFactory("ProtocolProxy");
  const protocolProxy = await ProtocolProxy.connect(team).deploy();

  // ---------- TOKENS ----------

  // MockUsdc
  const MockUsdc = await ethers.getContractFactory("MockUsdc");
  const mockUsdc = await MockUsdc.connect(team).deploy();

  // tUsdc
  const TUsdc = await ethers.getContractFactory("tUsdc");
  const tUsdcDefaultOperators = [ protocolProxy.address ];
  const tUsdc = await TUsdc.connect(team).deploy(tUsdcDefaultOperators);

  // TangibleNft
  const TangibleNft = await ethers.getContractFactory("TangibleNft");
  const tangibleNft = await TangibleNft.connect(team).deploy(protocolProxy.address);

  // ---------- INITIALIZE ----------

  // Initialize ProtocolProxy
  protocolProxy.connect(team).initialize(mockUsdc.address, tUsdc.address, tangibleNft.address);

  // ---------- IMPLEMENTATIONS ----------

  // Auctions
  const Auctions = await ethers.getContractFactory("Auctions");
  const auctions = await Auctions.connect(team).deploy();

  // Automation
  const Automation = await ethers.getContractFactory("Automation");
  const automation = await Automation.connect(team).deploy();

  // Borrowing
  // const Borrowing = await ethers.getContractFactory("Borrowing");
  // const borrowing = await Borrowing.connect(team).deploy();

  // Interest
  const Interest = await ethers.getContractFactory("Interest");
  const interest = await Interest.connect(team).deploy();

  // Lending
  const Lending = await ethers.getContractFactory("Lending");
  const lending = await Lending.connect(team).deploy();

  // ---------- BID ACCEPTANCE IMPLEMENTATIONS ----------

  // AcceptNone
  const AcceptNone = await ethers.getContractFactory("AcceptNone");
  const acceptNone = await AcceptNone.connect(team).deploy();

  // AcceptMortgage
  const AcceptMortgage = await ethers.getContractFactory("AcceptMortgage");
  const acceptMortgage = await AcceptMortgage.connect(team).deploy();

  // AcceptDefault
  const AcceptDefault = await ethers.getContractFactory("AcceptDefault");
  const acceptDefault = await AcceptDefault.connect(team).deploy();

  // AcceptForeclosurable
  const AcceptForeclosurable = await ethers.getContractFactory("AcceptForeclosurable");
  const acceptForeclosurable = await AcceptForeclosurable.connect(team).deploy();

  // ---------- SELECTORS ------------

  // Auctions
  const auctionSelectors = [];
  protocolProxy.connect(team).setSelectorsTarget(auctionSelectors, auctions.address);

  // Automation
  const automationSelectors = [];
  protocolProxy.connect(team).setSelectorsTarget(automationSelectors, automation.address);

  // Borrowing
  // const borrowingSelectors = [];
  // protocolProxy.connect(team).setSelectorsTarget(borrowingSelectors, borrowing.address);

  // Interest
  const interestSelectors = [];
  protocolProxy.connect(team).setSelectorsTarget(interestSelectors, interest.address);
  
  // Lending
  const lendingSelectors = [];
  protocolProxy.connect(team).setSelectorsTarget(lendingSelectors, lending.address);

  // ---------- BID ACCEPTANCE SELECTORS ----------

  // acceptNoneSelectors
  const acceptNoneSelectors = [];
  protocolProxy.connect(team).setSelectorsTarget(acceptNoneSelectors, acceptNone.address);

  // acceptMortgageSelectors
  const acceptMortgageSelectors = [];
  protocolProxy.connect(team).setSelectorsTarget(acceptMortgageSelectors, acceptMortgage.address);

  // acceptDefaultSelectors
  const acceptDefaultSelectors = [];
  protocolProxy.connect(team).setSelectorsTarget(acceptDefaultSelectors, acceptDefault.address);

  // acceptForeclosurableSelectors
  const acceptForeclosurableSelectors = [];
  protocolProxy.connect(team).setSelectorsTarget(acceptForeclosurableSelectors, acceptForeclosurable.address);
}