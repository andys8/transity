module Main where

import Control.Applicative (pure)
import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Console (CONSOLE, log, error)
import Control.Monad.Eff.Exception (EXCEPTION)
import Data.Array ((!!))
import Data.Functor (map)
import Data.Monoid ((<>))
import Data.Result (Result(..), note)
import Data.Tuple
import Node.Encoding (Encoding(UTF8))
import Node.FS (FS)
import Node.FS.Sync (readTextFile)
import Node.Path as Path
import Node.Process (PROCESS, argv, cwd)
import Prelude (Unit, bind)
import Transity.Data.Ledger (Ledger)
import Transity.Data.Ledger as Ledger


usageString :: String
usageString = """
Usage: transity <command> <path to ledger.yaml>

Commands:
  balance       Show a simple balance of all accounts
  transactions  Show all transcations and their transfers
  postings      Show all individual postings
"""


run :: String -> Ledger -> Result String String
run command ledger =
  case command of
    "balance" -> Ok (Ledger.showBalance true ledger)
    "transactions" -> Ok (Ledger.showPrettyAligned true ledger)
    "postings" -> Ok (Ledger.showBalance true ledger)

    other -> Error ("\"" <> other <> "\" is not a valid command")


parseArguments :: Array String -> Result String (Tuple String String)
parseArguments arguments = do
  commandName <- note usageString (arguments !! 2)
  filePathArg <- note
    ("No path to a ledger file was provided\n\n" <> usageString)
    (arguments !! 3)
  pure (Tuple commandName filePathArg)


loadAndExec
  :: String
  -> Tuple String String
  -> forall e. Eff (exception :: EXCEPTION, fs :: FS | e) (Result String String)

loadAndExec currentDir (Tuple command filePathRel) = do
  let resolve = Path.resolve [currentDir]
  let filePathAbs = resolve filePathRel
  ledgerFileContent <- readTextFile UTF8 filePathAbs
  let
    result = do
      ledger <- Ledger.fromYaml ledgerFileContent
      run command ledger
  pure result


main :: forall eff . Eff
  ( exception :: EXCEPTION
  , console :: CONSOLE
  , fs :: FS
  , process :: PROCESS | eff) Unit
main = do
  arguments <- argv
  currentDir <- cwd

  let
    result = map
      (loadAndExec currentDir)
      (parseArguments arguments)

  execution <- case result of
    Ok output -> output
    Error message -> pure (Error message)

  case execution of
    Ok output -> log output
    Error message -> error message


-- TODO: Use Monad trasnformers
-- resultT = ExceptT <<< toEither
-- unResultT = unExceptT >>> either Error Ok
-- main = do
--   result <- runResultT $ join $ map resultT $
--     loadAndExec <$> lift cwd <*> (resultT <<< parseArguments =<< lift argv)
--   case result of
--     Ok output -> log output
--     Error message -> error message
