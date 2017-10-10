# Cardano SL configuration

This document describes Cardano SL configuration. Configuration is
stored in YAML format, conventional name for the file is
`configuration.yaml`. This file contains multiple configurations, each
one is associated with a key. Almost all executables accept two
options to specify configuration: `--configuration-file` is used to
specify path to configuration and `--configuration-key` specifies key
in this configuration. An example of configuration can be found in
file `lib/configuration.yaml`.

## Genesis

Configuration is used to specify genesis data used by the node. It is
part of `core` configuration (it's accessible by key
`<configuration-key>.core.genesis`). There are two ways to specify
genesis data.

* One way is to provide genesis data itself, stored in json
  format. Genesis data explicitly states balances of all addresses,
  all bootstrap stakeholders, heavyweight delegation certificates,
  etc. It makes it clearer which genesis is used, but it doesn't
  describe _how_ this genesis was constructed. Also it requires more
  steps to create genesis data, than to create a spec. Current design
  implies that this mechanism should be used only for mainnet where we
  want to have full understanding of which addresses have which
  stake. The format is demonstrated below. `hash` is the hash (Blake2b
  256 bits) of canonically encoded `mainnet-genesis.json` file. It can
  be computed manually using `scripts/js/genesis-hash.js` script.

```
    genesis:
      src:
        file: mainnet-genesis.json
        hash: 5f20df933584822601f9e3f8c024eb5eb252fe8cefb24d1317dc3d432e940ebb
```

* Another way is to provide a specification how to generate genesis
  data. It allows one to specify how many nodes should have stake,
  which bootstrap stakeholders should be used, what should be total
  balance, etc. When node is launched with spec as genesis, it
  automatically constructs genesis data from it. This way to specify
  genesis is supposed to be used for everything except
  mainnet. Example:

```
    genesis:
      spec:
        initializer:
          testnetInitializer:
            testBalance:
              poors:        12
              richmen:      4
              richmenShare: 0.99
              useHDAddresses: True
              totalBalance: 600000000000000000
            fakeAvvmBalance:
              count: 10
              oneBalance: 100000
            distribution:
              testnetRichmenStakeDistr: []
            seed: 0
        blockVersionData:
          scriptVersion:     0
          slotDuration:      7000
          maxBlockSize:      2000000
          maxHeaderSize:     2000000
          maxTxSize:         4096 # 4 Kb
          maxProposalSize:   700 # 700 bytes
          mpcThd:            0.01 # 1% of stake
          heavyDelThd:       0.005 # 0.5% of stake
          updateVoteThd:     0.001 # 0.1% of total stake
          updateProposalThd: 0.1 # 10% of total stake
          updateImplicit:    10 # slots
          softforkRule:
            initThd:        0.9 # 90% of total stake
            minThd:         0.6 # 60% of total stake
            thdDecrement:   0.05 # 5% of total stake
          txFeePolicy:
            txSizeLinear:
              a: 155381 # absolute minimal fees per transaction
              b: 43.946 # additional minimal fees per byte of transaction size
          unlockStakeEpoch: 18446744073709551615 # last epoch (maxBound @Word64)
        protocolConstants: &dev_core_genesis_spec_protocolConstants
          k: 2
          protocolMagic: 55550001
          vssMinTTL: 2
          vssMaxTTL: 6
        ftsSeed: "c2tvdm9yb2RhIEdndXJkYSBib3JvZGEgcHJvdm9kYSA="
        heavyDelegation: {}
        avvmDistr: {}
```

### Initializer

There are two substantially different types of genesis spec, with the
difference in `initializer` value. Initializer can be either
`testnetInitializer` or `mainnetInitializer`.

The key point of `testnetInitializer` is that it contains seed which
is used to generate secret keys. It's quite convenient for testnet,
because there we want everyone to be able to have some coins. So we
can deterministically generate a lot of addresses with some coins and
let people use them. It's also convenient for devnet clusters
(i. e. clusters primarily used by developers to test something),
because in this case we also want to know all secrets. An example of
`testnetInitializer` was provided above. The most interesting part
there is `distribution` field:

```
  distribution:
   testnetRichmenStakeDistr: []
```

It means that generated richmen will also be bootstrap stakeholders
and will be participating in SSC. Note that richmen's keys are
deterministically generated, so basically everyone has full control
over system in this case. It's suitable for devnet where we don't care
about adversaries, but it's not suitable for testnet, because we don't
want to give full control over the system to arbitrary people.

For testnet there is another possible value of `distribution`:
`testnetCustomStakeDistr`. It allows one to explicitly specify
bootstrap stakeholders and VSS certificates. Example:

