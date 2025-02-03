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
    name: "Can start charging and earn rewards with refund of unused payment",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const station = accounts.get('wallet_1')!;
        const user = accounts.get('wallet_2')!;
        
        let peakHours = Array(24).fill(false);
        
        // First register station
        let block = chain.mineBlock([
            Tx.contractCall('charging-station', 'register-station', [
                types.principal(station.address),
                types.ascii("123 Main St"),
                types.list(peakHours.map(x => types.bool(x)))
            ], deployer.address),
            
            // Start charging with more payment than needed
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
        
        const result = block2.receipts[0].result.expectOk().expectTuple();
        assertEquals(result['rewards-earned'].toString(), '5');
        assertEquals(result['refund'].toString(), '90');  // 100 - (1 minute * 10 rate)
    }
});
