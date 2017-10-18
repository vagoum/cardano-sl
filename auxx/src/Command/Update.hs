{-# LANGUAGE NamedFieldPuns #-}

-- | Update system related functionality in Auxx.

module Command.Update
       ( vote
       , propose
       , hashInstaller
       ) where

import           Universum

import qualified Data.ByteString.Lazy     as BSL
import qualified Data.HashMap.Strict      as HM
import           Data.List                ((!!))
import           Data.Time.Units          (convertUnit)
import           Formatting               (sformat, string, (%))
import           Serokell.Util            (sec)
import           System.Wlog              (logDebug)

import           Pos.Binary               (Raw)
import           Pos.Communication        (SendActions, immediateConcurrentConversations,
                                           sendUpdateProposal, submitUpdateProposal,
                                           submitVote)
import           Pos.Configuration        (HasNodeConfiguration)
import           Pos.Core.Configuration   (HasConfiguration, genesisBlockVersionData)
import           Pos.Crypto               (Hash, SignTag (SignUSVote), emptyPassphrase,
                                           encToPublic, hash, hashHexF, safeSign,
                                           unsafeHash, withSafeSigner, withSafeSigners)
import           Pos.Data.Attributes      (mkAttributes)
import           Pos.Infra.Configuration  (HasInfraConfiguration)
import           Pos.Update               (BlockVersionData (..),
                                           BlockVersionModifier (..), SystemTag, UpId,
                                           UpdateData (..), UpdateVote (..),
                                           installerHash, mkUpdateProposalWSign)
import           Pos.Update.Configuration (HasUpdateConfiguration)
import           Pos.Wallet               (getSecretKeysPlain)

import           Command.Types            (ProposeUpdateParams (..),
                                           ProposeUpdateSystem (..))
import           Mode                     (AuxxMode, CmdCtx (..), getCmdCtx)

----------------------------------------------------------------------------
-- Vote
----------------------------------------------------------------------------

vote ::
       ( HasConfiguration
       , HasInfraConfiguration
       , HasUpdateConfiguration
       , HasNodeConfiguration
       )
    => SendActions AuxxMode
    -> Int
    -> Bool
    -> UpId
    -> AuxxMode ()
vote sendActions idx decision upid = do
    CmdCtx{ccPeers} <- getCmdCtx
    logDebug $ "Submitting a vote :" <> show (idx, decision, upid)
    skey <- (!! idx) <$> getSecretKeysPlain
    msignature <- withSafeSigner skey (pure emptyPassphrase) $ mapM $
                        \ss -> pure $ safeSign SignUSVote ss (upid, decision)
    case msignature of
        Nothing -> putText "Invalid passphrase"
        Just signature -> do
            let voteUpd = UpdateVote
                    { uvKey        = encToPublic skey
                    , uvProposalId = upid
                    , uvDecision   = decision
                    , uvSignature  = signature
                }
            if null ccPeers
                then putText "Error: no addresses specified"
                else do
                    submitVote (immediateConcurrentConversations sendActions ccPeers) voteUpd
                    putText "Submitted vote"

----------------------------------------------------------------------------
-- Propose, hash installer
----------------------------------------------------------------------------

propose ::
       ( HasConfiguration
       , HasInfraConfiguration
       , HasUpdateConfiguration
       , HasNodeConfiguration
       )
    => SendActions AuxxMode
    -> Int
    -> ProposeUpdateParams
    -> Bool
    -> AuxxMode ()
propose sendActions idx ProposeUpdateParams{..} voteAll = do
    CmdCtx{ccPeers} <- getCmdCtx
    logDebug "Proposing update..."
    skey <- (!! idx) <$> getSecretKeysPlain
    let BlockVersionData {..} = genesisBlockVersionData
    let bvm =
            BlockVersionModifier
            { bvmScriptVersion     = Just puScriptVersion
            , bvmSlotDuration      = Just $ convertUnit (sec puSlotDurationSec)
            , bvmMaxBlockSize      = Just puMaxBlockSize
            , bvmMaxHeaderSize     = Just bvdMaxHeaderSize
            , bvmMaxTxSize         = Just bvdMaxTxSize
            , bvmMaxProposalSize   = Just bvdMaxProposalSize
            , bvmMpcThd            = Just bvdMpcThd
            , bvmHeavyDelThd       = Just bvdHeavyDelThd
            , bvmUpdateVoteThd     = Just bvdUpdateVoteThd
            , bvmUpdateProposalThd = Just bvdUpdateProposalThd
            , bvmUpdateImplicit    = Just bvdUpdateImplicit
            , bvmSoftforkRule      = Nothing
            , bvmTxFeePolicy       = Nothing
            , bvmUnlockStakeEpoch  = Nothing
            }
    updateData <- mapM updateDataElement puUpdates
    let udata = HM.fromList updateData
    let whenCantCreate = error . mappend "Failed to create update proposal: "

    withSafeSigner skey (pure emptyPassphrase) $ \case
        Nothing -> putText "Invalid passphrase"
        Just ss -> do
            let updateProposal = either whenCantCreate identity $
                    mkUpdateProposalWSign
                        puBlockVersion
                        bvm
                        puSoftwareVersion
                        udata
                        (mkAttributes ())
                        ss
            if null ccPeers
                then putText "Error: no addresses specified"
                else do
                    let upid = hash updateProposal
                    let enqueue = immediateConcurrentConversations sendActions ccPeers
                    if not voteAll then do
                        submitUpdateProposal enqueue ss updateProposal
                        putText $ sformat ("Update proposal submitted, upId: "%hashHexF) upid
                    else do
                        votes <- constructVotes upid
                        sendUpdateProposal enqueue upid updateProposal votes
                        putText $ sformat ("Update proposal submitted along with votes, upId: "%hashHexF) upid
  where
    constructVotes :: UpId -> AuxxMode [UpdateVote]
    constructVotes upid = do
        skeys <- getSecretKeysPlain
        signatures <-
            withSafeSigners
                skeys
                (pure emptyPassphrase)
                (pure . map (\s -> safeSign SignUSVote s (upid, True)))
        let safeZip a b =
                if length a == length b then zip a b
                else error $ "Number of signatures: " <> show (length b) <> ", expected " <> show (length a)
        forM (safeZip skeys signatures) $ \(skey, signature) -> pure $
            UpdateVote
                { uvKey        = encToPublic skey
                , uvProposalId = upid
                , uvDecision   = True
                , uvSignature  = signature
                }

updateDataElement :: MonadIO m => ProposeUpdateSystem -> m (SystemTag, UpdateData)
updateDataElement ProposeUpdateSystem{..} = do
    diffHash <- hashFile pusBinDiffPath
    pkgHash <- hashFile pusInstallerPath
    pure (pusSystemTag, UpdateData diffHash pkgHash dummyHash dummyHash)

dummyHash :: Hash Raw
dummyHash = unsafeHash (0 :: Integer)

hashFile :: MonadIO m => Maybe FilePath -> m (Hash Raw)
hashFile Nothing  = pure dummyHash
hashFile (Just filename) = do
    fileData <- liftIO $ BSL.readFile filename
    let h = installerHash fileData
    putText $ sformat ("Read file "%string%" succesfuly, its hash: "%hashHexF) filename h
    pure h

hashInstaller :: FilePath -> AuxxMode ()
hashInstaller path = do
    h <- installerHash <$> liftIO (BSL.readFile path)
    putText $ sformat ("Hash of installer '"%string%"' is "%hashHexF) path h
