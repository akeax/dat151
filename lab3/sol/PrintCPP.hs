{-# OPTIONS_GHC -fno-warn-incomplete-patterns #-}
module PrintCPP where

-- pretty-printer generated by the BNF converter

import AbsCPP
import Data.Char


-- the top-level printing method
printTree :: Print a => a -> String
printTree = render . prt 0

type Doc = [ShowS] -> [ShowS]

doc :: ShowS -> Doc
doc = (:)

render :: Doc -> String
render d = rend 0 (map ($ "") $ d []) "" where
  rend i ss = case ss of
    "["      :ts -> showChar '[' . rend i ts
    "("      :ts -> showChar '(' . rend i ts
    "{"      :ts -> showChar '{' . new (i+1) . rend (i+1) ts
    "}" : ";":ts -> new (i-1) . space "}" . showChar ';' . new (i-1) . rend (i-1) ts
    "}"      :ts -> new (i-1) . showChar '}' . new (i-1) . rend (i-1) ts
    ";"      :ts -> showChar ';' . new i . rend i ts
    t  : "," :ts -> showString t . space "," . rend i ts
    t  : ")" :ts -> showString t . showChar ')' . rend i ts
    t  : "]" :ts -> showString t . showChar ']' . rend i ts
    t        :ts -> space t . rend i ts
    _            -> id
  new i   = showChar '\n' . replicateS (2*i) (showChar ' ') . dropWhile isSpace
  space t = showString t . (\s -> if null s then "" else (' ':s))

parenth :: Doc -> Doc
parenth ss = doc (showChar '(') . ss . doc (showChar ')')

concatS :: [ShowS] -> ShowS
concatS = foldr (.) id

concatD :: [Doc] -> Doc
concatD = foldr (.) id

replicateS :: Int -> ShowS -> ShowS
replicateS n f = concatS (replicate n f)

-- the printer class does the job
class Print a where
  prt :: Int -> a -> Doc
  prtList :: [a] -> Doc
  prtList = concatD . map (prt 0)

instance Print a => Print [a] where
  prt _ = prtList

instance Print Char where
  prt _ s = doc (showChar '\'' . mkEsc '\'' s . showChar '\'')
  prtList s = doc (showChar '"' . concatS (map (mkEsc '"') s) . showChar '"')

mkEsc :: Char -> Char -> ShowS
mkEsc q s = case s of
  _ | s == q -> showChar '\\' . showChar s
  '\\'-> showString "\\\\"
  '\n' -> showString "\\n"
  '\t' -> showString "\\t"
  _ -> showChar s

prPrec :: Int -> Int -> Doc -> Doc
prPrec i j = if j<i then parenth else id


instance Print Integer where
  prt _ x = doc (shows x)


instance Print Double where
  prt _ x = doc (shows x)



instance Print Id where
  prt _ (Id i) = doc (showString ( i))
  prtList es = case es of
   [x] -> (concatD [prt 0 x])
   x:xs -> (concatD [prt 0 x , doc (showString ",") , prt 0 xs])



instance Print Program where
  prt i e = case e of
   PDefs defs -> prPrec i 0 (concatD [prt 0 defs])


instance Print Def where
  prt i e = case e of
   DFun type' id args stms -> prPrec i 0 (concatD [prt 0 type' , prt 0 id , doc (showString "(") , prt 0 args , doc (showString ")") , doc (showString "{") , prt 0 stms , doc (showString "}")])

  prtList es = case es of
   [] -> (concatD [])
   x:xs -> (concatD [prt 0 x , prt 0 xs])

instance Print Arg where
  prt i e = case e of
   ADecl type' id -> prPrec i 0 (concatD [prt 0 type' , prt 0 id])

  prtList es = case es of
   [] -> (concatD [])
   [x] -> (concatD [prt 0 x])
   x:xs -> (concatD [prt 0 x , doc (showString ",") , prt 0 xs])

