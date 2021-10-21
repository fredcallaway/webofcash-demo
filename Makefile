dev:
	coffee -o static/js -cbw src/* &
	env/bin/python herokuapp.py

local:
	env/bin/python herokuapp.py

js:
	coffee -o static/js -cb src/*

watch:
	coffee -o static/js -cbw src/*