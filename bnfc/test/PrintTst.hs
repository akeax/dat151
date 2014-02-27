{-# OPTIONS_GHC -fno-warn-incomplete-patterns #-}
module PrintTst where

-- pretty-printer generated by the BNF converter

import AbsTst
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
  prt _ (Id (_,i)) = doc (showString ( i))
  prtList es = case es of
   [x] -> (concatD [prt 0 x])
   x:xs -> (concatD [prt 0 x , doc (showString ",") , prt 0 xs])



instance Print Program where
  prt i e = case e of
   DProgram defs -> prPrec i 0 (concatD [prt 0 defs])


instance Print Def where
  prt i e = case e of
   DInl def -> prPrec i 0 (concatD [doc (showString "inline") , prt 1 def])
   DProt type' id args -> prPrec i 1 (concatD [prt 0 type' , prt 0 id , doc (showString "(") , prt 0 args , doc (showString ")") , doc (showString ";")])
   DFun type' id args stmts -> prPrec i 1 (concatD [prt 0 type' , prt 0 id , doc (showString "(") , prt 0 args , doc (showString ")") , doc (showString "{") , prt 0 stmts , doc (showString "}")])
   DTDef tdef -> prPrec i 0 (concatD [prt 0 tdef])
   DVar var -> prPrec i 0 (concatD [prt 0 var , doc (showString ";")])
   DStruct struct -> prPrec i 0 (concatD [prt 0 struct])
   DUsing qconst -> prPrec i 0 (concatD [doc (showString "using") , prt 0 qconst , doc (showString ";")])

  prtList es = case es of
   [] -> (concatD [])
   x:xs -> (concatD [prt 0 x , prt 0 xs])

instance Print Stmt where
  prt i e = case e of
   SExpr expr -> prPrec i 0 (concatD [prt 0 expr , doc (showString ";")])
   SVar var -> prPrec i 0 (concatD [prt 0 var , doc (showString ";")])
   SEmpty  -> prPrec i 0 (concatD [doc (showString ";")])
   SReturn expr -> prPrec i 0 (concatD [doc (showString "return") , prt 0 expr , doc (showString ";")])
   SDoWhile stmt expr -> prPrec i 0 (concatD [doc (showString "do") , prt 0 stmt , doc (showString "while") , doc (showString "(") , prt 0 expr , doc (showString ")")])
   SWhile expr stmt -> prPrec i 0 (concatD [doc (showString "while") , doc (showString "(") , prt 0 expr , doc (showString ")") , prt 0 stmt])
   SIf expr stmt -> prPrec i 0 (concatD [doc (showString "if") , doc (showString "(") , prt 0 expr , doc (showString ")") , prt 0 stmt])
   SIfElse expr stmt0 stmt -> prPrec i 0 (concatD [doc (showString "if") , doc (showString "(") , prt 0 expr , doc (showString ")") , prt 0 stmt0 , doc (showString "else") , prt 0 stmt])
   SFor var expr0 expr stmt -> prPrec i 0 (concatD [doc (showString "for") , doc (showString "(") , prt 0 var , doc (showString ";") , prt 0 expr0 , doc (showString ";") , prt 0 expr , doc (showString ")") , prt 0 stmt])
   SBlock stmts -> prPrec i 0 (concatD [doc (showString "{") , prt 0 stmts , doc (showString "}")])
   STDef tdef -> prPrec i 0 (concatD [prt 0 tdef])
   SStruct struct -> prPrec i 0 (concatD [prt 0 struct])

  prtList es = case es of
   [] -> (concatD [])
   x:xs -> (concatD [prt 0 x , prt 0 xs])