instance Print Stm where
  prt i e = case e of
   SExp exp -> prPrec i 0 (concatD [prt 0 exp , doc (showString ";")])
   SDecls type' ids -> prPrec i 0 (concatD [prt 0 type' , prt 0 ids , doc (showString ";")])
   SInit type' id exp -> prPrec i 0 (concatD [prt 0 type' , prt 0 id , doc (showString "=") , prt 0 exp , doc (showString ";")])
   SReturn exp -> prPrec i 0 (concatD [doc (showString "return") , prt 0 exp , doc (showString ";")])
   SWhile exp stm -> prPrec i 0 (concatD [doc (showString "while") , doc (showString "(") , prt 0 exp , doc (showString ")") , prt 0 stm])
   SBlock stms -> prPrec i 0 (concatD [doc (showString "{") , prt 0 stms , doc (showString "}")])
   SIfElse exp stm0 stm -> prPrec i 0 (concatD [doc (showString "if") , doc (showString "(") , prt 0 exp , doc (showString ")") , prt 0 stm0 , doc (showString "else") , prt 0 stm])

  prtList es = case es of
   [] -> (concatD [])
   x:xs -> (concatD [prt 0 x , prt 0 xs])

instance Print Exp where
  prt i e = case e of
   ETrue  -> prPrec i 15 (concatD [doc (showString "true")])
   EFalse  -> prPrec i 15 (concatD [doc (showString "false")])
   EInt n -> prPrec i 15 (concatD [prt 0 n])
   EDouble d -> prPrec i 15 (concatD [prt 0 d])
   EId id -> prPrec i 15 (concatD [prt 0 id])
   EString str -> prPrec i 15 (concatD [prt 0 str])
   EApp id exps -> prPrec i 15 (concatD [prt 0 id , doc (showString "(") , prt 0 exps , doc (showString ")")])
   EPIncr exp -> prPrec i 14 (concatD [prt 15 exp , doc (showString "++")])
   EPDecr exp -> prPrec i 14 (concatD [prt 15 exp , doc (showString "--")])
   EIncr exp -> prPrec i 13 (concatD [doc (showString "++") , prt 14 exp])
   EDecr exp -> prPrec i 13 (concatD [doc (showString "--") , prt 14 exp])
   ETimes exp0 exp -> prPrec i 12 (concatD [prt 12 exp0 , doc (showString "*") , prt 13 exp])
   EDiv exp0 exp -> prPrec i 12 (concatD [prt 12 exp0 , doc (showString "/") , prt 13 exp])
   EPlus exp0 exp -> prPrec i 11 (concatD [prt 11 exp0 , doc (showString "+") , prt 12 exp])
   EMinus exp0 exp -> prPrec i 11 (concatD [prt 11 exp0 , doc (showString "-") , prt 12 exp])
   ELt exp0 exp -> prPrec i 9 (concatD [prt 9 exp0 , doc (showString "<") , prt 10 exp])
   EGt exp0 exp -> prPrec i 9 (concatD [prt 9 exp0 , doc (showString ">") , prt 10 exp])
   ELtEq exp0 exp -> prPrec i 9 (concatD [prt 9 exp0 , doc (showString "<=") , prt 10 exp])
   EGtWq exp0 exp -> prPrec i 9 (concatD [prt 9 exp0 , doc (showString ">=") , prt 10 exp])
   EEq exp0 exp -> prPrec i 8 (concatD [prt 8 exp0 , doc (showString "==") , prt 9 exp])
   ENEq exp0 exp -> prPrec i 8 (concatD [prt 8 exp0 , doc (showString "!=") , prt 9 exp])
   EAnd exp0 exp -> prPrec i 4 (concatD [prt 4 exp0 , doc (showString "&&") , prt 5 exp])
   EOr exp0 exp -> prPrec i 3 (concatD [prt 3 exp0 , doc (showString "||") , prt 4 exp])
   EAss exp0 exp -> prPrec i 2 (concatD [prt 3 exp0 , doc (showString "=") , prt 2 exp])
   ETyped exp type' -> prPrec i 0 (concatD [doc (showString "[") , prt 0 exp , doc (showString ":") , prt 0 type' , doc (showString "]")])
   EConv type' exp -> prPrec i 0 (concatD [prt 0 type' , doc (showString "(") , prt 0 exp , doc (showString ")")])

  prtList es = case es of
   [] -> (concatD [])
   [x] -> (concatD [prt 0 x])
   x:xs -> (concatD [prt 0 x , doc (showString ",") , prt 0 xs])

instance Print Type where
  prt i e = case e of
   Type_bool  -> prPrec i 0 (concatD [doc (showString "bool")])
   Type_int  -> prPrec i 0 (concatD [doc (showString "int")])
   Type_double  -> prPrec i 0 (concatD [doc (showString "double")])
   Type_void  -> prPrec i 0 (concatD [doc (showString "void")])
   Type_string  -> prPrec i 0 (concatD [doc (showString "string")])



