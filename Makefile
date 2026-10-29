.PHONY: fmt validate test

fmt:
	terraform fmt -recursive

validate:
	terraform validate

test: validate
	terraform test
