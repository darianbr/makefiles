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
	@find . \( -name "*.o" -o -name "*.so" -o -name "*.a" -o -name "*.dylib" -o -name "*.exe" -o -name "*.out" \) -type f -delete
	@echo "Clean complete."
