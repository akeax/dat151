compiler: bnfc compiler

compiler:
	ghc -threaded --make lab3.hs -o lab3

bnfc:
	bnfc --haskell CPP.cf
	happy -gca ParCPP.y
	alex -g LexCPP.x

clean:
	-rm -f *.log *.aux *.hi *.o *.dvi
	-rm -f DocCPP.ps

distclean: clean
	-rm -f DocCPP.* LexCPP.* ParCPP.* LayoutCPP.* SkelCPP.* PrintCPP.* TestCPP.* AbsCPP.* TestCPP ErrM.* SharedString.* CPP.dtd XMLCPP.*
	