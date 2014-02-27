module TypeChecker where

import AbsCPP
import PrintCPP
import ErrM
import qualified Data.Map as Map
import Data.Map (Map)
import Control.Monad (foldM)

type Env        = (Signature,[Context]) -- functions and context stack
type Signature  = Map Id ([Type],Type)  -- function type signature
type Context    = Map Id Type           -- variables with their types

-- Check a whole program
typecheck :: Program -> Err ()
typecheck (PDefs ds) = do
  -- Add all (function) definitions to environment
  env  <- foldM (\env  (DFun typ id args _) -> updateFun env id (argTypes args,typ) ) emptyEnv ds
  
  -- Add standard functions to environment
  env' <- foldM (\env' (DFun typ id args _) -> updateFun env' id (argTypes args,typ) ) env stdFunctions
  
  -- Check all definitions
  mapM_ (checkDef env') ds 
  where argTypes = map (\(ADecl typ _) -> typ) 
        stdFunctions = [ DFun Type_void   (Id "printInt")    [ADecl Type_int (Id "x")]    [],
                         DFun Type_void   (Id "printDouble") [ADecl Type_double (Id "x")] [],
                         DFun Type_int    (Id "readInt")     []                           [],
                         DFun Type_double (Id "readDouble")  []                           [] ]

checkDef :: Env -> Def -> Err ()
checkDef env (DFun typ _ args stms) = do
    newEnv <- foldM addArg env args
    checkStms newEnv typ stms
    return ()
    where addArg env' (ADecl typ' id') = updateVar env' id' typ'

emptyEnv :: Env
emptyEnv = let
    empty_signature = Map.empty
    empty_context   = Map.empty
    in (empty_signature, [empty_context])

newBlock :: Env -> Env
newBlock (signature, context) = 
    let empty_context         = Map.empty
    in (signature, empty_context:context)

lookupVar :: Env -> Id -> Err Type
lookupVar (_signature, []) id = fail $ "Unknown variable: " ++ printTree id ++ "."
lookupVar (signature, scope:rest) id =
    case Map.lookup id scope of
      Just t      -> return t
      Nothing     -> lookupVar (signature, rest) id
  
lookupFun :: Env -> Id -> Err ([Type],Type)
lookupFun (signature, _context) id =
    case Map.lookup id signature of
      Just t      -> return t
      Nothing     -> fail $ "Unknown function: " ++ printTree id ++ "."

updateVar :: Env -> Id -> Type -> Err Env
updateVar (signature, context:contexts) id typ =
    let lookup_var = Map.lookup id context
    in case lookup_var of
        Nothing -> return (signature, Map.insert id typ context:contexts)
        Just t  -> fail $ "variable already declared: "++ show id
                          ++ ", type: " ++ show t

updateFun :: Env -> Id -> ([Type],Type) -> Err Env
updateFun (signature, context) id fun =
    let lookup_fun = Map.lookup id signature
    in case lookup_fun of
        Nothing -> return (Map.insert id fun signature, context)
        Just _  -> fail $ "Function already declared: "++ show id
  
checkStm :: Env -> Type -> Stm -> Err Env
checkStm env typ stm = case stm of
    SExp exp       -> do inferExp env exp
                         return env
    SDecls typ ids -> case ids of
                         id:ids -> do env' <- updateVar env id typ
                                      checkStm env' typ (SDecls typ ids)
                         []     -> fail $ "No variable for " ++ show typ
    SInit t id exp -> do checkExp env t exp
                         updateVar env id t
    SReturn exp    -> do t_return <- inferExp env exp
                         if t_return == typ
                         then return env
                         else fail $ "Found type: " ++ show t_return ++
                                     "; expected type: " ++ show typ
    SWhile exp st  -> do checkExp env Type_bool exp
                         checkStm env typ st 
    SBlock stms    -> do checkStms (newBlock env) typ stms
                         return env
    SIfElse exp stm1 stm2 -> do checkExp env Type_bool exp
                                checkStm env typ stm1
                                checkStm env typ stm2   

checkStms :: Env -> Type -> [Stm] -> Err Env
checkStms env typ stms = case stms of
    stm:stms -> do env' <- checkStm env typ stm
                   checkStms env' typ stms
    []       -> return env

checkExp :: Env -> Type -> Exp -> Err ()
checkExp env typ exp =
    do typ2 <- inferExp env exp
       if typ2 == typ
       then return ()
       else fail $ "type of " ++ printTree exp ++ "expected "
                ++ printTree typ ++ "but found " ++ printTree typ2

inferExp :: Env -> Exp -> Err Type
inferExp env exp = case exp of
    ETrue            -> return Type_bool
    EFalse           -> return Type_bool
    EInt _           -> return Type_int
    EDouble _        -> return Type_double
    EId id           -> lookupVar env id
    EApp id exps     -> do (args, r) <- lookupFun env id
                           exps'     <- mapM (inferExp env) exps
                           if args == exps'
                           then return r
                           else fail $ "Arguments (" ++ show exps' 
                                       ++ ") don't match parameters (" ++ show args ++ ")"
    EPIncr exp       -> inferNum exp
    EPDecr exp       -> inferNum exp
    EIncr  exp       -> inferNum exp
    EDecr  exp       -> inferNum exp
    ETimes exp1 exp2 -> inferBin numTypes env exp1 exp2
    EDiv   exp1 exp2 -> inferBin numTypes env exp1 exp2
    EPlus  exp1 exp2 -> inferBin numTypes env exp1 exp2
    EMinus exp1 exp2 -> inferBin numTypes env exp1 exp2
    ELt    exp1 exp2 -> inferXBool numTypes exp1 exp2
    EGt    exp1 exp2 -> inferXBool numTypes exp1 exp2
    ELtEq  exp1 exp2 -> inferXBool numTypes exp1 exp2
    EGtWq  exp1 exp2 -> inferXBool numTypes exp1 exp2
    EEq    exp1 exp2 -> inferXBool allTypes exp1 exp2
    ENEq   exp1 exp2 -> inferXBool allTypes exp1 exp2
    EAnd   exp1 exp2 -> inferBin [Type_bool] env exp1 exp2
    EOr    exp1 exp2 -> inferBin [Type_bool] env exp1 exp2      
    EAss exp1@(EId _) exp2 -> inferBin allTypes env exp1 exp2
    EAss exp1 exp2         -> fail $ "LHS of assignment must be variable: " ++
                                     printTree exp1 ++ printTree exp2
    where inferNum exp  = do typ <- inferExp env exp
                             if typ `elem` numTypes
                             then return typ
                             else fail $ "Invalid type: "++ show typ    
          inferXBool x exp1 exp2 = do inferBin x env exp1 exp2
                                      return Type_bool
          numTypes = [Type_int, Type_double]
          allTypes = numTypes ++ [Type_bool]                                                        

inferBin :: [Type] -> Env -> Exp -> Exp -> Err Type
inferBin types env exp1 exp2 = do
    typ <- inferExp env exp1
    if typ `elem` types
    then do checkExp env typ exp2
            return typ
    else fail $ "Wrong type of expression: " ++ printTree exp1
