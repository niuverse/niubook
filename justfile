set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

# Download and verify the pinned Typst binary
bootstrap:
    python3 scripts/bootstrap.py

# Check local toolchain, fonts and vendored packages
doctor:
    python3 scripts/doctor.py

# Compile one book
build book="embodied-rsi":
    python3 scripts/build.py --book {{book}}

# Compile every book
build-all:
    python3 scripts/build.py

# Run quality gates for one book
check book="embodied-rsi":
    python3 scripts/check.py books/{{book}}

# Run quality gates for all books plus the catalogue
check-all:
    python3 scripts/check.py --all

# Regenerate a book's _meta.typ from book.toml
meta book="embodied-rsi":
    python3 scripts/gen_meta.py books/{{book}} --write

# Regenerate catalog/books.json
catalog:
    python3 scripts/catalog.py --write

# Build the mdBook catalogue site into dist/site
site:
    python3 scripts/site.py

# Serve the generated site at http://localhost:8000
serve:
    python3 -m http.server 8000 -d dist/site

# Print the text fingerprint of a built PDF (regression baseline)
text book="embodied-rsi":
    pdftotext -layout dist/books/{{book}}/{{book}}.pdf - | sha256sum

# Verify bibliography entries against arXiv / Crossref (needs network)
audit-cites book="embodied-rsi":
    python3 scripts/audit_cites.py books/{{book}}

# Remove build outputs (keeps .tools)
clean:
    rm -rf dist
