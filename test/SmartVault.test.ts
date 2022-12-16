import { assertIndirectEvent, deploy, fp, getSigner, getSigners, instanceAt, ZERO_ADDRESS } from '@mimic-fi/v2-helpers'
import { assertPermissions, createTokenMock, Mimic, setupMimic } from '@mimic-fi/v2-smart-vaults-base'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address'
import { expect } from 'chai'
import { Contract } from 'ethers'

describe('SmartVault', () => {
  let smartVault: Contract, mimic: Mimic
  let index: Contract, weth: Contract, wbtc: Contract, usdc: Contract
  let other: SignerWithAddress, owner: SignerWithAddress, managers: SignerWithAddress[], relayers: SignerWithAddress[]

  before('setup mimic', async () => {
    mimic = await setupMimic(false)
  })

  before('set up signers', async () => {
    other = await getSigner(1)
    owner = await getSigner(2)
    managers = await getSigners(3, 3)
    relayers = await getSigners(2, 6)
  })

  before('deploy tokens', async () => {
    weth = await createTokenMock()
    wbtc = await createTokenMock()
    usdc = await createTokenMock()
  })

  before('deploy smart vault', async () => {
    const deployer = await deploy('SmartVaultDeployer', [], owner, { Deployer: mimic.deployer.address })
    index = await deploy('SimpleIndex', [deployer.address, mimic.registry.address, (1e16).toString()])

    const tx = await deployer.deploy({
      registry: mimic.registry.address,
      smartVaultParams: {
        impl: mimic.smartVault.address,
        admin: owner.address,
        feeCollector: mimic.admin.address,
        strategies: [],
        priceFeedParams: [],
        priceOracle: mimic.priceOracle.address,
        swapConnector: mimic.swapConnector.address,
        swapFee: { pct: fp(0.01), cap: 0, token: ZERO_ADDRESS, period: 0 },
        withdrawFee: { pct: 0, cap: 0, token: ZERO_ADDRESS, period: 0 },
        performanceFee: { pct: 0, cap: 0, token: ZERO_ADDRESS, period: 0 },
      },
      indexActionParams: {
        impl: index.address,
        admin: owner.address,
        managers: managers.map((m) => m.address),
        tokens: [weth.address, wbtc.address, usdc.address],
        weights: [fp(0.5), fp(0.3), fp(0.2)],
        maxSlippage: fp(0.001), // 0.1%
        relayedActionParams: {
          relayers: relayers.map((m) => m.address),
          gasPriceLimit: fp(100),
          totalCostLimit: 0,
          payingGasToken: weth.address,
        },
      },
    })

    const { args } = await assertIndirectEvent(tx, mimic.registry.interface, 'Cloned', {
      implementation: mimic.smartVault.address,
    })

    smartVault = await instanceAt('SmartVault', args.instance)
  })

  describe('smart vault', () => {
    it('has set its permissions correctly', async () => {
      await assertPermissions(smartVault, [
        {
          name: 'owner',
          account: owner,
          roles: [
            'authorize',
            'unauthorize',
            'collect',
            'withdraw',
            'wrap',
            'unwrap',
            'claim',
            'join',
            'exit',
            'swap',
            'setStrategy',
            'setPriceFeed',
            'setPriceFeeds',
            'setPriceOracle',
            'setSwapConnector',
            'setWithdrawFee',
            'setSwapFee',
            'setPerformanceFee',
          ],
        },
        { name: 'mimic', account: mimic.admin, roles: ['setFeeCollector'] },
        { name: 'index', account: index, roles: ['swap'] },
      ])
    })

    it('sets a fee collector', async () => {
      expect(await smartVault.feeCollector()).to.be.equal(mimic.admin.address)
    })

    it('sets a swap fee', async () => {
      const swapFee = await smartVault.swapFee()

      expect(swapFee.pct).to.be.equal(fp(0.01))
      expect(swapFee.cap).to.be.equal(0)
      expect(swapFee.token).to.be.equal(ZERO_ADDRESS)
      expect(swapFee.period).to.be.equal(0)
    })

    it('sets no withdraw fee', async () => {
      const withdrawFee = await smartVault.withdrawFee()

      expect(withdrawFee.pct).to.be.equal(0)
      expect(withdrawFee.cap).to.be.equal(0)
      expect(withdrawFee.token).to.be.equal(ZERO_ADDRESS)
      expect(withdrawFee.period).to.be.equal(0)
    })

    it('sets no performance fee', async () => {
      const performanceFee = await smartVault.performanceFee()

      expect(performanceFee.pct).to.be.equal(0)
      expect(performanceFee.cap).to.be.equal(0)
      expect(performanceFee.token).to.be.equal(ZERO_ADDRESS)
      expect(performanceFee.period).to.be.equal(0)
    })

    it('sets a price oracle', async () => {
      expect(await smartVault.priceOracle()).to.be.equal(mimic.priceOracle.address)
    })

    it('sets a swap connector', async () => {
      expect(await smartVault.swapConnector()).to.be.equal(mimic.swapConnector.address)
    })
  })

  describe('simple index', () => {
    it('has set its permissions correctly', async () => {
      await assertPermissions(index, [
        {
          name: 'owner',
          account: owner,
          roles: [
            'authorize',
            'unauthorize',
            'setSmartVault',
            'setLimits',
            'setRelayer',
            'setMaxSlippage',
            'setPortfolio',
            'call',
          ],
        },
        { name: 'mimic', account: mimic.admin, roles: [] },
        { name: 'index', account: index, roles: [] },
        { name: 'other', account: other, roles: [] },
        { name: 'managers', account: managers, roles: ['call'] },
        { name: 'relayers', account: relayers, roles: ['call'] },
      ])
    })

    it('has the proper smart vault set', async () => {
      expect(await index.smartVault()).to.be.equal(smartVault.address)
    })

    it('sets the expected initial portfolio params', async () => {
      expect(await index.assets(0)).to.equal(weth.address)
      expect(await index.assets(1)).to.equal(wbtc.address)
      expect(await index.assets(2)).to.equal(usdc.address)
      expect(await index.weights(0)).to.equal(fp(0.5))
      expect(await index.weights(1)).to.equal(fp(0.3))
      expect(await index.weights(2)).to.equal(fp(0.2))

      expect(await index.maxSlippage()).to.be.equal(fp(0.001))
    })

    it('sets the expected gas limits', async () => {
      expect(await index.gasPriceLimit()).to.be.equal(fp(100))
      expect(await index.totalCostLimit()).to.be.equal(0)
      expect(await index.payingGasToken()).to.be.equal(weth.address)
    })

    it('whitelists the requested relayers', async () => {
      for (const relayer of relayers) {
        expect(await index.isRelayer(relayer.address)).to.be.true
      }
    })

    it('does not whitelist managers as relayers', async () => {
      for (const manager of managers) {
        expect(await index.isRelayer(manager.address)).to.be.false
      }
    })
  })
})
