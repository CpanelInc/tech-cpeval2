PROJECT=cpeval2
SHELL=/bin/sh
PATH=/usr/local/cpanel/3rdparty/perl/524/bin:/usr/local/cpanel/3rdparty/bin:/usr/sbin:/usr/bin
PERLCRITIC=perlcritic
PERLCRITICRC=tools/.perlcriticrc
PERLTIDY=perltidy
PERLTIDYRC=tools/.perltidyrc
NEW_VER=$(shell grep 'my $$VERSION' $(PROJECT) | awk '{print $$4}' | sed -e "s/'//g" -e 's/;//')
NEW_SHASUM_CMD=shasum -a 512 $(PROJECT) | awk '{print $$1}'
NEW_SHASUM_SUFFIX=    cpeval2 $(NEW_VER)

.DEFAULT: help
.IGNORE: clean
.PHONY: all clean help test tidy
.PRECIOUS: $(PROJECT)
.SILENT: all help SHA512SUM $(PROJECT).tdy test tidy

# A line beginning with a double hash mark is used to provide help text for the target that follows it when running 'make help' or 'make'.  The help target must be first.
# "Invisible" targets should not be marked with help text.

## Show this help
help:
	printf "\nAvailable targets:\n"
	awk '/^[a-zA-Z\-\_0-9]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")-1); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf "%-15s - %s\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)
	printf "\n"

## Make $(PROJECT) ready for commit
all: SHA512SUM
	
## Clean up
clean:
	$(RM) $(PROJECT).tdy

## Add new $(PROJECT) version to SHA512SUM file
SHA512SUM: tidy
	if ( egrep -q '$(NEW_VER)$$' SHA512SUM ); then \
		echo "Version $(NEW_VER) already exists in SHA512SUM!"; \
		exit 2; \
	else \
		sed -i '1i$(shell $(NEW_SHASUM_CMD))$(NEW_VER_SUFFIX)' SHA512SUM && echo "Updated SHA512SUM"; \
	fi

$(PROJECT).tdy: $(PROJECT)
	which $(PERLTIDY) | egrep -q '/usr/local/cpanel' || echo "cPanel perltidy not found!  Are you running this on a WHM 64+ system?"
	echo "-- Running tidy"
	$(PERLTIDY) --profile=$(PERLTIDYRC) $(PROJECT)

## Run basic tests
test:
	[ -e /usr/local/cpanel/version ] || ( echo "You're not running this on a WHM system."; exit 2 )
	echo "-- Running perl syntax check"
	perl -c $(PROJECT) || ( echo "$(PROJECT) perl syntax check failed"; exit 2 )
	echo "-- Running perlcritic"
	$(PERLCRITIC) --profile $(PERLCRITICRC) $(PROJECT)

## Run perltidy on $(PROJECT), compare, and ask for overwrite
tidy: test $(PROJECT).tdy
	echo "-- Checking if tidy"
	if ( diff -u $(PROJECT) $(PROJECT).tdy > /dev/null ); then \
		echo "$(PROJECT) is tidy."; \
		exit 0; \
	else \
		diff -u $(PROJECT) $(PROJECT).tdy | less -F; \
		cp -i $(PROJECT).tdy $(PROJECT); \
		if ( diff -u $(PROJECT) $(PROJECT).tdy > /dev/null ); then \
			echo "$(PROJECT) is tidy."; \
			exit 0; \
		else \
			echo "$(PROJECT) is NOT tidy."; \
			exit 2; \
		fi; \
	fi;
