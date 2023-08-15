
.PHONY: install test lint clean build all
.ONESHELL:

install:
	pip install -r requirements-dev.txt
	pip install -r requirements.txt

TARGET ?= test
test:
	pytest --cov=Function --cov=shared_code --no-cov-on-fail --cov-report term-missing --junit-xml=unittest_output.xml $(TARGET)

lint:
	flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics

lint-hard:
	flake8 . --count --exit-zero --max-complexity=10 --max-line-length=127 --statistics

COVLINT_FILES = cov.xml coverage.xml pytest-report.xml pylint-report.txt htmlcov unittest*.xml
clean:
	rm -rf $(COVLINT_FILES) 
	rm -rf dist
	rm -rf build
	rm -rf *.egg-info
	rm -rf .pytest_cache
	find . -name '*.pyc' -delete
	find . -name '__pycache__' -delete
	find . -name '.pytest_cache' -delete
	find . -name '.egg-info' -delete
	find . -name 'build' -delete
	find . -name 'unittest_output.xml' -delete
	find . -name '.coverage' -delete

build:
	python -m build --sdist

all: clean test lint install
