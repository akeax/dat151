module Interpreter where

import AbsCPP
import PrintCPP

import Control.Monad
import qualified Data.Map as Map
import Data.Map (Map)
import Prelude hiding (id, exp)

interpret :: Program -> IO ()
interpret (PDefs defs) = do
  -- Add function definitions
  env <- foldM (\env (DFun _type id args stms) -> addFun env id (argNames args,stms) ) emptyEnv defs
  -- Evaluate "main" function
  evalFun env (Id "main") []
  return ()
  where argNames = map (\(ADecl _type val) -> val) 

-- Types
data Val = VInteger Integer
         | VDouble Double
         | VString String
         | VBool Bool
         | VUndefined
         | VVoid
  deriving (Eq,Show)

type Env = (Sig,[Context]) -- functions and context stack
type Sig = Map Id Fun -- function names and values
type Context = Map Id Val -- variables with their values
type Fun = ([Id],[Stm]) -- parameter names and statements

-- Special variable, used for passing return value from fn to caller
returnId :: Id
returnId = Id "return"

-- Helper functions

-- Looks up the value of a variable in all contexts
-- Prints an error if unsuccessful
lookupVar :: Env -> Id -> IO Val
lookupVar (sig, c:cs) id =
  case Map.lookup id c of
    Just v  -> return v
    Nothing -> lookupVar (sig, cs) id
lookupVar (_sig, []) id = do
  putStrLn $ "Variable not initialised: " ++ printTree id ++ "."
  return VUndefined

-- Adds a variable to the topmost context
-- Prints an error if unsuccessful
addVar :: Env -> Id -> Val -> IO Env
addVar env@(sig,c:cs) id val =
  case Map.lookup id c of
    Just _  -> do putStrLn $ "Variable already declared: " ++ printTree id
                  return env
    Nothing -> return (sig, Map.insert id val c : cs)

