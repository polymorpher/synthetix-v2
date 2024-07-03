import solcx
from web3 import Web3, HTTPProvider
from solcx import compile_files
from utils.generalutils import TERMCOLORS
# deploy_settings is a file that contains two strings, or however you want to decompile your private key

solcx.install_solc('0.4.24')
solcx.set_solc_version('0.4.24')

MASTER_KEY=""
MASTER_ADDRESS=""
BLOCKCHAIN_ADDRESS = "https://api.harmony.one"
W3 = Web3(HTTPProvider(BLOCKCHAIN_ADDRESS))
POLLING_INTERVAL = 0.1
STATUS_ALIGN_SPACING = 6

# The number representing 1 in our contracts.
UNIT = 10**18
ZERO_ADDRESS = "0x" + "0" * 40

# Source files to compile from
SOLIDITY_SOURCES = ["contracts/Havven.sol",
                    "contracts/Nomin.sol",
                    "contracts/Court.sol",
                    "contracts/HavvenEscrow.sol",
                    "contracts/ExternStateToken.sol",
                   #  "contracts/DestructibleExternStateToken.sol",
                    "contracts/Proxy.sol"]


def attempt(function, func_args, init_string, func_kwargs=None, print_status=True, print_exception=True):
    if func_kwargs is None:
        func_kwargs = {}

    if print_status:
        print(init_string, end="", flush=True)

    pad = (STATUS_ALIGN_SPACING - len(init_string)) % STATUS_ALIGN_SPACING
    reset = TERMCOLORS.RESET
    try:
        result = function(*func_args, **func_kwargs)
        if print_status:
            print(f"{TERMCOLORS.GREEN}{' '*pad}Done!{reset}")
        return result
    except Exception as e:
        if print_status:
            print(f"{TERMCOLORS.RED}{' '*pad}Failed.{reset}")
        if print_exception:
            print(f"{TERMCOLORS.YELLOW}{TERMCOLORS.BOLD}ERROR:{reset} {TERMCOLORS.BOLD}{e}{reset}")
        return None


def sign_and_mine_txs(from_acc, key, txs):
    receipts = []
    for item in txs:
        print("Sending transaction")
        tx = item.build_transaction({
            'from': from_acc,
            'to': from_acc,
            'gas': 30000000,
            'gasPrice': W3.to_wei('100', 'gwei'),
            'nonce': W3.eth.get_transaction_count(from_acc, "pending")
        })
        signed = W3.eth.account.sign_transaction(tx, key)
        txh = W3.eth.send_raw_transaction(signed.raw_transaction)
        print("Transaction hash:", "0x"+txh.hex())
        txn_receipt = W3.eth.wait_for_transaction_receipt(txh)
        print("Transaction accepted")
        receipts.append(txn_receipt)
    return receipts


def compile_contracts(files, remappings=None):
    if remappings is None:
        remappings = []
    contract_interfaces = {}
    compiled = compile_files(files)
    for key in compiled:
        name = key.split(':')[-1]
        contract_interfaces[name] = compiled[key]
    return contract_interfaces


def attempt_deploy_signed(compiled_sol, contract_name, from_acc, key, constructor_args=None, gas=5000000):
    if constructor_args is None:
        constructor_args = []
    print("Deploying:", contract_name, "constructor_args:", constructor_args)
    if compiled_sol is not None:
        contract_interface = compiled_sol[contract_name]
        contract = W3.eth.contract(abi=contract_interface['abi'], bytecode=contract_interface['bin'])
        const_f = contract.constructor(*constructor_args)
        nonce = W3.eth.get_transaction_count(from_acc)
        # print("Nonce:", nonce, "gas:", gas)
        tx = const_f.build_transaction({'from': from_acc, 'nonce': nonce, 'gas':gas, 'gasPrice': W3.to_wei('100', 'gwei')})
        signed = W3.eth.account.sign_transaction(tx, key)
        txh = W3.eth.send_raw_transaction(signed.raw_transaction)
        txn_receipt = W3.eth.wait_for_transaction_receipt(txh)
        address = txn_receipt.contractAddress
        print("Deployed to:", address, "txnHash:", "0x"+txh.hex())
        contract.address = address
        return contract, txn_receipt


