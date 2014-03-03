module Interpreter where

import System.Exit (exitFailure)
import ErrM
import qualified Data.Map as Map
import Data.Map (Map)
import Data.Maybe

import AbsFun
import PrintFun


type Env = (Functions, Variables)
type Functions = Map Ident Fun
type Variables = Map Ident Exp

type Fun = ([Ident], Exp, Closure)
type Closure = Map Ident Exp

-- TODO: flag for call-by-name/call-by-value

interpret :: Program -> IO ()
interpret p = case lookupFun (Ident "main") $ env of
    Bad err  -> do
        error err
        exitFailure
    Ok  main -> case evalFun env main of
             Bad err -> do
                 error err
                 exitFailure
             Ok  i   -> putStrLn $ show i
    where env = createEnv p

createEnv :: Program -> Env
createEnv prog = addFuns prog emptyEnv

emptyEnv :: Env
emptyEnv = (Map.empty, Map.empty)

addFuns :: Program -> Env -> Env
addFuns (Prog defs) env | defs == [] = env
                        | otherwise  = addFuns (Prog $ tail defs) (addFun (head defs) env)

addFun :: Def -> Env -> Env
addFun (Df funId args exp) (funs, vars) =
    ((Map.insert funId (args, exp, Map.empty) funs), vars)

lookupFun :: Ident -> Env -> Err Fun
lookupFun id (funs, vars) = case Map.lookup id funs of
    Just fun   -> return fun
    Nothing    -> Bad $ "function not found"

-- overshadowing: variable overshadows function symbol (done)
-- TODO inner variable overshadows outer variable (?)
lookupVar :: Ident -> Env -> Err (Exp, Closure)
lookupVar id (funs, vars) = case Map.lookup id vars of
    Just exp    -> Ok (exp, Map.empty)
    Nothing     -> case Map.lookup id funs of
        Nothing             -> Bad "not found"
        Just (ids, exp, cl) -> case Map.lookup id cl of
            Nothing -> Ok (exp, cl)
            Just e  -> Ok (e, Map.empty)


updateEnv :: [Ident] -> Env -> Exp -> Env
updateEnv ids env val | ids == [] = env
                      | otherwise = updateEnv (tail ids) (updateEnv' (head ids) env val) val

-- TODO:
-- what gets updated?
updateEnv' :: Ident -> Env -> Exp -> Env
updateEnv' id env val = undefined


evalFun :: Env -> Fun -> Err Integer
evalFun env (ids, exp, cl) = evalExp (updateEnv ids env exp) exp


evalExp :: Env -> Exp -> Err Integer
evalExp env x = case x of

    EVar id  -> do
        (e, cl)  <- lookupVar id env
        let (funs, vars) = env
        evalExp (funs, cl) e                            

    EInt i          -> return i
    
-- TODO:
-- requires call by name/value
    EApp exp1 exp2 -> do  
        x    <- evalExp env exp1
        --env' <- updateEnv id env
        --fun  <- lookupFun exp1 env'
        --evalFun env' fun
        return 0
                           
    EPlus exp1 exp2  -> do
        e1 <- evalExp env exp1
        e2 <- evalExp env exp2
        return $ e1 + e2
        
    EMinus exp1 exp2 -> do
        e1 <- evalExp env exp1
        e2 <- evalExp env exp2
        return $ e1 - e2
        
    ELess exp1 exp2 -> do
        e1 <- evalExp env exp1
        e2 <- evalExp env exp2
        return $ if e1 < e2 then 1 else 0        
    
    ECond exp1 exp2 exp3 -> do
        e <- evalExp env exp1
        evalExp env $ if e == 1 then exp2 else exp3
    
    -- ??
    EAbs id exp -> do
        -- closures with variables of current environment:
        let (_funs, vars) = env
        evalFun env ([id], exp, vars)
