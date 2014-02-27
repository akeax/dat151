all: 
	happy -gca ParTst.y
	alex -g LexTst.x
	ghc --make TestTst.hs -o TestTst

doc: DocTst.pdf

DocTst.pdf: DocTst.tex
	pdflatex DocTst.tex

clean: 
	-rm -f *.log *.aux *.hi *.o *.dvi
	-rm -f DocTst.ps

distclean: clean
	-rm -f DocTst.* LexTst.* ParTst.* LayoutTst.* SkelTst.* PrintTst.* TestTst.* AbsTst.* TestTst ErrM.* SharedString.* ComposOpTst.* Tst.dtd XMLTst.* Makefile*
	