def deploy_havven(print_addresses=True):
    print("Deployment initiated...\n")

    compiled = attempt(compile_contracts, [SOLIDITY_SOURCES], "Compiling contracts... ")

    if compiled is not None:
        # Deploy contracts
        havven_proxy, h_prox_txr = attempt_deploy_signed(
            compiled, 'Proxy', MASTER_ADDRESS, MASTER_KEY, [MASTER_ADDRESS]
        )

        nomin_proxy, h_prox_txr = attempt_deploy_signed(
            compiled, 'Proxy', MASTER_ADDRESS, MASTER_KEY, [MASTER_ADDRESS]
        )

        havven_contract, hvn_txr = attempt_deploy_signed(
            compiled, 'Havven', MASTER_ADDRESS, MASTER_KEY,
            [havven_proxy.address, ZERO_ADDRESS, MASTER_ADDRESS, MASTER_ADDRESS, UNIT // 2, [MASTER_ADDRESS], ZERO_ADDRESS]
        )
        nomin_contract, nom_txr = attempt_deploy_signed(
            compiled, 'Nomin', MASTER_ADDRESS, MASTER_KEY,
            [nomin_proxy.address, MASTER_ADDRESS, havven_contract.address, 1000000000, MASTER_ADDRESS]
        )

        court_contract, court_txr = attempt_deploy_signed(
            compiled, 'Court', MASTER_ADDRESS, MASTER_KEY,
            [havven_contract.address, nomin_contract.address, MASTER_ADDRESS])

        escrow_contract, escrow_txr = attempt_deploy_signed(
            compiled, 'HavvenEscrow', MASTER_ADDRESS, MASTER_KEY, [MASTER_ADDRESS, havven_contract.address]
        )

#     havven_proxy = W3.eth.contract(abi=compiled['Proxy']['abi'], address='0xEF630f892b69acb7Fd80a908f9ea4e84DE588e01')
#     nomin_proxy = W3.eth.contract(abi=compiled['Proxy']['abi'], address='0xE77c61cD53301EfB6d9361fa91f5Fb6cd10d2253')
#     havven_contract = W3.eth.contract(abi=compiled['Havven']['abi'], address='0xfC92FeBD60E6B4A28F959e5a833d0C16B46fe905')
#     nomin_contract = W3.eth.contract(abi=compiled['Nomin']['abi'], address='0x95537CdC53Ef318b97A31BF66A620C2f760c962B')
#     court_contract = W3.eth.contract(abi=compiled['Court']['abi'], address='0x0248f9f62e7613EFD3e10C09eeDd6153B2f2EAA2')
#     escrow_contract = W3.eth.contract(abi=compiled['HavvenEscrow']['abi'], address='0xA05Abe0Eba145E9A5b9B4D049772A3f92D45638e')

        # Hook up each of those contracts to each other
        sign_and_mine_txs(MASTER_ADDRESS, MASTER_KEY, [
            havven_proxy.functions.setTarget(havven_contract.address),
            nomin_proxy.functions.setTarget(nomin_contract.address),
            havven_contract.functions.setNomin(nomin_contract.address),
            nomin_contract.functions.setCourt(court_contract.address),
            nomin_contract.functions.setHavven(havven_contract.address),
            havven_contract.functions.setEscrow(escrow_contract.address)
        ])
        print("Addresses")
        print(f"Havven Proxy: {havven_proxy.address}")

    print("\nDeployment complete.\n")

#     if print_addresses:
#         print("Addresses")
#         print("========\n")
#         print(f"Havven Proxy: {havven_proxy.address}")
#         print(f"Nomin Proxy:  {nomin_proxy.address}")
#         print(f"Havven:       {havven_contract.address}")
#         print(f"Nomin:        {nomin_contract.address}")
#         print(f"Court:        {court_contract.address}")
#         print(f"Escrow:       {escrow_contract.address}")
#         print()

#     return havven_proxy, nomin_proxy, havven_contract, nomin_contract, court_contract, escrow_contract

if __name__ == "__main__":
    deploy_havven(True)
    print(f"Owner: {MASTER_ADDRESS}")
