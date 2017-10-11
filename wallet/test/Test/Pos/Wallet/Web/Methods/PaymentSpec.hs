module Test.Pos.Wallet.Web.Methods.PaymentSpec
       ( spec
       ) where

import           Universum

import           Data.List                      ((!!))
import           Formatting                     (build, sformat, (%))
import           Test.Hspec                     (Spec, describe)
import           Test.Hspec.QuickCheck          (modifyMaxSuccess)
import           Test.QuickCheck                (choose)
import           Test.QuickCheck.Monadic        (pick)

import           Pos.Client.Txp.Balances        (getBalance)
import           Pos.Core                       (mkCoin, unsafeGetCoin)
import           Pos.Launcher                   (HasConfigurations)
import           Pos.Wallet.Web.Account         (myRootAddresses)
import           Pos.Wallet.Web.ClientTypes     (CAccount (..), CWAddressMeta (..))
import           Pos.Wallet.Web.Methods.Logic   (getAccounts)
import           Pos.Wallet.Web.Methods.Payment (newPayment)
import qualified Pos.Wallet.Web.State.State     as WS
import           Pos.Wallet.Web.Util            (decodeCTypeOrFail,
                                                 getAccountAddrsOrThrow)
import           Test.Pos.Util                  (maybeStopProperty, stopProperty,
                                                 withDefConfigurations)

import           Test.Pos.Wallet.Web.Mode       (WalletProperty, walletPropertySpec)
import           Test.Pos.Wallet.Web.Util       (deriveRandomAddress, expectedAddrBalance,
                                                 importSomeWallets)


spec :: Spec
spec = withDefConfigurations $ describe "Wallet.Web.Methods.Payment" $ modifyMaxSuccess (const 10) $ do
    describe "newPayment" $ do
        describe "One payment" oneNewPaymentSpec

oneNewPaymentSpec :: HasConfigurations => Spec
oneNewPaymentSpec = walletPropertySpec oneNewPaymentDesc $ do
    passphrases <- importSomeWallets
    dstCAddr <- deriveRandomAddress passphrases
    let l = length passphrases
    rootsEnc <- lift myRootAddresses
    idx <- pick $ choose (0, l - 1)
    let walId = rootsEnc !! idx
    let pswd = passphrases !! idx
    let noOneAccount = sformat ("There is no one account for wallet: "%build) walId
    srcAccount <- maybeStopProperty noOneAccount =<< (lift $ head <$> getAccounts (Just walId))
    srcAccId <- lift $ decodeCTypeOrFail (caId srcAccount)

    srcAddr <- getAddress srcAccId
    -- Dunno how to get account's balances without CAccModifier
    initBalance <- getBalance srcAddr
    -- `div` 2 to leave money for tx fee
    coins <- pick $ mkCoin <$> choose (1, unsafeGetCoin initBalance `div` 2)
    void $ lift $ newPayment pswd srcAccId dstCAddr coins
    -- !() <- traceM $ sformat ("newPayment: srcAddr "%build%" coins "%build) srcAddr coins
    -- TODO get changeAddr from TxAux
    --changeAddr <- getAddress srcAccId
    dstAddr <- lift $ decodeCTypeOrFail dstCAddr

    -- Validate tx sent, tx history

    -- Validate balances
    expectedAddrBalance dstAddr coins
    expectedAddrBalance srcAddr (mkCoin 0)
    --expectedAddrBalance changeAddress

    -- Validate change and used address
    -- expectedUserAddresses
    -- expectedChangeAddresses
  where
    getAddress srcAccId =
        lift . decodeCTypeOrFail . cwamId =<< expectedOne =<< lift (getAccountAddrsOrThrow WS.Existing srcAccId)
    expectedOne :: [a] -> WalletProperty a
    expectedOne []     = stopProperty "expected at least one element, but list empty"
    expectedOne (x:[]) = pure x
    expectedOne (_:_)  = stopProperty "expected one element, but list contains more elements"

    oneNewPaymentDesc =
        "Send money from one own address to another; " <>
        "check balances validity for destination address, source address and change address; " <>
        "validate history and used/change addresses"
