all: 
	happy -gca ParFun.y
	alex -g LexFun.x
	ghc --make TestFun.hs -o TestFun

doc: DocFun.pdf

DocFun.pdf: DocFun.tex
	pdflatex DocFun.tex

clean: 
	-rm -f *.log *.aux *.hi *.o *.dvi
	-rm -f DocFun.ps

distclean: clean
	-rm -f DocFun.* LexFun.* ParFun.* LayoutFun.* SkelFun.* PrintFun.* TestFun.* AbsFun.* TestFun ErrM.* SharedString.* ComposOpFun.* Fun.dtd XMLFun.* Makefile*
	

