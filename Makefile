
.PHONY: cqfd
cqfd:
	@git submodule update --init > /dev/null
	@./scripts/cqfd/cqfd init > /dev/null
	@./scripts/cqfd/cqfd run make tests

.PHONY: test tests
test tests:
	@cog check --from-latest-tag
	@-./scripts/run_tests
	@./scripts/print_cloc

.PHONY: demo
demo:
	@nvim --clean \
		--cmd 'set runtimepath^=.' \
		-c 'compiler gcc' \
		-c 'setlocal makeprg=gcc\ -Wall\ -fsyntax-only\ %' \
		demo/broken.c
