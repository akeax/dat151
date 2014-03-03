@echo off

rem del Makefile
del AbsFun.hi
del AbsFun.hs
del AbsFun.o
del DocFun.tex
del DocFun.txt
del ErrM.hi
del ErrM.hs
del ErrM.o
del LexFun.hi
del LexFun.hs
del LexFun.o
del LexFun.x
del LexFun.x.bak
del ParFun.hi
del ParFun.hs
del ParFun.hs
del ParFun.o
del ParFun.o
del ParFun.y
del ParFun.y.tmp
del PrintFun.hi
del PrintFun.hs
del PrintFun.o
del SkelFun.hi
del SkelFun.hs
del SkelFun.o
del TestFun.exe
del TestFun.hi
del TestFun.hs
del TestFun.o

rem bnfc -m Fun.cf
mingw32-make
rem .\r