```
  distribution:
    testnetCustomStakeDistr:
      bootStakeholders:
        75fc2050ea497eb615461d01170679d143fb70c07c0baf3db54c6237: 1
        eaba957b871c4d5d9f5eab1a4183a037b3b0a59e31a52185d37627f1: 1
      vssCerts:
        75fc2050ea497eb615461d01170679d143fb70c07c0baf3db54c6237:
          expiryEpoch: 5
          signature: "34c3f15a59997a3b95d022ec223999ade1824e0ec709e2fcef6d7e92c614f9f8297cc377b71e54825226d84792867a0067000f20a7600c1eb2b368e6b8cc4602"
          signingKey: "4vHA0HXrmpD6VhhCe44CAJ8IHr9BKpCUtOmGRZu/39vRLJ1z2vJp8h+rdOqb7tJg7Uzf94x0NlM8xHgmhPBecg=="
          vssKey: "WCECml0Nc9bjjerxHGf2sDfKJIILyDKvjM8zCdfzBmYxcyU="
        eaba957b871c4d5d9f5eab1a4183a037b3b0a59e31a52185d37627f1:
          expiryEpoch: 5
          signature: "628a5076967851da90bedb36f5c8cc38d1a3fe66f09acdfa9be02c6ed7910480156e1a7d0d8fe67f2604caa404146798807c35ee0cde4111ced742d7f53b590a"
          signingKey: "FXU35aHyAKouHgj+qWi/vfC8CzU4JI9+zxDkQwq+B4sFIsaai3+U307SFLp2zxZB7Jm9kjc19TcBtTefkHxxmg=="
          vssKey: "WCEDNB6FR+wZABJptA2JiReaIHLBRVz04Ys3P6UMDuSW8Qg="
```

`mainnetInitializer` doesn't have any seed, in this case all data is
specified explicitly, not generated somehow. It contains bootstrap
stakeholders, vss certificates, non-avvm balances and system start
time (see below). Example:

```
    initializer:
        mainnetInitializer:
        startTime: 1505621332000000
        bootStakeholders:
            0d916567f96b6a65d204966e6aab5fbd242e56c321833f8ba5d607da: 1
        vssCerts:
            0d916567f96b6a65d204966e6aab5fbd242e56c321833f8ba5d607da:
                expiryEpoch: 1
                signature: "396fe505f4287f832fd26c1eba1843a49f3d23b64d664fb3c8a2f25c8de73ce6f2f4cf37ec7fa0fee7750d1d6c55e1b07e1018ce0c6443bacdb01fb8e15f1a0f"
                signingKey: "ohsV3RtEFD1jeOzKwNulmMRhBG2RLdFxPbcSGbkmJ+xd/2cOALSDahPlydFRjd15sH0PkPE/zTvP4iN8wJr/hA=="
                vssKey: "WCECtpe8B/5XPefEhgg7X5veUIYH/RRcvXbz6w7MIJBwWYU="
            4bd1884f5ce2231be8623ecf5778a9112e26514205b39ff53529e735:
                expiryEpoch: 2
                signature: "773dcdf727d05720a76e7f88ef1c8a629399a30a98943eac761f9706a0e45def608765362202ce571b9394167c310a445a84745695d73e89086254a4c5be610c"
                signingKey: "oUDzVUqwmXH4E3RlDrS4zhZ6kwv9rnNiwe8dI6lIg794+bWQBlULwvnwiIGgK4z0HT8+o+nru8F5xDy4ZL2/lA=="
                vssKey: "WCEChSQx6z4OxYrHNYbu5GGztX4FBBxGMfzmO6C+xNTrDVw="
        nonAvvmBalances: {}
```

Such type of genesis spec was used once to construct mainnet genesis
data. It's not clear whether it will be ever used again.

### System start time

System start time is taken from configuration or command line
option. It's taken from configuration if genesis is provided as
genesis data (which always contains system start time) or if genesis
is provided as genesis spec with `mainnetInitializer`. The reason why
system start is part of `mainnetInitializer`, but not part of
`testnetInitializer` is that mainnet is launched rarely (actually only
once, but there is also staging), but other
clusters are launched more often, and it's easier to change this value
from CLI.

### Tools

There are some tools relevant to genesis data.

* `cardano-keygen` has a command to dump all secret keys and similar
  data to files. Usage: `cardano-keygen --system-start 0
  --configuration-file <file> --configuration-key <key>
  generate-keys-by-spec --genesis-out-dir <dir>`. This command will
  generate dump secrets to `<dir>`. To deploy a cluster you need keys
  of core nodes. In case of devnet, just use `generate-keys-by-spec`
  to obtain these keys. They can be found in
  `keys-testnet/rich`. Workflow for testnet is described
  below. Workflow for mainnet (not sure if someone will ever need it)
  is described in `scripts/prepare-genesis` (**TODO** move it here
  maybe?).
