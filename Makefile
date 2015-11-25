

REBAR := ./rebar

all:get-deps compile run

get-deps:
	@$(REBAR) get-deps

compile:
	@$(REBAR) compile

run:
	erl -pa ./deps/*/ebin -pa ./ebin

