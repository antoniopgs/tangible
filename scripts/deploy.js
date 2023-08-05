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
  const borrowing = await deployContract("Borrowing", team);
  const interest = await deployContract("Interest", team);
  const lending = await deployContract("Lending", team);
  const info = await deployContract("Info", team);

  // ---------- SELECTORS ------------

  // Borrowing
  console.log("");
  console.log("setting borrowingSelectors...");
  const Borrowing = await ethers.getContractFactory("Borrowing");
  const borrowingSelectors = [
    Borrowing.interface.getSighash("startNewLoan"),
    Borrowing.interface.getSighash("payLoan"),
    Borrowing.interface.getSighash("redeemLoan"),
  ];
  await proxy.connect(team).setSelectorsTarget(borrowingSelectors, borrowing.address);
  console.log("borrowingSelectors set.");

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
    Lending.interface.getSighash("withdraw")
  ];
  await proxy.connect(team).setSelectorsTarget(lendingSelectors, lending.address);
  console.log("lendingSelectors set.");

  // Info
  console.log("");
  console.log("setting infoSelectors...");
  const Info = await ethers.getContractFactory("Info");
  const infoSelectors = [
    Info.interface.getSighash("loans"),
    Info.interface.getSighash("availableLiquidity"),
    Info.interface.getSighash("userLoans"),
    Info.interface.getSighash("loansTokenIdsLength"),
    Info.interface.getSighash("loansTokenIdsAt"),
    Info.interface.getSighash("redemptionFeeSpread"),
    Info.interface.getSighash("defaultFeeSpread"),
    Info.interface.getSighash("unpaidPrincipal"),
    Info.interface.getSighash("accruedInterest"),
    Info.interface.getSighash("lenderApy"),
    Info.interface.getSighash("usdcToTUsdc"),
    Info.interface.getSighash("tUsdcToUsdc"),
    Info.interface.getSighash("status"),
    Info.interface.getSighash("utilization")
  ];
  await proxy.connect(team).setSelectorsTarget(infoSelectors, info.address);
  console.log("infoSelectors set.");

  return {
    team: team,
    proxy: proxy,
    tokens: {
      mockUsdc: mockUsdc,
      tUsdc: tUsdc,
      tangibleNft: tangibleNft
    },
    borrowing: borrowing,
    interest: interest,
    lending: lending,
    info: info
  }
}