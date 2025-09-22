import path from "path"
import fs from "fs"


const deployAddressPath = path.join(__dirname, "../deployAddress.json")

export function saveDeployAddress(network: string, contractName: string, address: string) {
    let deployAddress:Record<string, Record<string, string>> = {}
    if (fs.existsSync(deployAddressPath)) {
        const data = fs.readFileSync(deployAddressPath, "utf-8")
        deployAddress = JSON.parse(data)
    }
    if (!deployAddress[network]) {
        deployAddress[network] = {}
    }
    deployAddress[network][contractName] = address
    fs.writeFileSync(deployAddressPath, JSON.stringify(deployAddress, null, 2))
}

export function getDeployAddress(network: string, contractName: string): string | undefined {
    if (fs.existsSync(deployAddressPath)) {
        const data = fs.readFileSync(deployAddressPath, "utf-8")
        const deployAddress = JSON.parse(data)
        return deployAddress[network]?.[contractName]
    }
    return undefined
}