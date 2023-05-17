const proxyAddress = "0xD9D2E2447e091C2B0722aAEBb1C6EF6fab73c278";
const lendingAddress = "0xC81ce65757f8815BBaD65DdC8Bc1d742849E8357";

const getMnemonicTeam = async () => {

    // Get tangibleTeam
    const teamAddress = ethers.Wallet.fromMnemonic(process.env.MNEMONIC).address;
  
    // Return fungifyTeam signer
    return (await ethers.getSigner(teamAddress));
  }

const runFix = async () => {

    console.log(0);
    const team = await getMnemonicTeam();
    console.log(1);
    const proxy = await ethers.getContractAt("ProtocolProxy", proxyAddress);

    // Lending
    const Lending = await ethers.getContractFactory("Lending");
    console.log(2);
    const lendingSelectors = [
        Lending.interface.getSighash("tUsdcToUsdc")
    ];
    console.log(3);
    await proxy.connect(team).setSelectorsTarget(lendingSelectors, lendingAddress);
    console.log(4);
  
}

runFix().then(
    console.log("Fix done!")
)