* `cardano-node-simple` and `cardano-node` have command line option to
  dump genesis data (in JSON format). The option is
  `--dump-genesis-data-to genesis.json` (data will be dumped to
  `genesis.json`). It can be used to verify generated balances, for
  example.

### Generating genesis for testnet

There is `testnet_public_full` configuration which is almost suitable
for testnet. The only values to be changed are inside
`testnetCustomStakeDistr`: `bootStakeholders` and `vssCerts`. They
depend on secret keys of core nodes which shouldn't be publicly
known. You need to generate secret keys and VSS certificates and put
them into configuration. There is also `testnet_staging_full` which
has different `k`, `protocolMagic` and some other values.

To generate a secret key use `cardano-keygen --system-start 0
generate-key --path <SECRET_KEY_PATH>`. Generate as many keys as there
should be core nodes. Last line looks like this:

> [keygen:INFO] Successfully generated primary key and dumped to secrets/testnet/node4.sk, stakeholder id: 39f2bb9fd75ac348e6c92467e61eb3e1418a394f5a2105f9e014b666, PK (base64): /fbQqCqUPdPImYA2djkGYMpj9HZGkDeKhTc/mLcPG7sdhJSR6Ou0sB3J5OII2VdWTXSHRM1cPdNwZsaNba4rcg==

You should use stakeholder ids as keys in `bootStakeholders`
map. Values are stakeholders' weights, having all weights equal to 1
is fine.

The second step is VSS certificates generation. Use `cardano-keygen
--system-start 0 --configuration-key testnet_public_full generate-vss
--path <SECRET_KEY_PATH>` to generate VSS certificate. This how it
looks like:

> JSON: key 75fc2050ea497eb615461d01170679d143fb70c07c0baf3db54c6237, value {"expiryEpoch":5,"signature":"b735325b8f21a033cbe3005c35e4397dd33168c62c05cc8f59e66efbcdeb36b5862d7a324def1ba10e4a79cf0e56c75568c84e6ca28b1a9bb5da65fc6a8cb002","signingKey":"4vHA0HXrmpD6VhhCe44CAJ8IHr9BKpCUtOmGRZu/39vRLJ1z2vJp8h+rdOqb7tJg7Uzf94x0NlM8xHgmhPBecg==","vssKey":"WCECml0Nc9bjjerxHGf2sDfKJIILyDKvjM8zCdfzBmYxcyU="}

**IMPORTANT**: you must pass correct `--configuration-key`, because
certificate validity depends on `protocolMagic`. So if you are
generating certificates for staging, use `testnet_staging_full`
instead.

Put this data into `vssCerts` map. There should be as many VSS
certificates as there are core nodes (i. e. do it for each secret).

## Our configurations

### `mainnet` configurations

There are several mainnet configurations in `lib/configuration.yaml`
file for different keys.

* `mainnet_base` configuration serves as a basis for other mainnet
  configurations and shouldn't be used directly.
* `mainnet_example_generated` configuration is an example of mainnet
  configuration where genesis is provded by spec. It shouldn't be used
  directly, only as an example.
* `mainnet_full` configuration is what core nodes use in real
  mainnet. `mainnet_wallet_win64` and `mainnet_wallet_macos64` are
  almost same, but they have different application name and system tag
  which matters for update system. They should be used by wallets
  (i. e. nodes launched with Daedalus).
* `mainnet_dryrun_full` is like `mainnet_full`, but for
  staging. `mainnet_dryrun_wallet_win64` and
  `mainnet_dryrun_wallet_macos64` are for staging wallets.

### `devnet` configuration

There is a configuration called `devnet` which should be used to setup
clusters for developers or QA to test something. There are some values
which should be set carefully before using this configuration, they
depend on particular task:

* `slotDuration`, `k` are parameters of the protocol, set to
  reasonable defaults, but sometimes we may want to use different
  values.
* `networkDiameter`, `mdNoBlocksSlotThreshold`,
  `recoveryHeadersMessage` depend on `k`, comments are provided in
  configuration file.
* `genesis.spec.initializer.testnetInitializer.richmen` is basically
  the number of core nodes. Should be the same as the number of core
  nodes deployed.

### `testnet` configurations

There are two configurations for testnets. They are ready to be used,
except `bootStakeholders` and `vssCerts`. Testnet genesis preparation
is described above. Bootstrap stakeholders and vss certificates in
`lib/configuration.yaml` are derived from secret keys from
`secrets/testnet/`. Since they are publicly avaiable, they shouldn't
be used for real testnet. Note that `vssCerts` differ even though
secret keys are same. That's because certificates validity depends on
protocol magic.

### Other configurations

There are few more configurations which should be briefly
mentioned. `dev` configuration is used by developers to launch cluster
locally. It's very simple and provides bare minimum. `bench`
configuration is used for benchmarks. `test` configuration is used in
tests by default (it's embedded into binary). `default` configuration
is an alias for `dev`.
