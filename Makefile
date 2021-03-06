export PIPENV_VERBOSITY=-1

# get version string
version  = $(shell cat poseur.py | grep "^__version__" | sed "s/__version__ = '\(.*\)'/\1/")

after: git-after
clean: pypi-clean
pipenv: pipenv-update
maintainer: update-maintainer

dist: pipenv test pypi setup github formula maintainer after
github: git-upload git-release
pypi: pypi-dist pypi-upload
setup: setup-sync setup-manual

coverage:
	pipenv run coverage run tests/test.py
	pipenv run coverage html
	open htmlcov/index.html
	echo "Press ENTER to continue..."
	read
	rm -rf htmlcov
	rm .coverage

.ONESHELL:
formula: setup-formula
	set -ae
	cd Tap
	git pull
	git add Formula/poseur.rb
	git commit -S -m "poseur: $(version)"
	git push

test:
	pipenv run python tests/test.py
	rm -rf archive

ln-prep:
	rm -f setup.py
	cp scripts/setup.${name}.py setup.py

ln-post:
	rm -f setup.py
	ln -s scripts/setup.pypi.py setup.py

pipenv-init:
	pipenv install --dev \
	    autopep8 \
	    codecov \
	    coverage \
	    doc8 \
	    pylint \
	    sphinx

pipenv-update:
	$(MAKE) name="pypi" ln-prep
	pipenv run pip install -U \
	    pip \
	    setuptools \
	    wheel
	while true; do \
            pipenv update && break ; \
        done
	pipenv install --dev
	pipenv clean
	$(MAKE) ln-post

pipenv-deinit:
	pipenv --rm

update-maintainer:
	go run github.com/gaocegege/maintainer changelog
	go run github.com/gaocegege/maintainer contributor
	go run github.com/gaocegege/maintainer contributing

pypi-clean:
	mkdir -p dist sdist eggs wheels
	[ -d dist ] && find dist -iname '*.egg' -exec mv {} eggs \; || true
	[ -d dist ] && find dist -iname '*.whl' -exec mv {} wheels \; || true
	[ -d dist ] && find dist -iname '*.tar.gz' -exec mv {} sdist \; || true
	rm -rf build dist *.egg-info

pypi-dist: pypi-clean setup-sync dist-pypi dist-pypitest

dist-pypi: pypi-clean setup-sync
	$(MAKE) name="pypi" ln-prep
	pipenv run python setup.py sdist bdist_wheel
	$(MAKE) ln-post

dist-pypitest: pypi-clean setup-sync
	$(MAKE) name="pypitest" ln-prep
	pipenv run python setup.py sdist bdist_wheel
	$(MAKE) ln-post

pypi-register: pypi-dist
	twine check dist/* || true
	twine register dist/*.whl -r pypi --skip-existing
	twine register dist/python*.whl -r pypitest --skip-existing

pypi-upload:
	twine check dist/* || true
	twine upload dist/* -r pypi --skip-existing
	twine upload dist/python* -r pypitest --skip-existing

setup-version:
	pipenv run python scripts/setup-version.py

setup-sync: setup-version
	pipenv run python scripts/setup-sync.py

setup-formula: setup-version pipenv-update
	pipenv run python scripts/setup-formula.py

setup-manual: setup-version
	pipenv run rst2man.py share/poseur.rst > share/poseur.1

git-upload:
	git pull
	git add .
	git commit -S
	git push

git-after:
	git pull
	git add .
	git commit -S -m "Regular update after distribution"
	git push

git-release:
	go run github.com/aktau/github-release release \
	    --user pybpc \
	    --repo poseur \
	    --tag "v$(version)" \
	    --name "poseur v$(version)" \
	    --description "$$(git log -1 --pretty=%B)"
