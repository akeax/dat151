@echo off

del Makefile
del AbsCalc.hi
del AbsCalc.hs
del AbsCalc.o
del DocCalc.tex
del DocCalc.txt
del ErrM.hi
del ErrM.hs
del ErrM.o
del LexCalc.hi
del LexCalc.hs
del LexCalc.o
del LexCalc.x
del LexCalc.x.bak
del ParCalc.hi
del ParCalc.hs
del ParCalc.hs
del ParCalc.o
del ParCalc.o
del ParCalc.y
del ParCalc.y.tmp
del PrintCalc.hi
del PrintCalc.hs
del PrintCalc.o
del SkelCalc.hi
del SkelCalc.hs
del SkelCalc.o
del TestCalc.exe
del TestCalc.hi
del TestCalc.hs
del TestCalc.o

..\bnfc -m Calc.bnfc
mingw32-make
