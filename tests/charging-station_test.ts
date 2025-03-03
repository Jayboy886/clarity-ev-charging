// [Previous test content remains, adding new tests...]

Clarinet.test({
    name: "Contract pause functionality works correctly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const user = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('charging-station', 'toggle-pause', [], deployer.address)
        ]);
        
        block.receipts[0].result.expectOk().expectBool(true);
        
        // Attempt operation while paused
        block = chain.mineBlock([
            Tx.contractCall('charging-station', 'register-station', [
                types.principal(user.address),
                types.ascii("Test Location"),
                types.list(Array(24).fill(types.bool(false)))
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectErr(107); // err-contract-paused
    }
});
