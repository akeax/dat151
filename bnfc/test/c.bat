@echo off

del Makefile
del AbsTst.hi
del AbsTst.hs
del AbsTst.o
del DocTst.tex
del DocTst.txt
del ErrM.hi
del ErrM.hs
del ErrM.o
del LexTst.hi
del LexTst.hs
del LexTst.o
del LexTst.x
del LexTst.x.bak
del ParTst.hi
del ParTst.hs
del ParTst.hs
del ParTst.o
del ParTst.o
del ParTst.y
del ParTst.y.tmp
del PrintTst.hi
del PrintTst.hs
del PrintTst.o
del SkelTst.hi
del SkelTst.hs
del SkelTst.o
del TestTst.exe
del TestTst.hi
del TestTst.hs
del TestTst.o

..\bnfc -m Tst.bnfc
mingw32-make
.\r
