all: pdf ascii

pdf:
	pdflatex resume.tex
	+rm -f resume.aux  resume.log
ascii:
	perl create_ascii.pl resume.tex > resume.txt
clean:
	+rm -f resume.pdf *.log resume.aux resume.txt
