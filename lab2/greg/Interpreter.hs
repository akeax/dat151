module Interpreter where

import AbsCPP
import PrintCPP
import ErrM

import Control.Monad
import qualified Data.Map as Map
import Data.Map (Map)
import Control.Monad (foldM)
import Data.Maybe

type Env       = (Signature,[Context])  -- functions and context stack
type Signature = Map Id Fun             -- function type signature
type Context   = Map Id Value           -- variables with their values
type Fun = ([Value],Value)

data Value = VInt Integer
           | VDouble Double 
           | VBool Bool
           | VString String
           | VVoid 
           | VUndef
    deriving Eq

instance Show Value where
    show (VInt i)    = show i
    show (VDouble d) = show d
    show (VBool b)   = show b
    show (VString s) = show s
    show VVoid       = "null"
    show VUndef      = "undefined"    
       
-- TODO: clean up function body
evalExp :: Env -> Exp -> IO (Value, Env)
evalExp env e = 
    case e of
      EId id         -> return (lookupVar id env, env)
      EInt i         -> return (VInt i, env)
      EDouble d      -> return (VDouble d, env)
      ETrue          -> return (VBool True, env)
      EFalse         -> return (VBool False, env)
      
      EMinus exp1 exp2  -> do v1 <- evalExp env exp1
                              v2 <- evalExp env exp2
                              case (v1,v2) of
                               (((VInt i1), _env), ((VInt i2), env'))       -> return ((VInt (i1 - i2)), env')
                               (((VDouble d1), _env), ((VDouble d2), env')) -> return ((VDouble (d1 - d2)), env')
                      
      EPlus exp1 exp2  -> do v1 <- evalExp env exp1
                             v2 <- evalExp env exp2
                             case (v1,v2) of
                              (((VInt i1), _env), ((VInt i2), env'))       -> return ((VInt (i1 + i2)), env')
                              (((VDouble d1), _env), ((VDouble d2), env')) -> return ((VDouble (d1 + d2)), env')
                              
      ETimes exp1 exp2  -> do v1 <- evalExp env exp1
                              v2 <- evalExp env exp2
                              case (v1,v2) of
                               ((VInt i1, _env), (VInt i2, env'))       -> return ((VInt (i1 * i2)), env')
                               ((VDouble d1, _env), (VDouble d2, env')) -> return ((VDouble (d1 * d2)), env')
      
      EDiv exp1 exp2  -> do (VInt i1, _env) <- evalExp env exp1
                            (VInt i2, env') <- evalExp env exp2
                            return (VInt (i1 `div` i2), env')

      EAnd exp1 exp2 -> do
                (VBool p, env') <- evalExp env exp1
                if p == False
                then return (VBool False, env')
                else evalExp env' exp2
                
      EOr exp1 exp2 -> do
                (VBool p, env') <- evalExp env exp1
                if p == True
                then return (VBool True, env')
                else evalExp env' exp2
      
      ELt exp1 exp2 -> do
            do p <- evalExp env exp1
               q <- evalExp env exp2
               case (p, q) of
                    ( (VInt i1, _), (VInt i2, _)) -> if i1 < i2
                                                     then return (VBool True, env)
                                                     else return (VBool False, env)
                    ( (VDouble d1, _), (VDouble d2, _)) -> if d1 < d2
                                                           then return (VBool True, env)
                                                           else return (VBool False, env)
                                                           
      EGt exp1 exp2 -> do
            do p <- evalExp env exp1
               q <- evalExp env exp2
               case (p, q) of
                    ( (VInt i1, _), (VInt i2, _)) -> if i1 > i2
                                                     then return (VBool True, env)
                                                     else return (VBool False, env)
                    ( (VDouble d1, _), (VDouble d2, _)) -> if d1 > d2
                                                           then return (VBool True, env)
                                                           else return (VBool False, env)

      ELtEq exp1 exp2 -> do
            do p <- evalExp env exp1
               q <- evalExp env exp2
               case (p, q) of
                    ( (VInt i1, _), (VInt i2, _)) -> if i1 <= i2
                                                     then return (VBool True, env)
                                                     else return (VBool False, env)
                    ( (VDouble d1, _), (VDouble d2, _)) -> if d1 <= d2
                                                           then return (VBool True, env)
                                                           else return (VBool False, env)

      EGtWq exp1 exp2 -> do
               p <- evalExp env exp1
               q <- evalExp env exp2
               case (p, q) of
                    ( (VInt i1, _), (VInt i2, _)) -> if i1 >= i2
                                                     then return (VBool True, env)
                                                     else return (VBool False, env)
                    ( (VDouble d1, _), (VDouble d2, _)) -> if d1 >= d2
                                                           then return (VBool True, env)
                                                           else return (VBool False, env)
                                                           
                                                          
      EEq exp1 exp2 -> do
            p <- evalExp env exp1
            q <- evalExp env exp2
            if p == q
            then return (VBool True, env)
            else return (VBool False, env)
            
      ENEq  exp1 exp2 -> do
            p <- evalExp env exp1
            q <- evalExp env exp2
            if p /= q
            then return (VBool True, env)
            else return (VBool False, env)
            
            
      (EIncr (EId id)) -> do
                    (p, env) <- evalExp env (EId id)
                    case p of
                        (VInt i)     -> return (VInt i, (updateVar env id (VInt (i + 1))))
                        (VDouble d)  -> return (VDouble d, (updateVar env id (VDouble (d + 1))))

      (EDecr (EId id)) -> do
                    (p, env) <- evalExp env (EId id)
                    case p of
                        (VInt i)     -> return (VInt i, (updateVar env id (VInt (i - 1))))
                        (VDouble d)  -> return (VDouble d, (updateVar env id (VDouble (d - 1))))

      (EPIncr (EId id)) -> do
                    (p, env) <- evalExp env (EId id)
                    case p of
                        (VInt i)     -> return (VInt (i+1), (updateVar env id (VInt (i + 1))))
                        (VDouble d)  -> return (VDouble (d+1), (updateVar env id (VDouble (d + 1))))

      (EPDecr (EId id)) -> do
                    (p, env) <- evalExp env (EId id)
                    case p of
                        (VInt i)     -> return (VInt    (i-1), (updateVar env id $ VInt    (i - 1)))
                        (VDouble d)  -> return (VDouble (d-1), (updateVar env id $ VDouble (d - 1)))

      (EAss (EId id) exp) -> do (v, env') <- evalExp env exp
                                let res = updateVar env' id v
                                return (v, res)

-- TODO: EApp Id [Exp]  (incl. inbuilt functions!)

             
interpret :: Program -> IO ()
interpret = undefined

execStms :: Env -> [Stm] -> IO Env
execStms env []        = return env
execStms env (st:stms) = do env' <- execStm env st
                            execStms env' stms

execStm :: Env -> Stm -> IO Env
execStm env stm = case stm of
    SExp   exp            -> do (_val, env') <- evalExp env exp
                                return env'
                              
    SDecls _typ ids       -> return $ updateVars env ids VUndef
       
    SInit typ id exp      -> do (val, env') <- evalExp env exp
                                return $ updateVar env' id val
                              
    SReturn exp           -> do (_val, env') <- evalExp env exp
                                return env'
                                     
    SWhile  exp stm       -> do ((VBool b), env') <- evalExp env exp
                                if b
                                then do env'' <- execStm env' stm
                                        execStm env'' (SWhile exp stm)
                                else return env'
                              
    SBlock stms           -> do let env' = newBlock env
                                env''   <- execStms env' stms
                                return $ exitBlock env''

    SIfElse exp stm1 stm2 -> do ((VBool b), env') <- evalExp env exp
                                if b
                                then execStm env' stm1
                                else execStm env' stm2
    
lookupVar :: Id -> Env -> Value
-- TODO: check error handling
lookupVar id (_signature, []) = error $ "Uninitialized variable: " ++ printTree id ++ "."
lookupVar id (signature, scope:rest) =
    case Map.lookup id scope of
      Just t      -> t
      Nothing     -> lookupVar id (signature, rest)

lookupFun :: Id -> Env -> Fun
lookupFun id (signature, _context) = fromJust $ Map.lookup id signature

updateVars :: Env -> [Id] -> Value -> Env
updateVars env [] _   = env
updateVars env (id:ids) val = do let env' = updateVar env id val
                                 updateVars env' ids val 

updateVar :: Env -> Id -> Value -> Env
updateVar (signature, context:contexts) id val =
    (signature, Map.insert id val context:contexts)

updateFun :: Env -> Id -> Fun -> Env
updateFun (signature, context) id fun = (Map.insert id fun signature, context)
    
newBlock :: Env -> Env
newBlock (signature, context) = let empty_context = Map.empty
                                in (signature, empty_context:context)
exitBlock :: Env -> Env
exitBlock (signature, _c:cs) = (signature, cs)

emptyEnv :: Env
emptyEnv = let empty_signature = Map.empty
               empty_context   = Map.empty
           in (empty_signature, [empty_context])
