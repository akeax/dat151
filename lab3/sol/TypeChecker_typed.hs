module TypeChecker where

import AbsCPP
import PrintCPP
import ErrM
import qualified Data.Map as Map
import Data.Map (Map)
import Control.Monad (foldM)
import Prelude hiding (id,exp)

type Env        = (Signature,[Context]) -- functions and context stack
type Signature  = Map Id ([Type],Type)  -- function type signature
type Context    = Map Id Type           -- variables with their types

-- Check a whole program
typecheck :: Program -> Err Program
typecheck (PDefs ds) = do
  -- Add all (function) definitions to environment
  env  <- foldM (\env  (DFun typ id args _) -> updateFun env id (argTypes args,typ) ) emptyEnv ds
  
  -- Add standard functions to environment
  env' <- foldM (\env' (DFun typ id args _) -> updateFun env' id (argTypes args,typ) ) env stdFunctions
  
  -- Check all definitions
  ds' <- mapM (checkDef env') ds
  return $ PDefs ds'

  where argTypes = map (\(ADecl typ _) -> typ) 
        stdFunctions = [ DFun Type_void   (Id "printInt")    [ADecl Type_int (Id "x")]    [],
                         DFun Type_void   (Id "printDouble") [ADecl Type_double (Id "x")] [],
                         DFun Type_int    (Id "readInt")     []                           [],
                         DFun Type_double (Id "readDouble")  []                           [] ]

checkDef :: Env -> Def -> Err Def
checkDef env (DFun typ id args stms) = do
    newEnv <- foldM addArg env args
    stms' <- checkStms newEnv typ stms
    return $ DFun typ id args stms'
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
  
-- TODO what should we return? 
-- Whenever we encounter exp, type-annotate it
checkStm :: Env -> Type -> Stm -> Err (Env,Stm)
checkStm env typ stm = case stm of
    SExp exp       -> do typedExp <- inferExp env exp
                         return (env, SExp typedExp)
    SDecls typ' []   -> fail $ "no variable found for declaration: " ++ show typ'
    SDecls typ' vars -> do env' <- foldM (\env' var -> updateVar env' var typ') env vars
                           return (env',stm) -- TODO don't use new env right?
    SInit t id exp -> do typedExp <- checkExp env t exp
                         env'     <- updateVar env id t
                         return (env', SInit t id typedExp)
    SReturn exp    -> do typedExp <- inferExp env exp
                         typ'     <- getType typedExp
                         if typ == typ'
                         then return (env, SReturn typedExp)
                         else fail $ "Found type: " ++ show typ' ++
                                     "; expected type: " ++ show typ
    SWhile exp st  -> do typedExp    <- checkExp env Type_bool exp
                         (env',stm') <- checkStm env typ st 
                         return (env,stm') -- TODO shouldn't use new env here, right? block and so forth?
    SBlock stms    -> do stms' <- checkStms (newBlock env) typ stms
                         return (env, SBlock stms')
    SIfElse exp stm1 stm2 -> do typedExp     <- checkExp env Type_bool exp
                                (_env,stm1') <- checkStm env typ stm1
                                (_env,stm2') <- checkStm env typ stm2
                                return (env, SIfElse typedExp stm1' stm2') -- TODO should't update env right?

-- TODO what should we return?
checkStms :: Env -> Type -> [Stm] -> Err [Stm]
checkStms env typ stms = case stms of
    stm:stms' -> do (env',stm') <- checkStm env typ stm
                    stms''      <- checkStms env' typ stms'
                    return $ stm':stms''
    []       -> return []

checkExp :: Env -> Type -> Exp -> Err Exp
checkExp env typ exp =
    do typedExp <- inferExp env exp
       typ'     <- getType typedExp
       if typ' == typ
       then return $ ETyped exp typ
       else fail $ "type of " ++ printTree exp ++ "expected "
                ++ printTree typ ++ "but found " ++ printTree typ'

inferExp :: Env -> Exp -> Err Exp
inferExp env exp = case exp of
    ETrue            -> return $ ETyped exp Type_bool
    EFalse           -> return $ ETyped exp Type_bool
    EInt _           -> return $ ETyped exp Type_int
    EDouble _        -> return $ ETyped exp Type_double
    EId id           -> do typ <- lookupVar env id
                           return $ ETyped exp typ
    EApp id exps     -> do (args, r) <- lookupFun env id
                           exps'     <- mapM (inferExp env) exps
                           types     <- getTypes exps'
                           if args == types
                           then return $ ETyped exp r
                           else fail $ "Arguments (" ++ show exps' 
                                       ++ ") don't match parameters (" ++ show args ++ ")"
    EPIncr exp'       -> inferNum exp'
    EPDecr exp'       -> inferNum exp'
    EIncr  exp'       -> inferNum exp'
    EDecr  exp'       -> inferNum exp'
    ETimes exp1 exp2 -> annotateExp exp $ inferBin numTypes env exp1 exp2
    EDiv   exp1 exp2 -> annotateExp exp $ inferBin numTypes env exp1 exp2
    EPlus  exp1 exp2 -> annotateExp exp $ inferBin numTypes env exp1 exp2
    EMinus exp1 exp2 -> annotateExp exp $ inferBin numTypes env exp1 exp2
    ELt    exp1 exp2 -> annotateExp exp $ inferXBool numTypes exp1 exp2
    EGt    exp1 exp2 -> annotateExp exp $ inferXBool numTypes exp1 exp2
    ELtEq  exp1 exp2 -> annotateExp exp $ inferXBool numTypes exp1 exp2
    EGtWq  exp1 exp2 -> annotateExp exp $ inferXBool numTypes exp1 exp2
    EEq    exp1 exp2 -> annotateExp exp $ inferXBool allTypes exp1 exp2
    ENEq   exp1 exp2 -> annotateExp exp $ inferXBool allTypes exp1 exp2
    EAnd   exp1 exp2 -> annotateExp exp $ inferBin [Type_bool] env exp1 exp2
    EOr    exp1 exp2 -> annotateExp exp $ inferBin [Type_bool] env exp1 exp2      
    EAss exp1@(EId _) exp2 -> annotateExp exp $ inferBin allTypes env exp1 exp2
    EAss exp1 exp2         -> fail $ "LHS of assignment must be variable: " ++
                                     printTree exp1 ++ printTree exp2
    where inferNum exp'  = do typedExp <- inferExp env exp'
                              typ <- getType typedExp
                              if typ `elem` numTypes
                              then return $ ETyped exp' typ
                              else fail $ "Invalid type: "++ show typ
          inferXBool x exp1 exp2 = do inferBin x env exp1 exp2
                                      return Type_bool
          numTypes = [Type_int, Type_double]
          allTypes = numTypes ++ [Type_bool]                                                        

inferBin :: [Type] -> Env -> Exp -> Exp -> Err Type
inferBin types env exp1 exp2 = do
    typedExp <- inferExp env exp1
    typ      <- getType typedExp
    if typ `elem` types
    then do checkExp env typ exp2
            return typ
    else fail $ "Wrong type of expression: " ++ printTree exp1


---- Annotated expression helpers ----

-- Extracts the type from an annotated expression
getType :: Exp -> Err Type
getType (ETyped _exp typ) = return typ
getType e                 = fail $ "Expected annotated expression, got " ++ show e
-- Extracts a list of types from a list of annotated expressions
getTypes :: [Exp] -> Err [Type]
getTypes = mapM getType

-- Annotates the expression with the type given by evaluating the given type
annotateExp :: Exp -> Err Type -> Err Exp
annotateExp exp typ = do typ' <- typ
                         return $ ETyped exp typ'