-- Updates the topmost occurence of variable 'id'
-- Prints an error if unsuccessful
updateVar :: Env -> Id -> Val -> IO Env
updateVar (sig,c:cs) id val =
  case Map.lookup id c of
    Just _  -> return (sig, Map.insert id val c : cs)
    Nothing -> do (_,cs') <- updateVar (sig, cs) id val
                  return (sig,c:cs')
updateVar env@(_sig,[]) id _val = do putStrLn $ "Cannot assign to undeclared variable " ++ printTree id
                                     return env

-- Looks up the params/statements of a function
-- Prints an error if unsuccessful
lookupFun :: Env -> Id -> IO Fun
lookupFun (sig, _context) id =
    case Map.lookup id sig of
      Just v      -> return v
      Nothing     -> do putStrLn $ "Unknown function: " ++ printTree id ++ "."
                        return ([],[])

-- Adds a function to the environment
-- Prints an error if unsuccessful
addFun :: Env -> Id -> Fun -> IO Env
addFun env@(sig, cs) id fun =
    case Map.lookup id sig of
      Nothing -> return (Map.insert id fun sig, cs)
      Just _  -> do
        putStrLn $ "Function already declared: "++ show id
        return env

emptyEnv :: Env
emptyEnv = (Map.empty, [Map.empty])

newBlock :: Env -> Env
newBlock (sig, cs) = (sig, Map.empty:cs)


---- Value operations ----
-- Maths
-- TODO generalise
addVal :: Val -> Val -> Val
addVal (VInteger i1) (VInteger i2) = VInteger (i1 + i2)
addVal (VDouble d1)  (VDouble d2)  = VDouble  (d1 + d2)
addVal (VString s1)  (VString s2)  = VString  (s1 ++ s2)
addVal _             _             = undefined
subVal :: Val -> Val -> Val
subVal (VInteger i1) (VInteger i2) = VInteger (i1 - i2)
subVal (VDouble d1)  (VDouble d2)  = VDouble  (d1 - d2)
subVal _             _             = undefined 
mulVal :: Val -> Val -> Val
mulVal (VInteger i1) (VInteger i2) = VInteger (i1 * i2)
mulVal (VDouble d1)  (VDouble d2)  = VDouble  (d1 * d2)
mulVal _             _             = undefined 
divVal :: Val -> Val -> Val
divVal (VInteger i1) (VInteger i2) = VInteger (i1 `div` i2)
divVal (VDouble d1)  (VDouble d2)  = VDouble  (d1 / d2)
divVal _             _             = undefined
incVal :: Val -> Val
incVal (VInteger i) = VInteger (i+1)
incVal (VDouble d)  = VDouble  (d+1)
incVal _            = undefined
decVal :: Val -> Val
decVal (VInteger i) = VInteger (i-1)
decVal (VDouble d)  = VDouble  (d-1)
decVal _            = undefined
-- Comparisons
ltVal :: Val -> Val -> Val
ltVal (VInteger i1) (VInteger i2) = VBool (i1 < i2)
ltVal (VDouble d1)  (VDouble d2)  = VBool (d1 < d2)
ltVal _             _             = undefined 
gtVal :: Val -> Val -> Val
gtVal (VInteger i1) (VInteger i2) = VBool (i1 > i2)
gtVal (VDouble d1)  (VDouble d2)  = VBool (d1 > d2)
gtVal _             _             = undefined 
lteVal :: Val -> Val -> Val
lteVal (VInteger i1) (VInteger i2) = VBool (i1 <= i2)
lteVal (VDouble d1)  (VDouble d2)  = VBool (d1 <= d2)
lteVal _             _             = undefined 
gteVal :: Val -> Val -> Val
gteVal (VInteger i1) (VInteger i2) = VBool (i1 >= i2)
gteVal (VDouble d1)  (VDouble d2)  = VBool (d1 >= d2)
gteVal _             _             = undefined 
eqVal :: Val -> Val -> Val
eqVal (VInteger i1) (VInteger i2) = VBool (i1 == i2)
eqVal (VDouble d1)  (VDouble d2)  = VBool (d1 == d2)
eqVal (VBool b1)    (VBool b2)    = VBool (b1 == b2)
eqVal _             _             = undefined 
neqVal :: Val -> Val -> Val
neqVal (VInteger i1) (VInteger i2) = VBool (i1 /= i2)
neqVal (VDouble d1)  (VDouble d2)  = VBool (d1 /= d2)
neqVal (VBool b1)    (VBool b2)    = VBool (b1 /= b2)
neqVal _             _             = undefined 
-- Boolean operations
andVal :: Val -> Val -> Val
andVal (VBool b1) (VBool b2) = VBool (b1 && b2)
andVal _             _       = undefined 
orVal :: Val -> Val -> Val
orVal (VBool b1) (VBool b2) = VBool (b1 || b2)
orVal _             _       = undefined 

-- Evaluate expressions (eval)
evalExp :: Env -> Exp -> IO (Val,Env)
evalExp env x = case x of
  -- Literals
  ETrue            -> return (VBool True,env)
  EFalse           -> return (VBool False,env)
  EInt i           -> return (VInteger i,env)
  EDouble d        -> return (VDouble d,env)
  EString s        -> return (VString s,env)
  EId id           -> do val <- lookupVar env id
                         return (val,env)
  -- Binary operations
  EPlus exp1 exp2  -> eval2ExpsFn env exp1 exp2 addVal
  EMinus exp1 exp2 -> eval2ExpsFn env exp1 exp2 subVal
  ETimes exp1 exp2 -> eval2ExpsFn env exp1 exp2 mulVal
  EDiv exp1 exp2   -> eval2ExpsFn env exp1 exp2 divVal
  ELt exp1 exp2    -> eval2ExpsFn env exp1 exp2 ltVal
  EGt exp1 exp2    -> eval2ExpsFn env exp1 exp2 gtVal
  ELtEq exp1 exp2  -> eval2ExpsFn env exp1 exp2 lteVal
  EGtWq exp1 exp2  -> eval2ExpsFn env exp1 exp2 gteVal
  EEq exp1 exp2    -> eval2ExpsFn env exp1 exp2 eqVal
  ENEq exp1 exp2   -> eval2ExpsFn env exp1 exp2 neqVal
  -- TODO lazily evaluate
  EAnd exp1 exp2   -> do (val1,env') <- evalExp env exp1
                         if val1 == VBool False
                         then return (val1,env')
                         else evalExp env' exp2
  EOr exp1 exp2    -> do (val1,env') <- evalExp env exp1
                         if val1 == VBool True
                         then return (val1,env')
                         else evalExp env' exp2
  -- Pre-increment
  EIncr (EId id)   -> do val <- lookupVar env id
                         let val' = incVal val
                         env' <- updateVar env id val'
                         return (val',env')
  EIncr exp1       -> do putStrLn $ "Cannot increment non-variable" ++ printTree exp1
                         return (VUndefined,env)
  -- Pre-decrement
  EDecr (EId id)   -> do val <- lookupVar env id
                         let val' = decVal val
                         env' <- updateVar env id val'
                         return (val',env')
  EDecr exp1       -> do putStrLn $ "Cannot decrement non-variable" ++ printTree exp1
                         return (VUndefined,env)
  -- Post-increment
  EPIncr (EId id)  -> do val <- lookupVar env id
                         let val' = incVal val
                         env' <- updateVar env id val'
                         return (val,env')
  EPIncr exp1      -> do putStrLn $ "Cannot increment non-variable" ++ printTree exp1
                         return (VUndefined,env)
  -- Post-decrement
  EPDecr (EId id)  -> do val <- lookupVar env id
                         let val' = decVal val
                         env' <- updateVar env id val'
                         return (val,env')
  EPDecr exp1      -> do putStrLn $ "Cannot decrement non-variable" ++ printTree exp1
                         return (VUndefined,env)

  EAss (EId id) exp' -> do (val,env') <- evalExp env exp'
                           env'' <- updateVar env' id val
                           return (val,env'')
  EAss exp1 exp2    -> do putStrLn $ "Cannot assign "++ printTree exp2 ++
                                     " to non-variable " ++ printTree exp1
                          return (VUndefined,env)

  -- Standard function printInt
  EApp (Id "printInt") (exp:_exps) -> do
    val <- evalExp env exp
    case val of
      (VInteger i,env') -> do print i
                              return (VVoid,env')
      (_, env') -> do putStrLn "Argument to printInt was not an integer"
                      return (VUndefined,env')

  -- Standard function printDouble
  EApp (Id "printDouble") (exp:_exps) -> do
    val <- evalExp env exp
    case val of
      (VDouble d,env') -> do print d
                             return (VVoid,env')
      (_, env') -> do putStrLn "Argument to printDouble was not a double"
                      return (VUndefined,env')

  -- Standard function readInt
  EApp (Id "readInt") [] -> do i <- readLn
                               return (VInteger i,env)

  -- Standard function readDouble
  EApp (Id "readDouble") [] -> do d <- readLn
                                  return (VDouble d,env)

  -- Function application
  EApp id exps     -> do (args,env') <- evalExps env exps
                         val <- evalFun env' id args
                         return (val,env')
  where
    -- Evaluate 2 expressions sequentially, and apply function to result
    eval2ExpsFn env' exp1 exp2 fn = do
      (v1,env'')  <- evalExp env'  exp1
      (v2,env''') <- evalExp env'' exp2
      return (fn v1 v2,env''')

-- Evaluates many expressions
evalExps :: Env -> [Exp] -> IO ([Val],Env)
evalExps env (exp:exps) = do (val,env')   <- evalExp env exp
                             (vals,env'') <- evalExps env' exps
                             return (val:vals,env'')
evalExps env []         = return ([],env)

-- Evaluates a function
-- Does not evaluate arguments => does not change environment
evalFun :: Env -> Id -> [Val] -> IO Val
evalFun env id args = do (params,stms) <- lookupFun env id
                         -- create new block and assign arguments to parameters
                         env' <- foldM argToParam (newBlock env) $ zip params args 
                         -- reserve variable "return"
                         env'' <- addVar env' returnId VUndefined
                         -- evaluate all statements (and expose topmost context)
                         (_sig,c:_cs) <- foldM execStm env'' stms
                         -- look in topmost context for return value
                         case Map.lookup returnId c of
                           Just t  -> return t
                           Nothing -> return VUndefined
  where
    -- TODO uncurry instead?
    argToParam env'' (param,arg) = addVar env'' param arg 


-- Execute statements
-- (Would like to use Either type to handle return value as Left, but can't mix with IO afaik)
execStm :: Env -> Stm -> IO Env
execStm env stm = case stm of
  SExp exp               -> do (_val,env') <- evalExp env exp
                               return env'
  SDecls _type vars      -> foldM (\env' var -> addVar env' var VUndefined) env vars
  SInit _type id exp     -> do (val,env') <- evalExp env exp
                               addVar env' id val
  SReturn exp            -> do (val,env') <- evalExp env exp
                                -- push return value to reserved variable
                               updateVar env' returnId val
  wexp@(SWhile exp stm') -> do (val,env') <- evalExp env exp
                               if val == VBool True
                               then do env'' <- execStm env' stm'
                                       execStm env'' wexp
                               else return env'
  SBlock stms            -> do let env' = newBlock env -- (add new context)
                               (sig,_c:cs) <- foldM execStm env' stms
                               return (sig,cs) -- (remove topmost context)
  SIfElse exp stm1 stm2  -> do (val,env') <- evalExp env exp
                               execStm env' $ if val == VBool True then stm1 else stm2
