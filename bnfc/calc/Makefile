all: 
	happy -gca ParCalc.y
	alex -g LexCalc.x
	ghc --make TestCalc.hs -o TestCalc

doc: DocCalc.pdf

DocCalc.pdf: DocCalc.tex
	pdflatex DocCalc.tex

clean: 
	-rm -f *.log *.aux *.hi *.o *.dvi
	-rm -f DocCalc.ps

distclean: clean
	-rm -f DocCalc.* LexCalc.* ParCalc.* LayoutCalc.* SkelCalc.* PrintCalc.* TestCalc.* AbsCalc.* TestCalc ErrM.* SharedString.* ComposOpCalc.* Calc.dtd XMLCalc.* Makefile*
	

