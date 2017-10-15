module Test.Pos.Wallet.Web.Tracking.SyncSpec
       ( spec
       ) where

import           Universum

import           Test.Hspec               (Spec, describe)
import           Test.Hspec.QuickCheck    (prop)
import           Test.QuickCheck          (Property, arbitrary, forAll, property, (===))
import           Test.QuickCheck.Gen      (Gen)

import           Pos.Block.Core           (BlockHeader)
import           Pos.Core                 (HasConfiguration)
import           Pos.Crypto               (EncryptedSecretKey, PassPhrase, noPassEncrypt)
import           Pos.Txp                  (TxAux, TxUndo)
import           Pos.Txp.Toil             (Utxo)
import qualified Pos.Util.Modifier        as MM

import           Pos.Wallet.SscType       (WalletSscType)
import           Pos.Wallet.Web.Tracking  (CAccModifier (..), trackingApplyTxs,
                                           trackingRollbackTxs)

import           Test.Pos.Util            (withDefConfigurations)

import           Test.Pos.Wallet.Web.Util (genWalletAddress, genWalletUtxo)

spec :: Spec
spec = withDefConfigurations $ describe "tx apply and rollback" $ do
    prop "doesn't change initial utxo " testApplyRollback

testApplyRollback :: HasConfiguration => Property
testApplyRollback =
    forAll (genWalletWithUtxo 20) $ \case
    Nothing -> property False
    Just (encSk, psw, utxo) ->
        forAll (genTxSequence encSk psw utxo) $ \txs ->
        let applyModifier =
                trackingApplyTxs encSk []
                (const Nothing)
                (const Nothing)
                (const Nothing)
                txs
            rollbackModifier =
                trackingRollbackTxs encSk []
                (const Nothing)
                (const Nothing)
                (reverse txs)
            applyCAccModifierToUtxo CAccModifier {..} =
                MM.modifyMap camUtxo
        in utxo === (applyCAccModifierToUtxo rollbackModifier $
                     applyCAccModifierToUtxo applyModifier utxo)

genWalletWithUtxo :: Int -> Gen (Maybe (EncryptedSecretKey, PassPhrase, Utxo))
genWalletWithUtxo size = do
    sk <- arbitrary
    let encSk = noPassEncrypt sk
    (encSk, mempty, ) <<$>> genWalletUtxo encSk mempty size

genTxSequence
    :: HasConfiguration
    => EncryptedSecretKey
    -> PassPhrase
    -> Utxo
    -> Gen [(TxAux, TxUndo, BlockHeader WalletSscType)]
genTxSequence = undefined
