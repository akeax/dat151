module Compiler where

import Control.Monad
import Control.Monad.State
import Prelude hiding (id,exp)
import Data.Maybe (fromMaybe)
import qualified Data.Map as Map
import Data.Map (Map)
import Data.List (delete)

import AbsCPP
import PrintCPP
import Debug.Trace

compile :: String -> Program -> String
compile name p = unlines $ reverse $ code $ execState (compileProgram name p) (emptyEnv name)

compileProgram :: String -> Program -> State Env ()
compileProgram name (PDefs defs) = do
  -- Add all functions to environment
  mapM_ (\fn@(DFun _typ id _args _stms) ->  addFun id fn) defs

  mapM_ emit [
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
  mapM_ (compileStm True) stms

  emit "return"
  emit ".end method"

  let normalDefs = delete main defs
  mapM_ compileDef normalDefs


-- Does definitions alter environment?
compileDef :: Def -> State Env ()
compileDef (DFun typ (Id name) args stms) = do
  let argTypes' = typesToString $ argTypes args
  let typ'  = typeToString typ
  emit $ ".method public static "++name++"("++argTypes'++")"++typ'
  emit ".limit locals 100"
  emit ".limit stack 1000"
  a <- newBlock

  -- Add all parameters to current block
  mapM_ (\(ADecl typ'' id) -> addVar id typ'') args
  -- Compile all statements
  mapM_ (compileStm False) stms

  emit "return"

  exitBlock a
  emit ".end method"

typesToString :: [Type] -> String
typesToString = concatMap typeToString 

typeToString :: Type -> String
typeToString typ = case typ of
                   Type_double -> "D"
                   Type_int    -> "I"
                   Type_void   -> "V"
                   Type_bool   -> "I"

compileStm :: Bool -> Stm -> State Env ()
compileStm isMain stm = trace ("compileStm "++printTree stm) $ case stm of
  -- Hacky way to handle expression statements of type void
  -- (Could be handled nicer using typed expressions. hardcoded atm)
  SExp e@(EApp (Id s) _args) -> if s == "printInt"
                                then compileExp e
                                else do compileExp e
                                        emit "pop"
  SExp exp -> do compileExp exp
                 emit "pop"
  SDecls typ vars -> mapM_ (`addVar` typ) vars
  SInit typ id exp -> do addVar id typ
                         a <- lookupVar id
                         compileExp exp -- (this adds value to stack)
                         emit $ "istore " ++ show a
  -- Hack: if function is main, disregard return value
  SReturn exp -> do compileExp exp
                    emit (if isMain then "return" else "ireturn")
  SBlock stms -> do
    a <- newBlock
    mapM_ (compileStm False) stms -- todo save return value?
    exitBlock a

  SWhile exp stm' -> do
                        test <- newLabel
                        end <- newLabel
                        emit $ test ++ ":"
                        compileExp exp
                        emit $ "ifeq " ++ end
                        compileStm False stm'
                        emit $ "goto " ++ test
                        emit $ end ++ ":"

  SIfElse exp stm1 stm2 -> do

                            true <- newLabel
                            false <- newLabel
                            compileExp exp
                            emit $ "ifeq " ++ false
                            compileStm False stm1
                            emit $ "goto " ++ true
                            emit $ false ++ ":"
                            compileStm False stm2
                            emit $ true ++ ":"

compileExp :: Exp -> State Env ()
compileExp e = trace ("compileExp"++printTree e) $ case e of
  EId x  -> do
    a <- trace "looking up" $ lookupVar x
    emit ("iload " ++ show a)
  EInt i    -> emit ("bipush " ++ show i)
  EDouble d -> emit ("ldc2_w " ++ show d)
  ETrue     -> emit "iconst_1"
  EFalse    -> emit "iconst_0"
  EPlus e1 e2 -> do
    compileExp e1
    compileExp e2
    emit "iadd"
  EAss (EId id) exp -> do
    compileExp exp
    a <- lookupVar id
    emit "dup"
    emit ("istore " ++ show a) 

  -- TODO fix
  EApp (Id s) args -> do
    -- Compile arguments
    mapM_ compileExp args
    env <- get
    -- Get function and its parts from environment
    let (DFun typ _id params _stms) = functions env Map.! Id s
    let argsTypes' = typesToString $ argTypes params
    let typ'  = typeToString typ

    emit $ case s of
      "printInt"    -> "invokestatic Runtime/printInt(I)V"
      "readInt"     -> "invokestatic Runtime/readInt()I"
      _             -> "invokestatic "++progName env++"/"++s++"("++argsTypes'++")"++typ'

  EString s -> emit $ "ldc " ++ show s
  EMinus exp1 exp2 -> binOp exp1 exp2 "isub"
  ETimes exp1 exp2 -> binOp exp1 exp2 "imul"
  EDiv   exp1 exp2 -> binOp exp1 exp2 "idiv"
  EPIncr (EId x)   -> postVarOp x "iadd"
  EIncr  (EId x)   -> preVarOp x "iadd"
  EPDecr (EId x)   -> postVarOp x "isub"
  EDecr  (EId x)   -> preVarOp x "iadd"
  ELt    exp1 exp2 -> icmpX exp1 exp2 "if_icmplt"
  EGt    exp1 exp2 -> icmpX exp1 exp2 "if_icmpgt"
  ELtEq  exp1 exp2 -> icmpX exp1 exp2 "if_icmple"
  EGtWq  exp1 exp2 -> icmpX exp1 exp2 "if_icmpge"
  EEq    exp1 exp2 -> icmpX exp1 exp2 "if_icmpeq"
  ENEq   exp1 exp2 -> icmpX exp1 exp2 "if_icmpne"
  EAnd   exp1 exp2 -> bool exp1 exp2 "ifeq"
  EOr    exp1 exp2 -> bool exp1 exp2 "ifne"

  where binOp exp1 exp2 op = do
          compileExp exp1
          compileExp exp2
          emit op
        postVarOp id op = do
          a <- lookupVar id
          emit $ "iload " ++ show a
          emit "dup"
          emit "bipush 1"
          emit op
          emit $ "istore " ++ show a
        preVarOp id op = do
          a <- lookupVar id
          emit $ "iload " ++ show a
          emit "bipush 1"
          emit op
          emit "dup"
          emit $ "istore " ++ show a
        icmpX exp1 exp2 op = do
          true <- newLabel
          emit "iconst_1"
          compileExp exp1
          compileExp exp2
          emit $ op ++ " " ++ true
          emit "pop"
          emit "iconst_0"
          emit $ true ++ ":"
        bool exp1 exp2 op =  do
            end  <- newLabel
            compileExp exp1
            emit "dup"
            emit $ op ++ ' ' : end
            emit "pop"
            compileExp exp2
            emit $ end ++ ":"


data Env = E {
  progName        :: String, -- The program name
  addresses   :: [[(Id,Address)]], -- Map from variable names to stack adresses
  nextLabel   :: Int, -- used in newLabel
  nextAddress :: Address, -- used in addVar
  maxAddress  :: Address, -- .limit locals
  maxSize     :: Int, -- .limit stack
  code        :: [Instruction],
  functions   :: Map Id Def
  }

emptyEnv :: String -> Env
emptyEnv name = E {
  progName = name,
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

argTypes :: [Arg] -> [Type]
argTypes = map (\(ADecl typ' _) -> typ')

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


emit :: Instruction -> State Env ()
emit i = modify (\env -> env{code = i : code env})

typeSize :: Type -> Int
typeSize t = case t of
  Type_int -> 1
  Type_double -> 2
  Type_bool -> 1

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

newLabel :: State Env String
newLabel = do env <- get
              modify (\env' -> env' {nextLabel = nextLabel env' + 1} )
              return $ 'L' : show (nextLabel env)
