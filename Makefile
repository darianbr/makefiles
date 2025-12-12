.PHONY: install build clean

install:
	@echo "Installing dependencies..."

build:
	@if [ -d ".makefiles" ]; then \
		echo "deps exist"; \
	fi

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf build/ dist/ .makefiles/
	@find . -name "*.o" -type f -delete
	@find . -name "*.so" -type f -delete
	@find . -name "*.a" -type f -delete
	@find . -name "*.dylib" -type f -delete
	@find . -name "*.exe" -type f -delete
	@find . -name "*.out" -type f -delete
	@echo "Clean complete."
