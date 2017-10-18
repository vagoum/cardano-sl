-- | This module tests Binary instances for 'Pos.Explorer' types.

module Test.Pos.Explorer.Identity.BinarySpec
       ( spec
       ) where

import           Universum

import           Test.Hspec (Spec, describe)

spec :: Spec
spec = describe "Explorer types" $ do
    pass
    -- TODO Use @binaryTest@ when Test.Pos.Util will be splitted
    -- after merge CSM-423
    -- describe "Bi instances" $ do
    --     binaryTest @TxExtra
