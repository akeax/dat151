compiler: bnfc compiler

compiler:
	ghc -threaded --make lab4.hs -o lab4

bnfc:
	bnfc --haskell Fun.cf
	happy -gca ParFun.y
	alex -g LexFun.x

# clean:
# 	-rm -Force *.log
# 	-rm -Force *.aux
# 	-rm -Force *.hi
# 	-rm -Force *.o
# 	-rm -Force *.dvi
# 	-rm -Force DocFun.ps

# distclean: clean
# 	-rm -Force DocFun.*
# 	-rm -Force LexFun.*
# 	-rm -Force ParFun.*
# 	-rm -Force LayoutFun.*
# 	-rm -Force SkelFun.*
# 	-rm -Force PrintFun.*
# 	-rm -Force TestFun.*
# 	-rm -Force AbsFun.*
# 	-rm -Force TestFun
# 	-rm -Force ErrM.*
# 	-rm -Force SharedString.*
# 	-rm -Force Fun.dtd
# 	-rm -Force XMLFun.*
