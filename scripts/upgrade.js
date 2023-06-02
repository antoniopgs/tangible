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
  
module.exports = upgrade = async () => {

    // ---------- MAIN ----------

    // Get team
    const team = await getMnemonicTeam();
    // const team = await ethers.getSigner();

    // proxy
    const proxyAddress = "0x1dEFcE9d58f278C84fE46c1cb6Da0b4caced5541";
    const proxy = await ethers.getContractAt("ProtocolProxy", proxyAddress);

    // ---------- IMPLEMENTATIONS ----------
    const info = await deployContract("Info", team);

    // Info
    console.log("");
    console.log("setting infoSelectors...");
    const Info = await ethers.getContractFactory("Info");
    const infoSelectors = [
        Info.interface.getSighash("loans"),
        Info.interface.getSighash("bids"),
        Info.interface.getSighash("availableLiquidity"),
        Info.interface.getSighash("userLoans"),
        Info.interface.getSighash("userBids"),
        Info.interface.getSighash("loansTokenIdsLength"),
        Info.interface.getSighash("loansTokenIdsAt"),
        Info.interface.getSighash("redemptionFeeSpread"),
        Info.interface.getSighash("defaultFeeSpread"),
        Info.interface.getSighash("accruedInterest"),
        Info.interface.getSighash("lenderApy"),
        Info.interface.getSighash("tUsdcToUsdc"),
        Info.interface.getSighash("bidActionable")
    ];
    await proxy.connect(team).setSelectorsTarget(infoSelectors, info.address);
    console.log("infoSelectors set.");
}

upgrade();