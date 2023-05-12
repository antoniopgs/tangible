const deploy = require("../scripts/deploy");
const fs = require('fs');

const getDate = () => {
    console.log("Getting date...");
    const date = new Date();
    const day = date.getUTCDate();
    const month = date.getUTCMonth() + 1;
    const year = date.getUTCFullYear();
    const hours = date.getUTCHours();
    const minutes = date.getUTCMinutes();
    const seconds = date.getUTCSeconds();
    return `${year}-${month}-${day}_${hours}_${minutes}_${seconds}`;
}

const isObject = obj => {
    return obj != null && obj.constructor.name === "Object"
}

const preBuildDeploymentData = (_deployment) => {
    return Object.fromEntries(
        Object.entries(_deployment).map(
            ([k, v]) => {

                // If v is array
                if (Array.isArray(v)) {
                    const subArray = v.map(v => v.address);
                    return [k, subArray];
                
                // If v is object
                } else if (isObject(v)) {
                    const subObject = Object.fromEntries(Object.entries(v).map(([k2, v2]) => {
                        if (isObject(v2)) {
                            const subObject2 = Object.fromEntries(Object.entries(v2).map(([k3, v3]) => [k3, v3.address])); // amy: Todo: maybe implement recursion later
                            return [k2, subObject2];
                        } else {
                            return [k2, v2.address];
                        }
                    }));
                    return [k, subObject];
                
                // If v is neither array nor object
                } else {
                    return [k, v.address];
                }
            }
        ) 
    );
}

const buildDeploymentData = async () => {
    console.log("Building deployment data...")
    const deployment = await deploy();
    const deploymentData = preBuildDeploymentData(deployment);
    deploymentData.network = hre.network.name;
    deploymentData.date = getDate();
    console.log(`Data: ${JSON.stringify(deploymentData, null, 4)}`);
    return deploymentData;
}

const saveDeployment = _deployment => {
    console.log("Saving deployment...")

    // Set dir
    const dir = `./deployments/${_deployment.network}`;

    // Create dir if it doesn't exist
    if (!fs.existsSync(dir)){
        fs.mkdirSync(dir, {recursive: true });
    }

    // Write deployment
    fs.writeFileSync(`${dir}/${_deployment.date}.json`, JSON.stringify(_deployment, null, 4));
    console.log("Deployment saved.")
}

module.exports = deploySave = async () => {
    console.log("Starting deployment...");
    const data = await buildDeploymentData();
    saveDeployment(data);
    console.log("Deployment done!");
    return data;
}

deploySave();