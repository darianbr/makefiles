#
# Filename: modules/composer/install-binary.mk
# Last edited: 2026-10-20 12:23:52
# Description: Downloads and verifies composer.phar into the tools cache.
#

ifndef MF_TOOLS_ROOT
$(error MF_TOOLS_ROOT is not set. Include modules/Makefile before using modules/composer/install-binary.mk.)
endif

install-composer-binary:
	@set -eu; \
	mkdir -p "$(MF_TOOLS_ROOT)"; \
	installer="$(MF_TOOLS_ROOT)composer-setup.php"; \
	signature="$(MF_TOOLS_ROOT)composer-setup.sig"; \
	trap 'rm -f "$$installer" "$$signature"' EXIT; \
	curl -fsSL https://getcomposer.org/installer -o "$$installer"; \
	curl -fsSL https://composer.github.io/installer.sig -o "$$signature"; \
	expected_sig=$$(cat "$$signature"); \
	actual_sig=$$("$(PHP)" -r 'echo hash_file("sha384", $$argv[1]);' "$$installer"); \
	if [ "$$expected_sig" != "$$actual_sig" ]; then \
		echo "ERROR: Invalid installer signature" >&2; \
		exit 1; \
	fi; \
	"$(PHP)" "$$installer" --install-dir="$(MF_TOOLS_ROOT)" --filename=composer.phar