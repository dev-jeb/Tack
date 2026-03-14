.PHONY: deps

wd := $(shell git rev-parse --show-toplevel)

define monitor-file-changes
	fswatch -rv $(1) | xargs -I {} sh -c '$(call $(2))'
endef

define build-command
	$(wd)/build.sh
endef

spoon:
	$(call build-command)
	cp -r $(wd)/dist/build $(wd)/dist/Tack.spoon
	zip -r dist/Tack.spoon.zip $(wd)/dist/Tack.spoon

dev:
	$(call build-command)

watch-dev:
	$(call monitor-file-changes,$(wd)/src,build-command)

deps:
	luarocks install --lua-version 5.4 --tree deps fsm 1.1.0-1
	luarocks install --lua-version 5.4 --tree deps lustache 1.3.1-0
	luarocks install --lua-version 5.4 --tree deps middleclass 4.1.1-0

clean:
	rm -rfv $(wd)/dist
