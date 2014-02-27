@echo off

del Makefile
del AbsCPP.hi
del AbsCPP.hs
del AbsCPP.o
del DocCPP.tex
del DocCPP.txt
del ErrM.hi
del ErrM.hs
del ErrM.o
del LexCPP.hi
del LexCPP.hs
del LexCPP.o
del LexCPP.x
del LexCPP.x.bak
del ParCPP.hi
del ParCPP.hs
del ParCPP.hs
del ParCPP.o
del ParCPP.o
del ParCPP.y
del ParCPP.y.tmp
del PrintCPP.hi
del PrintCPP.hs
del PrintCPP.o
del SkelCPP.hi
del SkelCPP.hs
del SkelCPP.o
del TestCPP.exe
del TestCPP.hi
del TestCPP.hs
del TestCPP.o

bnfc -m CPP.cf
mingw32-make
rem .\r
