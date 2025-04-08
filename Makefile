.PHONY: up logs down gen

up:
	./setup.sh up

logs:
	./setup.sh logs

down:
	./setup.sh down

gen:
	./generate_events.sh