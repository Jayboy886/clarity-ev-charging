import {
    Clarinet,
    Tx,
    Chain,
    Account,
    types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can register new charging station with peak hours",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const station = accounts.get('wallet_1')!;
        
        let peakHours = Array(24).fill(false);
        peakHours[9] = true; // 9am is peak
        peakHours[17] = true; // 5pm is peak
        
        let block = chain.mineBlock([
            Tx.contractCall('charging-station', 'register-station', [
                types.principal(station.address),
                types.ascii("123 Main St"),
                types.list(peakHours.map(x => types.bool(x)))
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectOk().expectBool(true);
    }
});

Clarinet.test({
    name: "Cannot exceed maximum charging rate",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const station = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('charging-station', 'update-station-rate', [
                types.principal(station.address),
                types.uint(51) // Exceeds max rate of 50
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectErr(104); // err-invalid-rate
    }
});

Clarinet.test({
    name: "Can toggle maintenance mode",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const station = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('charging-station', 'toggle-maintenance-mode', [
                types.principal(station.address)
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectOk().expectBool(true);
    }
});

Clarinet.test({
    name: "Cannot start charging when station in maintenance",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const station = accounts.get('wallet_1')!;
        const user = accounts.get('wallet_2')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('charging-station', 'toggle-maintenance-mode', [
                types.principal(station.address)
            ], deployer.address),
            
            Tx.contractCall('charging-station', 'start-charging', [
                types.principal(station.address),
                types.uint(100)
            ], user.address)
        ]);
        
        block.receipts[1].result.expectErr(106); // err-station-maintenance
    }
});
