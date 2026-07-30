EMACS ?= emacs
PACKAGE = bongo-cat-mode.el
TESTS = test/bongo-cat-mode-test.el

.PHONY: all compile lint checkdoc package-lint test clean

all: compile lint test

## Byte-compile with warnings treated as errors.
compile:
	$(EMACS) -Q --batch \
	  --eval "(setq byte-compile-error-on-warn t)" \
	  -f batch-byte-compile $(PACKAGE)

lint: checkdoc package-lint

## Run checkdoc on the package source.
checkdoc:
	$(EMACS) -Q --batch \
	  --eval "(require 'checkdoc)" \
	  --eval "(let ((checkdoc-diagnostic-buffer \"*warn*\")) \
	            (checkdoc-file \"$(PACKAGE)\"))"

## Run package-lint (installed on demand from GNU/MELPA).
package-lint:
	$(EMACS) -Q --batch \
	  --eval "(progn \
	            (require 'package) \
	            (add-to-list 'package-archives '(\"melpa\" . \"https://melpa.org/packages/\") t) \
	            (package-initialize) \
	            (unless (package-installed-p 'package-lint) \
	              (package-refresh-contents) \
	              (package-install 'package-lint)))" \
	  --eval "(require 'package-lint)" \
	  -f package-lint-batch-and-exit $(PACKAGE)

## Run the ERT test suite.
test:
	$(EMACS) -Q --batch \
	  -L . \
	  -l $(TESTS) \
	  -f ert-run-tests-batch-and-exit

clean:
	rm -f *.elc test/*.elc