instance Print Expr where
  prt i e = case e of
   EInt n -> prPrec i 16 (concatD [prt 0 n])
   EDbl d -> prPrec i 16 (concatD [prt 0 d])
   EChar c -> prPrec i 16 (concatD [prt 0 c])
   EStr strs -> prPrec i 16 (concatD [prt 0 strs])
   ETrue  -> prPrec i 16 (concatD [doc (showString "true")])
   EFalse  -> prPrec i 16 (concatD [doc (showString "false")])
   EQConst qconst -> prPrec i 16 (concatD [prt 0 qconst])
   EIdx expr0 expr -> prPrec i 15 (concatD [prt 16 expr0 , doc (showString "[") , prt 0 expr , doc (showString "]")])
   ECall expr exprs -> prPrec i 15 (concatD [prt 16 expr , doc (showString "(") , prt 0 exprs , doc (showString ")")])
   EDot expr0 expr -> prPrec i 14 (concatD [prt 14 expr0 , doc (showString ".") , prt 15 expr])
   EArrow expr0 expr -> prPrec i 14 (concatD [prt 14 expr0 , doc (showString "->") , prt 15 expr])
   EPostIncr expr -> prPrec i 14 (concatD [prt 15 expr , doc (showString "++")])
   EPostDecr expr -> prPrec i 14 (concatD [prt 15 expr , doc (showString "--")])
   EDeref expr -> prPrec i 14 (concatD [doc (showString "*") , prt 15 expr])
   ENeg expr -> prPrec i 13 (concatD [doc (showString "!") , prt 14 expr])
   EPreIncr expr -> prPrec i 13 (concatD [doc (showString "++") , prt 14 expr])
   EPreDecr expr -> prPrec i 13 (concatD [doc (showString "--") , prt 14 expr])
   ENumNeg expr -> prPrec i 13 (concatD [doc (showString "-") , prt 14 expr])
   EMod expr0 expr -> prPrec i 12 (concatD [prt 12 expr0 , doc (showString "%") , prt 13 expr])
   EMul expr0 expr -> prPrec i 12 (concatD [prt 12 expr0 , doc (showString "*") , prt 13 expr])
   EDiv expr0 expr -> prPrec i 12 (concatD [prt 12 expr0 , doc (showString "/") , prt 13 expr])
   EAdd expr0 expr -> prPrec i 11 (concatD [prt 11 expr0 , doc (showString "+") , prt 12 expr])
   ESub expr0 expr -> prPrec i 11 (concatD [prt 11 expr0 , doc (showString "-") , prt 12 expr])
   ELsh expr0 expr -> prPrec i 10 (concatD [prt 10 expr0 , doc (showString "<<") , prt 11 expr])
   ERsh expr0 expr -> prPrec i 10 (concatD [prt 10 expr0 , doc (showString ">>") , prt 11 expr])
   ELt expr0 expr -> prPrec i 9 (concatD [prt 9 expr0 , doc (showString "<") , prt 10 expr])
   EGt expr0 expr -> prPrec i 9 (concatD [prt 9 expr0 , doc (showString ">") , prt 10 expr])
   ELte expr0 expr -> prPrec i 9 (concatD [prt 9 expr0 , doc (showString "<=") , prt 10 expr])
   EGte expr0 expr -> prPrec i 9 (concatD [prt 9 expr0 , doc (showString ">=") , prt 10 expr])
   EEq expr0 expr -> prPrec i 8 (concatD [prt 8 expr0 , doc (showString "==") , prt 9 expr])
   ENeq expr0 expr -> prPrec i 8 (concatD [prt 8 expr0 , doc (showString "!=") , prt 9 expr])
   EAnd expr0 expr -> prPrec i 4 (concatD [prt 4 expr0 , doc (showString "&&") , prt 5 expr])
   EAss expr0 expr -> prPrec i 2 (concatD [prt 2 expr0 , doc (showString "=") , prt 3 expr])
   EIAss expr0 expr -> prPrec i 2 (concatD [prt 2 expr0 , doc (showString "+=") , prt 3 expr])
   EDAss expr0 expr -> prPrec i 2 (concatD [prt 2 expr0 , doc (showString "-=") , prt 3 expr])
   EInlIf expr0 expr1 expr -> prPrec i 2 (concatD [prt 2 expr0 , doc (showString "?") , prt 2 expr1 , doc (showString ":") , prt 2 expr])
   EThrow expr -> prPrec i 1 (concatD [doc (showString "throw") , prt 2 expr])

  prtList es = case es of
   [] -> (concatD [])
   [x] -> (concatD [prt 0 x])
   x:xs -> (concatD [prt 0 x , doc (showString ",") , prt 0 xs])

instance Print Type where
  prt i e = case e of
   TRef type' -> prPrec i 0 (concatD [prt 0 type' , doc (showString "&")])
   TBool  -> prPrec i 0 (concatD [doc (showString "bool")])
   TDbl  -> prPrec i 0 (concatD [doc (showString "double")])
   TInt  -> prPrec i 0 (concatD [doc (showString "int")])
   TVoid  -> prPrec i 0 (concatD [doc (showString "void")])
   TQConst qconst -> prPrec i 0 (concatD [prt 0 qconst])

  prtList es = case es of
   [x] -> (concatD [prt 0 x])
   x:xs -> (concatD [prt 0 x , doc (showString ",") , prt 0 xs])

instance Print QConst where
  prt i e = case e of
   DQConst consts -> prPrec i 0 (concatD [prt 0 consts])


instance Print Const where
  prt i e = case e of
   QCId id -> prPrec i 0 (concatD [prt 0 id])
   QCConst id types -> prPrec i 0 (concatD [prt 0 id , doc (showString "<") , prt 0 types , doc (showString ">")])

  prtList es = case es of
   [x] -> (concatD [prt 0 x])
   x:xs -> (concatD [prt 0 x , doc (showString "::") , prt 0 xs])

instance Print TDef where
  prt i e = case e of
   TDef type' id -> prPrec i 0 (concatD [doc (showString "typedef") , prt 0 type' , prt 0 id , doc (showString ";")])


instance Print Var where
  prt i e = case e of
   VConst var -> prPrec i 0 (concatD [doc (showString "const") , prt 1 var])
   VDecl type' id -> prPrec i 1 (concatD [prt 0 type' , prt 0 id])
   VDecls type' id ids -> prPrec i 1 (concatD [prt 0 type' , prt 0 id , doc (showString ",") , prt 0 ids])
   VInit type' id expr -> prPrec i 1 (concatD [prt 0 type' , prt 0 id , doc (showString "=") , prt 0 expr])


instance Print Arg where
  prt i e = case e of
   AConst arg -> prPrec i 0 (concatD [doc (showString "const") , prt 1 arg])
   AType type' -> prPrec i 1 (concatD [prt 0 type'])
   AName type' id -> prPrec i 1 (concatD [prt 0 type' , prt 0 id])
   AInit type' id expr -> prPrec i 1 (concatD [prt 0 type' , prt 0 id , doc (showString "=") , prt 0 expr])

  prtList es = case es of
   [] -> (concatD [])
   [x] -> (concatD [prt 0 x])
   x:xs -> (concatD [prt 0 x , doc (showString ",") , prt 0 xs])

instance Print Struct where
  prt i e = case e of
   Struct id defs -> prPrec i 0 (concatD [doc (showString "struct") , prt 0 id , doc (showString "{") , prt 0 defs , doc (showString "}") , doc (showString ";")])


