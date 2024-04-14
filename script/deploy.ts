import { TezosToolkit } from '@taquito/taquito';
import { importKey } from '@taquito/signer';
import * as dotenv from 'dotenv';
dotenv.config();

async function deployContract() {
  const tezos = new TezosToolkit('https://tezos-node-url');
await importKey(tezos,
process.env.TEZOS_EMAIL ?? '',
process.env.TEZOS_PASSWORD,
process.env.TEZOS_MNEMONIC,
process.env.TEZOS_SECRET
);

  const code = await tezos.contract.originate({
    code: `smart_contract_code_here`, // Use your compiled contract code
    storage: {
      admin: 'tz1-your-admin-address',
      start_time: null,
      end_time: null,
      freeze_period: 100,
      vesting_period: 300,
      beneficiaries: new Map([['tz1-beneficiary-address', { address: 'tz1-beneficiary-address', amount: 1000, claimed: 0 }]]),
      token_address: 'tz1-token-address',
      token_id: 0
    }
  });

  const contract = await code.contract();
  console.log(`Contract deployed at: ${contract.address}`);
}

deployContract().catch(e => console.error(e));

async function testKillContract() {
        const tezos = new TezosToolkit('https://tezos-node-url');
        try {
            const contract = await tezos.wallet.at('deployed_contract_address');
            const op = await contract.methods.kill().send();
            await op.confirmation();
            console.log('Kill operation executed:', op.opHash);
        } catch (error) {
            console.error('Failed to execute kill:', error);
        }
    }
  
testKillContract().catch(e => console.error(e));