import {
    Clarinet,
    Tx,
    Chain,
    Account,
    types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can register new charging station",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const station = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('charging-station', 'register-station', [
                types.principal(station.address),
                types.ascii("123 Main St")
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectOk().expectBool(true);
    }
});

Clarinet.test({
    name: "Can start and end charging session",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const station = accounts.get('wallet_1')!;
        const user = accounts.get('wallet_2')!;
        
        // First register station
        let block = chain.mineBlock([
            Tx.contractCall('charging-station', 'register-station', [
                types.principal(station.address),
                types.ascii("123 Main St")
            ], deployer.address),
            
            // Start charging
            Tx.contractCall('charging-station', 'start-charging', [
                types.principal(station.address),
                types.uint(100)
            ], user.address)
        ]);
        
        block.receipts[1].result.expectOk();
        
        // End charging
        let block2 = chain.mineBlock([
            Tx.contractCall('charging-station', 'end-charging', [
                types.principal(station.address)
            ], user.address)
        ]);
        
        block2.receipts[0].result.expectOk();
    }
});
