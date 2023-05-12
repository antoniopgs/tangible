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

  // tUsdc
  const TUsdc = await ethers.getContractFactory("tUsdc");
  const tUsdcDefaultOperators = [ protocolProxy.address ];
  const tUsdc = await TUsdc.connect(team).deploy(tUsdcDefaultOperators);

  // TangibleNft
  const TangibleNft = await ethers.getContractFactory("TangibleNft");
  const tangibleNft = await TangibleNft.connect(team).deploy(protocolProxy.address);

  // ---------- MOCKS ----------

  // MockUsdc
  const MockUsdc = await ethers.getContractFactory("MockUsdc");
  const mockUsdc = await MockUsdc.connect(team).deploy();

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
}