#!/bin/bash
# LaTeX compilation script for IEICE paper

echo "Compiling IEICE paper..."

# Clean previous build files
rm -f *.aux *.log *.dvi *.bbl *.blg *.toc *.out

# First compilation
platex ieice_paper.tex

# BibTeX (if using .bib file)
# pbibtex ieice_paper

# Second compilation (for cross-references)
platex ieice_paper.tex

# Third compilation (final)
platex ieice_paper.tex

# Convert to PDF
dvipdfmx ieice_paper.dvi

echo "Compilation complete!"
echo "Output: ieice_paper.pdf"

# Optional: Open PDF
# open ieice_paper.pdf  # macOS
# xdg-open ieice_paper.pdf  # Linux