# Makefile for LaTeX paper compilation

# Main file name (without extension)
MAIN = main

# LaTeX compiler
LATEX = platex
BIBTEX = pbibtex
DVIPDF = dvipdfmx

# Output directories
OUTDIR = output
FIGDIR = figures

# Targets
all: pdf

pdf: $(MAIN).pdf

$(MAIN).pdf: $(MAIN).dvi
	$(DVIPDF) $(MAIN).dvi

$(MAIN).dvi: $(MAIN).tex references.bib
	$(LATEX) $(MAIN)
	$(BIBTEX) $(MAIN)
	$(LATEX) $(MAIN)
	$(LATEX) $(MAIN)

# Create necessary directories
dirs:
	mkdir -p $(OUTDIR) $(FIGDIR)

# Clean intermediate files
clean:
	rm -f *.aux *.bbl *.blg *.dvi *.log *.out *.toc *.lof *.lot

# Clean everything including PDF
distclean: clean
	rm -f $(MAIN).pdf

# View PDF
view: $(MAIN).pdf
	open $(MAIN).pdf

.PHONY: all pdf dirs clean distclean view