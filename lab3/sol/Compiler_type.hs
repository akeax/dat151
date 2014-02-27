module Compiler where

import Control.Monad
import Control.Monad.State
--import System.Environment (getArgs)
--import System.Exit (exitFailure)
import Prelude hiding (id,exp)
import Data.Maybe (fromMaybe)
import qualified Data.Map as Map
import Data.Map (Map)
import Data.List (delete)


import AbsCPP
--import AnnotatingTypeChecker
--import LexCPP
--import ParCPP
import PrintCPP
--import ErrM
import Debug.Trace

-- iadd
-- isub
-- imul
-- bipush 
-- iload (loads value from stack)
-- istore (stores value to stack)
-- dup
-- 
-- invokestatic
-- goto
-- ifeq

compile :: String -> Program -> String
compile name p = unlines $ reverse $ code $ execState (compileProgram name p) emptyEnv

compileProgram :: String -> Program -> State Env ()
compileProgram name (PDefs defs) = do
  -- Add all functions to environment
  mapM_ (\fn@(DFun _typ id _args _stms) ->  addFun id fn) defs

  mapM_ emit $ trace "helo" [
    ".class public " ++ name,
    ".super java/lang/Object",
    "",
    ".method public <init>()V",
    "aload_0",
    "invokenonvirtual java/lang/Object/<init>()V",
    "return",
    ".end method",
    "",
    ".method public static main([Ljava/lang/String;)V",
    ".limit locals 100",
    ".limit stack 1000"
   ]

  -- Compile all statements in main
  main@(DFun _typ _id _args stms) <- lookupFun $ Id "main"
  mapM_ compileStm stms

  emit $ trace "emitting return" "return"
  emit ".end method"


  -- remove main from environment (or not!? from local defs instead!?)
  let normalDefs = delete main defs
  -- compile all others in environment (or not!? all remaining local defs instead!?
  mapM_ compileDef normalDefs


-- Does definitions alter environment?
compileDef :: Def -> State Env ()
compileDef (DFun typ (Id name) args stms) = do
  let args' = typesToString $ argTypes args
  let typ'  = typeToString typ
  emit $ ".method public static "++name++"("++args'++")"++typ'
  emit ".limit locals 100"
  emit ".limit stack 1000"
  -- TODO limits
  a <- newBlock
  -- "newBlock", i.e. new variable storage
  -- TODO add params to this new block (Environment's 'addresses')
  mapM_ compileStm stms
  exitBlock a
  emit ".end method"
  where argTypes = map (\(ADecl typ' _) -> typ')

typesToString :: [Type] -> String
typesToString = concatMap typeToString 

typeToString :: Type -> String
typeToString typ = case typ of
                   Type_double -> "D"
                   Type_int    -> "I"


compileStm :: Stm -> State Env ()
compileStm stm = trace ("compileStm "++show stm) $ case stm of
  -- todo
  SExp exp -> do compileExp exp
                 emit "pop"
  SDecls typ vars -> mapM_ (`addVar` typ) vars
  SInit typ id exp -> do addVar id typ
                         a <- lookupVar id
                         compileExp exp -- (this adds value to stack)
                         emitTyped typ $ "store " ++ show a
  SReturn exp -> compileExp exp
  SBlock stms -> do
    a <- newBlock
    mapM_ compileStm stms -- todo save return value?
    exitBlock a
  --SIfElse exp stm1 stm2 -> undefined



  SWhile exp stm' -> do
                        l1 <- newLabel
                        l2 <- newLabel
                        let  test = 'L' : show l1
                             end  = 'L' : show l2
                        emit $ test ++ ":"
                        compileExp exp
                        emit $ "ifeq " ++ read end
                        compileStm stm'
                        emit $ "goto " ++ read test
                        emit $ end ++ ":"

  SIfElse exp stm1 stm2 -> do
                            l1 <- newLabel
                            l2 <- newLabel
                            let true  = 'L' : show l1
                                false = 'L' : show l2
                            compileExp exp
                            emit $ "ifeq " ++ read false
                            compileStm stm1
                            emit $ "goto " ++ read true
                            emit $ false ++ ":"
                            compileStm stm2
                            emit $ true ++ ":"



compileExp :: Exp -> State Env ()
compileExp (ETyped e t) = trace ("compileExp"++printTree e) $ case e of
  EId x  -> do
    a <- trace "looking up" $ lookupVar x
    emitTyped t ("load " ++ show a)
  EInt i    -> emit ("bipush " ++ show i)
  EDouble d -> emit ("ldc2_w " ++ show d)
  EPlus e1 e2 -> do
    compileExp e1
    compileExp e2
    emitTyped t "add"
  EAss (EId id) exp@(ETyped _ t') -> do
    compileExp exp
    a <- lookupVar id
    dup t'
    emitTyped t' ("store " ++ show a) 

  -- TODO should take ETyped instead of id?
  EApp (Id s) args -> do
    -- Compile arguments
    mapM_ compileExp $ trace "compiling arguments" args
    -- TODO lookup type (used for function call)
    emit $ case s of
      "printInt"    -> "invokestatic Runtime/printInt(I)V"
      --Type_double -> "invokestatic Runtime/printDouble(D)V"
      s'             -> "invokestatic C/"++s'

  EString s -> emit $ "ldc " ++ show s
  EMinus exp1 exp2 -> do
    compileExp exp1
    compileExp exp2
    emitTyped t "sub"
  ETimes exp1 exp2 -> do
    compileExp exp1
    compileExp exp2
    emitTyped t "mul"
  EDiv exp1 exp2 -> do
    compileExp exp1
    compileExp exp2
    emitTyped t "div"
  EIncr (EId x) -> do
    a <- lookupVar x
    emitTyped t $ "load " ++ show a
    dup t
    emit "bipush 1"
    emit "iadd"
    emit $ "istore " ++ show a
  EPIncr (EId x) -> do
    a <- lookupVar x
    emit $ "iload " ++ show a
    emit "bipush 1"
    emit "iadd"
    emit "dup"
    emit $ "istore " ++ show a
  EDecr (EId x) -> do
    a <- lookupVar x
    emit $ "iload " ++ show a
    emit "dup"
    emit "bipush 1"
    emit "isub"
    emit $ "istore " ++ show a
  EPDecr (EId x) -> do
    a <- lookupVar x
    emit $ "iload " ++ show a
    emit "bipush 1"
    emit "isub"
    emit "dup"
    emit $ "istore " ++ show a
  _ -> return $ trace "OAOAS" ()
  e'@(ETyped _ _) -> compileExp e'
compileExp e = return $ trace ("HELO! LOOKING UP " ++ printTree e) ()


-- TODO When is stack cleared during function application? GC?
-- is cleared automatically

data Env = E {
  addresses   :: [[(Id,Address)]], -- Map from variable names to stack adresses
  nextLabel   :: Int, -- used in newLabel
  nextAddress :: Address, -- used in addVar
  maxAddress  :: Address, -- .limit locals
  maxSize     :: Int, -- .limit stack
  code        :: [Instruction],
  functions   :: Map Id Def
  }

emptyEnv :: Env
emptyEnv = E {
  addresses = [[]],
  nextLabel = 0,
  nextAddress = 1,
  maxAddress = 1,
  maxSize = 1,
  code = [],
  functions = Map.empty
  }

type Instruction = String
type Address = Int

-- A function and its various auxiliary functions
getParamTypes :: Def -> [Type]
getParamTypes (DFun _typ _id args _stms) = map (\(ADecl t _id) -> t) args
getParamNames :: Def -> [Id]
getParamNames (DFun _typ _id args _stms) = map (\(ADecl _t id) -> id) args
getReturnType :: Def -> Type
getReturnType (DFun typ _id _args _stms) = typ

-- Adds a function to the environment
addFun :: Id -> Def -> State Env ()
addFun id fn = modify (\env -> env {
  functions = Map.insert id fn (functions env)
  })
-- Looks up a function in the environment
lookupFun :: Id -> State Env Def
lookupFun id = do
  env <- get
  return $ functions env Map.! id 


emit :: Instruction -> State Env ()
emit i = modify (\env -> env{code = i : code env})

emitTyped :: Type -> Instruction -> State Env ()
emitTyped t i = emit (c ++ i)
  where c = case t of
              Type_int -> "i"
              Type_double -> "d"

dup :: Type -> State Env ()
dup t = emit i
  where i = case t of
              Type_int    -> "dup"
              Type_double -> "dup2"

pop :: Type -> State Env ()
pop t = emit i
  where i = case t of
              Type_int    -> "pop"
              Type_double -> "pop2"

addVar :: Id -> Type -> State Env ()
addVar x t = modify (\env -> env {
  addresses = case addresses env of (scope:rest) -> ((x,nextAddress env):scope):rest,
  nextAddress = nextAddress env + typeSize t
  })

lookupVar :: Id -> State Env Address
lookupVar x = do
  env <- get
  return $ look (addresses env) x 
 where
   look [] x' = error $ "Unknown variable " ++ printTree x' ++ "."
   look (scope:rest) x' = fromMaybe (look rest x') (lookup x' scope)

typeSize :: Type -> Int
typeSize t = case t of
  Type_int -> 1
  Type_double -> 2

-- TODO newLabel (generates unique names)


-- todo extend(def)

newBlock :: State Env Address
newBlock = do
  modify (\env -> env {addresses = [] : addresses env})
  env <- get
  return $ nextAddress env

exitBlock :: Address -> State Env ()
exitBlock a = modify (\env -> env {
   addresses = tail (addresses env),
   nextAddress = a
   })

newLabel :: State Env Int
newLabel = do env <- get
              modify (\env' -> env' {nextLabel = nextLabel env' + 1} )
              return $ nextLabel env
