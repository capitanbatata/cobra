-- | 

module Cobra.ShellRunner where

import           Control.Monad.IO.Class
import qualified Data.Map                as Map
import           qualified Control.Foldl as F
import           qualified Data.Text     as T
import           Turtle                         hiding (s)
import           Control.Monad.Except
import           Control.Exception
import           Data.Maybe

import           Cobra.Runner
import           Cobra.ResultsParser
import           Cobra.Data
import           Cobra.Builder
import           Cobra.Error

data ShellRunner = ShellRunner

newtype RunnerM a = RunnerM { runShell :: ExceptT CobraError IO a}
    deriving (Functor, Applicative, Monad, MonadIO, MonadError CobraError)

instance Runner ShellRunner RunnerM where
    runBenchmark _ (Command cmdText) =
        do
        -- Check that the command exists
        mPath <- which (fromText cmdText)
        unless (isJust mPath) (throwError cmdNotFound)
        res <- liftIO $ gatherOutputFromCmd `catch` handler
        case res of
            Left errMsg -> throwError errMsg
            Right testResults -> return testResults
        where
          gatherOutputFromCmd :: IO (Either CobraError TestResults)
          gatherOutputFromCmd = do
              res <- fold (runCmdShell cmdText) F.list
              return $ Right $ TestResults $ Map.fromList res
    
          handler :: IOError -> IO (Either CobraError TestResults)
          handler ex = return $ Left $ mkError 1 (T.pack (show ex))
    
          cmdNotFound :: CobraError
          cmdNotFound = mkError 1 $ "Command not found: " <> cmdText
          
          runCmdShell :: Text -> Shell (TestName, MetricValues)
          runCmdShell cmd = do
              line <- inproc cmd [] empty
              tryParseBMLine line
    
          tryParseBMLine line =
              case parseBMLine (lineToText line) of
                  Left parseErr -> die $ T.pack (show parseErr)
                  Right res -> return res
    
