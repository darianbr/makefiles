# makefiles

## More headings
blah blah

### Usage Example

Create a Makefile with the following contents
What it does - needs evaluation
```
-include artifacts/make/go/Makefile
-include artifacts/make/docker/Makefile

artifacts/make/%/Makefile:
	curl -sf https://jmalloc.github.io/makefiles/fetch | bash /dev/stdin $*
```
### Other headings
